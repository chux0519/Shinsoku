#pragma once

#include "platform/network/nearby_discovery_publisher.hpp"

#include <dns_sd.h>

#include <atomic>
#include <condition_variable>
#include <mutex>
#include <string>
#include <thread>

namespace ohmytypeless {

class MacOSBonjourPublisher final : public NearbyDiscoveryPublisher {
public:
    MacOSBonjourPublisher() = default;
    ~MacOSBonjourPublisher() override;

    MacOSBonjourPublisher(const MacOSBonjourPublisher&) = delete;
    MacOSBonjourPublisher& operator=(const MacOSBonjourPublisher&) = delete;

    void start(const NearbyDiscoveryRecord& record) override;
    void stop() override;
    bool running() const override;
    std::string registered_name() const override;

private:
    static void register_callback(DNSServiceRef service,
                                  DNSServiceFlags flags,
                                  DNSServiceErrorType error,
                                  const char* name,
                                  const char* type,
                                  const char* domain,
                                  void* context);
    void process_events();

    mutable std::mutex mutex_;
    std::condition_variable condition_;
    DNSServiceRef service_ = nullptr;
    std::thread worker_;
    std::atomic<bool> stop_requested_ = false;
    bool running_ = false;
    bool callback_received_ = false;
    DNSServiceErrorType registration_error_ = kDNSServiceErr_NoError;
    std::string registered_name_;
};

}  // namespace ohmytypeless
