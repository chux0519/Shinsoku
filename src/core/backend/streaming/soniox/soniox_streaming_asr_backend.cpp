#include "core/backend/streaming/soniox/soniox_streaming_asr_backend.hpp"
#include "core/backend/streaming/ix_proxy_socket.hpp"

#define private public
#include <ixwebsocket/IXWebSocketTransport.h>
#undef private

#include <ixwebsocket/IXUrlParser.h>
#include <ixwebsocket/IXWebSocketCloseConstants.h>
#include <ixwebsocket/IXWebSocketHandshake.h>

#include <nlohmann/json.hpp>

#include <atomic>
#include <algorithm>
#include <cstddef>
#include <map>
#include <mutex>
#include <span>
#include <string_view>
#include <thread>
#include <utility>

namespace ohmytypeless {

namespace {

std::string audio_format_name(const StreamingAudioFormat& format) {
    switch (format.encoding) {
    case StreamingAudioEncoding::Pcm16Le:
        return "s16le";
    case StreamingAudioEncoding::Float32Le:
        return "f32le";
    }
    return "s16le";
}

std::string join_token_text(const nlohmann::json& tokens, bool finals_only) {
    std::string text;
    if (!tokens.is_array()) {
        return text;
    }

    for (const auto& token : tokens) {
        if (!token.is_object()) {
            continue;
        }
        const bool is_final = token.value("is_final", false);
        if (finals_only && !is_final) {
            break;
        }
        const std::string piece = token.value("text", std::string());
        if (piece == "<fin>") {
            continue;
        }
        text += piece;
    }
    return text;
}

bool has_fin_token(const nlohmann::json& tokens) {
    if (!tokens.is_array()) {
        return false;
    }
    for (const auto& token : tokens) {
        if (!token.is_object()) {
            continue;
        }
        if (token.value("text", std::string()) == "<fin>") {
            return true;
        }
    }
    return false;
}

struct TimedToken {
    int start_ms = 0;
    int end_ms = 0;
    std::string text;
    bool is_final = false;
};

using TimedTokenKey = std::pair<int, int>;

void merge_timed_tokens(const nlohmann::json& tokens, std::map<TimedTokenKey, TimedToken>* aggregate) {
    if (!tokens.is_array() || aggregate == nullptr) {
        return;
    }

    for (const auto& token : tokens) {
        if (!token.is_object()) {
            continue;
        }

        TimedToken merged;
        merged.start_ms = token.value("start_ms", 0);
        merged.end_ms = token.value("end_ms", 0);
        merged.text = token.value("text", std::string());
        merged.is_final = token.value("is_final", false);
        if (merged.text.empty() || merged.text == "<fin>") {
            continue;
        }

        const TimedTokenKey key{merged.start_ms, merged.end_ms};
        auto existing = aggregate->find(key);
        if (existing == aggregate->end()) {
            aggregate->emplace(key, std::move(merged));
            continue;
        }

        if (!merged.text.empty()) {
            existing->second.text = std::move(merged.text);
        }
        existing->second.is_final = existing->second.is_final || merged.is_final;
    }
}

std::string render_aggregate_text(const std::map<TimedTokenKey, TimedToken>& aggregate, bool finals_only) {
    std::string text;
    for (const auto& [_, token] : aggregate) {
        if (finals_only && !token.is_final) {
            continue;
        }
        text += token.text;
    }
    return text;
}

class SonioxStreamingAsrSession final : public StreamingAsrSession {
public:
    SonioxStreamingAsrSession(SonioxConfig config, WebSocketTransportOptions transport)
        : config_(std::move(config)), transport_(std::move(transport)) {}

    ~SonioxStreamingAsrSession() override {
        cancel();
    }

    void start(const StreamingAsrStartOptions& options, StreamingAsrCallbacks callbacks) override {
        options_ = options;
        callbacks_ = std::move(callbacks);
        stop_requested_ = false;
        closed_emitted_ = false;
        last_partial_text_.clear();
        last_final_text_.clear();
        aggregate_tokens_.clear();

        if (started_) {
            if (callbacks_.on_error) {
                callbacks_.on_error("Soniox streaming session already started.");
            }
            return;
        }
        if (config_.api_key.empty()) {
            if (callbacks_.on_error) {
                callbacks_.on_error("Soniox API key is empty.");
            }
            return;
        }
        if (config_.url.empty()) {
            if (callbacks_.on_error) {
                callbacks_.on_error("Soniox WebSocket URL is empty.");
            }
            return;
        }
        if (options_.audio_format.channel_count == 0 || options_.audio_format.sample_rate_hz == 0) {
            if (callbacks_.on_error) {
                callbacks_.on_error("Soniox audio format is invalid.");
            }
            return;
        }

        ix::SocketTLSOptions tls_options;
        tls_options.tls = true;

        transport_impl_.configure(ix::WebSocketPerMessageDeflateOptions(false), tls_options, true, -1);
        transport_impl_.setOnCloseCallback([this](uint16_t, const std::string&, size_t, bool) {
            emit_closed_once();
        });

        std::string protocol;
        std::string host;
        std::string path;
        std::string query;
        int port = 0;
        if (!ix::UrlParser::parse(config_.url, protocol, host, path, query, port)) {
            if (callbacks_.on_error) {
                callbacks_.on_error("Soniox WebSocket URL could not be parsed.");
            }
            return;
        }

        transport_impl_._socket = std::make_unique<IxProxySocket>(tls_options, transport_);
        transport_impl_._perMessageDeflate = std::make_unique<ix::WebSocketPerMessageDeflate>();

        ix::WebSocketHandshake handshake(transport_impl_._requestInitCancellation,
                                         transport_impl_._socket,
                                         transport_impl_._perMessageDeflate,
                                         transport_impl_._perMessageDeflateOptions,
                                         transport_impl_._enablePerMessageDeflate);

        const ix::WebSocketInitResult status =
            handshake.clientHandshake(config_.url, ix::WebSocketHttpHeaders(), protocol, host, path, port, 30);
        if (!status.success) {
            if (callbacks_.on_error) {
                callbacks_.on_error(status.errorStr.empty() ? "Soniox websocket handshake failed." : status.errorStr);
            }
            transport_impl_._socket.reset();
            return;
        }

        transport_impl_.setReadyState(ix::WebSocketTransport::ReadyState::OPEN);
        started_ = true;

        nlohmann::json start_request = {
            {"api_key", config_.api_key},
            {"model", config_.model},
            {"audio_format", audio_format_name(options_.audio_format)},
            {"num_channels", options_.audio_format.channel_count},
            {"sample_rate", options_.audio_format.sample_rate_hz},
        };
        if (options_.language.has_value() && !options_.language->empty()) {
            start_request["language_hints"] = nlohmann::json::array({*options_.language});
        }

        {
            std::lock_guard<std::mutex> lock(write_mutex_);
            const ix::WebSocketSendInfo send_info = transport_impl_.sendText(start_request.dump(), nullptr);
            if (!send_info.success) {
                started_ = false;
                transport_impl_.close(ix::WebSocketCloseConstants::kInternalErrorCode,
                                      "failed to send Soniox start message");
                if (callbacks_.on_error) {
                    callbacks_.on_error("Failed to send Soniox start message.");
                }
                emit_closed_once();
                return;
            }
            {
                std::scoped_lock diagnostics_lock(diagnostics_mutex_);
                ++text_frames_sent_;
            }
        }

        worker_ = std::thread([this]() { run(); });
        if (callbacks_.on_session_started) {
            callbacks_.on_session_started();
        }
    }

    void push_audio(std::span<const std::byte> audio_bytes) override {
        if (!started_) {
            return;
        }
        const char* data = reinterpret_cast<const char*>(audio_bytes.data());
        std::lock_guard<std::mutex> lock(write_mutex_);
        const ix::WebSocketSendInfo send_info =
            transport_impl_.sendBinary(std::string(data, audio_bytes.size()), nullptr);
        if (send_info.success) {
            std::scoped_lock diagnostics_lock(diagnostics_mutex_);
            ++binary_frames_sent_;
        }
        if (!send_info.success && callbacks_.on_error) {
            callbacks_.on_error("Failed to send audio chunk to Soniox.");
        }
    }

    void finish() override {
        if (!started_) {
            return;
        }
        {
            std::lock_guard<std::mutex> lock(write_mutex_);
            if (transport_impl_.sendText(std::string(R"({"type":"finalize"})"), nullptr).success) {
                std::scoped_lock diagnostics_lock(diagnostics_mutex_);
                ++text_frames_sent_;
            }
            if (transport_impl_.sendBinary(std::string(), nullptr).success) {
                std::scoped_lock diagnostics_lock(diagnostics_mutex_);
                ++binary_frames_sent_;
            }
        }
    }

    void cancel() override {
        if (!started_ && !worker_.joinable()) {
            return;
        }
        stop_requested_ = true;
        transport_impl_.close(ix::WebSocketCloseConstants::kNormalClosureCode,
                              ix::WebSocketCloseConstants::kNormalClosureMessage);
        join_worker();
    }

    nlohmann::json runtime_diagnostics() const override {
        std::scoped_lock lock(diagnostics_mutex_);
        return nlohmann::json{
            {"messages_received", messages_received_},
            {"binary_frames_sent", binary_frames_sent_},
            {"text_frames_sent", text_frames_sent_},
            {"aggregate_token_count", aggregate_token_count_},
            {"partial_emits", partial_emits_},
            {"final_emits", final_emits_},
            {"fin_seen", fin_seen_},
            {"final_audio_proc_ms", final_audio_proc_ms_},
            {"total_audio_proc_ms", total_audio_proc_ms_},
        };
    }

private:
    void run() {
        while (!stop_requested_) {
            const auto state = transport_impl_.getReadyState();
            if (state == ix::WebSocketTransport::ReadyState::CLOSED) {
                break;
            }

            const ix::WebSocketTransport::PollResult poll_result = transport_impl_.poll();
            transport_impl_.dispatch(
                poll_result,
                [this](const std::string& message,
                       std::size_t,
                       bool,
                       ix::WebSocketTransport::MessageKind kind) {
                    if (kind != ix::WebSocketTransport::MessageKind::MSG_TEXT) {
                        return;
                    }
                    handle_message(message);
                });
        }

        started_ = false;
        emit_closed_once();
    }

    void handle_message(const std::string& message) {
        nlohmann::json payload;
        try {
            payload = nlohmann::json::parse(message);
        } catch (const std::exception& exception) {
            if (callbacks_.on_error) {
                callbacks_.on_error(std::string("Invalid Soniox message: ") + exception.what());
            }
            return;
        }

        {
            std::scoped_lock lock(diagnostics_mutex_);
            ++messages_received_;
            final_audio_proc_ms_ = payload.value("final_audio_proc_ms", final_audio_proc_ms_);
            total_audio_proc_ms_ = payload.value("total_audio_proc_ms", total_audio_proc_ms_);
        }

        const int error_code = payload.value("error_code", 0);
        const std::string error_message = payload.value("error_message", std::string());
        if (error_code != 0 || !error_message.empty()) {
            if (callbacks_.on_error) {
                callbacks_.on_error(error_message.empty() ? "Soniox returned an error." : error_message);
            }
            transport_impl_.close(ix::WebSocketCloseConstants::kInternalErrorCode,
                                  error_message.empty() ? "soniox error" : error_message);
            return;
        }

        const nlohmann::json tokens = payload.value("tokens", nlohmann::json::array());
        merge_timed_tokens(tokens, &aggregate_tokens_);
        {
            std::scoped_lock lock(diagnostics_mutex_);
            aggregate_token_count_ = aggregate_tokens_.size();
        }
        const std::string partial_text = render_aggregate_text(aggregate_tokens_, false);
        const std::string final_text = render_aggregate_text(aggregate_tokens_, true);
        const bool finished = payload.value("finished", false) || has_fin_token(tokens);

        if (options_.emit_partial_results && callbacks_.on_partial_text && !partial_text.empty() &&
            partial_text != last_partial_text_) {
            last_partial_text_ = partial_text;
            {
                std::scoped_lock lock(diagnostics_mutex_);
                ++partial_emits_;
            }
            callbacks_.on_partial_text(partial_text);
        }

        const std::string candidate_text = !final_text.empty() ? final_text : partial_text;
        if (callbacks_.on_final_text && !candidate_text.empty() && candidate_text != last_final_text_) {
            last_final_text_ = candidate_text;
            {
                std::scoped_lock lock(diagnostics_mutex_);
                ++final_emits_;
            }
            callbacks_.on_final_text(candidate_text);
        }

        if (finished) {
            {
                std::scoped_lock lock(diagnostics_mutex_);
                fin_seen_ = true;
            }
            stop_requested_ = true;
            transport_impl_.close(ix::WebSocketCloseConstants::kNormalClosureCode,
                                  ix::WebSocketCloseConstants::kNormalClosureMessage);
        }
    }

    void emit_closed_once() {
        if (closed_emitted_.exchange(true)) {
            return;
        }
        if (callbacks_.on_session_closed) {
            callbacks_.on_session_closed();
        }
    }

    void join_worker() {
        if (worker_.joinable()) {
            worker_.join();
        }
        started_ = false;
    }

    SonioxConfig config_;
    WebSocketTransportOptions transport_;
    StreamingAsrStartOptions options_;
    StreamingAsrCallbacks callbacks_;
    ix::WebSocketTransport transport_impl_;
    std::thread worker_;
    std::mutex write_mutex_;
    mutable std::mutex diagnostics_mutex_;
    std::atomic_bool stop_requested_ = false;
    std::atomic_bool closed_emitted_ = false;
    bool started_ = false;
    std::string last_partial_text_;
    std::string last_final_text_;
    std::map<TimedTokenKey, TimedToken> aggregate_tokens_;
    std::size_t messages_received_ = 0;
    std::size_t binary_frames_sent_ = 0;
    std::size_t text_frames_sent_ = 0;
    std::size_t partial_emits_ = 0;
    std::size_t final_emits_ = 0;
    std::size_t aggregate_token_count_ = 0;
    bool fin_seen_ = false;
    int final_audio_proc_ms_ = 0;
    int total_audio_proc_ms_ = 0;
};

}  // namespace

SonioxStreamingAsrBackend::SonioxStreamingAsrBackend(const AppConfig& config)
    : config_(config.providers.soniox), transport_(make_websocket_transport_options(config)) {}

std::string SonioxStreamingAsrBackend::name() const {
    return "soniox";
}

StreamingAsrCapabilities SonioxStreamingAsrBackend::capabilities() const {
    return StreamingAsrCapabilities{
        .supports_partial_results = true,
        .supports_server_vad = true,
        .supports_language_hint = true,
    };
}

std::unique_ptr<StreamingAsrSession> SonioxStreamingAsrBackend::create_session() const {
    return std::make_unique<SonioxStreamingAsrSession>(config_, transport_);
}

}  // namespace ohmytypeless
