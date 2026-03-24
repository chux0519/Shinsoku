#pragma once

#include "core/app_config.hpp"

#include <string>

namespace ohmytypeless {

enum class WebSocketProxyType {
    None,
    Http,
    Socks5,
};

struct WebSocketTransportOptions {
    WebSocketProxyType proxy_type = WebSocketProxyType::None;
    std::string proxy_host;
    int proxy_port = 0;
    std::string proxy_username;
    std::string proxy_password;
};

WebSocketTransportOptions make_websocket_transport_options(const AppConfig& config);
std::string websocket_proxy_type_name(WebSocketProxyType type);

}  // namespace ohmytypeless
