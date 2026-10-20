#include "platform/network/nearby_websocket_server.hpp"

#include <ixwebsocket/IXNetSystem.h>
#include <ixwebsocket/IXSocketTLSOptions.h>
#include <ixwebsocket/IXWebSocket.h>
#include <ixwebsocket/IXWebSocketCloseConstants.h>
#include <ixwebsocket/IXWebSocketMessage.h>
#include <ixwebsocket/IXWebSocketMessageType.h>
#include <ixwebsocket/IXWebSocketServer.h>

#include <chrono>
#include <mutex>
#include <stdexcept>
#include <utility>

namespace ohmytypeless {

namespace {

bool ensure_network_runtime() {
    static std::once_flag initialization;
    static bool initialized = false;
    std::call_once(initialization, []() { initialized = ix::initNetSystem(); });
    return initialized;
}

}  // namespace

NearbyWebSocketServer::NearbyWebSocketServer(NearbyWebSocketServerConfig config,
                                             std::filesystem::path trust_store_path,
                                             PushAudioSink& audio_sink,
                                             NearbyPairingService::RandomBytes random_bytes)
    : config_(std::move(config)),
      trust_store_(std::move(trust_store_path)),
      pairing_service_(trust_store_, std::move(random_bytes)),
      audio_sink_(audio_sink) {}

NearbyWebSocketServer::~NearbyWebSocketServer() {
    stop();
}

void NearbyWebSocketServer::start() {
    std::scoped_lock lock(mutex_);
    if (running_) {
        return;
    }
    if (!config_.tls_enabled && !is_loopback_host(config_.host)) {
        throw std::runtime_error("Nearby LAN listening requires TLS; plaintext is restricted to loopback");
    }
    if (config_.port <= 0 || config_.port > 65535 || config_.max_connections == 0U) {
        throw std::invalid_argument("invalid nearby WebSocket server configuration");
    }
    if (!ensure_network_runtime()) {
        throw std::runtime_error("failed to initialize the Nearby network runtime");
    }

    trust_store_.load();
    server_ = std::make_unique<ix::WebSocketServer>(
        config_.port,
        config_.host,
        ix::SocketServer::kDefaultTcpBacklog,
        config_.max_connections);
    server_->disablePerMessageDeflate();
    server_->enablePong();

    if (config_.tls_enabled) {
        ix::SocketTLSOptions tls;
        tls.tls = true;
        tls.certFile = config_.tls_certificate_path;
        tls.keyFile = config_.tls_private_key_path;
        tls.caFile = "NONE";
        if (!tls.isValid()) {
            server_.reset();
            throw std::runtime_error("invalid Nearby TLS configuration: " + tls.getErrorMsg());
        }
        server_->setTLSOptions(tls);
    }

    const bool secure_transport = config_.tls_enabled || is_loopback_host(config_.host);
    server_->setOnConnectionCallback([this, secure_transport](std::weak_ptr<ix::WebSocket> socket,
                                                             std::shared_ptr<ix::ConnectionState> state) {
        const auto connected_socket = socket.lock();
        if (connected_socket == nullptr) {
            return;
        }
        auto session = std::make_shared<NearbyConnectionSession>(pairing_service_, audio_sink_, secure_transport);
        const std::string connection_id = state->getId();
        {
            std::scoped_lock callback_lock(mutex_);
            connections_[connection_id] = Connection{.socket = socket, .session = session};
        }
        connected_socket->setOnMessageCallback(
            [this, connection_id, socket = std::move(socket), session = std::move(session)](
                const ix::WebSocketMessagePtr& message) {
            if (message->type == ix::WebSocketMessageType::Close || message->type == ix::WebSocketMessageType::Error) {
                remove_connection(connection_id);
                return;
            }
            if (message->type != ix::WebSocketMessageType::Message) {
                return;
            }

            const auto active_socket = socket.lock();
            if (active_socket == nullptr) {
                return;
            }

            NearbyConnectionResult result;
            if (message->binary) {
                const std::span<const std::byte> bytes(
                    reinterpret_cast<const std::byte*>(message->str.data()), message->str.size());
                result = session->handle_binary(bytes);
            } else {
                result = session->handle_text(message->str, current_time_ms());
            }
            if (result.response.has_value()) {
                active_socket->sendText(result.response->dump());
            }
            if (result.close_connection) {
                active_socket->close(result.close_code, result.close_reason);
            }
        });
    });

    const auto [listening, error] = server_->listen();
    if (!listening) {
        server_.reset();
        throw std::runtime_error("failed to start Nearby WebSocket server: " + error);
    }
    server_->start();
    running_ = true;
}

void NearbyWebSocketServer::stop() {
    std::unique_ptr<ix::WebSocketServer> server;
    std::vector<std::shared_ptr<NearbyConnectionSession>> sessions;
    {
        std::scoped_lock lock(mutex_);
        if (!server_) {
            running_ = false;
            return;
        }
        for (const auto& [id, connection] : connections_) {
            static_cast<void>(id);
            sessions.push_back(connection.session);
        }
        connections_.clear();
        running_ = false;
        server = std::move(server_);
    }
    for (const auto& session : sessions) {
        session->disconnect();
    }
    server->stop();
}

bool NearbyWebSocketServer::running() const {
    std::scoped_lock lock(mutex_);
    return running_;
}

int NearbyWebSocketServer::port() const {
    std::scoped_lock lock(mutex_);
    return server_ != nullptr ? server_->getPort() : 0;
}

std::string NearbyWebSocketServer::websocket_url() const {
    std::scoped_lock lock(mutex_);
    if (server_ == nullptr) {
        return {};
    }
    const std::string scheme = config_.tls_enabled ? "wss://" : "ws://";
    const std::string host = config_.host == "::1" ? "[::1]" : config_.host;
    return scheme + host + ":" + std::to_string(server_->getPort());
}

NearbyPairingOffer NearbyWebSocketServer::open_pairing(std::int64_t now_ms, std::int64_t lifetime_ms) {
    return pairing_service_.open_pairing(now_ms, lifetime_ms);
}

void NearbyWebSocketServer::close_pairing() {
    pairing_service_.close_pairing();
}

std::vector<NearbyTrustedClient> NearbyWebSocketServer::trusted_clients() const {
    return pairing_service_.trusted_clients();
}

bool NearbyWebSocketServer::revoke_client(const std::string& client_id) {
    if (!pairing_service_.revoke_client(client_id)) {
        return false;
    }

    std::vector<std::shared_ptr<NearbyConnectionSession>> sessions;
    std::vector<std::shared_ptr<ix::WebSocket>> sockets;
    {
        std::scoped_lock lock(mutex_);
        for (const auto& [id, connection] : connections_) {
            static_cast<void>(id);
            if (connection.session->client_id() == std::optional<std::string>(client_id)) {
                sessions.push_back(connection.session);
                if (auto socket = connection.socket.lock()) {
                    sockets.push_back(std::move(socket));
                }
            }
        }
    }
    for (const auto& session : sessions) {
        session->disconnect();
    }
    for (const auto& socket : sockets) {
        socket->close(1008, "Nearby client trust was revoked");
    }
    return true;
}

bool NearbyWebSocketServer::is_loopback_host(const std::string& host) {
    return host == "127.0.0.1" || host == "::1" || host == "localhost";
}

std::int64_t NearbyWebSocketServer::current_time_ms() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::system_clock::now().time_since_epoch())
        .count();
}

void NearbyWebSocketServer::remove_connection(const std::string& connection_id) {
    std::shared_ptr<NearbyConnectionSession> session;
    {
        std::scoped_lock lock(mutex_);
        const auto iterator = connections_.find(connection_id);
        if (iterator == connections_.end()) {
            return;
        }
        session = std::move(iterator->second.session);
        connections_.erase(iterator);
    }
    session->disconnect();
}

}  // namespace ohmytypeless
