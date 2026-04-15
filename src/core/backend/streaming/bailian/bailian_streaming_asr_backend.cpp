#include "core/backend/streaming/bailian/bailian_streaming_asr_backend.hpp"
#include "core/backend/streaming/ix_proxy_socket.hpp"

#define private public
#include <ixwebsocket/IXWebSocketTransport.h>
#undef private

#include <ixwebsocket/IXUrlParser.h>
#include <ixwebsocket/IXWebSocketCloseConstants.h>
#include <ixwebsocket/IXWebSocketHandshake.h>

#include <nlohmann/json.hpp>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <map>
#include <mutex>
#include <sstream>
#include <span>
#include <string_view>
#include <thread>
#include <utility>

namespace ohmytypeless {

namespace {

constexpr int kHandshakeTimeoutSeconds = 10;

struct BailianSentenceState {
    std::string text;
    bool is_final = false;
};

std::string render_bailian_text(const std::map<int, BailianSentenceState>& sentences, bool finals_only) {
    std::string text;
    for (const auto& [_, sentence] : sentences) {
        if (finals_only && !sentence.is_final) {
            continue;
        }
        text += sentence.text;
    }
    return text;
}

std::string make_task_id() {
    const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
    std::ostringstream out;
    out << std::hex << now;
    return out.str();
}

std::string describe_handshake_failure(const std::string& url, const std::string& error) {
    std::ostringstream message;
    message << "Bailian websocket connection failed for " << url << ".";
    if (!error.empty()) {
        message << ' ' << error;
    }
    message << " Check that the endpoint scheme, host, port, and path are correct.";
    return message.str();
}

class BailianStreamingAsrSession final : public StreamingAsrSession {
public:
    BailianStreamingAsrSession(BailianConfig config, WebSocketTransportOptions transport)
        : config_(std::move(config)), transport_(std::move(transport)) {}

    ~BailianStreamingAsrSession() override {
        cancel();
    }

    void start(const StreamingAsrStartOptions& options, StreamingAsrCallbacks callbacks) override {
        options_ = options;
        callbacks_ = std::move(callbacks);
        stop_requested_ = false;
        closed_emitted_ = false;
        last_partial_text_.clear();
        last_final_text_.clear();
        sentences_.clear();
        task_id_.clear();

        if (started_) {
            if (callbacks_.on_error) {
                callbacks_.on_error("Bailian streaming session already started.");
            }
            return;
        }
        if (config_.api_key.empty()) {
            if (callbacks_.on_error) {
                callbacks_.on_error("Bailian API key is empty.");
            }
            return;
        }
        if (config_.url.empty()) {
            if (callbacks_.on_error) {
                callbacks_.on_error("Bailian WebSocket URL is empty.");
            }
            return;
        }
        if (options_.audio_format.encoding != StreamingAudioEncoding::Pcm16Le) {
            if (callbacks_.on_error) {
                callbacks_.on_error("Bailian streaming only supports PCM16 audio today.");
            }
            return;
        }

        std::string protocol;
        std::string host;
        std::string path;
        std::string query;
        int port = 0;
        if (!ix::UrlParser::parse(config_.url, protocol, host, path, query, port)) {
            if (callbacks_.on_error) {
                callbacks_.on_error("Bailian WebSocket URL could not be parsed.");
            }
            return;
        }
        if (protocol != "ws" && protocol != "wss") {
            if (callbacks_.on_error) {
                callbacks_.on_error("Bailian WebSocket URL must start with ws:// or wss://.");
            }
            return;
        }

        ix::SocketTLSOptions tls_options;
        tls_options.tls = (protocol == "wss");

        transport_impl_.configure(ix::WebSocketPerMessageDeflateOptions(false), tls_options, true, -1);
        transport_impl_.setOnCloseCallback([this](uint16_t, const std::string&, size_t, bool) {
            emit_closed_once();
        });

        transport_impl_._socket = std::make_unique<IxProxySocket>(tls_options, transport_);
        transport_impl_._perMessageDeflate = std::make_unique<ix::WebSocketPerMessageDeflate>();

        ix::WebSocketHttpHeaders headers;
        headers["Authorization"] = std::string("bearer ") + config_.api_key;

        ix::WebSocketHandshake handshake(transport_impl_._requestInitCancellation,
                                         transport_impl_._socket,
                                         transport_impl_._perMessageDeflate,
                                         transport_impl_._perMessageDeflateOptions,
                                         transport_impl_._enablePerMessageDeflate);

        const ix::WebSocketInitResult status =
            handshake.clientHandshake(config_.url, headers, protocol, host, path, port, kHandshakeTimeoutSeconds);
        if (!status.success) {
            if (callbacks_.on_error) {
                callbacks_.on_error(describe_handshake_failure(config_.url, status.errorStr));
            }
            transport_impl_._socket.reset();
            return;
        }

        transport_impl_.setReadyState(ix::WebSocketTransport::ReadyState::OPEN);
        started_ = true;
        task_id_ = make_task_id();

        nlohmann::json run_task = {
            {"header",
             {
                 {"action", "run-task"},
                 {"task_id", task_id_},
                 {"streaming", "duplex"},
             }},
            {"payload",
             {
                 {"task_group", "audio"},
                 {"task", "asr"},
                 {"function", "recognition"},
                 {"model", config_.model},
                 {"parameters",
                  {
                      {"format", "pcm"},
                      {"sample_rate", options_.audio_format.sample_rate_hz},
                  }},
                 {"input", nlohmann::json::object()},
             }},
        };

        {
            std::lock_guard<std::mutex> lock(write_mutex_);
            const ix::WebSocketSendInfo send_info = transport_impl_.sendText(run_task.dump(), nullptr);
            if (!send_info.success) {
                started_ = false;
                transport_impl_.close(ix::WebSocketCloseConstants::kInternalErrorCode,
                                      "failed to send Bailian run-task");
                if (callbacks_.on_error) {
                    callbacks_.on_error("Failed to send Bailian run-task.");
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
            callbacks_.on_error("Failed to send audio chunk to Bailian.");
        }
    }

    void finish() override {
        if (!started_ || task_id_.empty()) {
            return;
        }

        nlohmann::json finish_task = {
            {"header",
             {
                 {"action", "finish-task"},
                 {"task_id", task_id_},
                 {"streaming", "duplex"},
             }},
            {"payload", {{"input", nlohmann::json::object()}}},
        };

        std::lock_guard<std::mutex> lock(write_mutex_);
        if (transport_impl_.sendText(finish_task.dump(), nullptr).success) {
            std::scoped_lock diagnostics_lock(diagnostics_mutex_);
            ++text_frames_sent_;
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
            {"result_generated_events", result_generated_events_},
            {"binary_frames_sent", binary_frames_sent_},
            {"text_frames_sent", text_frames_sent_},
            {"task_started", task_started_},
            {"task_finished", task_finished_},
            {"final_sentence_count", final_sentence_count_},
            {"partial_emits", partial_emits_},
            {"final_emits", final_emits_},
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
                callbacks_.on_error(std::string("Invalid Bailian message: ") + exception.what());
            }
            return;
        }

        {
            std::scoped_lock lock(diagnostics_mutex_);
            ++messages_received_;
        }

        const nlohmann::json header = payload.value("header", nlohmann::json::object());
        const std::string event = header.value("event", std::string());
        if (event == "task-failed") {
            const std::string error_message =
                header.value("error_message", std::string("Bailian returned task-failed."));
            if (callbacks_.on_error) {
                callbacks_.on_error(error_message);
            }
            transport_impl_.close(ix::WebSocketCloseConstants::kInternalErrorCode, error_message);
            return;
        }
        if (event == "task-started") {
            {
                std::scoped_lock lock(diagnostics_mutex_);
                task_started_ = true;
            }
            if (callbacks_.on_session_started) {
                callbacks_.on_session_started();
            }
            return;
        }
        if (event == "task-finished") {
            {
                std::scoped_lock lock(diagnostics_mutex_);
                task_finished_ = true;
            }
            stop_requested_ = true;
            transport_impl_.close(ix::WebSocketCloseConstants::kNormalClosureCode,
                                  ix::WebSocketCloseConstants::kNormalClosureMessage);
            return;
        }
        if (event != "result-generated") {
            return;
        }

        {
            std::scoped_lock lock(diagnostics_mutex_);
            ++result_generated_events_;
        }

        const nlohmann::json sentence =
            payload.value("payload", nlohmann::json::object()).value("output", nlohmann::json::object()).value("sentence",
                                                                                                                   nlohmann::json::object());
        const int sentence_id = sentence.value("sentence_id", 0);
        const std::string text = sentence.value("text", std::string());
        if (sentence_id <= 0 || text.empty()) {
            return;
        }

        BailianSentenceState state{
            .text = text,
            .is_final = sentence.value("sentence_end", false),
        };
        sentences_[sentence_id] = state;
        if (state.is_final) {
            std::scoped_lock lock(diagnostics_mutex_);
            final_sentence_count_ = static_cast<std::size_t>(std::count_if(
                sentences_.begin(), sentences_.end(), [](const auto& item) { return item.second.is_final; }));
        }

        const std::string partial_text = render_bailian_text(sentences_, false);
        const std::string final_text = render_bailian_text(sentences_, true);

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

    BailianConfig config_;
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
    std::string task_id_;
    std::string last_partial_text_;
    std::string last_final_text_;
    std::map<int, BailianSentenceState> sentences_;
    std::size_t messages_received_ = 0;
    std::size_t result_generated_events_ = 0;
    std::size_t binary_frames_sent_ = 0;
    std::size_t text_frames_sent_ = 0;
    std::size_t final_sentence_count_ = 0;
    std::size_t partial_emits_ = 0;
    std::size_t final_emits_ = 0;
    bool task_started_ = false;
    bool task_finished_ = false;
};

}  // namespace

BailianStreamingAsrBackend::BailianStreamingAsrBackend(const AppConfig& config)
    : config_(config.providers.bailian), transport_(make_websocket_transport_options(config)) {}

std::string BailianStreamingAsrBackend::name() const {
    return "bailian";
}

StreamingAsrCapabilities BailianStreamingAsrBackend::capabilities() const {
    return StreamingAsrCapabilities{
        .supports_partial_results = true,
        .supports_server_vad = false,
        .supports_language_hint = false,
    };
}

std::unique_ptr<StreamingAsrSession> BailianStreamingAsrBackend::create_session() const {
    return std::make_unique<BailianStreamingAsrSession>(config_, transport_);
}

}  // namespace ohmytypeless
