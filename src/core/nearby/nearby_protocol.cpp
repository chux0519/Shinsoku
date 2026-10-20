#include "core/nearby/nearby_protocol.hpp"

#include <mbedtls/ctr_drbg.h>
#include <mbedtls/entropy.h>
#include <mbedtls/md.h>

#include <nlohmann/json.hpp>

#include <algorithm>
#include <array>
#include <fstream>
#include <limits>
#include <stdexcept>
#include <string_view>
#include <system_error>
#include <unordered_set>
#include <utility>

#ifndef _WIN32
#include <sys/stat.h>
#endif

namespace ohmytypeless {

namespace {

constexpr std::array<std::byte, 4> kAudioMagic{
    std::byte{'S'},
    std::byte{'N'},
    std::byte{'P'},
    std::byte{'A'},
};
constexpr std::uint16_t kAudioHeaderSize = 20;
constexpr int kPairingAttempts = 5;

std::vector<std::uint8_t> secure_random_bytes(std::size_t size) {
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context generator;
    mbedtls_entropy_init(&entropy);
    mbedtls_ctr_drbg_init(&generator);

    constexpr std::string_view personalization = "shinsoku-nearby-v1";
    const int seed_result = mbedtls_ctr_drbg_seed(
        &generator,
        mbedtls_entropy_func,
        &entropy,
        reinterpret_cast<const unsigned char*>(personalization.data()),
        personalization.size());
    if (seed_result != 0) {
        mbedtls_ctr_drbg_free(&generator);
        mbedtls_entropy_free(&entropy);
        throw std::runtime_error("failed to initialize the nearby secure random generator");
    }

    std::vector<std::uint8_t> bytes(size);
    const int random_result = mbedtls_ctr_drbg_random(&generator, bytes.data(), bytes.size());
    mbedtls_ctr_drbg_free(&generator);
    mbedtls_entropy_free(&entropy);
    if (random_result != 0) {
        throw std::runtime_error("failed to generate nearby authentication material");
    }
    return bytes;
}

std::string hex_encode(std::span<const std::uint8_t> bytes) {
    static constexpr char digits[] = "0123456789abcdef";
    std::string output;
    output.reserve(bytes.size() * 2U);
    for (const std::uint8_t byte : bytes) {
        output.push_back(digits[(byte >> 4U) & 0x0FU]);
        output.push_back(digits[byte & 0x0FU]);
    }
    return output;
}

std::optional<std::vector<std::uint8_t>> hex_decode(std::string_view text) {
    if ((text.size() % 2U) != 0U) {
        return std::nullopt;
    }

    auto nibble = [](char character) -> std::optional<std::uint8_t> {
        if (character >= '0' && character <= '9') {
            return static_cast<std::uint8_t>(character - '0');
        }
        if (character >= 'a' && character <= 'f') {
            return static_cast<std::uint8_t>(character - 'a' + 10);
        }
        if (character >= 'A' && character <= 'F') {
            return static_cast<std::uint8_t>(character - 'A' + 10);
        }
        return std::nullopt;
    };

    std::vector<std::uint8_t> output;
    output.reserve(text.size() / 2U);
    for (std::size_t index = 0; index < text.size(); index += 2U) {
        const auto high = nibble(text[index]);
        const auto low = nibble(text[index + 1U]);
        if (!high.has_value() || !low.has_value()) {
            return std::nullopt;
        }
        output.push_back(static_cast<std::uint8_t>((*high << 4U) | *low));
    }
    return output;
}

std::array<std::uint8_t, 32> sha256(std::span<const std::uint8_t> input) {
    const mbedtls_md_info_t* info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
    if (info == nullptr) {
        throw std::runtime_error("SHA-256 is unavailable");
    }

    std::array<std::uint8_t, 32> digest{};
    if (mbedtls_md(info, input.data(), input.size(), digest.data()) != 0) {
        throw std::runtime_error("SHA-256 failed");
    }
    return digest;
}

std::array<std::uint8_t, 32> hmac_sha256(std::span<const std::uint8_t> key, std::string_view message) {
    const mbedtls_md_info_t* info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
    if (info == nullptr) {
        throw std::runtime_error("HMAC-SHA-256 is unavailable");
    }

    std::array<std::uint8_t, 32> digest{};
    if (mbedtls_md_hmac(info,
                        key.data(),
                        key.size(),
                        reinterpret_cast<const unsigned char*>(message.data()),
                        message.size(),
                        digest.data()) != 0) {
        throw std::runtime_error("HMAC-SHA-256 failed");
    }
    return digest;
}

bool constant_time_equal(std::string_view left, std::string_view right) {
    const std::size_t maximum = std::max(left.size(), right.size());
    unsigned char difference = static_cast<unsigned char>(left.size() ^ right.size());
    for (std::size_t index = 0; index < maximum; ++index) {
        const unsigned char left_byte = index < left.size() ? static_cast<unsigned char>(left[index]) : 0U;
        const unsigned char right_byte = index < right.size() ? static_cast<unsigned char>(right[index]) : 0U;
        difference = static_cast<unsigned char>(difference | (left_byte ^ right_byte));
    }
    return difference == 0U;
}

std::string pairing_payload(const std::string& pairing_id, const std::string& client_id) {
    return "shinsoku-nearby-pair/v1\n" + pairing_id + "\n" + client_id;
}

std::string authentication_payload(const NearbyAuthChallenge& challenge, const std::string& client_id) {
    return "shinsoku-nearby-auth/v1\n" + challenge.challenge_id + "\n" + challenge.nonce_hex + "\n" + client_id;
}

bool valid_identifier(std::string_view value, std::size_t maximum_size) {
    if (value.empty() || value.size() > maximum_size) {
        return false;
    }
    return std::all_of(value.cbegin(), value.cend(), [](unsigned char character) {
        return character >= 0x21U && character <= 0x7EU;
    });
}

bool valid_display_text(std::string_view value, std::size_t maximum_size) {
    return !value.empty() && value.size() <= maximum_size &&
           value.find('\0') == std::string_view::npos && value.find('\n') == std::string_view::npos &&
           value.find('\r') == std::string_view::npos;
}

void restrict_file_permissions(const std::filesystem::path& path) {
#ifndef _WIN32
    if (::chmod(path.c_str(), S_IRUSR | S_IWUSR) != 0) {
        throw std::runtime_error("failed to restrict nearby trust-store permissions");
    }
#else
    static_cast<void>(path);
#endif
}

void append_be16(std::vector<std::byte>& output, std::uint16_t value) {
    output.push_back(static_cast<std::byte>((value >> 8U) & 0xFFU));
    output.push_back(static_cast<std::byte>(value & 0xFFU));
}

void append_be32(std::vector<std::byte>& output, std::uint32_t value) {
    output.push_back(static_cast<std::byte>((value >> 24U) & 0xFFU));
    output.push_back(static_cast<std::byte>((value >> 16U) & 0xFFU));
    output.push_back(static_cast<std::byte>((value >> 8U) & 0xFFU));
    output.push_back(static_cast<std::byte>(value & 0xFFU));
}

std::uint16_t read_be16(std::span<const std::byte> bytes, std::size_t offset) {
    return static_cast<std::uint16_t>((std::to_integer<std::uint8_t>(bytes[offset]) << 8U) |
                                      std::to_integer<std::uint8_t>(bytes[offset + 1U]));
}

std::uint32_t read_be32(std::span<const std::byte> bytes, std::size_t offset) {
    return (static_cast<std::uint32_t>(std::to_integer<std::uint8_t>(bytes[offset])) << 24U) |
           (static_cast<std::uint32_t>(std::to_integer<std::uint8_t>(bytes[offset + 1U])) << 16U) |
           (static_cast<std::uint32_t>(std::to_integer<std::uint8_t>(bytes[offset + 2U])) << 8U) |
           static_cast<std::uint32_t>(std::to_integer<std::uint8_t>(bytes[offset + 3U]));
}

void set_decode_error(std::string* error, std::string message) {
    if (error != nullptr) {
        *error = std::move(message);
    }
}

}  // namespace

NearbyTrustStore::NearbyTrustStore(std::filesystem::path path) : path_(std::move(path)) {}

void NearbyTrustStore::load() {
    clients_.clear();
    if (!std::filesystem::exists(path_)) {
        return;
    }

    std::ifstream input(path_);
    if (!input) {
        throw std::runtime_error("failed to open the nearby trust store");
    }

    const nlohmann::json document = nlohmann::json::parse(input);
    if (!document.is_object() || document.value("schema_version", 0) != 1 ||
        !document.contains("clients") || !document.at("clients").is_array()) {
        throw std::runtime_error("the nearby trust store has an unsupported schema");
    }

    std::unordered_set<std::string> client_ids;
    for (const auto& item : document.at("clients")) {
        NearbyTrustedClient client{
            .identity = {
                .client_id = item.at("client_id").get<std::string>(),
                .display_name = item.at("display_name").get<std::string>(),
                .client_kind = item.at("client_kind").get<std::string>(),
            },
            .credential_verifier_hex = item.at("credential_verifier").get<std::string>(),
            .created_at_ms = item.at("created_at_ms").get<std::int64_t>(),
            .last_seen_at_ms = item.at("last_seen_at_ms").get<std::int64_t>(),
        };
        if (valid_identifier(client.identity.client_id, 128U) &&
            valid_display_text(client.identity.display_name, 160U) &&
            valid_identifier(client.identity.client_kind, 32U) &&
            client.credential_verifier_hex.size() == 64U && hex_decode(client.credential_verifier_hex).has_value() &&
            client_ids.insert(client.identity.client_id).second) {
            clients_.push_back(std::move(client));
            continue;
        }
        throw std::runtime_error("the nearby trust store contains an invalid client");
    }
}

void NearbyTrustStore::save() const {
    if (path_.empty()) {
        throw std::runtime_error("the nearby trust-store path is empty");
    }
    if (!path_.parent_path().empty()) {
        std::filesystem::create_directories(path_.parent_path());
    }

    nlohmann::json document{
        {"schema_version", 1},
        {"clients", nlohmann::json::array()},
    };
    for (const NearbyTrustedClient& client : clients_) {
        document["clients"].push_back({
            {"client_id", client.identity.client_id},
            {"display_name", client.identity.display_name},
            {"client_kind", client.identity.client_kind},
            {"credential_verifier", client.credential_verifier_hex},
            {"created_at_ms", client.created_at_ms},
            {"last_seen_at_ms", client.last_seen_at_ms},
        });
    }

    std::filesystem::path temporary = path_;
    temporary += ".tmp";
    {
        std::ofstream output(temporary, std::ios::trunc);
        if (!output) {
            throw std::runtime_error("failed to create the nearby trust store");
        }
        output << document.dump(2) << '\n';
        output.flush();
        if (!output) {
            throw std::runtime_error("failed to write the nearby trust store");
        }
    }
    restrict_file_permissions(temporary);

    std::error_code error;
    std::filesystem::rename(temporary, path_, error);
    if (error) {
        std::filesystem::remove(path_, error);
        error.clear();
        std::filesystem::rename(temporary, path_, error);
    }
    if (error) {
        std::filesystem::remove(temporary);
        throw std::runtime_error("failed to replace the nearby trust store");
    }
    restrict_file_permissions(path_);
}

const std::filesystem::path& NearbyTrustStore::path() const {
    return path_;
}

const std::vector<NearbyTrustedClient>& NearbyTrustStore::clients() const {
    return clients_;
}

std::optional<NearbyTrustedClient> NearbyTrustStore::find(const std::string& client_id) const {
    const auto iterator = std::find_if(clients_.cbegin(), clients_.cend(), [&](const NearbyTrustedClient& client) {
        return client.identity.client_id == client_id;
    });
    return iterator == clients_.cend() ? std::nullopt : std::optional<NearbyTrustedClient>(*iterator);
}

void NearbyTrustStore::upsert(NearbyTrustedClient client) {
    const auto iterator = std::find_if(clients_.begin(), clients_.end(), [&](const NearbyTrustedClient& candidate) {
        return candidate.identity.client_id == client.identity.client_id;
    });
    if (iterator == clients_.end()) {
        clients_.push_back(std::move(client));
    } else {
        *iterator = std::move(client);
    }
}

bool NearbyTrustStore::revoke(const std::string& client_id) {
    const auto old_size = clients_.size();
    std::erase_if(clients_, [&](const NearbyTrustedClient& client) {
        return client.identity.client_id == client_id;
    });
    return clients_.size() != old_size;
}

NearbyPairingService::NearbyPairingService(NearbyTrustStore& trust_store, RandomBytes random_bytes)
    : trust_store_(trust_store),
      random_bytes_(random_bytes ? std::move(random_bytes) : RandomBytes(secure_random_bytes)) {}

NearbyPairingOffer NearbyPairingService::open_pairing(std::int64_t now_ms, std::int64_t lifetime_ms) {
    std::scoped_lock lock(mutex_);
    if (lifetime_ms <= 0) {
        throw std::invalid_argument("nearby pairing lifetime must be positive");
    }
    const std::vector<std::uint8_t> bytes = random(17U);
    pairing_ = NearbyPairingOffer{
        .pairing_id = hex_encode(std::span<const std::uint8_t>(bytes.data(), 16U)),
        .display_code = (bytes[16] % 100U < 10U ? "0" : "") + std::to_string(bytes[16] % 100U),
        .expires_at_ms = now_ms + lifetime_ms,
        .attempts_remaining = kPairingAttempts,
    };
    return *pairing_;
}

void NearbyPairingService::close_pairing() {
    std::scoped_lock lock(mutex_);
    pairing_.reset();
}

std::optional<NearbyPairingOffer> NearbyPairingService::active_pairing(std::int64_t now_ms) const {
    std::scoped_lock lock(mutex_);
    if (!pairing_.has_value() || now_ms >= pairing_->expires_at_ms || pairing_->attempts_remaining <= 0) {
        return std::nullopt;
    }
    return pairing_;
}

NearbyPairingResult NearbyPairingService::pair_client(const NearbyClientIdentity& client,
                                                      const std::string& pairing_id,
                                                      const std::string& proof_hex,
                                                      std::int64_t now_ms) {
    std::scoped_lock lock(mutex_);
    if (!valid_client(client)) {
        return {.status = NearbyPairingStatus::InvalidClient};
    }
    if (!pairing_.has_value()) {
        return {.status = NearbyPairingStatus::Unavailable};
    }
    if (now_ms >= pairing_->expires_at_ms) {
        pairing_.reset();
        return {.status = NearbyPairingStatus::Expired};
    }

    const std::string expected = pairing_proof(pairing_->display_code, pairing_->pairing_id, client.client_id);
    if (!constant_time_equal(pairing_id, pairing_->pairing_id) || !constant_time_equal(proof_hex, expected)) {
        --pairing_->attempts_remaining;
        const int attempts_remaining = pairing_->attempts_remaining;
        if (attempts_remaining <= 0) {
            pairing_.reset();
            return {.status = NearbyPairingStatus::AttemptsExhausted, .attempts_remaining = 0};
        }
        return {.status = NearbyPairingStatus::InvalidProof, .attempts_remaining = attempts_remaining};
    }

    const std::vector<std::uint8_t> credential = random(32U);
    const auto verifier = sha256(credential);
    trust_store_.upsert(NearbyTrustedClient{
        .identity = client,
        .credential_verifier_hex = hex_encode(verifier),
        .created_at_ms = now_ms,
        .last_seen_at_ms = now_ms,
    });
    trust_store_.save();

    NearbyPairingResult result{
        .status = NearbyPairingStatus::Paired,
        .credential_hex = hex_encode(credential),
        .attempts_remaining = pairing_->attempts_remaining,
    };
    pairing_.reset();
    return result;
}

std::optional<NearbyAuthChallenge> NearbyPairingService::begin_authentication(const std::string& client_id,
                                                                               std::int64_t now_ms,
                                                                               std::int64_t lifetime_ms) {
    std::scoped_lock lock(mutex_);
    if (lifetime_ms <= 0 || !trust_store_.find(client_id).has_value()) {
        return std::nullopt;
    }
    const std::vector<std::uint8_t> bytes = random(48U);
    NearbyAuthChallenge challenge{
        .challenge_id = hex_encode(std::span<const std::uint8_t>(bytes.data(), 16U)),
        .nonce_hex = hex_encode(std::span<const std::uint8_t>(bytes.data() + 16U, 32U)),
        .expires_at_ms = now_ms + lifetime_ms,
    };
    challenges_[challenge.challenge_id] = PendingChallenge{.challenge = challenge, .client_id = client_id};
    return challenge;
}

NearbyAuthStatus NearbyPairingService::authenticate(const std::string& client_id,
                                                    const std::string& challenge_id,
                                                    const std::string& proof_hex,
                                                    std::int64_t now_ms) {
    std::scoped_lock lock(mutex_);
    auto trusted = trust_store_.find(client_id);
    if (!trusted.has_value()) {
        return NearbyAuthStatus::UnknownClient;
    }

    auto challenge_node = challenges_.extract(challenge_id);
    if (challenge_node.empty() || challenge_node.mapped().client_id != client_id) {
        return NearbyAuthStatus::InvalidChallenge;
    }
    const NearbyAuthChallenge challenge = challenge_node.mapped().challenge;
    if (now_ms >= challenge.expires_at_ms) {
        return NearbyAuthStatus::Expired;
    }

    const auto verifier = hex_decode(trusted->credential_verifier_hex);
    if (!verifier.has_value()) {
        return NearbyAuthStatus::InvalidProof;
    }
    const auto expected_digest = hmac_sha256(*verifier, authentication_payload(challenge, client_id));
    if (!constant_time_equal(proof_hex, hex_encode(expected_digest))) {
        return NearbyAuthStatus::InvalidProof;
    }

    trusted->last_seen_at_ms = now_ms;
    trust_store_.upsert(*trusted);
    trust_store_.save();
    return NearbyAuthStatus::Authenticated;
}

std::vector<NearbyTrustedClient> NearbyPairingService::trusted_clients() const {
    std::scoped_lock lock(mutex_);
    return trust_store_.clients();
}

bool NearbyPairingService::revoke_client(const std::string& client_id) {
    std::scoped_lock lock(mutex_);
    if (!trust_store_.revoke(client_id)) {
        return false;
    }
    std::erase_if(challenges_, [&](const auto& item) {
        return item.second.client_id == client_id;
    });
    trust_store_.save();
    return true;
}

std::string NearbyPairingService::pairing_proof(const std::string& display_code,
                                                const std::string& pairing_id,
                                                const std::string& client_id) {
    const std::span<const std::uint8_t> key(reinterpret_cast<const std::uint8_t*>(display_code.data()),
                                           display_code.size());
    return hex_encode(hmac_sha256(key, pairing_payload(pairing_id, client_id)));
}

std::string NearbyPairingService::authentication_proof(const std::string& credential_hex,
                                                       const NearbyAuthChallenge& challenge,
                                                       const std::string& client_id) {
    const auto credential = hex_decode(credential_hex);
    if (!credential.has_value() || credential->size() != 32U) {
        throw std::invalid_argument("invalid nearby credential");
    }
    const auto verifier = sha256(*credential);
    return hex_encode(hmac_sha256(verifier, authentication_payload(challenge, client_id)));
}

bool NearbyPairingService::valid_client(const NearbyClientIdentity& client) {
    return valid_identifier(client.client_id, 128U) && valid_display_text(client.display_name, 160U) &&
           valid_identifier(client.client_kind, 32U);
}

std::vector<std::uint8_t> NearbyPairingService::random(std::size_t size) const {
    std::vector<std::uint8_t> bytes = random_bytes_(size);
    if (bytes.size() != size) {
        throw std::runtime_error("the nearby random source returned the wrong number of bytes");
    }
    return bytes;
}

std::vector<std::byte> encode_nearby_audio_frame(std::uint32_t stream_id,
                                                 std::uint32_t sequence,
                                                 std::span<const std::int16_t> samples) {
    if (stream_id == 0U || samples.empty() || samples.size() > kNearbyMaxFrameSamples) {
        throw std::invalid_argument("invalid nearby audio frame");
    }

    std::vector<std::byte> output;
    output.reserve(kAudioHeaderSize + samples.size() * sizeof(std::int16_t));
    output.insert(output.end(), kAudioMagic.cbegin(), kAudioMagic.cend());
    output.push_back(static_cast<std::byte>(kNearbyProtocolVersion));
    output.push_back(std::byte{0});
    append_be16(output, kAudioHeaderSize);
    append_be32(output, stream_id);
    append_be32(output, sequence);
    append_be32(output, static_cast<std::uint32_t>(samples.size()));
    for (const std::int16_t sample : samples) {
        const auto value = static_cast<std::uint16_t>(sample);
        output.push_back(static_cast<std::byte>(value & 0xFFU));
        output.push_back(static_cast<std::byte>((value >> 8U) & 0xFFU));
    }
    return output;
}

std::optional<NearbyAudioFrame> decode_nearby_audio_frame(std::span<const std::byte> bytes, std::string* error) {
    if (bytes.size() < kAudioHeaderSize) {
        set_decode_error(error, "nearby audio frame is shorter than its header");
        return std::nullopt;
    }
    if (!std::equal(kAudioMagic.cbegin(), kAudioMagic.cend(), bytes.begin())) {
        set_decode_error(error, "nearby audio frame has an invalid magic value");
        return std::nullopt;
    }
    if (std::to_integer<std::uint8_t>(bytes[4]) != kNearbyProtocolVersion || bytes[5] != std::byte{0} ||
        read_be16(bytes, 6U) != kAudioHeaderSize) {
        set_decode_error(error, "nearby audio frame uses an unsupported header");
        return std::nullopt;
    }

    const std::uint32_t stream_id = read_be32(bytes, 8U);
    const std::uint32_t sequence = read_be32(bytes, 12U);
    const std::uint32_t sample_count = read_be32(bytes, 16U);
    if (stream_id == 0U || sample_count == 0U || sample_count > kNearbyMaxFrameSamples) {
        set_decode_error(error, "nearby audio frame has invalid stream or sample fields");
        return std::nullopt;
    }
    const std::size_t expected_size = kAudioHeaderSize + static_cast<std::size_t>(sample_count) * 2U;
    if (bytes.size() != expected_size) {
        set_decode_error(error, "nearby audio frame payload length does not match its header");
        return std::nullopt;
    }

    NearbyAudioFrame frame{
        .stream_id = stream_id,
        .sequence = sequence,
    };
    frame.samples.reserve(sample_count);
    for (std::size_t offset = kAudioHeaderSize; offset < bytes.size(); offset += 2U) {
        const auto value = static_cast<std::uint16_t>(std::to_integer<std::uint8_t>(bytes[offset]) |
                                                      (std::to_integer<std::uint8_t>(bytes[offset + 1U]) << 8U));
        frame.samples.push_back(static_cast<std::int16_t>(value));
    }
    return frame;
}

NearbyAudioSession::NearbyAudioSession(PushAudioSink& sink, NearbyClientIdentity client)
    : sink_(sink), client_(std::move(client)) {}

bool NearbyAudioSession::start(std::uint32_t stream_id,
                               const PushAudioFormat& format,
                               std::string requested_profile_id,
                               std::string* error) {
    if (active_) {
        set_decode_error(error, "a nearby audio stream is already active");
        return false;
    }
    if (stream_id == 0U || format.encoding != PushAudioEncoding::Pcm16Le ||
        format.sample_rate_hz != kNearbySampleRate || format.channel_count != kNearbyChannelCount) {
        set_decode_error(error, "nearby audio must be mono PCM16LE at 16 kHz");
        return false;
    }

    const PushAudioStreamInfo info{
        .source_id = client_.client_id,
        .source_name = client_.display_name,
        .source_kind = client_.client_kind,
        .requested_profile_id = std::move(requested_profile_id),
        .stream_id = stream_id,
        .format = format,
    };
    if (!sink_.on_push_audio_start(info, error)) {
        return false;
    }

    active_ = true;
    stream_id_ = stream_id;
    next_sequence_ = 0;
    received_samples_ = 0;
    missing_frames_ = 0;
    return true;
}

NearbyAudioFrameResult NearbyAudioSession::accept_frame(std::span<const std::byte> bytes) {
    if (!active_) {
        return {.status = NearbyAudioFrameStatus::NoActiveStream, .error = "no nearby audio stream is active"};
    }

    std::string error;
    const auto frame = decode_nearby_audio_frame(bytes, &error);
    if (!frame.has_value()) {
        return {.status = NearbyAudioFrameStatus::Malformed, .error = std::move(error)};
    }
    if (frame->stream_id != stream_id_) {
        return {.status = NearbyAudioFrameStatus::StaleStream, .error = "nearby audio frame belongs to a stale stream"};
    }
    if (frame->sequence < next_sequence_) {
        return {.status = NearbyAudioFrameStatus::Replayed, .error = "nearby audio frame was replayed or reordered"};
    }
    if (frame->sequence == std::numeric_limits<std::uint32_t>::max()) {
        return {.status = NearbyAudioFrameStatus::Malformed, .error = "nearby audio sequence is exhausted"};
    }

    const std::uint32_t missing = frame->sequence - next_sequence_;
    if (!sink_.on_push_audio_samples(stream_id_, frame->samples, &error)) {
        sink_.on_push_audio_stop(stream_id_, PushAudioStopReason::Error);
        active_ = false;
        return {.status = NearbyAudioFrameStatus::SinkRejected, .error = std::move(error)};
    }

    next_sequence_ = frame->sequence + 1U;
    received_samples_ += frame->samples.size();
    missing_frames_ += missing;
    return {.status = NearbyAudioFrameStatus::Accepted, .missing_frames = missing};
}

bool NearbyAudioSession::stop(std::uint32_t stream_id, std::string* error) {
    if (!active_) {
        set_decode_error(error, "no nearby audio stream is active");
        return false;
    }
    if (stream_id != stream_id_) {
        set_decode_error(error, "nearby stop belongs to a stale stream");
        return false;
    }
    sink_.on_push_audio_stop(stream_id_, PushAudioStopReason::Completed);
    active_ = false;
    return true;
}

void NearbyAudioSession::disconnect() {
    if (!active_) {
        return;
    }
    sink_.on_push_audio_stop(stream_id_, PushAudioStopReason::Disconnected);
    active_ = false;
}

bool NearbyAudioSession::active() const {
    return active_;
}

std::uint32_t NearbyAudioSession::stream_id() const {
    return stream_id_;
}

std::uint64_t NearbyAudioSession::received_samples() const {
    return received_samples_;
}

std::uint64_t NearbyAudioSession::missing_frames() const {
    return missing_frames_;
}

}  // namespace ohmytypeless
