#pragma once

#include "platform/audio_capture_service.hpp"

#include <mutex>
#include <vector>

struct ma_context;
struct ma_device;

namespace ohmytypeless {

class MiniaudioAudioCaptureService final : public AudioCaptureService {
public:
    MiniaudioAudioCaptureService();
    ~MiniaudioAudioCaptureService() override;

    MiniaudioAudioCaptureService(const MiniaudioAudioCaptureService&) = delete;
    MiniaudioAudioCaptureService& operator=(const MiniaudioAudioCaptureService&) = delete;

    void start(std::uint32_t sample_rate,
               std::uint32_t channels,
               const std::string& device_id,
               AudioCaptureMode capture_mode) override;
    std::vector<float> stop() override;
    std::vector<float> take_pending_samples() override;
    bool is_recording() const override;
    std::vector<AudioInputDevice> list_input_devices() const override;

private:
    void shutdown_audio_unlocked(ma_device* device, ma_context* context) noexcept;
    static void data_callback(ma_device* device, void* output, const void* input, unsigned int frame_count);
    void append_input(const float* input, unsigned int frame_count);

    ma_context* context_ = nullptr;
    ma_device* device_ = nullptr;
    mutable std::mutex mutex_;
    std::vector<float> samples_;
    std::vector<float> pending_samples_;
    bool recording_ = false;
    std::uint32_t channels_ = 1;
};

}  // namespace ohmytypeless
