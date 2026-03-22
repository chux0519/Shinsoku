#include "core/curl_support.hpp"

#include <mutex>
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
