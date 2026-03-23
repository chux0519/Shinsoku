#pragma once

#include <curl/curl.h>

#include "core/app_config.hpp"

#include <atomic>
#include <string>

namespace ohmytypeless {

void ensure_curl_global_init();

struct CurlTransportOptions {
    bool proxy_enabled = false;
    std::string proxy_type = "http";
    std::string proxy_host;
    int proxy_port = 8080;
    std::string proxy_username;
    std::string proxy_password;
};

struct CurlCancelContext {
    const std::atomic_bool* cancel_flag = nullptr;
};

CurlTransportOptions make_curl_transport_options(const AppConfig& config);
void apply_curl_transport_options(CURL* curl, const CurlTransportOptions& options);

int curl_cancel_callback(void* clientp,
                         curl_off_t dltotal,
                         curl_off_t dlnow,
                         curl_off_t ultotal,
                         curl_off_t ulnow);

}  // namespace ohmytypeless
