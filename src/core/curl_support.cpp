#include "core/curl_support.hpp"

#include <mutex>
#include <string>
#include <stdexcept>

namespace ohmytypeless {

void ensure_curl_global_init() {
    static std::once_flag init_flag;
    static CURLcode init_result = CURLE_OK;

    std::call_once(init_flag, []() {
        init_result = curl_global_init(CURL_GLOBAL_DEFAULT);
    });

    if (init_result != CURLE_OK) {
        throw std::runtime_error("failed to initialize curl globals");
    }
}

CurlTransportOptions make_curl_transport_options(const AppConfig& config) {
    return CurlTransportOptions{
        .proxy_enabled = config.network.proxy.enabled,
        .proxy_type = config.network.proxy.type,
        .proxy_host = config.network.proxy.host,
        .proxy_port = config.network.proxy.port,
        .proxy_username = config.network.proxy.username,
        .proxy_password = config.network.proxy.password,
    };
}

void apply_curl_transport_options(CURL* curl, const CurlTransportOptions& options) {
    if (curl == nullptr || !options.proxy_enabled) {
        return;
    }
    if (options.proxy_host.empty()) {
        throw std::runtime_error("proxy host is empty");
    }
    if (options.proxy_port <= 0) {
        throw std::runtime_error("proxy port is invalid");
    }

    curl_easy_setopt(curl, CURLOPT_PROXY, (options.proxy_host + ":" + std::to_string(options.proxy_port)).c_str());
    if (options.proxy_type == "socks5") {
        curl_easy_setopt(curl, CURLOPT_PROXYTYPE, CURLPROXY_SOCKS5_HOSTNAME);
    } else {
        curl_easy_setopt(curl, CURLOPT_PROXYTYPE, CURLPROXY_HTTP);
    }

    if (!options.proxy_username.empty()) {
        curl_easy_setopt(curl, CURLOPT_PROXYUSERNAME, options.proxy_username.c_str());
    }
    if (!options.proxy_password.empty()) {
        curl_easy_setopt(curl, CURLOPT_PROXYPASSWORD, options.proxy_password.c_str());
    }
}

int curl_cancel_callback(void* clientp,
                         curl_off_t dltotal,
                         curl_off_t dlnow,
                         curl_off_t ultotal,
                         curl_off_t ulnow) {
    static_cast<void>(dltotal);
    static_cast<void>(dlnow);
    static_cast<void>(ultotal);
    static_cast<void>(ulnow);

    const auto* context = static_cast<const CurlCancelContext*>(clientp);
    if (context != nullptr && context->cancel_flag != nullptr && context->cancel_flag->load()) {
        return 1;
    }

    return 0;
}

}  // namespace ohmytypeless
