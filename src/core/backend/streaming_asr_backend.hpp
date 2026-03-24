#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <optional>
#include <span>
#include <string>

#include <nlohmann/json.hpp>

namespace ohmytypeless {

enum class StreamingAudioEncoding {
    Pcm16Le,
    Float32Le,
};

struct StreamingAudioFormat {
    StreamingAudioEncoding encoding = StreamingAudioEncoding::Pcm16Le;
    std::uint32_t sample_rate_hz = 16000;
    std::uint16_t channel_count = 1;
};

struct StreamingAsrStartOptions {
    StreamingAudioFormat audio_format;
    std::optional<std::string> language;
    bool emit_partial_results = true;
};

struct StreamingAsrCapabilities {
    bool supports_partial_results = false;
    bool supports_server_vad = false;
    bool supports_language_hint = false;
};

struct StreamingAsrCallbacks {
    std::function<void()> on_session_started;
    std::function<void(std::string)> on_partial_text;
    std::function<void(std::string)> on_final_text;
    std::function<void(std::string)> on_error;
    std::function<void()> on_session_closed;
};

class StreamingAsrSession {
public:
    virtual ~StreamingAsrSession() = default;

    virtual void start(const StreamingAsrStartOptions& options, StreamingAsrCallbacks callbacks) = 0;
    virtual void push_audio(std::span<const std::byte> audio_bytes) = 0;
    virtual void finish() = 0;
    virtual void cancel() = 0;
    virtual nlohmann::json runtime_diagnostics() const = 0;
};

class StreamingAsrBackend {
public:
    virtual ~StreamingAsrBackend() = default;

    virtual std::string name() const = 0;
    virtual StreamingAsrCapabilities capabilities() const = 0;
    virtual std::unique_ptr<StreamingAsrSession> create_session() const = 0;
};

}  // namespace ohmytypeless
