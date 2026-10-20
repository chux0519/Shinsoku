#pragma once

#include <cstdint>
#include <string>

namespace ohmytypeless {

inline constexpr const char* kNearbyBonjourServiceType = "_shinsoku-mic._tcp";

struct NearbyDiscoveryRecord {
    std::string service_name;
    std::uint16_t port = 0;
    std::string instance_id;
    std::string certificate_sha256;
};

class NearbyDiscoveryPublisher {
public:
    virtual ~NearbyDiscoveryPublisher() = default;

    virtual void start(const NearbyDiscoveryRecord& record) = 0;
    virtual void stop() = 0;
    virtual bool running() const = 0;
    virtual std::string registered_name() const = 0;
};

}  // namespace ohmytypeless
