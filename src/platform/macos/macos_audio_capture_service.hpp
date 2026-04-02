#pragma once

#include "platform/audio_capture_service.hpp"
#include "platform/miniaudio_audio_capture_service.hpp"

#include <atomic>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

#ifdef __OBJC__
@class ShinsokuMacOSSystemAudioBridge;
#else
class ShinsokuMacOSSystemAudioBridge;
#endif

namespace ohmytypeless {

class MacOSAudioCaptureService final : public AudioCaptureService {
public:
    MacOSAudioCaptureService();
    ~MacOSAudioCaptureService() override;

    MacOSAudioCaptureService(const MacOSAudioCaptureService&) = delete;
    MacOSAudioCaptureService& operator=(const MacOSAudioCaptureService&) = delete;

    bool supports_capture_mode(AudioCaptureMode capture_mode) const override;
    void start(std::uint32_t sample_rate,
               std::uint32_t channels,
               const std::string& device_id,
               AudioCaptureMode capture_mode) override;
    std::vector<float> stop() override;
    std::vector<float> take_pending_samples() override;
    bool is_recording() const override;
    std::vector<AudioInputDevice> list_input_devices() const override;

    void append_system_audio_samples(const float* samples, std::size_t sample_count);
    void fail_system_audio_capture(const std::string& error_text);

private:
    std::optional<std::string> take_capture_error();

    MiniaudioAudioCaptureService microphone_delegate_;

    mutable std::mutex mutex_;
    std::vector<float> samples_;
    std::vector<float> pending_samples_;
    std::atomic<bool> recording_ = false;
    AudioCaptureMode active_mode_ = AudioCaptureMode::Microphone;
    std::optional<std::string> capture_error_;
    ShinsokuMacOSSystemAudioBridge* system_bridge_ = nullptr;
};

}  // namespace ohmytypeless
