#include "core/nearby/nearby_connection.hpp"

#include <algorithm>
#include <limits>
#include <stdexcept>
#include <utility>

namespace ohmytypeless {

namespace {

constexpr std::size_t kMaxControlMessageSize = 16U * 1024U;

bool valid_identifier(std::string_view value, std::size_t maximum_size) {
    if (value.empty() || value.size() > maximum_size) {
        return false;
    }
    return std::all_of(value.cbegin(), value.cend(), [](unsigned char character) {
        return character >= 0x21U && character <= 0x7EU;
    });
}

bool valid_display_text(std::string_view value, std::size_t maximum_size) {
    return !value.empty() && value.size() <= maximum_size && value.find('\0') == std::string_view::npos &&
           value.find('\n') == std::string_view::npos && value.find('\r') == std::string_view::npos;
}

std::optional<std::string> required_string(const nlohmann::json& object,
                                           const char* key,
                                           std::size_t maximum_size) {
    if (!object.is_object() || !object.contains(key) || !object.at(key).is_string()) {
        return std::nullopt;
    }
    std::string value = object.at(key).get<std::string>();
    if (value.empty() || value.size() > maximum_size) {
        return std::nullopt;
    }
    return value;
}

std::optional<std::uint32_t> required_uint32(const nlohmann::json& object, const char* key) {
    if (!object.is_object() || !object.contains(key) ||
        (!object.at(key).is_number_unsigned() && !object.at(key).is_number_integer())) {
        return std::nullopt;
    }
    if (object.at(key).is_number_unsigned()) {
        const auto value = object.at(key).get<std::uint64_t>();
        if (value == 0U || value > std::numeric_limits<std::uint32_t>::max()) {
            return std::nullopt;
        }
        return static_cast<std::uint32_t>(value);
    }
    const auto value = object.at(key).get<std::int64_t>();
    return value > 0 && value <= std::numeric_limits<std::uint32_t>::max()
               ? std::optional<std::uint32_t>(static_cast<std::uint32_t>(value))
               : std::nullopt;
}

nlohmann::json pairing_status_response(NearbyPairingStatus status, int attempts_remaining) {
    switch (status) {
    case NearbyPairingStatus::Unavailable:
        return {{"type", "pairing.error"}, {"code", "pairing_unavailable"}};
    case NearbyPairingStatus::Expired:
        return {{"type", "pairing.error"}, {"code", "pairing_expired"}};
    case NearbyPairingStatus::InvalidClient:
        return {{"type", "pairing.error"}, {"code", "invalid_client"}};
    case NearbyPairingStatus::InvalidProof:
        return {{"type", "pairing.error"},
                {"code", "invalid_proof"},
                {"attempts_remaining", attempts_remaining}};
    case NearbyPairingStatus::AttemptsExhausted:
        return {{"type", "pairing.error"}, {"code", "attempts_exhausted"}, {"attempts_remaining", 0}};
    case NearbyPairingStatus::Paired:
        break;
    }
    return {{"type", "pairing.error"}, {"code", "pairing_failed"}};
}

std::string auth_status_code(NearbyAuthStatus status) {
    switch (status) {
    case NearbyAuthStatus::UnknownClient:
        return "unknown_client";
    case NearbyAuthStatus::InvalidChallenge:
        return "invalid_challenge";
    case NearbyAuthStatus::Expired:
        return "challenge_expired";
    case NearbyAuthStatus::InvalidProof:
        return "invalid_proof";
    case NearbyAuthStatus::Authenticated:
        break;
    }
    return "authentication_failed";
}

}  // namespace

NearbyConnectionSession::NearbyConnectionSession(NearbyPairingService& pairing_service,
                                                 PushAudioSink& audio_sink,
                                                 bool secure_transport)
    : pairing_service_(pairing_service), audio_sink_(audio_sink), secure_transport_(secure_transport) {}

NearbyConnectionResult NearbyConnectionSession::handle_text(std::string_view message, std::int64_t now_ms) {
    if (message.empty() || message.size() > kMaxControlMessageSize) {
        return protocol_error("invalid_message_size", "Control message size is invalid.", true);
    }

    nlohmann::json document;
    try {
        document = nlohmann::json::parse(message);
    } catch (const nlohmann::json::exception&) {
        return protocol_error("invalid_json", "Control message is not valid JSON.", true);
    }
    if (!document.is_object()) {
        return protocol_error("invalid_message", "Control message must be a JSON object.", true);
    }

    const auto type = required_string(document, "type", 64U);
    if (!type.has_value()) {
        return protocol_error("missing_type", "Control message type is required.", true);
    }
    if (*type == "hello") {
        return handle_hello(document, now_ms);
    }
    if (!hello_received_ || !client_.has_value()) {
        return protocol_error("hello_required", "Send hello before other control messages.", true);
    }
    if (*type == "pairing.refresh") {
        return handle_pairing_refresh(now_ms);
    }
    if (*type == "pairing.prove") {
        return handle_pairing_proof(document, now_ms);
    }
    if (*type == "auth.prove") {
        return handle_authentication_proof(document, now_ms);
    }
    if (*type == "ping") {
        return {.response = nlohmann::json{{"type", "pong"}}};
    }
    if (!authenticated_) {
        return protocol_error("authentication_required", "Authenticate before starting audio.");
    }
    if (*type == "audio.start") {
        return handle_audio_start(document);
    }
    if (*type == "audio.stop") {
        return handle_audio_stop(document);
    }
    return protocol_error("unknown_type", "Control message type is not supported.");
}

NearbyConnectionResult NearbyConnectionSession::handle_binary(std::span<const std::byte> message) {
    if (!authenticated_ || audio_session_ == nullptr) {
        return protocol_error("authentication_required", "Authenticate before sending audio.", true);
    }
    const NearbyAudioFrameResult result = audio_session_->accept_frame(message);
    if (result.status == NearbyAudioFrameStatus::Accepted) {
        if (result.missing_frames == 0U) {
            return {};
        }
        return {.response = nlohmann::json{{"type", "audio.gap"},
                                          {"stream_id", audio_session_->stream_id()},
                                          {"missing_frames", result.missing_frames}}};
    }

    std::string code;
    switch (result.status) {
    case NearbyAudioFrameStatus::Malformed:
        code = "malformed_frame";
        break;
    case NearbyAudioFrameStatus::NoActiveStream:
        code = "stream_not_started";
        break;
    case NearbyAudioFrameStatus::StaleStream:
        code = "stale_stream";
        break;
    case NearbyAudioFrameStatus::Replayed:
        code = "replayed_frame";
        break;
    case NearbyAudioFrameStatus::SinkRejected:
        code = "audio_rejected";
        break;
    case NearbyAudioFrameStatus::Accepted:
        break;
    }
    return protocol_error(std::move(code), result.error, result.status == NearbyAudioFrameStatus::SinkRejected);
}

void NearbyConnectionSession::disconnect() {
    if (audio_session_ != nullptr) {
        audio_session_->disconnect();
    }
    authenticated_ = false;
}

bool NearbyConnectionSession::authenticated() const {
    return authenticated_;
}

std::optional<std::string> NearbyConnectionSession::client_id() const {
    return client_.has_value() ? std::optional<std::string>(client_->client_id) : std::nullopt;
}

NearbyConnectionResult NearbyConnectionSession::handle_hello(const nlohmann::json& message, std::int64_t now_ms) {
    if (hello_received_) {
        return protocol_error("duplicate_hello", "A connection may send hello only once.", true);
    }
    if (!message.contains("protocol_version") || !message.at("protocol_version").is_number_integer() ||
        message.at("protocol_version").get<std::int64_t>() != kNearbyProtocolVersion ||
        !message.contains("client") || !message.at("client").is_object()) {
        return protocol_error("unsupported_protocol", "Nearby protocol version 1 is required.", true);
    }

    const nlohmann::json& client_document = message.at("client");
    const auto client_id = required_string(client_document, "id", 128U);
    const auto display_name = required_string(client_document, "name", 160U);
    const auto client_kind = required_string(client_document, "kind", 32U);
    if (!client_id.has_value() || !display_name.has_value() || !client_kind.has_value() ||
        !valid_identifier(*client_id, 128U) || !valid_display_text(*display_name, 160U) ||
        !valid_identifier(*client_kind, 32U)) {
        return protocol_error("invalid_client", "Client identity is invalid.", true);
    }

    hello_received_ = true;
    client_ = NearbyClientIdentity{
        .client_id = *client_id,
        .display_name = *display_name,
        .client_kind = *client_kind,
    };
    audio_session_ = std::make_unique<NearbyAudioSession>(audio_sink_, *client_);

    pending_auth_challenge_ = pairing_service_.begin_authentication(client_->client_id, now_ms);
    if (pending_auth_challenge_.has_value()) {
        return {.response = nlohmann::json{{"type", "auth.challenge"},
                                          {"protocol_version", kNearbyProtocolVersion},
                                          {"challenge_id", pending_auth_challenge_->challenge_id},
                                          {"nonce", pending_auth_challenge_->nonce_hex},
                                          {"expires_at_ms", pending_auth_challenge_->expires_at_ms}}};
    }
    return pairing_prompt(now_ms);
}

NearbyConnectionResult NearbyConnectionSession::handle_pairing_refresh(std::int64_t now_ms) const {
    if (authenticated_) {
        return protocol_error("already_authenticated", "This connection is already authenticated.");
    }
    return pairing_prompt(now_ms);
}

NearbyConnectionResult NearbyConnectionSession::handle_pairing_proof(const nlohmann::json& message,
                                                                     std::int64_t now_ms) {
    if (authenticated_) {
        return protocol_error("already_authenticated", "This connection is already authenticated.");
    }
    if (!secure_transport_) {
        return protocol_error("secure_transport_required",
                              "Pairing and audio require TLS or a loopback-only connection.",
                              true);
    }
    const auto pairing_id = required_string(message, "pairing_id", 64U);
    const auto proof = required_string(message, "proof", 128U);
    if (!pairing_id.has_value() || !proof.has_value()) {
        return protocol_error("invalid_pairing_proof", "Pairing ID and proof are required.");
    }

    const NearbyPairingResult result =
        pairing_service_.pair_client(*client_, *pairing_id, *proof, now_ms);
    if (result.status != NearbyPairingStatus::Paired) {
        return {.response = pairing_status_response(result.status, result.attempts_remaining)};
    }

    authenticated_ = true;
    pending_auth_challenge_.reset();
    return {.response = nlohmann::json{{"type", "pairing.accepted"},
                                      {"protocol_version", kNearbyProtocolVersion},
                                      {"credential", result.credential_hex}}};
}

NearbyConnectionResult NearbyConnectionSession::handle_authentication_proof(const nlohmann::json& message,
                                                                            std::int64_t now_ms) {
    if (authenticated_) {
        return protocol_error("already_authenticated", "This connection is already authenticated.");
    }
    const auto challenge_id = required_string(message, "challenge_id", 64U);
    const auto proof = required_string(message, "proof", 128U);
    if (!pending_auth_challenge_.has_value() || !challenge_id.has_value() || !proof.has_value() ||
        *challenge_id != pending_auth_challenge_->challenge_id) {
        return protocol_error("invalid_challenge", "Authentication challenge is invalid.", true);
    }

    const NearbyAuthStatus status =
        pairing_service_.authenticate(client_->client_id, *challenge_id, *proof, now_ms);
    pending_auth_challenge_.reset();
    if (status != NearbyAuthStatus::Authenticated) {
        return protocol_error(auth_status_code(status), "Authentication failed.", true);
    }
    authenticated_ = true;
    return {.response = nlohmann::json{{"type", "auth.accepted"},
                                      {"protocol_version", kNearbyProtocolVersion}}};
}

NearbyConnectionResult NearbyConnectionSession::handle_audio_start(const nlohmann::json& message) {
    const auto stream_id = required_uint32(message, "stream_id");
    if (!stream_id.has_value() || !message.contains("format") || !message.at("format").is_object()) {
        return protocol_error("invalid_audio_start", "Audio stream ID and format are required.");
    }
    const nlohmann::json& format_document = message.at("format");
    const auto encoding = required_string(format_document, "encoding", 32U);
    const auto sample_rate = required_uint32(format_document, "sample_rate_hz");
    const auto channels = required_uint32(format_document, "channels");
    if (!encoding.has_value() || *encoding != "pcm16le" || !sample_rate.has_value() ||
        *sample_rate != kNearbySampleRate || !channels.has_value() || *channels != kNearbyChannelCount) {
        return protocol_error("unsupported_audio_format", "Audio must be mono PCM16LE at 16 kHz.");
    }

    std::string profile_id;
    if (message.contains("profile_id")) {
        if (!message.at("profile_id").is_string()) {
            return protocol_error("invalid_profile", "Profile ID must be a string.");
        }
        profile_id = message.at("profile_id").get<std::string>();
        if (profile_id.size() > 128U || profile_id.find('\0') != std::string::npos) {
            return protocol_error("invalid_profile", "Profile ID is invalid.");
        }
    }

    std::string error;
    const PushAudioFormat format{
        .encoding = PushAudioEncoding::Pcm16Le,
        .sample_rate_hz = *sample_rate,
        .channel_count = static_cast<std::uint16_t>(*channels),
    };
    if (!audio_session_->start(*stream_id, format, std::move(profile_id), &error)) {
        return protocol_error("audio_start_rejected", error);
    }
    return {.response = nlohmann::json{{"type", "audio.ready"}, {"stream_id", *stream_id}}};
}

NearbyConnectionResult NearbyConnectionSession::handle_audio_stop(const nlohmann::json& message) {
    const auto stream_id = required_uint32(message, "stream_id");
    if (!stream_id.has_value()) {
        return protocol_error("invalid_audio_stop", "Audio stream ID is required.");
    }
    std::string error;
    if (!audio_session_->stop(*stream_id, &error)) {
        return protocol_error("audio_stop_rejected", error);
    }
    return {.response = nlohmann::json{{"type", "audio.stopped"}, {"stream_id", *stream_id}}};
}

NearbyConnectionResult NearbyConnectionSession::pairing_prompt(std::int64_t now_ms) const {
    const auto offer = pairing_service_.active_pairing(now_ms);
    if (!offer.has_value()) {
        return {.response = nlohmann::json{{"type", "pairing.unavailable"},
                                          {"protocol_version", kNearbyProtocolVersion}}};
    }
    return {.response = nlohmann::json{{"type", "pairing.required"},
                                      {"protocol_version", kNearbyProtocolVersion},
                                      {"pairing_id", offer->pairing_id},
                                      {"expires_at_ms", offer->expires_at_ms},
                                      {"attempts_remaining", offer->attempts_remaining}}};
}

NearbyConnectionResult NearbyConnectionSession::protocol_error(std::string code,
                                                                std::string message,
                                                                bool close) const {
    if (message.empty()) {
        message = "Nearby protocol error.";
    }
    if (message.size() > 256U) {
        message.resize(256U);
    }
    return {
        .response = nlohmann::json{{"type", "error"}, {"code", std::move(code)}, {"message", std::move(message)}},
        .close_connection = close,
        .close_code = 1008,
        .close_reason = "Nearby protocol violation",
    };
}

}  // namespace ohmytypeless
