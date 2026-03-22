#pragma once

#include <curl/curl.h>

#include <atomic>

namespace ohmytypeless {

void ensure_curl_global_init();

struct CurlCancelContext {
    const std::atomic_bool* cancel_flag = nullptr;
};

int curl_cancel_callback(void* clientp,
                         curl_off_t dltotal,
                         curl_off_t dlnow,
                         curl_off_t ultotal,
                         curl_off_t ulnow);

}  // namespace ohmytypeless
