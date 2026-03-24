#pragma once

#include "core/backend/streaming/websocket_transport_options.hpp"

#include <ixwebsocket/IXSocket.h>
#include <ixwebsocket/IXSocketTLSOptions.h>

#include <mbedtls/ctr_drbg.h>
#include <mbedtls/entropy.h>
#include <mbedtls/error.h>
#include <mbedtls/net_sockets.h>
#include <mbedtls/pk.h>
#include <mbedtls/ssl.h>
#include <mbedtls/x509.h>
#include <mbedtls/x509_crt.h>

#include <mutex>
#include <string>

namespace ohmytypeless {

class IxProxySocket final : public ix::Socket {
public:
    IxProxySocket(const ix::SocketTLSOptions& tls_options, WebSocketTransportOptions transport_options, int fd = -1);
    ~IxProxySocket() override;

    bool accept(std::string& errMsg) override;
    bool connect(const std::string& host,
                 int port,
                 std::string& errMsg,
                 const ix::CancellationRequest& isCancellationRequested) override;
    void close() override;
    ssize_t send(char* buffer, size_t length) override;
    ssize_t recv(void* buffer, size_t length) override;

private:
    bool connect_raw(const std::string& host,
                     int port,
                     std::string& errMsg,
                     const ix::CancellationRequest& isCancellationRequested);
    bool establish_http_connect_tunnel(const std::string& host,
                                       int port,
                                       std::string& errMsg,
                                       const ix::CancellationRequest& isCancellationRequested);
    bool establish_socks5_tunnel(const std::string& host,
                                 int port,
                                 std::string& errMsg,
                                 const ix::CancellationRequest& isCancellationRequested);
    bool initialize_tls(const std::string& host, std::string& errMsg);
    bool load_system_certificates(std::string& errMsg);
    bool write_raw(const std::string& bytes, const ix::CancellationRequest& isCancellationRequested);
    bool read_raw_exact(std::size_t length,
                        std::string& out,
                        std::string& errMsg,
                        const ix::CancellationRequest& isCancellationRequested);
    bool read_raw_line(std::string& out,
                       std::string& errMsg,
                       const ix::CancellationRequest& isCancellationRequested);
    void initialize_mbedtls();
    void free_mbedtls();
    void close_unlocked();

    ix::SocketTLSOptions tls_options_;
    WebSocketTransportOptions transport_options_;
    bool tls_active_ = false;
    bool mbedtls_initialized_ = false;

    mbedtls_ssl_context ssl_;
    mbedtls_ssl_config conf_;
    mbedtls_entropy_context entropy_;
    mbedtls_ctr_drbg_context ctr_drbg_;
    mbedtls_x509_crt cacert_;
    mbedtls_x509_crt cert_;
    mbedtls_pk_context pkey_;

    std::mutex mutex_;
};

}  // namespace ohmytypeless
