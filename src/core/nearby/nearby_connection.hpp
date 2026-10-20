#pragma once

#include "core/nearby/nearby_protocol.hpp"

#include <nlohmann/json.hpp>

#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>
#include <span>
#include <string>

namespace ohmytypeless {

struct NearbyConnectionResult {
    std::optional<nlohmann::json> response;
    bool close_connection = false;
    std::uint16_t close_code = 1008;
    std::string close_reason;
};

class NearbyConnectionSession {
public:
    NearbyConnectionSession(NearbyPairingService& pairing_service,
                            PushAudioSink& audio_sink,
                            bool secure_transport);

    NearbyConnectionResult handle_text(std::string_view message, std::int64_t now_ms);
    NearbyConnectionResult handle_binary(std::span<const std::byte> message);
    void disconnect();

    bool authenticated() const;
    std::optional<std::string> client_id() const;

private:
    NearbyConnectionResult handle_hello(const nlohmann::json& message, std::int64_t now_ms);
    NearbyConnectionResult handle_pairing_refresh(std::int64_t now_ms) const;
    NearbyConnectionResult handle_pairing_proof(const nlohmann::json& message, std::int64_t now_ms);
    NearbyConnectionResult handle_authentication_proof(const nlohmann::json& message, std::int64_t now_ms);
    NearbyConnectionResult handle_audio_start(const nlohmann::json& message);
    NearbyConnectionResult handle_audio_stop(const nlohmann::json& message);
    NearbyConnectionResult pairing_prompt(std::int64_t now_ms) const;
    NearbyConnectionResult protocol_error(std::string code, std::string message, bool close = false) const;

    NearbyPairingService& pairing_service_;
    PushAudioSink& audio_sink_;
    bool secure_transport_ = false;
    bool hello_received_ = false;
    bool authenticated_ = false;
    std::optional<NearbyClientIdentity> client_;
    std::optional<NearbyAuthChallenge> pending_auth_challenge_;
    std::unique_ptr<NearbyAudioSession> audio_session_;
};

}  // namespace ohmytypeless
