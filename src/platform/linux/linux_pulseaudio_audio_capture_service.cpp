#include "platform/linux/linux_pulseaudio_audio_capture_service.hpp"

#include <pulse/context.h>
#include <pulse/error.h>
#include <pulse/introspect.h>
#include <pulse/sample.h>
#include <pulse/simple.h>
#include <pulse/thread-mainloop.h>

#include <algorithm>
#include <chrono>
#include <cstring>
#include <stdexcept>
#include <thread>
#include <vector>

namespace ohmytypeless {

namespace {

struct ServerInfoResult {
    bool server_ready = false;
    bool sink_ready = false;
    std::string default_sink_name;
    std::string monitor_source_name;
    std::string error;
};

void on_server_info(pa_context*, const pa_server_info* info, void* userdata) {
    auto* result = static_cast<ServerInfoResult*>(userdata);
    if (result == nullptr) {
        return;
    }
    if (info != nullptr && info->default_sink_name != nullptr) {
        result->default_sink_name = info->default_sink_name;
    }
    result->server_ready = true;
}

void on_sink_info(pa_context*, const pa_sink_info* info, int eol, void* userdata) {
    auto* result = static_cast<ServerInfoResult*>(userdata);
    if (result == nullptr) {
        return;
    }
    if (eol != 0) {
        result->sink_ready = true;
        return;
    }
    if (info != nullptr && info->monitor_source_name != nullptr) {
        result->monitor_source_name = info->monitor_source_name;
    }
}

std::runtime_error pulse_error(const char* prefix, pa_context* context) {
    const int error_code = context != nullptr ? pa_context_errno(context) : PA_ERR_UNKNOWN;
    return std::runtime_error(std::string(prefix) + ": " + pa_strerror(error_code));
}

std::string query_default_monitor_source() {
    pa_threaded_mainloop* mainloop = pa_threaded_mainloop_new();
    if (mainloop == nullptr) {
        throw std::runtime_error("failed to create PulseAudio mainloop");
    }
    if (pa_threaded_mainloop_start(mainloop) < 0) {
        pa_threaded_mainloop_free(mainloop);
        throw std::runtime_error("failed to start PulseAudio mainloop");
    }

    pa_threaded_mainloop_lock(mainloop);
    pa_context* context = pa_context_new(pa_threaded_mainloop_get_api(mainloop), "OhMyTypeless System Audio");
    if (context == nullptr) {
        pa_threaded_mainloop_unlock(mainloop);
        pa_threaded_mainloop_stop(mainloop);
        pa_threaded_mainloop_free(mainloop);
        throw std::runtime_error("failed to create PulseAudio context");
    }

    try {
        if (pa_context_connect(context, nullptr, PA_CONTEXT_NOFLAGS, nullptr) < 0) {
            throw pulse_error("failed to connect PulseAudio context", context);
        }

        while (true) {
            const pa_context_state_t state = pa_context_get_state(context);
            if (state == PA_CONTEXT_READY) {
                break;
            }
            if (!PA_CONTEXT_IS_GOOD(state)) {
                throw pulse_error("PulseAudio context error", context);
            }
            pa_threaded_mainloop_unlock(mainloop);
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
            pa_threaded_mainloop_lock(mainloop);
        }

        ServerInfoResult result;
        pa_operation* server_operation = pa_context_get_server_info(context, &on_server_info, &result);
        if (server_operation == nullptr) {
            throw pulse_error("failed to query PulseAudio server info", context);
        }
        while (!result.server_ready) {
            const pa_operation_state_t state = pa_operation_get_state(server_operation);
            if (state == PA_OPERATION_CANCELLED) {
                pa_operation_unref(server_operation);
                throw std::runtime_error("PulseAudio server info query was cancelled");
            }
            pa_threaded_mainloop_unlock(mainloop);
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
            pa_threaded_mainloop_lock(mainloop);
        }
        pa_operation_unref(server_operation);
        if (result.default_sink_name.empty()) {
            throw std::runtime_error("PulseAudio did not report a default sink for system capture");
        }

        pa_operation* sink_operation =
            pa_context_get_sink_info_by_name(context, result.default_sink_name.c_str(), &on_sink_info, &result);
        if (sink_operation == nullptr) {
            throw pulse_error("failed to query PulseAudio sink info", context);
        }
        while (!result.sink_ready) {
            const pa_operation_state_t state = pa_operation_get_state(sink_operation);
            if (state == PA_OPERATION_CANCELLED) {
                pa_operation_unref(sink_operation);
                throw std::runtime_error("PulseAudio sink info query was cancelled");
            }
            pa_threaded_mainloop_unlock(mainloop);
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
            pa_threaded_mainloop_lock(mainloop);
        }
        pa_operation_unref(sink_operation);
        if (result.monitor_source_name.empty()) {
            throw std::runtime_error("PulseAudio did not report a monitor source for the default sink");
        }

        pa_context_disconnect(context);
        pa_context_unref(context);
        pa_threaded_mainloop_unlock(mainloop);
        pa_threaded_mainloop_stop(mainloop);
        pa_threaded_mainloop_free(mainloop);
        return result.monitor_source_name;
    } catch (...) {
        pa_context_disconnect(context);
        pa_context_unref(context);
        pa_threaded_mainloop_unlock(mainloop);
        pa_threaded_mainloop_stop(mainloop);
        pa_threaded_mainloop_free(mainloop);
        throw;
    }
}

}  // namespace

LinuxPulseaudioAudioCaptureService::LinuxPulseaudioAudioCaptureService() = default;

LinuxPulseaudioAudioCaptureService::~LinuxPulseaudioAudioCaptureService() {
    try {
        stop();
    } catch (...) {
    }
}

bool LinuxPulseaudioAudioCaptureService::supports_capture_mode(AudioCaptureMode capture_mode) const {
    if (capture_mode == AudioCaptureMode::Microphone) {
        return true;
    }
    return true;
}

void LinuxPulseaudioAudioCaptureService::start(std::uint32_t sample_rate,
                                               std::uint32_t channels,
                                               const std::string& device_id,
                                               AudioCaptureMode capture_mode) {
    if (capture_mode == AudioCaptureMode::Microphone) {
        active_mode_ = AudioCaptureMode::Microphone;
        microphone_delegate_.start(sample_rate, channels, device_id, capture_mode);
        recording_.store(true);
        return;
    }

    {
        std::scoped_lock lock(mutex_);
        if (recording_.load()) {
            return;
        }
    }

    stop_simple_capture();
    {
        std::scoped_lock lock(mutex_);
        samples_.clear();
        pending_samples_.clear();
        channels_ = channels;
        active_mode_ = AudioCaptureMode::SystemLoopback;
        capture_error_.reset();
        stop_requested_.store(false);
        recording_.store(true);
    }

    capture_thread_ = std::thread(&LinuxPulseaudioAudioCaptureService::run_simple_capture, this, sample_rate, channels, device_id);
}

std::vector<float> LinuxPulseaudioAudioCaptureService::stop() {
    if (active_mode_ == AudioCaptureMode::Microphone) {
        recording_.store(false);
        return microphone_delegate_.stop();
    }

    std::vector<float> samples;
    bool was_recording = false;
    {
        std::scoped_lock lock(mutex_);
        was_recording = recording_.load();
        recording_.store(false);
        samples = std::move(samples_);
        samples_.clear();
        pending_samples_.clear();
    }
    if (!was_recording && !capture_thread_.joinable()) {
        return {};
    }

    stop_requested_.store(true);
    stop_simple_capture();
    active_mode_ = AudioCaptureMode::Microphone;

    if (const auto error = take_capture_error(); error.has_value() && samples.empty()) {
        throw std::runtime_error(*error);
    }
    return samples;
}

std::vector<float> LinuxPulseaudioAudioCaptureService::take_pending_samples() {
    if (active_mode_ == AudioCaptureMode::Microphone) {
        return microphone_delegate_.take_pending_samples();
    }

    if (const auto error = take_capture_error(); error.has_value()) {
        throw std::runtime_error(*error);
    }

    std::scoped_lock lock(mutex_);
    std::vector<float> chunk = std::move(pending_samples_);
    pending_samples_.clear();
    return chunk;
}

bool LinuxPulseaudioAudioCaptureService::is_recording() const {
    if (active_mode_ == AudioCaptureMode::Microphone) {
        return microphone_delegate_.is_recording();
    }
    return recording_.load();
}

std::vector<AudioInputDevice> LinuxPulseaudioAudioCaptureService::list_input_devices() const {
    return microphone_delegate_.list_input_devices();
}

void LinuxPulseaudioAudioCaptureService::stop_simple_capture() {
    std::thread capture_thread;
    {
        std::scoped_lock lock(mutex_);
        if (capture_thread_.joinable()) {
            capture_thread = std::move(capture_thread_);
        }
    }

    if (capture_thread.joinable()) {
        capture_thread.join();
    }
}

void LinuxPulseaudioAudioCaptureService::run_simple_capture(std::uint32_t sample_rate,
                                                            std::uint32_t channels,
                                                            std::string device_id) {
    try {
        std::string source_name = std::move(device_id);
        if (source_name.empty()) {
            source_name = query_default_monitor_source();
        }

        pa_sample_spec sample_spec{};
        sample_spec.format = PA_SAMPLE_FLOAT32LE;
        sample_spec.rate = sample_rate;
        sample_spec.channels = static_cast<std::uint8_t>(channels);
        if (!pa_sample_spec_valid(&sample_spec)) {
            throw std::runtime_error("invalid PulseAudio sample format for requested system capture");
        }

        pa_buffer_attr buffer_attr{};
        buffer_attr.maxlength = static_cast<uint32_t>(-1);
        buffer_attr.tlength = static_cast<uint32_t>(-1);
        buffer_attr.prebuf = static_cast<uint32_t>(-1);
        buffer_attr.minreq = static_cast<uint32_t>(-1);
        buffer_attr.fragsize = sizeof(float) * channels * std::max<std::uint32_t>(1, sample_rate / 50);

        int error_code = 0;
        pa_simple* simple = pa_simple_new(nullptr,
                                          "OhMyTypeless",
                                          PA_STREAM_RECORD,
                                          source_name.c_str(),
                                          "System Audio Loopback",
                                          &sample_spec,
                                          nullptr,
                                          &buffer_attr,
                                          &error_code);
        if (simple == nullptr) {
            throw std::runtime_error(std::string("failed to open PulseAudio simple record stream: ") + pa_strerror(error_code));
        }

        constexpr std::size_t kFramesPerChunk = 960;
        std::vector<float> buffer(kFramesPerChunk * channels);
        const std::size_t bytes_per_chunk = sizeof(float) * channels * kFramesPerChunk;

        while (!stop_requested_.load()) {
            if (pa_simple_read(simple, buffer.data(), bytes_per_chunk, &error_code) < 0) {
                throw std::runtime_error(std::string("PulseAudio simple read failed: ") + pa_strerror(error_code));
            }
            append_samples_from_bytes(buffer.data(), bytes_per_chunk);
        }

        pa_simple_free(simple);
    } catch (const std::exception& exception) {
        std::scoped_lock lock(mutex_);
        capture_error_ = exception.what();
        recording_.store(false);
    }
}

void LinuxPulseaudioAudioCaptureService::append_samples_from_bytes(const void* data, size_t nbytes) {
    if (data == nullptr || nbytes == 0) {
        return;
    }

    const std::size_t sample_count = nbytes / sizeof(float);
    const auto* floats = static_cast<const float*>(data);
    std::scoped_lock lock(mutex_);
    if (!recording_.load()) {
        return;
    }
    samples_.insert(samples_.end(), floats, floats + sample_count);
    pending_samples_.insert(pending_samples_.end(), floats, floats + sample_count);
}

std::optional<std::string> LinuxPulseaudioAudioCaptureService::take_capture_error() {
    std::scoped_lock lock(mutex_);
    if (!capture_error_.has_value()) {
        return std::nullopt;
    }
    auto error = std::move(capture_error_);
    capture_error_.reset();
    return error;
}

}  // namespace ohmytypeless
