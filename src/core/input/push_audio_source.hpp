#pragma once

#include <cstdint>
#include <span>
#include <string>

namespace ohmytypeless {

enum class PushAudioEncoding {
    Pcm16Le,
};

struct PushAudioFormat {
    PushAudioEncoding encoding = PushAudioEncoding::Pcm16Le;
    std::uint32_t sample_rate_hz = 16000;
    std::uint16_t channel_count = 1;
};

struct PushAudioStreamInfo {
    std::string source_id;
    std::string source_name;
    std::string source_kind;
    std::string requested_profile_id;
    std::uint32_t stream_id = 0;
    PushAudioFormat format;
};

enum class PushAudioStopReason {
    Completed,
    Cancelled,
    Disconnected,
    Error,
};

class PushAudioSink {
public:
    virtual ~PushAudioSink() = default;

    virtual bool on_push_audio_start(const PushAudioStreamInfo& stream, std::string* error) = 0;
    virtual bool on_push_audio_samples(std::uint32_t stream_id,
                                       std::span<const std::int16_t> samples,
                                       std::string* error) = 0;
    virtual void on_push_audio_stop(std::uint32_t stream_id, PushAudioStopReason reason) = 0;
};

}  // namespace ohmytypeless
