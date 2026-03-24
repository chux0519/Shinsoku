#pragma once

#include "core/app_config.hpp"
#include "core/backend/streaming_asr_backend.hpp"
#include "core/backend/streaming/websocket_transport_options.hpp"

#include <memory>

namespace ohmytypeless {

class SonioxStreamingAsrBackend final : public StreamingAsrBackend {
public:
    explicit SonioxStreamingAsrBackend(const AppConfig& config);

    std::string name() const override;
    StreamingAsrCapabilities capabilities() const override;
    std::unique_ptr<StreamingAsrSession> create_session() const override;

private:
    SonioxConfig config_;
    WebSocketTransportOptions transport_;
};

}  // namespace ohmytypeless
