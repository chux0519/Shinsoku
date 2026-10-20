#include "core/nearby/nearby_protocol.hpp"

#include <chrono>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

#ifndef _WIN32
#include <sys/stat.h>
#endif

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

std::filesystem::path unique_test_directory() {
    const auto suffix = std::chrono::steady_clock::now().time_since_epoch().count();
    return std::filesystem::temp_directory_path() / ("shinsoku-nearby-test-" + std::to_string(suffix));
}

class DeterministicRandom {
public:
    std::vector<std::uint8_t> operator()(std::size_t size) {
        std::vector<std::uint8_t> bytes;
        bytes.reserve(size);
        for (std::size_t index = 0; index < size; ++index) {
            bytes.push_back(next_++);
        }
        return bytes;
    }

private:
    std::uint8_t next_ = 0;
};

class RecordingSink final : public ohmytypeless::PushAudioSink {
public:
    bool on_push_audio_start(const ohmytypeless::PushAudioStreamInfo& stream, std::string* error) override {
        if (reject_start) {
            if (error != nullptr) {
                *error = "busy";
            }
            return false;
        }
        starts.push_back(stream);
        return true;
    }

    bool on_push_audio_samples(std::uint32_t stream_id,
                               std::span<const std::int16_t> chunk,
                               std::string* error) override {
        if (reject_audio) {
            if (error != nullptr) {
                *error = "consumer rejected audio";
            }
            return false;
        }
        sample_stream_ids.push_back(stream_id);
        samples.insert(samples.end(), chunk.begin(), chunk.end());
        return true;
    }

    void on_push_audio_stop(std::uint32_t stream_id, ohmytypeless::PushAudioStopReason reason) override {
        stops.emplace_back(stream_id, reason);
    }

    bool reject_start = false;
    bool reject_audio = false;
    std::vector<ohmytypeless::PushAudioStreamInfo> starts;
    std::vector<std::uint32_t> sample_stream_ids;
    std::vector<std::int16_t> samples;
    std::vector<std::pair<std::uint32_t, ohmytypeless::PushAudioStopReason>> stops;
};

void test_pairing_and_trust(const std::filesystem::path& directory) {
    using namespace ohmytypeless;

    const std::filesystem::path store_path = directory / "nearby-trust.json";
    NearbyTrustStore store(store_path);
    store.load();

    DeterministicRandom random;
    NearbyPairingService pairing(store, [&random](std::size_t size) { return random(size); });
    const NearbyClientIdentity client{
        .client_id = "phone-a1b2c3",
        .display_name = "Yongsheng's iPhone",
        .client_kind = "iphone",
    };

    const NearbyPairingOffer offer = pairing.open_pairing(1000, 10000);
    require(offer.display_code == "16" && offer.attempts_remaining == 5,
            "pairing must expose a fixed-width two-digit code and bounded attempts");
    require(pairing.active_pairing(10999).has_value() && !pairing.active_pairing(11000).has_value(),
            "pairing availability must honor its expiration boundary");

    const auto wrong = pairing.pair_client(client, offer.pairing_id, "not-a-proof", 2000);
    require(wrong.status == NearbyPairingStatus::InvalidProof && wrong.attempts_remaining == 4,
            "a wrong pairing proof must consume one attempt");

    const std::string proof = NearbyPairingService::pairing_proof(offer.display_code, offer.pairing_id, client.client_id);
    const auto paired = pairing.pair_client(client, offer.pairing_id, proof, 3000);
    require(paired.status == NearbyPairingStatus::Paired && paired.credential_hex.size() == 64U,
            "a valid proof must issue one high-entropy client credential");
    require(!pairing.active_pairing(3000).has_value(), "a successful pairing window must close immediately");
    require(store.find(client.client_id).has_value(), "paired clients must be persisted as trusted clients");
    require(store.find(client.client_id)->credential_verifier_hex != paired.credential_hex,
            "the server must not persist the client credential itself");

    std::ifstream stored_file(store_path);
    const std::string stored_text((std::istreambuf_iterator<char>(stored_file)), std::istreambuf_iterator<char>());
    require(stored_text.find(paired.credential_hex) == std::string::npos,
            "the serialized trust store must not contain the issued credential");
#ifndef _WIN32
    struct stat file_status {};
    require(::stat(store_path.c_str(), &file_status) == 0 && (file_status.st_mode & 0777) == 0600,
            "the trust store must be readable and writable only by its owner");
#endif

    NearbyTrustStore reloaded(store_path);
    reloaded.load();
    require(reloaded.clients().size() == 1U && reloaded.clients().front().identity.display_name == client.display_name,
            "trusted client identity must survive a storage round trip");

    NearbyPairingService authentication(reloaded, [&random](std::size_t size) { return random(size); });
    const auto challenge = authentication.begin_authentication(client.client_id, 4000, 5000);
    require(challenge.has_value(), "a trusted client must receive an authentication challenge");
    const std::string auth_proof =
        NearbyPairingService::authentication_proof(paired.credential_hex, *challenge, client.client_id);
    require(authentication.authenticate(client.client_id, challenge->challenge_id, auth_proof, 4500) ==
                NearbyAuthStatus::Authenticated,
            "a credential holder must authenticate successfully");
    require(authentication.authenticate(client.client_id, challenge->challenge_id, auth_proof, 4501) ==
                NearbyAuthStatus::InvalidChallenge,
            "an authentication challenge must not be replayable");

    const auto expired = authentication.begin_authentication(client.client_id, 5000, 100);
    require(expired.has_value() &&
                authentication.authenticate(client.client_id,
                                            expired->challenge_id,
                                            NearbyPairingService::authentication_proof(
                                                paired.credential_hex, *expired, client.client_id),
                                            5100) == NearbyAuthStatus::Expired,
            "expired authentication challenges must be rejected");

    require(authentication.revoke_client(client.client_id), "a trusted client must be revocable");
    require(!authentication.begin_authentication(client.client_id, 6000).has_value(),
            "revocation must prevent new authentication immediately");

    const NearbyPairingOffer exhausted_offer = authentication.open_pairing(7000, 5000);
    NearbyPairingResult exhausted;
    for (int attempt = 0; attempt < 5; ++attempt) {
        exhausted = authentication.pair_client(client, exhausted_offer.pairing_id, "wrong", 7001 + attempt);
    }
    require(exhausted.status == NearbyPairingStatus::AttemptsExhausted &&
                !authentication.active_pairing(7010).has_value(),
            "five invalid proofs must close the pairing window");

    const NearbyPairingOffer expiring_offer = authentication.open_pairing(8000, 10);
    require(authentication.pair_client(client,
                                       expiring_offer.pairing_id,
                                       NearbyPairingService::pairing_proof(
                                           expiring_offer.display_code, expiring_offer.pairing_id, client.client_id),
                                       8010)
                .status == NearbyPairingStatus::Expired,
            "a pairing proof at the expiration boundary must fail");
}

void test_audio_frames_and_session() {
    using namespace ohmytypeless;

    const std::vector<std::int16_t> samples{
        std::numeric_limits<std::int16_t>::min(),
        -1,
        0,
        1,
        std::numeric_limits<std::int16_t>::max(),
    };
    const auto encoded = encode_nearby_audio_frame(7, 0, samples);
    std::string error;
    const auto decoded = decode_nearby_audio_frame(encoded, &error);
    require(decoded.has_value() && decoded->stream_id == 7U && decoded->sequence == 0U &&
                decoded->samples == samples,
            "PCM16LE nearby frames must round-trip without changing signed samples");

    auto truncated = encoded;
    truncated.pop_back();
    require(!decode_nearby_audio_frame(truncated, &error).has_value() && !error.empty(),
            "truncated nearby frames must fail structural validation");

    RecordingSink sink;
    NearbyAudioSession session(sink,
                               NearbyClientIdentity{
                                   .client_id = "web-123",
                                   .display_name = "Browser microphone",
                                   .client_kind = "web",
                               });
    require(session.accept_frame(encoded).status == NearbyAudioFrameStatus::NoActiveStream,
            "audio must not be accepted before an authenticated stream starts");

    const PushAudioFormat wrong_format{
        .encoding = PushAudioEncoding::Pcm16Le,
        .sample_rate_hz = 48000,
        .channel_count = 1,
    };
    require(!session.start(7, wrong_format, "dictation", &error) && error.find("16 kHz") != std::string::npos,
            "nearby input must reject formats that would silently change the ASR contract");

    require(session.start(7, PushAudioFormat{}, "translate", &error), "a fixed-format nearby stream must start");
    require(sink.starts.size() == 1U && sink.starts.front().requested_profile_id == "translate" &&
                sink.starts.front().source_kind == "web",
            "stream start must preserve source identity and requested Profile");
    require(session.accept_frame(encoded).status == NearbyAudioFrameStatus::Accepted,
            "the first audio frame must be accepted");
    require(session.accept_frame(encoded).status == NearbyAudioFrameStatus::Replayed,
            "a duplicate audio sequence must be rejected");

    const auto gap_frame = encode_nearby_audio_frame(7, 2, std::span<const std::int16_t>(samples.data(), 2U));
    const auto gap_result = session.accept_frame(gap_frame);
    require(gap_result.status == NearbyAudioFrameStatus::Accepted && gap_result.missing_frames == 1U &&
                session.missing_frames() == 1U,
            "a sequence gap must remain visible in diagnostics while later audio continues");
    require(session.received_samples() == 7U && sink.samples.size() == 7U,
            "only accepted audio samples may reach the shared push sink");

    const auto stale_frame = encode_nearby_audio_frame(8, 3, samples);
    require(session.accept_frame(stale_frame).status == NearbyAudioFrameStatus::StaleStream,
            "audio from another stream generation must not affect the active stream");
    require(!session.stop(8, &error) && session.active(), "a stale stop event must not stop the active stream");
    require(session.stop(7, &error) && !session.active() && sink.stops.back().second == PushAudioStopReason::Completed,
            "the matching stop event must finalize the push stream");

    require(session.start(9, PushAudioFormat{}, {}, &error), "a new stream must start after finalization");
    require(session.accept_frame(encoded).status == NearbyAudioFrameStatus::StaleStream,
            "late frames from a completed stream must be rejected by stream ID");
    session.disconnect();
    require(!session.active() && sink.stops.back().second == PushAudioStopReason::Disconnected,
            "disconnect must terminate an active stream explicitly");

    RecordingSink rejecting_sink;
    NearbyAudioSession rejecting_session(rejecting_sink,
                                         NearbyClientIdentity{
                                             .client_id = "phone-2",
                                             .display_name = "Phone",
                                             .client_kind = "iphone",
                                         });
    require(rejecting_session.start(11, PushAudioFormat{}, {}, &error), "rejecting sink setup must start");
    rejecting_sink.reject_audio = true;
    const auto rejected = rejecting_session.accept_frame(encode_nearby_audio_frame(11, 0, samples));
    require(rejected.status == NearbyAudioFrameStatus::SinkRejected && !rejecting_session.active() &&
                rejecting_sink.stops.back().second == PushAudioStopReason::Error,
            "a sink failure must close the stream instead of accepting further audio");
}

}  // namespace

int main() {
    const std::filesystem::path directory = unique_test_directory();
    try {
        std::filesystem::create_directories(directory);
        test_pairing_and_trust(directory);
        test_audio_frames_and_session();
        std::filesystem::remove_all(directory);
        std::cout << "nearby_protocol_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::filesystem::remove_all(directory);
        std::cerr << "nearby_protocol_tests: " << exception.what() << '\n';
        return 1;
    }
}
