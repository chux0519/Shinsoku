#include "core/input/push_audio_source.hpp"
#include "core/nearby/nearby_tls_identity.hpp"
#include "platform/network/nearby_websocket_server.hpp"

#include <ixwebsocket/IXNetSystem.h>
#include <nlohmann/json.hpp>

#ifdef _WIN32
#include <winsock2.h>
#else
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#endif

#include <chrono>
#include <filesystem>
#include <iostream>
#include <mutex>
#include <span>
#include <stdexcept>
#include <string>

namespace {

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
        throw std::runtime_error("failed to create fixture socket");
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
        throw std::runtime_error("failed to reserve fixture port");
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
        throw std::runtime_error("failed to inspect fixture port");
    }
    const int port = ntohs(address.sin_port);
#ifdef _WIN32
    ::closesocket(descriptor);
#else
    ::close(descriptor);
#endif
    return port;
}

class FixtureSink final : public ohmytypeless::PushAudioSink {
public:
    bool on_push_audio_start(const ohmytypeless::PushAudioStreamInfo& stream, std::string*) override {
        emit({{"event", "audio.start"},
              {"stream_id", stream.stream_id},
              {"client_id", stream.source_id},
              {"profile_id", stream.requested_profile_id}});
        return true;
    }

    bool on_push_audio_samples(std::uint32_t stream_id,
                               std::span<const std::int16_t> samples,
                               std::string*) override {
        emit({{"event", "audio.samples"}, {"stream_id", stream_id}, {"sample_count", samples.size()}});
        return true;
    }

    void on_push_audio_stop(std::uint32_t stream_id, ohmytypeless::PushAudioStopReason reason) override {
        emit({{"event", "audio.stop"},
              {"stream_id", stream_id},
              {"reason", reason == ohmytypeless::PushAudioStopReason::Completed ? "completed" : "disconnected"}});
    }

private:
    void emit(const nlohmann::json& event) {
        std::scoped_lock lock(output_mutex_);
        std::cout << event.dump() << '\n' << std::flush;
    }

    std::mutex output_mutex_;
};

}  // namespace

int main() {
    const std::filesystem::path directory =
        std::filesystem::temp_directory_path() /
        ("shinsoku-nearby-fixture-" + std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
    try {
        ix::initNetSystem();
        FixtureSink sink;
        const auto identity = ohmytypeless::NearbyTlsIdentityStore(directory / "identity").load_or_create();
        ohmytypeless::NearbyWebSocketServer server(
            ohmytypeless::NearbyWebSocketServerConfig{
                .host = "127.0.0.1",
                .port = available_loopback_port(),
                .max_connections = 4,
                .tls_enabled = true,
                .tls_certificate_path = identity.certificate_path.string(),
                .tls_private_key_path = identity.private_key_path.string(),
            },
            directory / "trusted-clients.json",
            sink);
        server.start();
        const auto pairing = server.open_pairing(current_time_ms(), 10 * 60 * 1000);
        std::cout << nlohmann::json{{"event", "ready"},
                                   {"endpoint", "wss://127.0.0.1:" + std::to_string(server.port())},
                                   {"fingerprint", identity.certificate_sha256},
                                   {"pairing_code", pairing.display_code}}
                         .dump()
                  << '\n'
                  << std::flush;

        std::string command;
        while (std::getline(std::cin, command)) {
            if (command == "quit") {
                break;
            }
            constexpr std::string_view revoke_prefix = "revoke ";
            if (command.starts_with(revoke_prefix)) {
                const std::string client_id = command.substr(revoke_prefix.size());
                std::cout << nlohmann::json{{"event", "revoke"},
                                           {"client_id", client_id},
                                           {"revoked", server.revoke_client(client_id)}}
                                 .dump()
                          << '\n'
                          << std::flush;
            }
        }
        server.stop();
        std::filesystem::remove_all(directory);
        ix::uninitNetSystem();
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << "nearby_server_fixture: " << exception.what() << '\n';
        std::filesystem::remove_all(directory);
        ix::uninitNetSystem();
        return 1;
    }
}
