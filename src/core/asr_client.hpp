#pragma once

#include "core/app_config.hpp"
#include "core/curl_support.hpp"

#include <atomic>
#include <string>
#include <vector>

namespace ohmytypeless {

class AsrClient {
public:
    explicit AsrClient(AppConfig config);
    std::string transcribe(const std::vector<float>& samples, const std::atomic_bool* cancel_flag = nullptr) const;

private:
    EndpointConfig config_;
    CurlTransportOptions transport_options_;
    std::uint32_t sample_rate_ = kFixedSampleRate;
};

}  // namespace ohmytypeless
