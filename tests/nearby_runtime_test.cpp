#include "core/input/push_audio_source.hpp"
#include "platform/network/nearby_discovery_publisher.hpp"
#include "platform/network/nearby_runtime.hpp"

#include <ixwebsocket/IXNetSystem.h>

#ifdef _WIN32
#include <winsock2.h>
#else
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#endif

#include <chrono>
#include <filesystem>
#include <iostream>
#include <span>
#include <stdexcept>
#include <string>

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

std::filesystem::path unique_test_directory() {
    const auto suffix = std::chrono::steady_clock::now().time_since_epoch().count();
    return std::filesystem::temp_directory_path() / ("shinsoku-nearby-runtime-test-" + std::to_string(suffix));
}

int available_port() {
#ifdef _WIN32
    const SOCKET socket_fd = ::socket(AF_INET, SOCK_STREAM, 0);
    require(socket_fd != INVALID_SOCKET, "the runtime test must create a port probe socket");
#else
    const int socket_fd = ::socket(AF_INET, SOCK_STREAM, 0);
    require(socket_fd >= 0, "the runtime test must create a port probe socket");
#endif
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    require(::bind(socket_fd, reinterpret_cast<const sockaddr*>(&address), sizeof(address)) == 0,
            "the runtime test must bind a port probe socket");
#ifdef _WIN32
    int length = sizeof(address);
#else
    socklen_t length = sizeof(address);
#endif
    require(::getsockname(socket_fd, reinterpret_cast<sockaddr*>(&address), &length) == 0,
            "the runtime test must inspect its allocated port");
#ifdef _WIN32
    ::closesocket(socket_fd);
#else
    ::close(socket_fd);
#endif
    return ntohs(address.sin_port);
}

class Sink final : public ohmytypeless::PushAudioSink {
public:
    bool on_push_audio_start(const ohmytypeless::PushAudioStreamInfo&, std::string*) override {
        return true;
    }

    bool on_push_audio_samples(std::uint32_t,
                               std::span<const std::int16_t>,
                               std::string*) override {
        return true;
    }

    void on_push_audio_stop(std::uint32_t, ohmytypeless::PushAudioStopReason) override {}
};

class Publisher final : public ohmytypeless::NearbyDiscoveryPublisher {
public:
    explicit Publisher(bool fail = false) : fail_(fail) {}

    void start(const ohmytypeless::NearbyDiscoveryRecord& record) override {
        ++start_count;
        if (fail_) {
            throw std::runtime_error("injected discovery failure");
        }
        record_ = record;
        running_ = true;
    }

    void stop() override {
        ++stop_count;
        running_ = false;
    }

    bool running() const override {
        return running_;
    }

    std::string registered_name() const override {
        return running_ ? record_.service_name : std::string();
    }

    int start_count = 0;
    int stop_count = 0;
    ohmytypeless::NearbyDiscoveryRecord record_;

private:
    bool fail_ = false;
    bool running_ = false;
};

}  // namespace

int main() {
    const std::filesystem::path directory = unique_test_directory();
    ix::initNetSystem();
    try {
        Sink sink;
        auto publisher = std::make_unique<Publisher>();
        Publisher* publisher_view = publisher.get();
        ohmytypeless::NearbyRuntime runtime(sink, std::move(publisher));
        const ohmytypeless::NearbyRuntimeConfig config{
            .enabled = true,
            .port = available_port(),
            .service_name = "Shinsoku Runtime E2E",
            .storage_directory = directory,
        };

        runtime.apply(config);
        const auto status = runtime.status();
        require(status.running && status.discoverable && status.port == config.port,
                "the Nearby runtime must start WSS and discovery together");
        require(status.certificate_sha256.size() == 64U &&
                    std::filesystem::exists(directory / "identity" / "certificate.pem") &&
                    std::filesystem::exists(directory / "identity" / "private-key.pem"),
                "the Nearby runtime must persist its TLS identity");
        require(publisher_view->record_.port == config.port &&
                    publisher_view->record_.certificate_sha256 == status.certificate_sha256,
                "discovery must advertise the active WSS endpoint identity");

        const auto pairing = runtime.open_pairing(1000, 120000);
        require(pairing.display_code.size() == 2U && pairing.expires_at_ms == 121000,
                "the product runtime must expose limited-time two-digit pairing");
        runtime.apply(config);
        require(publisher_view->start_count == 1, "reapplying unchanged settings must not restart the service");

        runtime.stop();
        require(!runtime.status().running && publisher_view->stop_count >= 1,
                "stopping the product runtime must withdraw discovery and WSS");

        auto failing_publisher = std::make_unique<Publisher>(true);
        ohmytypeless::NearbyRuntime failing_runtime(sink, std::move(failing_publisher));
        bool failed = false;
        try {
            auto failing_config = config;
            failing_config.port = available_port();
            failing_config.storage_directory = directory / "failing";
            failing_runtime.apply(failing_config);
        } catch (const std::runtime_error&) {
            failed = true;
        }
        require(failed && !failing_runtime.status().running,
                "a discovery failure must roll back the WSS listener");

        std::filesystem::remove_all(directory);
        ix::uninitNetSystem();
        std::cout << "nearby_runtime_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::filesystem::remove_all(directory);
        ix::uninitNetSystem();
        std::cerr << "nearby_runtime_tests: " << exception.what() << '\n';
        return 1;
    }
}
