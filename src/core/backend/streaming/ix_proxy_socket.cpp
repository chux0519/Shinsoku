#include "core/backend/streaming/ix_proxy_socket.hpp"

#include <ixwebsocket/IXNetSystem.h>
#include <ixwebsocket/IXSocketConnect.h>

#include <array>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <mutex>
#include <sstream>
#include <stdexcept>

#ifdef _WIN32
#include <windows.h>
#include <wincrypt.h>
#include <winsock2.h>
#elif defined(__APPLE__)
#include <Security/SecCertificate.h>
#include <Security/SecTrust.h>
#include <sys/socket.h>
#include <sys/time.h>
#else
#include <sys/socket.h>
#include <sys/time.h>
#endif

namespace ohmytypeless {

namespace {

constexpr int kSocketIoTimeoutMs = 10000;

bool ensure_ix_net_system_initialized() {
    static std::once_flag init_flag;
    static bool init_ok = false;
    std::call_once(init_flag, []() {
        init_ok = ix::initNetSystem();
    });
    return init_ok;
}

std::string base64_encode(std::string_view input) {
    static constexpr char kAlphabet[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    std::string output;
    output.reserve(((input.size() + 2U) / 3U) * 4U);

    std::size_t i = 0;
    while (i + 2 < input.size()) {
        const std::uint32_t value = (static_cast<std::uint8_t>(input[i]) << 16U) |
                                    (static_cast<std::uint8_t>(input[i + 1]) << 8U) |
                                    static_cast<std::uint8_t>(input[i + 2]);
        output.push_back(kAlphabet[(value >> 18U) & 0x3FU]);
        output.push_back(kAlphabet[(value >> 12U) & 0x3FU]);
        output.push_back(kAlphabet[(value >> 6U) & 0x3FU]);
        output.push_back(kAlphabet[value & 0x3FU]);
        i += 3;
    }

    if (i < input.size()) {
        const bool has_second = (i + 1U) < input.size();
        const std::uint32_t value = (static_cast<std::uint8_t>(input[i]) << 16U) |
                                    (has_second ? (static_cast<std::uint8_t>(input[i + 1U]) << 8U) : 0U);
        output.push_back(kAlphabet[(value >> 18U) & 0x3FU]);
        output.push_back(kAlphabet[(value >> 12U) & 0x3FU]);
        output.push_back(has_second ? kAlphabet[(value >> 6U) & 0x3FU] : '=');
        output.push_back('=');
    }

    return output;
}

std::string trim_crlf(std::string text) {
    while (!text.empty() && (text.back() == '\r' || text.back() == '\n')) {
        text.pop_back();
    }
    return text;
}

}  // namespace

IxProxySocket::IxProxySocket(const ix::SocketTLSOptions& tls_options, WebSocketTransportOptions transport_options, int fd)
    : ix::Socket(fd), tls_options_(tls_options), transport_options_(std::move(transport_options)) {
    initialize_mbedtls();
}

IxProxySocket::~IxProxySocket() {
    IxProxySocket::close();
}

bool IxProxySocket::accept(std::string& errMsg) {
    errMsg = "IxProxySocket does not support accept().";
    return false;
}

bool IxProxySocket::connect(const std::string& host,
                            int port,
                            std::string& errMsg,
                            const ix::CancellationRequest& isCancellationRequested) {
    std::lock_guard<std::mutex> lock(mutex_);

    if (!ensure_ix_net_system_initialized()) {
        errMsg = "Failed to initialize IX network system.";
        return false;
    }

    if (!connect_raw(host, port, errMsg, isCancellationRequested)) {
        return false;
    }

    if (transport_options_.proxy_type == WebSocketProxyType::Http) {
        if (!establish_http_connect_tunnel(host, port, errMsg, isCancellationRequested)) {
            close_unlocked();
            return false;
        }
    } else if (transport_options_.proxy_type == WebSocketProxyType::Socks5) {
        if (!establish_socks5_tunnel(host, port, errMsg, isCancellationRequested)) {
            close_unlocked();
            return false;
        }
    }

    if (tls_options_.tls) {
        if (!initialize_tls(host, errMsg)) {
            close_unlocked();
            return false;
        }
        tls_active_ = true;
    }

    return true;
}

bool IxProxySocket::connect_raw(const std::string& host,
                                int port,
                                std::string& errMsg,
                                const ix::CancellationRequest& isCancellationRequested) {
    if (transport_options_.proxy_type == WebSocketProxyType::None) {
        _sockfd = ix::SocketConnect::connect(host, port, errMsg, isCancellationRequested);
    } else {
        if (transport_options_.proxy_host.empty()) {
            errMsg = "Proxy host is empty.";
            return false;
        }
        if (transport_options_.proxy_port <= 0) {
            errMsg = "Proxy port is invalid.";
            return false;
        }
        _sockfd = ix::SocketConnect::connect(
            transport_options_.proxy_host, transport_options_.proxy_port, errMsg, isCancellationRequested);
    }

    if (_sockfd == -1) {
        return false;
    }

    return configure_socket_timeouts(errMsg);
}

bool IxProxySocket::configure_socket_timeouts(std::string& errMsg) {
#ifdef _WIN32
    const DWORD timeout_ms = kSocketIoTimeoutMs;
    if (setsockopt(_sockfd,
                   SOL_SOCKET,
                   SO_RCVTIMEO,
                   reinterpret_cast<const char*>(&timeout_ms),
                   sizeof(timeout_ms)) != 0) {
        errMsg = "Failed to configure socket receive timeout.";
        return false;
    }
    if (setsockopt(_sockfd,
                   SOL_SOCKET,
                   SO_SNDTIMEO,
                   reinterpret_cast<const char*>(&timeout_ms),
                   sizeof(timeout_ms)) != 0) {
        errMsg = "Failed to configure socket send timeout.";
        return false;
    }
#else
    const timeval timeout{
        .tv_sec = kSocketIoTimeoutMs / 1000,
        .tv_usec = (kSocketIoTimeoutMs % 1000) * 1000,
    };
    if (::setsockopt(_sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) != 0) {
        errMsg = "Failed to configure socket receive timeout.";
        return false;
    }
    if (::setsockopt(_sockfd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout)) != 0) {
        errMsg = "Failed to configure socket send timeout.";
        return false;
    }
#endif

    return true;
}

bool IxProxySocket::establish_http_connect_tunnel(const std::string& host,
                                                  int port,
                                                  std::string& errMsg,
                                                  const ix::CancellationRequest& isCancellationRequested) {
    std::ostringstream request;
    request << "CONNECT " << host << ':' << port << " HTTP/1.1\r\n";
    request << "Host: " << host << ':' << port << "\r\n";
    request << "Proxy-Connection: Keep-Alive\r\n";
    if (!transport_options_.proxy_username.empty()) {
        const std::string credentials =
            transport_options_.proxy_username + ":" + transport_options_.proxy_password;
        request << "Proxy-Authorization: Basic " << base64_encode(credentials) << "\r\n";
    }
    request << "\r\n";

    if (!write_raw(request.str(), isCancellationRequested)) {
        errMsg = "Failed to write HTTP CONNECT request to proxy.";
        return false;
    }

    std::string status_line;
    if (!read_raw_line(status_line, errMsg, isCancellationRequested)) {
        return false;
    }
    status_line = trim_crlf(status_line);
    if (status_line.find(" 200 ") == std::string::npos && status_line.rfind("HTTP/1.1 200", 0) != 0 &&
        status_line.rfind("HTTP/1.0 200", 0) != 0) {
        errMsg = "HTTP proxy CONNECT failed: " + status_line;
        return false;
    }

    while (true) {
        std::string header_line;
        if (!read_raw_line(header_line, errMsg, isCancellationRequested)) {
            return false;
        }
        if (header_line == "\r\n" || trim_crlf(header_line).empty()) {
            break;
        }
    }

    return true;
}

bool IxProxySocket::establish_socks5_tunnel(const std::string& host,
                                            int port,
                                            std::string& errMsg,
                                            const ix::CancellationRequest& isCancellationRequested) {
    std::string greeting;
    greeting.push_back('\x05');
    greeting.push_back(transport_options_.proxy_username.empty() ? '\x01' : '\x02');
    greeting.push_back('\x00');
    if (!transport_options_.proxy_username.empty()) {
        greeting.push_back('\x02');
    }

    if (!write_raw(greeting, isCancellationRequested)) {
        errMsg = "Failed to write SOCKS5 greeting.";
        return false;
    }

    std::string response;
    if (!read_raw_exact(2, response, errMsg, isCancellationRequested)) {
        return false;
    }
    if (static_cast<std::uint8_t>(response[0]) != 0x05U) {
        errMsg = "Invalid SOCKS5 proxy greeting response.";
        return false;
    }

    const std::uint8_t method = static_cast<std::uint8_t>(response[1]);
    if (method == 0xFFU) {
        errMsg = "SOCKS5 proxy rejected all authentication methods.";
        return false;
    }

    if (method == 0x02U) {
        const std::string& username = transport_options_.proxy_username;
        const std::string& password = transport_options_.proxy_password;
        if (username.size() > 255U || password.size() > 255U) {
            errMsg = "SOCKS5 username/password is too long.";
            return false;
        }

        std::string auth_request;
        auth_request.push_back('\x01');
        auth_request.push_back(static_cast<char>(username.size()));
        auth_request.append(username);
        auth_request.push_back(static_cast<char>(password.size()));
        auth_request.append(password);

        if (!write_raw(auth_request, isCancellationRequested)) {
            errMsg = "Failed to write SOCKS5 username/password auth request.";
            return false;
        }

        if (!read_raw_exact(2, response, errMsg, isCancellationRequested)) {
            return false;
        }
        if (static_cast<std::uint8_t>(response[1]) != 0x00U) {
            errMsg = "SOCKS5 username/password authentication failed.";
            return false;
        }
    } else if (method != 0x00U) {
        errMsg = "SOCKS5 proxy selected an unsupported authentication method.";
        return false;
    }

    if (host.size() > 255U) {
        errMsg = "SOCKS5 target host is too long.";
        return false;
    }

    std::string connect_request;
    connect_request.push_back('\x05');
    connect_request.push_back('\x01');
    connect_request.push_back('\x00');
    connect_request.push_back('\x03');
    connect_request.push_back(static_cast<char>(host.size()));
    connect_request.append(host);
    connect_request.push_back(static_cast<char>((port >> 8) & 0xFF));
    connect_request.push_back(static_cast<char>(port & 0xFF));

    if (!write_raw(connect_request, isCancellationRequested)) {
        errMsg = "Failed to write SOCKS5 connect request.";
        return false;
    }

    if (!read_raw_exact(4, response, errMsg, isCancellationRequested)) {
        return false;
    }
    if (static_cast<std::uint8_t>(response[1]) != 0x00U) {
        std::ostringstream message;
        message << "SOCKS5 connect failed with reply code " << static_cast<int>(static_cast<std::uint8_t>(response[1]));
        errMsg = message.str();
        return false;
    }

    const std::uint8_t atyp = static_cast<std::uint8_t>(response[3]);
    std::size_t addr_length = 0;
    if (atyp == 0x01U) {
        addr_length = 4;
    } else if (atyp == 0x04U) {
        addr_length = 16;
    } else if (atyp == 0x03U) {
        std::string len_buf;
        if (!read_raw_exact(1, len_buf, errMsg, isCancellationRequested)) {
            return false;
        }
        addr_length = static_cast<std::uint8_t>(len_buf[0]);
    } else {
        errMsg = "SOCKS5 proxy returned an unsupported address type.";
        return false;
    }

    std::string skip;
    if (!read_raw_exact(addr_length + 2U, skip, errMsg, isCancellationRequested)) {
        return false;
    }

    return true;
}

bool IxProxySocket::initialize_tls(const std::string& host, std::string& errMsg) {
    const char* pers = "ShinsokuIxProxySocket";
    if (mbedtls_ctr_drbg_seed(&ctr_drbg_,
                              mbedtls_entropy_func,
                              &entropy_,
                              reinterpret_cast<const unsigned char*>(pers),
                              std::strlen(pers)) != 0) {
        errMsg = "Setting entropy seed failed.";
        return false;
    }

    if (mbedtls_ssl_config_defaults(
            &conf_, MBEDTLS_SSL_IS_CLIENT, MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT) != 0) {
        errMsg = "Setting TLS config defaults failed.";
        return false;
    }

    mbedtls_ssl_conf_rng(&conf_, mbedtls_ctr_drbg_random, &ctr_drbg_);

    if (tls_options_.isPeerVerifyDisabled()) {
        mbedtls_ssl_conf_authmode(&conf_, MBEDTLS_SSL_VERIFY_NONE);
    } else {
        mbedtls_ssl_conf_authmode(&conf_, MBEDTLS_SSL_VERIFY_REQUIRED);
        if (tls_options_.isUsingSystemDefaults()) {
            if (!load_system_certificates(errMsg)) {
                return false;
            }
        } else if (!tls_options_.caFile.empty() && tls_options_.caFile != "NONE") {
            if (mbedtls_x509_crt_parse_file(&cacert_, tls_options_.caFile.c_str()) < 0) {
                errMsg = "Cannot parse CA file '" + tls_options_.caFile + "'";
                return false;
            }
        }
        mbedtls_ssl_conf_ca_chain(&conf_, &cacert_, nullptr);
    }

    if (mbedtls_ssl_setup(&ssl_, &conf_) != 0) {
        errMsg = "TLS setup failed.";
        return false;
    }

    if (!tls_options_.disable_hostname_validation && !host.empty()) {
        if (mbedtls_ssl_set_hostname(&ssl_, host.c_str()) != 0) {
            errMsg = "TLS hostname validation setup failed.";
            return false;
        }
    }

    mbedtls_ssl_set_bio(&ssl_, &_sockfd, mbedtls_net_send, mbedtls_net_recv, nullptr);

    int res = 0;
    do {
        res = mbedtls_ssl_handshake(&ssl_);
    } while (res == MBEDTLS_ERR_SSL_WANT_READ || res == MBEDTLS_ERR_SSL_WANT_WRITE);

    if (res != 0) {
        std::array<char, 256> buffer{};
        mbedtls_strerror(res, buffer.data(), buffer.size());
        errMsg = "TLS handshake failed: " + std::string(buffer.data());
        return false;
    }

    return true;
}

bool IxProxySocket::load_system_certificates(std::string& errMsg) {
#ifdef _WIN32
    const DWORD flags = CERT_STORE_READONLY_FLAG | CERT_STORE_OPEN_EXISTING_FLAG | CERT_SYSTEM_STORE_CURRENT_USER;
    HCERTSTORE systemStore = CertOpenStore(CERT_STORE_PROV_SYSTEM, 0, 0, flags, L"Root");
    if (!systemStore) {
        errMsg = "CertOpenStore failed.";
        return false;
    }

    PCCERT_CONTEXT iterator = nullptr;
    int certificate_count = 0;
    while ((iterator = CertEnumCertificatesInStore(systemStore, iterator)) != nullptr) {
        if (iterator->dwCertEncodingType & X509_ASN_ENCODING) {
            const int ret = mbedtls_x509_crt_parse(&cacert_, iterator->pbCertEncoded, iterator->cbCertEncoded);
            if (ret == 0) {
                ++certificate_count;
            }
        }
    }

    CertCloseStore(systemStore, 0);

    if (certificate_count == 0) {
        errMsg = "No system certificates found.";
        return false;
    }
    return true;
#elif defined(__linux__)
    const auto try_parse_file = [this](const std::string& path) {
        return !path.empty() && std::filesystem::exists(path) &&
               mbedtls_x509_crt_parse_file(&cacert_, path.c_str()) == 0;
    };
    const auto try_parse_dir = [this](const std::string& path) {
        return !path.empty() && std::filesystem::exists(path) &&
               mbedtls_x509_crt_parse_path(&cacert_, path.c_str()) == 0;
    };

    if (const char* cert_file = std::getenv("SSL_CERT_FILE"); cert_file != nullptr && try_parse_file(cert_file)) {
        return true;
    }
    if (const char* cert_dir = std::getenv("SSL_CERT_DIR"); cert_dir != nullptr && try_parse_dir(cert_dir)) {
        return true;
    }

    static constexpr const char* kCommonCertFiles[] = {
        "/etc/ssl/certs/ca-certificates.crt",
        "/etc/pki/tls/certs/ca-bundle.crt",
        "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",
        "/etc/ssl/ca-bundle.pem",
        "/etc/ssl/cert.pem",
    };
    for (const char* path : kCommonCertFiles) {
        if (try_parse_file(path)) {
            return true;
        }
    }

    static constexpr const char* kCommonCertDirs[] = {
        "/etc/ssl/certs",
        "/etc/pki/tls/certs",
        "/etc/pki/ca-trust/extracted/pem",
    };
    for (const char* path : kCommonCertDirs) {
        if (try_parse_dir(path)) {
            return true;
        }
    }

    errMsg = "Failed to load system certificates from common Linux trust-store paths.";
    return false;
#elif defined(__APPLE__)
    CFArrayRef anchors = nullptr;
    const OSStatus status = SecTrustCopyAnchorCertificates(&anchors);
    if (status != errSecSuccess || anchors == nullptr) {
        errMsg = "Failed to load macOS system root certificates.";
        return false;
    }

    const CFIndex certificate_total = CFArrayGetCount(anchors);
    int certificate_count = 0;
    for (CFIndex i = 0; i < certificate_total; ++i) {
        auto* certificate = static_cast<SecCertificateRef>(const_cast<void*>(CFArrayGetValueAtIndex(anchors, i)));
        if (certificate == nullptr) {
            continue;
        }

        CFDataRef data = SecCertificateCopyData(certificate);
        if (data == nullptr) {
            continue;
        }

        const auto* bytes = static_cast<const unsigned char*>(CFDataGetBytePtr(data));
        const auto length = static_cast<size_t>(CFDataGetLength(data));
        if (bytes != nullptr && length > 0 &&
            mbedtls_x509_crt_parse(&cacert_, bytes, length) == 0) {
            ++certificate_count;
        }
        CFRelease(data);
    }

    CFRelease(anchors);

    if (certificate_count == 0) {
        errMsg = "No macOS system root certificates could be parsed.";
        return false;
    }
    return true;
#else
    errMsg = "System certificate loading is not implemented on this platform.";
    return false;
#endif
}

bool IxProxySocket::write_raw(const std::string& bytes, const ix::CancellationRequest& isCancellationRequested) {
    return ix::Socket::writeBytes(bytes, isCancellationRequested);
}

bool IxProxySocket::read_raw_exact(std::size_t length,
                                   std::string& out,
                                   std::string& errMsg,
                                   const ix::CancellationRequest& isCancellationRequested) {
    auto result = ix::Socket::readBytes(length, nullptr, nullptr, isCancellationRequested);
    if (!result.first) {
        errMsg = result.second.empty() ? "Failed to read from proxy." : result.second;
        return false;
    }
    out = std::move(result.second);
    return true;
}

bool IxProxySocket::read_raw_line(std::string& out,
                                  std::string& errMsg,
                                  const ix::CancellationRequest& isCancellationRequested) {
    auto result = ix::Socket::readLine(isCancellationRequested);
    if (!result.first) {
        errMsg = result.second.empty() ? "Failed to read line from proxy." : result.second;
        return false;
    }
    out = std::move(result.second);
    return true;
}

void IxProxySocket::initialize_mbedtls() {
    if (mbedtls_initialized_) {
        return;
    }
    mbedtls_ssl_init(&ssl_);
    mbedtls_ssl_config_init(&conf_);
    mbedtls_ctr_drbg_init(&ctr_drbg_);
    mbedtls_entropy_init(&entropy_);
    mbedtls_x509_crt_init(&cacert_);
    mbedtls_x509_crt_init(&cert_);
    mbedtls_pk_init(&pkey_);
#if MBEDTLS_VERSION_MAJOR >= 3 && MBEDTLS_VERSION_MINOR >= 6
    psa_crypto_init();
#endif
    mbedtls_initialized_ = true;
}

void IxProxySocket::free_mbedtls() {
    if (!mbedtls_initialized_) {
        return;
    }
    mbedtls_ssl_free(&ssl_);
    mbedtls_ssl_config_free(&conf_);
    mbedtls_ctr_drbg_free(&ctr_drbg_);
    mbedtls_entropy_free(&entropy_);
    mbedtls_x509_crt_free(&cacert_);
    mbedtls_x509_crt_free(&cert_);
    mbedtls_pk_free(&pkey_);
#if MBEDTLS_VERSION_MAJOR >= 3 && MBEDTLS_VERSION_MINOR >= 6
    mbedtls_psa_crypto_free();
#endif
    mbedtls_initialized_ = false;
}

void IxProxySocket::close() {
    std::lock_guard<std::mutex> lock(mutex_);
    close_unlocked();
}

void IxProxySocket::close_unlocked() {
    tls_active_ = false;
    free_mbedtls();
    ix::Socket::close();
}

ssize_t IxProxySocket::send(char* buffer, size_t length) {
    if (!tls_active_) {
        return ix::Socket::send(buffer, length);
    }

    const ssize_t res = mbedtls_ssl_write(&ssl_, reinterpret_cast<unsigned char*>(buffer), length);
    if (res > 0) {
        return res;
    }
    if (res == MBEDTLS_ERR_SSL_WANT_READ || res == MBEDTLS_ERR_SSL_WANT_WRITE) {
        errno = EWOULDBLOCK;
        return -1;
    }
    return -1;
}

ssize_t IxProxySocket::recv(void* buffer, size_t length) {
    if (!tls_active_) {
        return ix::Socket::recv(buffer, length);
    }

    const ssize_t res = mbedtls_ssl_read(&ssl_, reinterpret_cast<unsigned char*>(buffer), static_cast<int>(length));
    if (res > 0) {
        return res;
    }
    if (res == 0) {
        errno = ECONNRESET;
        return -1;
    }
    if (res == MBEDTLS_ERR_SSL_WANT_READ || res == MBEDTLS_ERR_SSL_WANT_WRITE) {
        errno = EWOULDBLOCK;
        return -1;
    }
    return -1;
}

}  // namespace ohmytypeless
