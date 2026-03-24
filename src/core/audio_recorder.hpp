#pragma once

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

struct ma_context;
struct ma_device;

namespace ohmytypeless {

struct AudioInputDevice {
    std::string id;
    std::string name;
    bool is_default = false;
};

class AudioRecorder {
public:
    AudioRecorder();
    ~AudioRecorder();

    AudioRecorder(const AudioRecorder&) = delete;
    AudioRecorder& operator=(const AudioRecorder&) = delete;

    void start(std::uint32_t sample_rate, std::uint32_t channels, const std::string& device_id);
    std::vector<float> stop();
    std::vector<float> take_pending_samples();
    bool is_recording() const;
    static std::vector<AudioInputDevice> list_input_devices();

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
