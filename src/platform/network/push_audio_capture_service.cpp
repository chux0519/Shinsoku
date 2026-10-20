#include "platform/network/push_audio_capture_service.hpp"

#include <algorithm>
#include <stdexcept>
#include <utility>

namespace ohmytypeless {

namespace {

constexpr std::uint32_t kPushSampleRate = 16000;
constexpr std::uint32_t kPushChannelCount = 1;

void set_error(std::string* error, std::string message) {
    if (error != nullptr) {
        *error = std::move(message);
    }
}

}  // namespace

void PushAudioCaptureService::set_callbacks(PushAudioCaptureCallbacks callbacks) {
    std::scoped_lock lock(mutex_);
    callbacks_ = std::move(callbacks);
}

bool PushAudioCaptureService::supports_capture_mode(AudioCaptureMode capture_mode) const {
    return capture_mode == AudioCaptureMode::NearbyRemote;
}

void PushAudioCaptureService::start(std::uint32_t sample_rate,
                                    std::uint32_t channels,
                                    const std::string& device_id,
                                    AudioCaptureMode capture_mode) {
    static_cast<void>(device_id);
    std::scoped_lock lock(mutex_);
    if (capture_mode != AudioCaptureMode::NearbyRemote || sample_rate != kPushSampleRate ||
        channels != kPushChannelCount) {
        throw std::invalid_argument("nearby capture requires mono audio at 16 kHz");
    }
    if (!stream_.has_value()) {
        throw std::runtime_error("no nearby client has started an audio stream");
    }
    if (capture_started_) {
        return;
    }
    if (capture_stopped_) {
        throw std::runtime_error("the nearby audio stream has already been stopped");
    }

    samples_ = std::move(prestart_samples_);
    pending_samples_ = samples_;
    prestart_samples_.clear();
    capture_started_ = true;
}

std::vector<float> PushAudioCaptureService::stop() {
    std::scoped_lock lock(mutex_);
    if (!capture_started_) {
        return {};
    }
    capture_started_ = false;
    capture_stopped_ = true;
    std::vector<float> samples = std::move(samples_);
    samples_.clear();
    pending_samples_.clear();
    prestart_samples_.clear();
    if (!stream_.has_value()) {
        capture_stopped_ = false;
    }
    return samples;
}

std::vector<float> PushAudioCaptureService::take_pending_samples() {
    std::scoped_lock lock(mutex_);
    std::vector<float> samples = std::move(pending_samples_);
    pending_samples_.clear();
    return samples;
}

bool PushAudioCaptureService::is_recording() const {
    std::scoped_lock lock(mutex_);
    return capture_started_;
}

std::vector<AudioInputDevice> PushAudioCaptureService::list_input_devices() const {
    return {};
}

bool PushAudioCaptureService::on_push_audio_start(const PushAudioStreamInfo& stream, std::string* error) {
    PushAudioCaptureCallbacks callbacks;
    {
        std::scoped_lock lock(mutex_);
        if (stream_.has_value() || capture_started_) {
            set_error(error, "another nearby audio stream is already active");
            return false;
        }
        if (stream.stream_id == 0U || stream.format.encoding != PushAudioEncoding::Pcm16Le ||
            stream.format.sample_rate_hz != kPushSampleRate || stream.format.channel_count != kPushChannelCount) {
            set_error(error, "nearby capture accepts only mono PCM16LE at 16 kHz");
            return false;
        }
        stream_ = stream;
        capture_stopped_ = false;
        prestart_samples_.clear();
        samples_.clear();
        pending_samples_.clear();
        callbacks = callbacks_;
    }

    if (!callbacks.on_stream_started) {
        std::scoped_lock lock(mutex_);
        stream_.reset();
        set_error(error, "nearby capture is not connected to the application controller");
        return false;
    }
    if (!callbacks.on_stream_started(stream, error)) {
        std::scoped_lock lock(mutex_);
        if (stream_.has_value() && stream_->stream_id == stream.stream_id) {
            stream_.reset();
            prestart_samples_.clear();
            samples_.clear();
            pending_samples_.clear();
            capture_started_ = false;
            capture_stopped_ = false;
        }
        return false;
    }

    std::scoped_lock lock(mutex_);
    if (!capture_started_) {
        stream_.reset();
        set_error(error, "the application controller did not start nearby capture");
        return false;
    }
    return true;
}

bool PushAudioCaptureService::on_push_audio_samples(std::uint32_t stream_id,
                                                    std::span<const std::int16_t> samples,
                                                    std::string* error) {
    std::scoped_lock lock(mutex_);
    if (!stream_.has_value() || stream_->stream_id != stream_id) {
        set_error(error, "nearby audio samples belong to a stale stream");
        return false;
    }
    if (capture_stopped_) {
        set_error(error, "nearby capture was stopped by the desktop");
        return false;
    }

    std::vector<float>& destination = capture_started_ ? samples_ : prestart_samples_;
    if (!capture_started_ && destination.size() + samples.size() > kMaximumPrestartSamples) {
        set_error(error, "nearby capture did not become ready before its pre-roll buffer filled");
        return false;
    }
    const std::size_t previous_size = destination.size();
    destination.resize(previous_size + samples.size());
    std::transform(samples.begin(), samples.end(), destination.begin() + static_cast<std::ptrdiff_t>(previous_size),
                   [](std::int16_t sample) { return static_cast<float>(sample) / 32768.0f; });
    if (capture_started_) {
        pending_samples_.insert(pending_samples_.end(),
                                destination.cbegin() + static_cast<std::ptrdiff_t>(previous_size),
                                destination.cend());
    }
    return true;
}

void PushAudioCaptureService::on_push_audio_stop(std::uint32_t stream_id, PushAudioStopReason reason) {
    PushAudioCaptureCallbacks callbacks;
    {
        std::scoped_lock lock(mutex_);
        if (!stream_.has_value() || stream_->stream_id != stream_id) {
            return;
        }
        stream_.reset();
        callbacks = callbacks_;
        if (!capture_started_) {
            capture_stopped_ = false;
            prestart_samples_.clear();
        }
    }
    if (callbacks.on_stream_stopped) {
        callbacks.on_stream_stopped(stream_id, reason);
    }
}

std::optional<PushAudioStreamInfo> PushAudioCaptureService::active_stream() const {
    std::scoped_lock lock(mutex_);
    return stream_;
}

RoutedAudioCaptureService::RoutedAudioCaptureService(AudioCaptureService& local_capture,
                                                     PushAudioCaptureService& push_capture)
    : local_capture_(local_capture), push_capture_(push_capture) {}

bool RoutedAudioCaptureService::supports_capture_mode(AudioCaptureMode capture_mode) const {
    return capture_mode == AudioCaptureMode::NearbyRemote ? push_capture_.supports_capture_mode(capture_mode)
                                                          : local_capture_.supports_capture_mode(capture_mode);
}

void RoutedAudioCaptureService::start(std::uint32_t sample_rate,
                                      std::uint32_t channels,
                                      const std::string& device_id,
                                      AudioCaptureMode capture_mode) {
    {
        std::scoped_lock lock(mutex_);
        if (active_mode_.has_value()) {
            if (active_capture_unlocked()->is_recording()) {
                throw std::runtime_error("an audio capture session is already active");
            }
            active_mode_.reset();
        }
    }

    AudioCaptureService& capture =
        capture_mode == AudioCaptureMode::NearbyRemote ? static_cast<AudioCaptureService&>(push_capture_) : local_capture_;
    capture.start(sample_rate, channels, device_id, capture_mode);
    std::scoped_lock lock(mutex_);
    active_mode_ = capture_mode;
}

std::vector<float> RoutedAudioCaptureService::stop() {
    AudioCaptureService* capture = nullptr;
    {
        std::scoped_lock lock(mutex_);
        capture = active_capture_unlocked();
        active_mode_.reset();
    }
    return capture != nullptr ? capture->stop() : std::vector<float>{};
}

std::vector<float> RoutedAudioCaptureService::take_pending_samples() {
    std::scoped_lock lock(mutex_);
    AudioCaptureService* capture = active_capture_unlocked();
    return capture != nullptr ? capture->take_pending_samples() : std::vector<float>{};
}

bool RoutedAudioCaptureService::is_recording() const {
    std::scoped_lock lock(mutex_);
    AudioCaptureService* capture = active_capture_unlocked();
    return capture != nullptr && capture->is_recording();
}

std::vector<AudioInputDevice> RoutedAudioCaptureService::list_input_devices() const {
    return local_capture_.list_input_devices();
}

AudioCaptureService* RoutedAudioCaptureService::active_capture_unlocked() const {
    if (!active_mode_.has_value()) {
        return nullptr;
    }
    return *active_mode_ == AudioCaptureMode::NearbyRemote
               ? static_cast<AudioCaptureService*>(&push_capture_)
               : &local_capture_;
}

}  // namespace ohmytypeless
