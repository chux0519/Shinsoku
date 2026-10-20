#pragma once

#include "core/nearby/nearby_protocol.hpp"

#include <cstdint>
#include <filesystem>
#include <memory>
#include <string>
#include <vector>

namespace ohmytypeless {

class NearbyDiscoveryPublisher;
class NearbyWebSocketServer;
class PushAudioSink;

struct NearbyRuntimeConfig {
    bool enabled = false;
    int port = 39273;
    std::string service_name = "Shinsoku Desktop";
    std::filesystem::path storage_directory;

    bool operator==(const NearbyRuntimeConfig&) const = default;
};

struct NearbyRuntimeStatus {
    bool running = false;
    bool discoverable = false;
    int port = 0;
    std::string service_name;
    std::string certificate_sha256;
};

class NearbyRuntime {
public:
    NearbyRuntime(PushAudioSink& audio_sink,
                  std::unique_ptr<NearbyDiscoveryPublisher> discovery_publisher = {});
    ~NearbyRuntime();

    NearbyRuntime(const NearbyRuntime&) = delete;
    NearbyRuntime& operator=(const NearbyRuntime&) = delete;

    void apply(const NearbyRuntimeConfig& config);
    void stop();
    NearbyRuntimeStatus status() const;

    NearbyPairingOffer open_pairing(std::int64_t now_ms, std::int64_t lifetime_ms = 120000);
    void close_pairing();
    std::vector<NearbyTrustedClient> trusted_clients() const;
    bool revoke_client(const std::string& client_id);

private:
    PushAudioSink& audio_sink_;
    std::unique_ptr<NearbyDiscoveryPublisher> discovery_publisher_;
    std::unique_ptr<NearbyWebSocketServer> server_;
    NearbyRuntimeConfig config_;
    NearbyRuntimeStatus status_;
};

}  // namespace ohmytypeless
