#include "platform/macos/macos_bonjour_publisher.hpp"

#include <arpa/inet.h>
#include <sys/select.h>

#include <algorithm>
#include <chrono>
#include <stdexcept>
#include <string_view>

namespace ohmytypeless {

namespace {

bool lower_hex(std::string_view value, std::size_t expected_size) {
    return value.size() == expected_size && std::all_of(value.cbegin(), value.cend(), [](char character) {
               return (character >= '0' && character <= '9') || (character >= 'a' && character <= 'f');
           });
}

void set_txt_value(TXTRecordRef& record, const char* key, const std::string& value) {
    if (value.size() > 255U ||
        TXTRecordSetValue(&record, key, static_cast<std::uint8_t>(value.size()), value.data()) !=
            kDNSServiceErr_NoError) {
        throw std::runtime_error(std::string("failed to encode Bonjour TXT field: ") + key);
    }
}

}  // namespace

MacOSBonjourPublisher::~MacOSBonjourPublisher() {
    stop();
}

void MacOSBonjourPublisher::start(const NearbyDiscoveryRecord& record) {
    stop();
    if (record.service_name.empty() || record.service_name.size() > 63U || record.port == 0U ||
        !lower_hex(record.instance_id, 32U) || !lower_hex(record.certificate_sha256, 64U)) {
        throw std::invalid_argument("invalid Nearby Bonjour record");
    }

    TXTRecordRef txt;
    TXTRecordCreate(&txt, 0, nullptr);
    try {
        set_txt_value(txt, "v", "1");
        set_txt_value(txt, "transport", "wss");
        set_txt_value(txt, "fp", record.certificate_sha256);
        set_txt_value(txt, "instance", record.instance_id);
    } catch (...) {
        TXTRecordDeallocate(&txt);
        throw;
    }

    DNSServiceRef service = nullptr;
    const DNSServiceErrorType error = DNSServiceRegister(&service,
                                                        0,
                                                        kDNSServiceInterfaceIndexAny,
                                                        record.service_name.c_str(),
                                                        kNearbyBonjourServiceType,
                                                        nullptr,
                                                        nullptr,
                                                        htons(record.port),
                                                        TXTRecordGetLength(&txt),
                                                        TXTRecordGetBytesPtr(&txt),
                                                        &MacOSBonjourPublisher::register_callback,
                                                        this);
    TXTRecordDeallocate(&txt);
    if (error != kDNSServiceErr_NoError || service == nullptr) {
        throw std::runtime_error("failed to register the Nearby Bonjour service: " + std::to_string(error));
    }

    {
        std::scoped_lock lock(mutex_);
        service_ = service;
        callback_received_ = false;
        registration_error_ = kDNSServiceErr_NoError;
        registered_name_.clear();
        running_ = false;
        stop_requested_.store(false);
    }
    worker_ = std::thread(&MacOSBonjourPublisher::process_events, this);

    std::unique_lock lock(mutex_);
    const bool completed = condition_.wait_for(lock, std::chrono::seconds(3), [this]() {
        return callback_received_ || registration_error_ != kDNSServiceErr_NoError;
    });
    const DNSServiceErrorType callback_error = registration_error_;
    lock.unlock();
    if (!completed || callback_error != kDNSServiceErr_NoError) {
        stop();
        throw std::runtime_error(!completed
                                     ? "timed out while publishing the Nearby Bonjour service"
                                     : "Nearby Bonjour registration failed: " + std::to_string(callback_error));
    }
}

void MacOSBonjourPublisher::stop() {
    stop_requested_.store(true);
    if (worker_.joinable()) {
        worker_.join();
    }

    DNSServiceRef service = nullptr;
    {
        std::scoped_lock lock(mutex_);
        service = service_;
        service_ = nullptr;
        running_ = false;
        callback_received_ = false;
        registered_name_.clear();
    }
    if (service != nullptr) {
        DNSServiceRefDeallocate(service);
    }
}

bool MacOSBonjourPublisher::running() const {
    std::scoped_lock lock(mutex_);
    return running_;
}

std::string MacOSBonjourPublisher::registered_name() const {
    std::scoped_lock lock(mutex_);
    return registered_name_;
}

void MacOSBonjourPublisher::register_callback(DNSServiceRef,
                                              DNSServiceFlags,
                                              DNSServiceErrorType error,
                                              const char* name,
                                              const char*,
                                              const char*,
                                              void* context) {
    auto* publisher = static_cast<MacOSBonjourPublisher*>(context);
    if (publisher == nullptr) {
        return;
    }
    {
        std::scoped_lock lock(publisher->mutex_);
        publisher->registration_error_ = error;
        publisher->callback_received_ = true;
        publisher->running_ = error == kDNSServiceErr_NoError;
        publisher->registered_name_ = error == kDNSServiceErr_NoError && name != nullptr ? name : std::string();
    }
    publisher->condition_.notify_all();
}

void MacOSBonjourPublisher::process_events() {
    DNSServiceRef service = nullptr;
    {
        std::scoped_lock lock(mutex_);
        service = service_;
    }
    if (service == nullptr) {
        return;
    }

    const int descriptor = DNSServiceRefSockFD(service);
    if (descriptor < 0) {
        std::scoped_lock lock(mutex_);
        registration_error_ = kDNSServiceErr_BadReference;
        condition_.notify_all();
        return;
    }

    while (!stop_requested_.load()) {
        fd_set read_set;
        FD_ZERO(&read_set);
        FD_SET(descriptor, &read_set);
        timeval timeout{.tv_sec = 0, .tv_usec = 200000};
        const int ready = ::select(descriptor + 1, &read_set, nullptr, nullptr, &timeout);
        if (ready == 0) {
            continue;
        }
        if (ready < 0 || DNSServiceProcessResult(service) != kDNSServiceErr_NoError) {
            std::scoped_lock lock(mutex_);
            registration_error_ = kDNSServiceErr_Unknown;
            running_ = false;
            condition_.notify_all();
            return;
        }
    }
}

}  // namespace ohmytypeless
