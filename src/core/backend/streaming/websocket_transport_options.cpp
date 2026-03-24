#include "core/backend/streaming/websocket_transport_options.hpp"

namespace ohmytypeless {

WebSocketTransportOptions make_websocket_transport_options(const AppConfig& config) {
    WebSocketTransportOptions options;
    if (!config.network.proxy.enabled) {
        return options;
    }

    options.proxy_type = config.network.proxy.type == "socks5" ? WebSocketProxyType::Socks5 : WebSocketProxyType::Http;
    options.proxy_host = config.network.proxy.host;
    options.proxy_port = config.network.proxy.port;
    options.proxy_username = config.network.proxy.username;
    options.proxy_password = config.network.proxy.password;
    return options;
}

std::string websocket_proxy_type_name(WebSocketProxyType type) {
    switch (type) {
    case WebSocketProxyType::None:
        return "none";
    case WebSocketProxyType::Http:
        return "http";
    case WebSocketProxyType::Socks5:
        return "socks5";
    }
    return "unknown";
}

}  // namespace ohmytypeless
