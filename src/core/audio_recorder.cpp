#define MINIAUDIO_IMPLEMENTATION
#include <miniaudio.h>

#include "core/audio_recorder.hpp"

#include <algorithm>
#include <cctype>
#include <sstream>
#include <stdexcept>

namespace ohmytypeless {

namespace {

std::string device_id_to_hex_string(const ma_device_id& id) {
    const auto* bytes = reinterpret_cast<const unsigned char*>(&id);
    std::size_t end = sizeof(ma_device_id);
    while (end > 0 && bytes[end - 1] == 0) {
        --end;
    }
    if (end == 0) {
        return "0";
    }

    std::ostringstream stream;
    stream << std::hex;
    for (std::size_t i = 0; i < end; ++i) {
        stream.width(2);
        stream.fill('0');
        stream << static_cast<unsigned int>(bytes[i]);
    }
    return stream.str();
}

std::string try_decode_utf16_ascii(const ma_device_id& id) {
    const auto* bytes = reinterpret_cast<const unsigned char*>(&id);
    constexpr std::size_t kSize = sizeof(ma_device_id);

    if ((kSize % 2U) != 0U) {
        return {};
    }

    std::string decoded;
    decoded.reserve(kSize / 2U);

    bool seen_non_zero = false;
    for (std::size_t i = 0; i + 1U < kSize; i += 2U) {
        const unsigned char low = bytes[i];
        const unsigned char high = bytes[i + 1U];

        if (low == 0 && high == 0) {
            break;
        }

        seen_non_zero = true;
        if (high != 0 || !std::isprint(low)) {
            return {};
        }

        decoded.push_back(static_cast<char>(low));
    }

    return seen_non_zero ? decoded : std::string();
}

std::string device_id_to_string(const ma_device_id& id) {
    if (const std::string decoded = try_decode_utf16_ascii(id); !decoded.empty()) {
        return decoded;
    }
    return device_id_to_hex_string(id);
}

bool device_matches(const ma_device_info& device, const std::string& configured) {
    const std::string readable = device_id_to_string(device.id);
    const std::string legacy_hex = device_id_to_hex_string(device.id);
    return readable == configured || legacy_hex == configured || device.name == configured;
}

}  // namespace

AudioRecorder::AudioRecorder() = default;

AudioRecorder::~AudioRecorder() {
    ma_device* device = nullptr;
    ma_context* context = nullptr;
    {
        std::scoped_lock lock(mutex_);
        recording_ = false;
        device = device_;
        context = context_;
        device_ = nullptr;
        context_ = nullptr;
    }
    shutdown_audio_unlocked(device, context);
}

void AudioRecorder::start(std::uint32_t sample_rate, std::uint32_t channels, const std::string& device_id) {
    {
        std::scoped_lock lock(mutex_);
        if (recording_) {
            return;
        }
    }

    auto* context = new ma_context;
    if (ma_context_init(nullptr, 0, nullptr, context) != MA_SUCCESS) {
        delete context;
        throw std::runtime_error("failed to initialize audio context");
    }

    ma_device_info* playback_infos = nullptr;
    ma_uint32 playback_count = 0;
    ma_device_info* capture_infos = nullptr;
    ma_uint32 capture_count = 0;
    if (ma_context_get_devices(context, &playback_infos, &playback_count, &capture_infos, &capture_count) != MA_SUCCESS) {
        ma_context_uninit(context);
        delete context;
        throw std::runtime_error("failed to enumerate audio devices");
    }
    static_cast<void>(playback_infos);
    static_cast<void>(playback_count);

    auto* device = new ma_device;
    ma_device_config config = ma_device_config_init(ma_device_type_capture);
    config.capture.format = ma_format_f32;
    config.capture.channels = channels;
    config.sampleRate = sample_rate;
    config.dataCallback = &AudioRecorder::data_callback;
    config.pUserData = this;

    bool found = device_id.empty();
    for (ma_uint32 i = 0; i < capture_count; ++i) {
        if (device_id.empty()) {
            if (capture_infos[i].isDefault != 0) {
                config.capture.pDeviceID = &capture_infos[i].id;
                found = true;
                break;
            }
            continue;
        }

        if (device_matches(capture_infos[i], device_id)) {
            config.capture.pDeviceID = &capture_infos[i].id;
            found = true;
            break;
        }
    }

    if (!found) {
        ma_context_uninit(context);
        delete context;
        delete device;
        throw std::runtime_error("requested input device not found");
    }

    if (ma_device_init(context, &config, device) != MA_SUCCESS) {
        ma_context_uninit(context);
        delete context;
        delete device;
        throw std::runtime_error("failed to initialize capture device");
    }

    {
        std::scoped_lock lock(mutex_);
        if (recording_) {
            shutdown_audio_unlocked(device, context);
            return;
        }
        samples_.clear();
        pending_samples_.clear();
        channels_ = channels;
        context_ = context;
        device_ = device;
        recording_ = true;
    }

    if (ma_device_start(device) != MA_SUCCESS) {
        {
            std::scoped_lock lock(mutex_);
            recording_ = false;
            device_ = nullptr;
            context_ = nullptr;
            samples_.clear();
            pending_samples_.clear();
        }
        shutdown_audio_unlocked(device, context);
        throw std::runtime_error("failed to start capture device");
    }
}

std::vector<float> AudioRecorder::stop() {
    ma_device* device = nullptr;
    ma_context* context = nullptr;
    std::vector<float> samples;

    {
        std::scoped_lock lock(mutex_);
        if (!recording_ || device_ == nullptr) {
            return {};
        }

        recording_ = false;
        device = device_;
        context = context_;
        device_ = nullptr;
        context_ = nullptr;
        samples = std::move(samples_);
        samples_.clear();
        pending_samples_.clear();
    }

    shutdown_audio_unlocked(device, context);

    return samples;
}

std::vector<float> AudioRecorder::take_pending_samples() {
    std::scoped_lock lock(mutex_);
    std::vector<float> chunk = std::move(pending_samples_);
    pending_samples_.clear();
    return chunk;
}

bool AudioRecorder::is_recording() const {
    std::scoped_lock lock(mutex_);
    return recording_;
}

void AudioRecorder::data_callback(ma_device* device, void* output, const void* input, unsigned int frame_count) {
    static_cast<void>(output);
    auto* recorder = static_cast<AudioRecorder*>(device->pUserData);
    if (recorder == nullptr || input == nullptr) {
        return;
    }

    recorder->append_input(static_cast<const float*>(input), frame_count);
}

void AudioRecorder::append_input(const float* input, unsigned int frame_count) {
    std::scoped_lock lock(mutex_);
    if (!recording_) {
        return;
    }

    const auto sample_count = static_cast<std::size_t>(frame_count) * channels_;
    samples_.insert(samples_.end(), input, input + sample_count);
    pending_samples_.insert(pending_samples_.end(), input, input + sample_count);
}

void AudioRecorder::shutdown_audio_unlocked(ma_device* device, ma_context* context) noexcept {
    if (device != nullptr) {
        ma_device_uninit(device);
        delete device;
    }
    if (context != nullptr) {
        ma_context_uninit(context);
        delete context;
    }
}

std::vector<AudioInputDevice> AudioRecorder::list_input_devices() {
    ma_context context;
    if (ma_context_init(nullptr, 0, nullptr, &context) != MA_SUCCESS) {
        throw std::runtime_error("failed to initialize audio context");
    }

    ma_device_info* playback_infos = nullptr;
    ma_uint32 playback_count = 0;
    ma_device_info* capture_infos = nullptr;
    ma_uint32 capture_count = 0;
    if (ma_context_get_devices(&context, &playback_infos, &playback_count, &capture_infos, &capture_count) != MA_SUCCESS) {
        ma_context_uninit(&context);
        throw std::runtime_error("failed to enumerate audio devices");
    }
    static_cast<void>(playback_infos);
    static_cast<void>(playback_count);

    std::vector<AudioInputDevice> devices;
    for (ma_uint32 i = 0; i < capture_count; ++i) {
        devices.push_back(AudioInputDevice{
            .id = device_id_to_string(capture_infos[i].id),
            .name = capture_infos[i].name,
            .is_default = capture_infos[i].isDefault != 0,
        });
    }

    ma_context_uninit(&context);
    return devices;
}

}  // namespace ohmytypeless
