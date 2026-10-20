#pragma once

#include "core/input/push_audio_source.hpp"
#include "platform/audio_capture_service.hpp"

#include <cstddef>
#include <cstdint>
#include <functional>
#include <mutex>
#include <optional>
#include <span>
#include <string>
#include <vector>

namespace ohmytypeless {

struct PushAudioCaptureCallbacks {
    std::function<bool(const PushAudioStreamInfo&, std::string*)> on_stream_started;
    std::function<void(std::uint32_t, PushAudioStopReason)> on_stream_stopped;
};

class PushAudioCaptureService final : public AudioCaptureService, public PushAudioSink {
public:
    void set_callbacks(PushAudioCaptureCallbacks callbacks);

    bool supports_capture_mode(AudioCaptureMode capture_mode) const override;
    void start(std::uint32_t sample_rate,
               std::uint32_t channels,
               const std::string& device_id,
               AudioCaptureMode capture_mode) override;
    std::vector<float> stop() override;
    std::vector<float> take_pending_samples() override;
    bool is_recording() const override;
    std::vector<AudioInputDevice> list_input_devices() const override;

    bool on_push_audio_start(const PushAudioStreamInfo& stream, std::string* error) override;
    bool on_push_audio_samples(std::uint32_t stream_id,
                               std::span<const std::int16_t> samples,
                               std::string* error) override;
    void on_push_audio_stop(std::uint32_t stream_id, PushAudioStopReason reason) override;

    std::optional<PushAudioStreamInfo> active_stream() const;

private:
    static constexpr std::size_t kMaximumPrestartSamples = 32000U;

    mutable std::mutex mutex_;
    PushAudioCaptureCallbacks callbacks_;
    std::optional<PushAudioStreamInfo> stream_;
    std::vector<float> prestart_samples_;
    std::vector<float> samples_;
    std::vector<float> pending_samples_;
    bool capture_started_ = false;
    bool capture_stopped_ = false;
};

class RoutedAudioCaptureService final : public AudioCaptureService {
public:
    RoutedAudioCaptureService(AudioCaptureService& local_capture, PushAudioCaptureService& push_capture);

    bool supports_capture_mode(AudioCaptureMode capture_mode) const override;
    void start(std::uint32_t sample_rate,
               std::uint32_t channels,
               const std::string& device_id,
               AudioCaptureMode capture_mode) override;
    std::vector<float> stop() override;
    std::vector<float> take_pending_samples() override;
    bool is_recording() const override;
    std::vector<AudioInputDevice> list_input_devices() const override;

private:
    AudioCaptureService* active_capture_unlocked() const;

    AudioCaptureService& local_capture_;
    PushAudioCaptureService& push_capture_;
    mutable std::mutex mutex_;
    std::optional<AudioCaptureMode> active_mode_;
};

}  // namespace ohmytypeless
