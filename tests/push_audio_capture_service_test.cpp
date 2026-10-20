#include "core/nearby/nearby_protocol.hpp"
#include "platform/network/push_audio_capture_service.hpp"

#include <cmath>
#include <cstdint>
#include <iostream>
#include <span>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

class FakeLocalCapture final : public ohmytypeless::AudioCaptureService {
public:
    bool supports_capture_mode(ohmytypeless::AudioCaptureMode mode) const override {
        return mode == ohmytypeless::AudioCaptureMode::Microphone ||
               mode == ohmytypeless::AudioCaptureMode::SystemLoopback;
    }

    void start(std::uint32_t,
               std::uint32_t,
               const std::string& device_id,
               ohmytypeless::AudioCaptureMode mode) override {
        if (!supports_capture_mode(mode)) {
            throw std::invalid_argument("unsupported fake mode");
        }
        started = true;
        active_mode = mode;
        active_device = device_id;
    }

    std::vector<float> stop() override {
        started = false;
        pending.clear();
        return samples;
    }

    std::vector<float> take_pending_samples() override {
        std::vector<float> result = std::move(pending);
        pending.clear();
        return result;
    }

    bool is_recording() const override {
        return started;
    }

    std::vector<ohmytypeless::AudioInputDevice> list_input_devices() const override {
        return {{.id = "local-mic", .name = "Local microphone", .is_default = true}};
    }

    bool started = false;
    ohmytypeless::AudioCaptureMode active_mode = ohmytypeless::AudioCaptureMode::Microphone;
    std::string active_device;
    std::vector<float> samples{0.25f, -0.25f};
    std::vector<float> pending{0.25f};
};

void test_local_route() {
    using namespace ohmytypeless;

    FakeLocalCapture local;
    PushAudioCaptureService push;
    RoutedAudioCaptureService routed(local, push);
    require(routed.supports_capture_mode(AudioCaptureMode::Microphone) &&
                routed.supports_capture_mode(AudioCaptureMode::SystemLoopback) &&
                routed.supports_capture_mode(AudioCaptureMode::NearbyRemote),
            "the routed service must expose local and remote capture capabilities");
    require(routed.list_input_devices().front().id == "local-mic",
            "remote routing must not replace local microphone enumeration");

    routed.start(16000, 1, "local-mic", AudioCaptureMode::Microphone);
    require(routed.is_recording() && local.active_device == "local-mic",
            "microphone capture must remain delegated to the platform service");
    require(routed.take_pending_samples() == std::vector<float>{0.25f},
            "pending local samples must remain available through the router");
    require(routed.stop() == local.samples && !routed.is_recording(),
            "stopping a local route must return the platform samples");
}

void test_nearby_route() {
    using namespace ohmytypeless;

    FakeLocalCapture local;
    PushAudioCaptureService push;
    RoutedAudioCaptureService routed(local, push);
    std::vector<float> completed_samples;
    std::uint32_t stopped_stream = 0;
    push.set_callbacks(PushAudioCaptureCallbacks{
        .on_stream_started = [&](const PushAudioStreamInfo&, std::string* error) {
            try {
                routed.start(16000, 1, {}, AudioCaptureMode::NearbyRemote);
                return true;
            } catch (const std::exception& exception) {
                if (error != nullptr) {
                    *error = exception.what();
                }
                return false;
            }
        },
        .on_stream_stopped = [&](std::uint32_t stream_id, PushAudioStopReason) {
            stopped_stream = stream_id;
            completed_samples = routed.stop();
        },
    });

    NearbyAudioSession session(push,
                               NearbyClientIdentity{
                                   .client_id = "iphone-remote",
                                   .display_name = "iPhone",
                                   .client_kind = "iphone",
                               });
    std::string error;
    require(session.start(77, PushAudioFormat{}, "translate", &error) && routed.is_recording(),
            "an accepted push stream must synchronously arm nearby capture");
    require(push.active_stream().has_value() && push.active_stream()->requested_profile_id == "translate",
            "the capture service must preserve remote source and Profile context");

    const std::vector<std::int16_t> pcm{-32768, -16384, 0, 16384, 32767};
    require(session.accept_frame(encode_nearby_audio_frame(77, 0, pcm)).status ==
                NearbyAudioFrameStatus::Accepted,
            "validated nearby frames must enter the routed capture service");
    const std::vector<float> pending = routed.take_pending_samples();
    require(pending.size() == pcm.size() && std::abs(pending.front() + 1.0f) < 0.0001f &&
                std::abs(pending[3] - 0.5f) < 0.0001f,
            "PCM16 samples must be converted to the controller's normalized float format");

    require(session.stop(77, &error) && stopped_stream == 77U && completed_samples.size() == pcm.size() &&
                !routed.is_recording(),
            "remote stop must finalize the same capture buffer consumed by the normal pipeline");

    routed.start(16000, 1, "local-mic", AudioCaptureMode::Microphone);
    require(!session.start(78, PushAudioFormat{}, {}, &error) && error.find("already active") != std::string::npos,
            "a remote stream must be rejected while local capture is active");
    routed.stop();
}

}  // namespace

int main() {
    try {
        test_local_route();
        test_nearby_route();
        std::cout << "push_audio_capture_service_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << "push_audio_capture_service_tests: " << exception.what() << '\n';
        return 1;
    }
}
