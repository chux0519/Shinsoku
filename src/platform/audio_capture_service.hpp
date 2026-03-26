#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace ohmytypeless {

struct AudioInputDevice {
    std::string id;
    std::string name;
    bool is_default = false;
};

enum class AudioCaptureMode {
    Microphone,
    SystemLoopback,
};

class AudioCaptureService {
public:
    virtual ~AudioCaptureService() = default;

    virtual bool supports_capture_mode(AudioCaptureMode capture_mode) const = 0;
    virtual void start(std::uint32_t sample_rate,
                       std::uint32_t channels,
                       const std::string& device_id,
                       AudioCaptureMode capture_mode) = 0;
    virtual std::vector<float> stop() = 0;
    virtual std::vector<float> take_pending_samples() = 0;
    virtual bool is_recording() const = 0;
    virtual std::vector<AudioInputDevice> list_input_devices() const = 0;
};

}  // namespace ohmytypeless
