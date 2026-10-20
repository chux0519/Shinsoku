#include "platform/process/device_adapter_runtime.hpp"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QThread>

#include <cmath>
#include <filesystem>
#include <iostream>
#include <span>
#include <string>
#include <vector>

namespace {

class RecordingSink final : public ohmytypeless::PushAudioSink {
public:
    bool on_push_audio_start(const ohmytypeless::PushAudioStreamInfo& stream,
                             std::string*) override {
        started = true;
        stream_info = stream;
        return true;
    }

    bool on_push_audio_samples(std::uint32_t stream_id,
                               std::span<const std::int16_t> chunk,
                               std::string*) override {
        if (stream_id != stream_info.stream_id) {
            return false;
        }
        samples.insert(samples.end(), chunk.begin(), chunk.end());
        return true;
    }

    void on_push_audio_stop(std::uint32_t stream_id,
                            ohmytypeless::PushAudioStopReason reason) override {
        stopped = stream_id == stream_info.stream_id;
        stop_reason = reason;
    }

    bool started = false;
    bool stopped = false;
    ohmytypeless::PushAudioStreamInfo stream_info;
    ohmytypeless::PushAudioStopReason stop_reason = ohmytypeless::PushAudioStopReason::Error;
    std::vector<std::int16_t> samples;
};

bool expect(bool condition, const char* message) {
    if (!condition) {
        std::cerr << message << '\n';
    }
    return condition;
}

}  // namespace

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);
    if (argc != 2) {
        std::cerr << "fixture executable path required\n";
        return 2;
    }

    bool ok = true;
    RecordingSink sink;
    ohmytypeless::DeviceAdapterRuntime runtime(sink);

    try {
        runtime.apply({.enabled = true, .executable_path = "relative-adapter"});
        ok = expect(false, "relative adapter path was accepted") && ok;
    } catch (const std::invalid_argument&) {
    }

    qputenv("SHINSOKU_TEST_API_KEY", "must-not-reach-adapter");
    runtime.apply({.enabled = true,
                   .executable_path = std::filesystem::absolute(argv[1])});

    QElapsedTimer timeout;
    timeout.start();
    while (!sink.stopped && timeout.elapsed() < 5000) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 25);
        QThread::msleep(5);
    }

    const auto status = runtime.status();
    ok = expect(sink.started, "adapter audio stream did not start") && ok;
    ok = expect(sink.stopped, "adapter audio stream did not stop") && ok;
    ok = expect(sink.stop_reason == ohmytypeless::PushAudioStopReason::Completed,
                "adapter stop reason was not completed") && ok;
    ok = expect(sink.samples == std::vector<std::int16_t>({-32768, 0, 32767}),
                "adapter PCM samples were decoded incorrectly") && ok;
    ok = expect(sink.stream_info.source_kind == "device_adapter",
                "adapter source kind was not preserved") && ok;
    ok = expect(sink.stream_info.requested_profile_id == "default",
                "adapter requested profile was not preserved") && ok;
    ok = expect(status.ready && status.running, "adapter runtime did not become ready") && ok;
    ok = expect(status.adapter_id == "dev.shinsoku.test.runtime",
                "adapter manifest was not exposed") && ok;
    ok = expect(status.connected_device_id == "fixture-001",
                "adapter device was not connected") && ok;
    ok = expect(status.last_error.empty(), "adapter runtime reported an unexpected error") && ok;

    runtime.stop();
    qunsetenv("SHINSOKU_TEST_API_KEY");
    return ok ? 0 : 1;
}
