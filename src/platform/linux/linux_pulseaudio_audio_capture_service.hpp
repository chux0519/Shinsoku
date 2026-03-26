#pragma once

#include "platform/audio_capture_service.hpp"
#include "platform/miniaudio_audio_capture_service.hpp"

#include <atomic>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

namespace ohmytypeless {

class LinuxPulseaudioAudioCaptureService final : public AudioCaptureService {
public:
    LinuxPulseaudioAudioCaptureService();
    ~LinuxPulseaudioAudioCaptureService() override;

    LinuxPulseaudioAudioCaptureService(const LinuxPulseaudioAudioCaptureService&) = delete;
    LinuxPulseaudioAudioCaptureService& operator=(const LinuxPulseaudioAudioCaptureService&) = delete;

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
    void stop_simple_capture();
    void run_simple_capture(std::uint32_t sample_rate, std::uint32_t channels, std::string device_id);
    void append_samples_from_bytes(const void* data, size_t nbytes);
    std::optional<std::string> take_capture_error();

    MiniaudioAudioCaptureService microphone_delegate_;

    mutable std::mutex mutex_;
    std::vector<float> samples_;
    std::vector<float> pending_samples_;
    std::atomic<bool> recording_ = false;
    std::atomic<bool> stop_requested_ = false;
    AudioCaptureMode active_mode_ = AudioCaptureMode::Microphone;
    std::uint32_t channels_ = 1;
    std::optional<std::string> capture_error_;
    std::thread capture_thread_;
};

}  // namespace ohmytypeless
