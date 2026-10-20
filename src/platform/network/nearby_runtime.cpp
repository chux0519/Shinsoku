#include "platform/network/nearby_runtime.hpp"

#include "core/nearby/nearby_tls_identity.hpp"
#include "platform/network/nearby_discovery_publisher.hpp"
#include "platform/network/nearby_websocket_server.hpp"

#include <stdexcept>
#include <utility>

namespace ohmytypeless {

NearbyRuntime::NearbyRuntime(PushAudioSink& audio_sink,
                             std::unique_ptr<NearbyDiscoveryPublisher> discovery_publisher)
    : audio_sink_(audio_sink), discovery_publisher_(std::move(discovery_publisher)) {}

NearbyRuntime::~NearbyRuntime() {
    stop();
}

void NearbyRuntime::apply(const NearbyRuntimeConfig& config) {
    if (!config.enabled) {
        stop();
        config_ = config;
        return;
    }
    if (config.port <= 0 || config.port > 65535 || config.storage_directory.empty() ||
        config.service_name.empty()) {
        throw std::invalid_argument("invalid Nearby runtime configuration");
    }
    if (server_ != nullptr && server_->running() && config == config_) {
        return;
    }

    stop();
    const NearbyTlsIdentity identity =
        NearbyTlsIdentityStore(config.storage_directory / "identity").load_or_create();
    auto server = std::make_unique<NearbyWebSocketServer>(
        NearbyWebSocketServerConfig{
            .host = "0.0.0.0",
            .port = config.port,
            .max_connections = 8,
            .tls_enabled = true,
            .tls_certificate_path = identity.certificate_path.string(),
            .tls_private_key_path = identity.private_key_path.string(),
        },
        config.storage_directory / "trusted-clients.json",
        audio_sink_);
    server->start();

    try {
        if (discovery_publisher_ != nullptr) {
            discovery_publisher_->start({
                .service_name = config.service_name,
                .port = static_cast<std::uint16_t>(server->port()),
                .instance_id = identity.instance_id,
                .certificate_sha256 = identity.certificate_sha256,
            });
        }
    } catch (...) {
        server->stop();
        throw;
    }

    config_ = config;
    status_ = {
        .running = true,
        .discoverable = discovery_publisher_ != nullptr && discovery_publisher_->running(),
        .port = server->port(),
        .service_name = discovery_publisher_ != nullptr && !discovery_publisher_->registered_name().empty()
                            ? discovery_publisher_->registered_name()
                            : config.service_name,
        .certificate_sha256 = identity.certificate_sha256,
    };
    server_ = std::move(server);
}

void NearbyRuntime::stop() {
    if (discovery_publisher_ != nullptr) {
        discovery_publisher_->stop();
    }
    if (server_ != nullptr) {
        server_->stop();
        server_.reset();
    }
    status_ = {};
}

NearbyRuntimeStatus NearbyRuntime::status() const {
    NearbyRuntimeStatus result = status_;
    result.running = server_ != nullptr && server_->running();
    result.discoverable = result.running && discovery_publisher_ != nullptr && discovery_publisher_->running();
    return result;
}

NearbyPairingOffer NearbyRuntime::open_pairing(std::int64_t now_ms, std::int64_t lifetime_ms) {
    if (server_ == nullptr || !server_->running()) {
        throw std::runtime_error("Nearby microphone is not running");
    }
    return server_->open_pairing(now_ms, lifetime_ms);
}

void NearbyRuntime::close_pairing() {
    if (server_ != nullptr) {
        server_->close_pairing();
    }
}

std::vector<NearbyTrustedClient> NearbyRuntime::trusted_clients() const {
    return server_ != nullptr ? server_->trusted_clients() : std::vector<NearbyTrustedClient>{};
}

bool NearbyRuntime::revoke_client(const std::string& client_id) {
    return server_ != nullptr && server_->revoke_client(client_id);
}

}  // namespace ohmytypeless
