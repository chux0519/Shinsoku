#include "platform/macos/macos_bonjour_publisher.hpp"

#include <dns_sd.h>

#include <arpa/inet.h>
#include <sys/select.h>

#include <chrono>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

struct BrowseResult {
    bool found = false;
    std::uint32_t interface_index = 0;
    std::string expected_name;
    std::string name;
    std::string type;
    std::string domain;
};

void browse_callback(DNSServiceRef,
                     DNSServiceFlags flags,
                     std::uint32_t interface_index,
                     DNSServiceErrorType error,
                     const char* service_name,
                     const char* service_type,
                     const char* reply_domain,
                     void* context) {
    auto* result = static_cast<BrowseResult*>(context);
    if (result == nullptr || error != kDNSServiceErr_NoError || (flags & kDNSServiceFlagsAdd) == 0U) {
        return;
    }
    if (service_name == nullptr || service_name != result->expected_name) {
        return;
    }
    result->found = true;
    result->interface_index = interface_index;
    result->name = service_name != nullptr ? service_name : "";
    result->type = service_type != nullptr ? service_type : "";
    result->domain = reply_domain != nullptr ? reply_domain : "";
}

struct ResolveResult {
    bool found = false;
    std::uint16_t port = 0;
    std::string version;
    std::string transport;
    std::string fingerprint;
    std::string instance;
    bool contains_pairing_code = false;
};

std::string txt_value(std::uint16_t length, const unsigned char* bytes, const char* key) {
    std::uint8_t value_length = 0;
    const void* value = TXTRecordGetValuePtr(length, bytes, key, &value_length);
    return value != nullptr ? std::string(static_cast<const char*>(value), value_length) : std::string();
}

void resolve_callback(DNSServiceRef,
                      DNSServiceFlags,
                      std::uint32_t,
                      DNSServiceErrorType error,
                      const char*,
                      const char*,
                      std::uint16_t port,
                      std::uint16_t txt_length,
                      const unsigned char* txt_record,
                      void* context) {
    auto* result = static_cast<ResolveResult*>(context);
    if (result == nullptr || error != kDNSServiceErr_NoError) {
        return;
    }
    result->found = true;
    result->port = ntohs(port);
    result->version = txt_value(txt_length, txt_record, "v");
    result->transport = txt_value(txt_length, txt_record, "transport");
    result->fingerprint = txt_value(txt_length, txt_record, "fp");
    result->instance = txt_value(txt_length, txt_record, "instance");
    result->contains_pairing_code = TXTRecordContainsKey(txt_length, txt_record, "code") != 0 ||
                                    TXTRecordContainsKey(txt_length, txt_record, "pairing") != 0;
}

template <typename Predicate>
bool process_until(DNSServiceRef service, Predicate predicate) {
    const int descriptor = DNSServiceRefSockFD(service);
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
    while (!predicate() && std::chrono::steady_clock::now() < deadline) {
        fd_set read_set;
        FD_ZERO(&read_set);
        FD_SET(descriptor, &read_set);
        timeval timeout{.tv_sec = 0, .tv_usec = 200000};
        const int ready = ::select(descriptor + 1, &read_set, nullptr, nullptr, &timeout);
        if (ready < 0) {
            return false;
        }
        if (ready > 0 && DNSServiceProcessResult(service) != kDNSServiceErr_NoError) {
            return false;
        }
    }
    return predicate();
}

}  // namespace

int main() {
    try {
        const std::string instance_id = "00112233445566778899aabbccddeeff";
        const std::string fingerprint(64U, 'a');
        ohmytypeless::MacOSBonjourPublisher publisher;
        publisher.start({
            .service_name = "Shinsoku Bonjour E2E",
            .port = 42424,
            .instance_id = instance_id,
            .certificate_sha256 = fingerprint,
        });
        require(publisher.running() && !publisher.registered_name().empty(),
                "the macOS Bonjour publisher must complete registration");

        BrowseResult browse_result{.expected_name = publisher.registered_name()};
        DNSServiceRef browser = nullptr;
        require(DNSServiceBrowse(&browser,
                                 0,
                                 kDNSServiceInterfaceIndexAny,
                                 ohmytypeless::kNearbyBonjourServiceType,
                                 "local.",
                                 &browse_callback,
                                 &browse_result) == kDNSServiceErr_NoError,
                "the Bonjour test browser must start");
        require(process_until(browser, [&]() {
                    return browse_result.found && browse_result.name == publisher.registered_name();
                }),
                "the published Nearby service must be discoverable through Bonjour");
        DNSServiceRefDeallocate(browser);

        ResolveResult resolve_result;
        DNSServiceRef resolver = nullptr;
        require(DNSServiceResolve(&resolver,
                                  0,
                                  browse_result.interface_index,
                                  browse_result.name.c_str(),
                                  browse_result.type.c_str(),
                                  browse_result.domain.c_str(),
                                  &resolve_callback,
                                  &resolve_result) == kDNSServiceErr_NoError,
                "the Bonjour test resolver must start");
        require(process_until(resolver, [&]() { return resolve_result.found; }),
                "the published Nearby service must resolve");
        DNSServiceRefDeallocate(resolver);

        require(resolve_result.port == 42424 && resolve_result.version == "1" &&
                    resolve_result.transport == "wss" && resolve_result.fingerprint == fingerprint &&
                    resolve_result.instance == instance_id,
                "Bonjour must advertise the WSS endpoint identity and protocol version");
        require(!resolve_result.contains_pairing_code,
                "Bonjour TXT records must never disclose a pairing code");

        publisher.stop();
        require(!publisher.running(), "stopping Bonjour must withdraw the publisher state");
        std::cout << "macos_bonjour_publisher_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << "macos_bonjour_publisher_tests: " << exception.what() << '\n';
        return 1;
    }
}
