#pragma once

#include "core/input/push_audio_source.hpp"

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <mutex>
#include <optional>
#include <span>
#include <string>
#include <unordered_map>
#include <vector>

namespace ohmytypeless {

inline constexpr std::uint32_t kNearbyProtocolVersion = 1;
inline constexpr std::uint32_t kNearbySampleRate = 16000;
inline constexpr std::uint16_t kNearbyChannelCount = 1;
inline constexpr std::size_t kNearbyMaxFrameSamples = 3200;

struct NearbyClientIdentity {
    std::string client_id;
    std::string display_name;
    std::string client_kind;
};

struct NearbyTrustedClient {
    NearbyClientIdentity identity;
    std::string credential_verifier_hex;
    std::int64_t created_at_ms = 0;
    std::int64_t last_seen_at_ms = 0;
};

class NearbyTrustStore {
public:
    explicit NearbyTrustStore(std::filesystem::path path);

    void load();
    void save() const;
    const std::filesystem::path& path() const;
    const std::vector<NearbyTrustedClient>& clients() const;
    std::optional<NearbyTrustedClient> find(const std::string& client_id) const;
    void upsert(NearbyTrustedClient client);
    bool revoke(const std::string& client_id);

private:
    std::filesystem::path path_;
    std::vector<NearbyTrustedClient> clients_;
};

struct NearbyPairingOffer {
    std::string pairing_id;
    std::string display_code;
    std::int64_t expires_at_ms = 0;
    int attempts_remaining = 0;
};

enum class NearbyPairingStatus {
    Paired,
    Unavailable,
    Expired,
    InvalidClient,
    InvalidProof,
    AttemptsExhausted,
};

struct NearbyPairingResult {
    NearbyPairingStatus status = NearbyPairingStatus::Unavailable;
    std::string credential_hex;
    int attempts_remaining = 0;
};

struct NearbyAuthChallenge {
    std::string challenge_id;
    std::string nonce_hex;
    std::int64_t expires_at_ms = 0;
};

enum class NearbyAuthStatus {
    Authenticated,
    UnknownClient,
    InvalidChallenge,
    Expired,
    InvalidProof,
};

class NearbyPairingService {
public:
    using RandomBytes = std::function<std::vector<std::uint8_t>(std::size_t)>;

    explicit NearbyPairingService(NearbyTrustStore& trust_store, RandomBytes random_bytes = {});

    NearbyPairingOffer open_pairing(std::int64_t now_ms, std::int64_t lifetime_ms = 120000);
    void close_pairing();
    std::optional<NearbyPairingOffer> active_pairing(std::int64_t now_ms) const;
    NearbyPairingResult pair_client(const NearbyClientIdentity& client,
                                    const std::string& pairing_id,
                                    const std::string& proof_hex,
                                    std::int64_t now_ms);

    std::optional<NearbyAuthChallenge> begin_authentication(const std::string& client_id,
                                                            std::int64_t now_ms,
                                                            std::int64_t lifetime_ms = 30000);
    NearbyAuthStatus authenticate(const std::string& client_id,
                                  const std::string& challenge_id,
                                  const std::string& proof_hex,
                                  std::int64_t now_ms);
    std::vector<NearbyTrustedClient> trusted_clients() const;
    bool revoke_client(const std::string& client_id);

    static std::string pairing_proof(const std::string& display_code,
                                     const std::string& pairing_id,
                                     const std::string& client_id);
    static std::string authentication_proof(const std::string& credential_hex,
                                            const NearbyAuthChallenge& challenge,
                                            const std::string& client_id);

private:
    struct PendingChallenge {
        NearbyAuthChallenge challenge;
        std::string client_id;
    };

    static bool valid_client(const NearbyClientIdentity& client);
    std::vector<std::uint8_t> random(std::size_t size) const;

    NearbyTrustStore& trust_store_;
    RandomBytes random_bytes_;
    mutable std::mutex mutex_;
    std::optional<NearbyPairingOffer> pairing_;
    std::unordered_map<std::string, PendingChallenge> challenges_;
};

struct NearbyAudioFrame {
    std::uint32_t stream_id = 0;
    std::uint32_t sequence = 0;
    std::vector<std::int16_t> samples;
};

enum class NearbyAudioFrameStatus {
    Accepted,
    Malformed,
    NoActiveStream,
    StaleStream,
    Replayed,
    SinkRejected,
};

struct NearbyAudioFrameResult {
    NearbyAudioFrameStatus status = NearbyAudioFrameStatus::Malformed;
    std::uint32_t missing_frames = 0;
    std::string error;
};

std::vector<std::byte> encode_nearby_audio_frame(std::uint32_t stream_id,
                                                 std::uint32_t sequence,
                                                 std::span<const std::int16_t> samples);
std::optional<NearbyAudioFrame> decode_nearby_audio_frame(std::span<const std::byte> bytes,
                                                          std::string* error = nullptr);

class NearbyAudioSession {
public:
    NearbyAudioSession(PushAudioSink& sink, NearbyClientIdentity client);

    bool start(std::uint32_t stream_id,
               const PushAudioFormat& format,
               std::string requested_profile_id,
               std::string* error = nullptr);
    NearbyAudioFrameResult accept_frame(std::span<const std::byte> bytes);
    bool stop(std::uint32_t stream_id, std::string* error = nullptr);
    void disconnect();

    bool active() const;
    std::uint32_t stream_id() const;
    std::uint64_t received_samples() const;
    std::uint64_t missing_frames() const;

private:
    PushAudioSink& sink_;
    NearbyClientIdentity client_;
    bool active_ = false;
    std::uint32_t stream_id_ = 0;
    std::uint32_t next_sequence_ = 0;
    std::uint64_t received_samples_ = 0;
    std::uint64_t missing_frames_ = 0;
};

}  // namespace ohmytypeless
