#include "core/nearby/nearby_protocol.hpp"
#include "core/nearby/nearby_tls_identity.hpp"
#include "platform/network/nearby_websocket_server.hpp"

#include <ixwebsocket/IXNetSystem.h>
#include <ixwebsocket/IXSocketTLSOptions.h>
#include <ixwebsocket/IXWebSocket.h>
#include <ixwebsocket/IXWebSocketMessage.h>
#include <ixwebsocket/IXWebSocketMessageType.h>

#include <nlohmann/json.hpp>

#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <filesystem>
#include <iostream>
#include <mutex>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#ifdef _WIN32
#include <winsock2.h>
#else
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#endif

namespace {

using namespace std::chrono_literals;

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

std::filesystem::path unique_test_directory() {
    const auto suffix = std::chrono::steady_clock::now().time_since_epoch().count();
    return std::filesystem::temp_directory_path() / ("shinsoku-nearby-websocket-test-" + std::to_string(suffix));
}

std::int64_t current_time_ms() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::system_clock::now().time_since_epoch())
        .count();
}

int available_loopback_port() {
#ifdef _WIN32
    const SOCKET descriptor = ::socket(AF_INET, SOCK_STREAM, 0);
    if (descriptor == INVALID_SOCKET) {
#else
    const int descriptor = ::socket(AF_INET, SOCK_STREAM, 0);
    if (descriptor < 0) {
#endif
        throw std::runtime_error("failed to create a temporary loopback socket");
    }

    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    if (::bind(descriptor, reinterpret_cast<const sockaddr*>(&address), sizeof(address)) != 0) {
#ifdef _WIN32
        ::closesocket(descriptor);
#else
        ::close(descriptor);
#endif
        throw std::runtime_error("failed to reserve a temporary loopback port");
    }

#ifdef _WIN32
    int length = sizeof(address);
#else
    socklen_t length = sizeof(address);
#endif
    if (::getsockname(descriptor, reinterpret_cast<sockaddr*>(&address), &length) != 0) {
#ifdef _WIN32
        ::closesocket(descriptor);
#else
        ::close(descriptor);
#endif
        throw std::runtime_error("failed to inspect a temporary loopback port");
    }
    const int port = ntohs(address.sin_port);
#ifdef _WIN32
    ::closesocket(descriptor);
#else
    ::close(descriptor);
#endif
    return port;
}

class ThreadSafeSink final : public ohmytypeless::PushAudioSink {
public:
    bool on_push_audio_start(const ohmytypeless::PushAudioStreamInfo& stream, std::string*) override {
        std::scoped_lock lock(mutex_);
        stream_ = stream;
        return true;
    }

    bool on_push_audio_samples(std::uint32_t,
                               std::span<const std::int16_t> samples,
                               std::string*) override {
        {
            std::scoped_lock lock(mutex_);
            samples_.insert(samples_.end(), samples.begin(), samples.end());
        }
        condition_.notify_all();
        return true;
    }

    void on_push_audio_stop(std::uint32_t stream_id, ohmytypeless::PushAudioStopReason reason) override {
        {
            std::scoped_lock lock(mutex_);
            stops_.emplace_back(stream_id, reason);
        }
        condition_.notify_all();
    }

    bool wait_for_samples(std::size_t count) {
        std::unique_lock lock(mutex_);
        return condition_.wait_for(lock, 5s, [&]() { return samples_.size() >= count; });
    }

    bool wait_for_stops(std::size_t count) {
        std::unique_lock lock(mutex_);
        return condition_.wait_for(lock, 5s, [&]() { return stops_.size() >= count; });
    }

    std::optional<ohmytypeless::PushAudioStreamInfo> stream() const {
        std::scoped_lock lock(mutex_);
        return stream_;
    }

    std::vector<std::int16_t> samples() const {
        std::scoped_lock lock(mutex_);
        return samples_;
    }

private:
    mutable std::mutex mutex_;
    std::condition_variable condition_;
    std::optional<ohmytypeless::PushAudioStreamInfo> stream_;
    std::vector<std::int16_t> samples_;
    std::vector<std::pair<std::uint32_t, ohmytypeless::PushAudioStopReason>> stops_;
};

class ClientInbox {
public:
    void attach(ix::WebSocket& socket) {
        socket.setOnMessageCallback([this](const ix::WebSocketMessagePtr& message) {
            std::scoped_lock lock(mutex_);
            if (message->type == ix::WebSocketMessageType::Open) {
                opened_ = true;
            } else if (message->type == ix::WebSocketMessageType::Close) {
                closed_ = true;
            } else if (message->type == ix::WebSocketMessageType::Error) {
                error_ = message->errorInfo.reason;
            } else if (message->type == ix::WebSocketMessageType::Message && !message->binary) {
                messages_.push_back(nlohmann::json::parse(message->str));
            }
            condition_.notify_all();
        });
    }

    bool wait_open() {
        std::unique_lock lock(mutex_);
        return condition_.wait_for(lock, 5s, [&]() { return opened_ || !error_.empty(); }) && opened_;
    }

    std::optional<nlohmann::json> wait_type(const std::string& type) {
        std::unique_lock lock(mutex_);
        const bool found = condition_.wait_for(lock, 5s, [&]() {
            return std::any_of(messages_.cbegin(), messages_.cend(), [&](const nlohmann::json& message) {
                return message.value("type", std::string()) == type;
            }) || !error_.empty();
        });
        if (!found) {
            return std::nullopt;
        }
        const auto iterator = std::find_if(messages_.begin(), messages_.end(), [&](const nlohmann::json& message) {
            return message.value("type", std::string()) == type;
        });
        if (iterator == messages_.end()) {
            return std::nullopt;
        }
        nlohmann::json message = std::move(*iterator);
        messages_.erase(iterator);
        return message;
    }

    bool wait_closed() {
        std::unique_lock lock(mutex_);
        return condition_.wait_for(lock, 5s, [&]() { return closed_; });
    }

private:
    std::mutex mutex_;
    std::condition_variable condition_;
    bool opened_ = false;
    bool closed_ = false;
    std::string error_;
    std::deque<nlohmann::json> messages_;
};

void send_json(ix::WebSocket& client, const nlohmann::json& message) {
    const auto result = client.sendText(message.dump());
    require(result.success, "failed to send a Nearby control message");
}

void send_hello(ix::WebSocket& client) {
    send_json(client,
              {{"type", "hello"},
               {"protocol_version", ohmytypeless::kNearbyProtocolVersion},
               {"client", {{"id", "ios-test-client"}, {"name", "iOS E2E"}, {"kind", "iphone"}}}});
}

void test_socket_round_trip(const std::filesystem::path& directory) {
    using namespace ohmytypeless;

    ThreadSafeSink sink;
    const NearbyTlsIdentity identity = NearbyTlsIdentityStore(directory / "tls").load_or_create();
    std::uint8_t next_random = 0;
    NearbyWebSocketServer server(
        NearbyWebSocketServerConfig{
            .host = "127.0.0.1",
            .port = available_loopback_port(),
            .max_connections = 4,
            .tls_enabled = true,
            .tls_certificate_path = identity.certificate_path.string(),
            .tls_private_key_path = identity.private_key_path.string(),
        },
        directory / "trust.json",
        sink,
        [&next_random](std::size_t size) {
            std::vector<std::uint8_t> bytes(size);
            for (std::uint8_t& byte : bytes) {
                byte = next_random++;
            }
            return bytes;
        });
    server.start();
    require(server.running() && server.port() > 0 && server.websocket_url().starts_with("wss://127.0.0.1:"),
            "the Nearby server must bind an encrypted loopback endpoint");

    ix::SocketTLSOptions client_tls;
    client_tls.tls = true;
    client_tls.caFile = identity.certificate_path.string();
    client_tls.disable_hostname_validation = true;

    const NearbyPairingOffer offer = server.open_pairing(current_time_ms(), 30000);
    ix::WebSocket first_client;
    first_client.disableAutomaticReconnection();
    first_client.setTLSOptions(client_tls);
    first_client.setUrl(server.websocket_url());
    ClientInbox first_inbox;
    first_inbox.attach(first_client);
    first_client.start();
    require(first_inbox.wait_open(), "the first Nearby WebSocket client must connect");
    send_hello(first_client);

    const auto pairing_required = first_inbox.wait_type("pairing.required");
    require(pairing_required.has_value() && pairing_required->at("pairing_id") == offer.pairing_id,
            "an unknown client must receive the active pairing challenge without the display code");
    send_json(first_client,
              {{"type", "pairing.prove"},
               {"pairing_id", offer.pairing_id},
               {"proof", NearbyPairingService::pairing_proof(
                             offer.display_code, offer.pairing_id, "ios-test-client")}});
    const auto pairing_accepted = first_inbox.wait_type("pairing.accepted");
    require(pairing_accepted.has_value(), "a valid proof must pair over a real WebSocket connection");
    const std::string credential = pairing_accepted->at("credential").get<std::string>();

    send_json(first_client,
              {{"type", "audio.start"},
               {"stream_id", 42},
               {"profile_id", "translate"},
               {"format", {{"encoding", "pcm16le"}, {"sample_rate_hz", 16000}, {"channels", 1}}}});
    require(first_inbox.wait_type("audio.ready").has_value(), "the authenticated client must start remote audio");

    const std::vector<std::int16_t> samples{-32768, -12, 0, 12, 32767};
    const std::vector<std::byte> frame = encode_nearby_audio_frame(42, 0, samples);
    const std::string frame_bytes(reinterpret_cast<const char*>(frame.data()), frame.size());
    require(first_client.sendBinary(frame_bytes).success, "the client must send a binary PCM frame");
    require(sink.wait_for_samples(samples.size()) && sink.samples() == samples,
            "binary audio must reach the shared push sink unchanged over a real socket");
    require(sink.stream().has_value() && sink.stream()->requested_profile_id == "translate",
            "the real socket flow must preserve the requested Profile");

    send_json(first_client, {{"type", "audio.stop"}, {"stream_id", 42}});
    require(first_inbox.wait_type("audio.stopped").has_value() && sink.wait_for_stops(1),
            "audio.stop must finalize the remote stream end to end");
    first_client.stop();

    ix::WebSocket returning_client;
    returning_client.disableAutomaticReconnection();
    returning_client.setTLSOptions(client_tls);
    returning_client.setUrl(server.websocket_url());
    ClientInbox returning_inbox;
    returning_inbox.attach(returning_client);
    returning_client.start();
    require(returning_inbox.wait_open(), "the returning Nearby client must reconnect");
    send_hello(returning_client);
    const auto auth_message = returning_inbox.wait_type("auth.challenge");
    require(auth_message.has_value(), "a paired client must receive a challenge instead of another pairing code");
    const NearbyAuthChallenge challenge{
        .challenge_id = auth_message->at("challenge_id").get<std::string>(),
        .nonce_hex = auth_message->at("nonce").get<std::string>(),
        .expires_at_ms = auth_message->at("expires_at_ms").get<std::int64_t>(),
    };
    send_json(returning_client,
              {{"type", "auth.prove"},
               {"challenge_id", challenge.challenge_id},
               {"proof", NearbyPairingService::authentication_proof(
                             credential, challenge, "ios-test-client")}});
    require(returning_inbox.wait_type("auth.accepted").has_value(),
            "long-term trust must authenticate after reconnecting through a real socket");

    require(server.revoke_client("ios-test-client"), "the desktop must revoke a connected trusted client");
    require(returning_inbox.wait_closed() && server.trusted_clients().empty(),
            "revocation must close the active socket and remove persisted trust");
    returning_client.stop();
    server.stop();
}

void test_plaintext_lan_guard(const std::filesystem::path& directory) {
    ThreadSafeSink sink;
    ohmytypeless::NearbyWebSocketServer server(
        ohmytypeless::NearbyWebSocketServerConfig{.host = "0.0.0.0", .port = 39273},
        directory / "guard-trust.json",
        sink);
    bool rejected = false;
    try {
        server.start();
    } catch (const std::runtime_error&) {
        rejected = true;
    }
    require(rejected, "the server must never expose unencrypted voice or credentials to the LAN");
}

}  // namespace

int main() {
    const std::filesystem::path directory = unique_test_directory();
    ix::initNetSystem();
    try {
        std::filesystem::create_directories(directory);
        test_socket_round_trip(directory);
        test_plaintext_lan_guard(directory);
        std::filesystem::remove_all(directory);
        ix::uninitNetSystem();
        std::cout << "nearby_websocket_server_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::filesystem::remove_all(directory);
        ix::uninitNetSystem();
        std::cerr << "nearby_websocket_server_tests: " << exception.what() << '\n';
        return 1;
    }
}
