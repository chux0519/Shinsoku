#include <pulse/context.h>
#include <pulse/error.h>
#include <pulse/introspect.h>
#include <pulse/sample.h>
#include <pulse/simple.h>
#include <pulse/thread-mainloop.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

namespace {

struct ServerInfoResult {
    bool server_ready = false;
    bool sink_ready = false;
    std::string default_sink_name;
    std::string monitor_source_name;
    std::string error;
};

bool wait_for_context_ready(pa_threaded_mainloop* mainloop, pa_context* context, std::chrono::seconds timeout) {
    const auto deadline = std::chrono::steady_clock::now() + timeout;
    while (std::chrono::steady_clock::now() < deadline) {
        pa_threaded_mainloop_lock(mainloop);
        const pa_context_state_t state = pa_context_get_state(context);
        pa_threaded_mainloop_unlock(mainloop);
        if (state == PA_CONTEXT_READY) {
            return true;
        }
        if (!PA_CONTEXT_IS_GOOD(state)) {
            return false;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
    return false;
}

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

bool wait_for_flag(pa_threaded_mainloop* mainloop, const bool* flag, std::chrono::seconds timeout) {
    const auto deadline = std::chrono::steady_clock::now() + timeout;
    while (std::chrono::steady_clock::now() < deadline) {
        pa_threaded_mainloop_lock(mainloop);
        const bool ready = *flag;
        pa_threaded_mainloop_unlock(mainloop);
        if (ready) {
            return true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
    return false;
}

double rms_of(const float* samples, std::size_t sample_count) {
    if (samples == nullptr || sample_count == 0) {
        return 0.0;
    }

    double sum = 0.0;
    for (std::size_t i = 0; i < sample_count; ++i) {
        sum += static_cast<double>(samples[i]) * static_cast<double>(samples[i]);
    }
    return std::sqrt(sum / static_cast<double>(sample_count));
}

}  // namespace

int main(int argc, char** argv) {
    const std::uint32_t sample_rate = argc > 1 ? static_cast<std::uint32_t>(std::strtoul(argv[1], nullptr, 10)) : 48000U;
    const std::uint32_t channels = argc > 2 ? static_cast<std::uint32_t>(std::strtoul(argv[2], nullptr, 10)) : 2U;

    pa_threaded_mainloop* mainloop = pa_threaded_mainloop_new();
    if (mainloop == nullptr) {
        std::cerr << "failed: pa_threaded_mainloop_new\n";
        return 1;
    }
    if (pa_threaded_mainloop_start(mainloop) < 0) {
        std::cerr << "failed: pa_threaded_mainloop_start\n";
        pa_threaded_mainloop_free(mainloop);
        return 1;
    }

    pa_context* context = nullptr;
    ServerInfoResult info;

    pa_threaded_mainloop_lock(mainloop);
    context = pa_context_new(pa_threaded_mainloop_get_api(mainloop), "OhMyTypeless Pulse Probe");
    if (context == nullptr) {
        pa_threaded_mainloop_unlock(mainloop);
        std::cerr << "failed: pa_context_new\n";
        pa_threaded_mainloop_stop(mainloop);
        pa_threaded_mainloop_free(mainloop);
        return 1;
    }
    if (pa_context_connect(context, nullptr, PA_CONTEXT_NOFLAGS, nullptr) < 0) {
        const int error = pa_context_errno(context);
        pa_threaded_mainloop_unlock(mainloop);
        std::cerr << "failed: pa_context_connect: " << pa_strerror(error) << "\n";
        pa_context_unref(context);
        pa_threaded_mainloop_stop(mainloop);
        pa_threaded_mainloop_free(mainloop);
        return 1;
    }
    pa_threaded_mainloop_unlock(mainloop);

    if (!wait_for_context_ready(mainloop, context, std::chrono::seconds(3))) {
        pa_threaded_mainloop_lock(mainloop);
        const int error = pa_context_errno(context);
        pa_threaded_mainloop_unlock(mainloop);
        std::cerr << "failed: context not ready within timeout: " << pa_strerror(error) << "\n";
        pa_threaded_mainloop_lock(mainloop);
        pa_context_disconnect(context);
        pa_context_unref(context);
        pa_threaded_mainloop_unlock(mainloop);
        pa_threaded_mainloop_stop(mainloop);
        pa_threaded_mainloop_free(mainloop);
        return 1;
    }

    std::cout << "context: ready\n";

    pa_threaded_mainloop_lock(mainloop);
    pa_operation* server_op = pa_context_get_server_info(context, &on_server_info, &info);
    pa_threaded_mainloop_unlock(mainloop);
    if (server_op == nullptr) {
        pa_threaded_mainloop_lock(mainloop);
        const int error = pa_context_errno(context);
        pa_threaded_mainloop_unlock(mainloop);
        std::cerr << "failed: pa_context_get_server_info: " << pa_strerror(error) << "\n";
        return 1;
    }
    if (!wait_for_flag(mainloop, &info.server_ready, std::chrono::seconds(3))) {
        std::cerr << "failed: server info timeout\n";
        pa_operation_unref(server_op);
        return 1;
    }
    pa_operation_unref(server_op);

    std::cout << "default sink: " << info.default_sink_name << "\n";
    if (info.default_sink_name.empty()) {
        std::cerr << "failed: no default sink\n";
        return 1;
    }

    pa_threaded_mainloop_lock(mainloop);
    pa_operation* sink_op = pa_context_get_sink_info_by_name(context, info.default_sink_name.c_str(), &on_sink_info, &info);
    pa_threaded_mainloop_unlock(mainloop);
    if (sink_op == nullptr) {
        pa_threaded_mainloop_lock(mainloop);
        const int error = pa_context_errno(context);
        pa_threaded_mainloop_unlock(mainloop);
        std::cerr << "failed: pa_context_get_sink_info_by_name: " << pa_strerror(error) << "\n";
        return 1;
    }
    if (!wait_for_flag(mainloop, &info.sink_ready, std::chrono::seconds(3))) {
        std::cerr << "failed: sink info timeout\n";
        pa_operation_unref(sink_op);
        return 1;
    }
    pa_operation_unref(sink_op);

    std::cout << "monitor source: " << info.monitor_source_name << "\n";
    if (info.monitor_source_name.empty()) {
        std::cerr << "failed: no monitor source\n";
        return 1;
    }

    pa_threaded_mainloop_lock(mainloop);
    pa_context_disconnect(context);
    pa_context_unref(context);
    pa_threaded_mainloop_unlock(mainloop);
    pa_threaded_mainloop_stop(mainloop);
    pa_threaded_mainloop_free(mainloop);

    pa_sample_spec sample_spec{};
    sample_spec.format = PA_SAMPLE_FLOAT32LE;
    sample_spec.rate = sample_rate;
    sample_spec.channels = static_cast<std::uint8_t>(channels);
    if (!pa_sample_spec_valid(&sample_spec)) {
        std::cerr << "failed: invalid sample spec\n";
        return 1;
    }

    pa_buffer_attr attr{};
    attr.maxlength = static_cast<uint32_t>(-1);
    attr.tlength = static_cast<uint32_t>(-1);
    attr.prebuf = static_cast<uint32_t>(-1);
    attr.minreq = static_cast<uint32_t>(-1);
    attr.fragsize = sizeof(float) * channels * std::max<std::uint32_t>(1, sample_rate / 50);

    int error_code = 0;
    pa_simple* simple = pa_simple_new(nullptr,
                                      "OhMyTypeless Pulse Probe",
                                      PA_STREAM_RECORD,
                                      info.monitor_source_name.c_str(),
                                      "Probe Monitor Source",
                                      &sample_spec,
                                      nullptr,
                                      &attr,
                                      &error_code);
    if (simple == nullptr) {
        std::cerr << "failed: pa_simple_new: " << pa_strerror(error_code) << "\n";
        return 1;
    }

    constexpr std::size_t kFramesPerChunk = 960;
    std::vector<float> buffer(kFramesPerChunk * channels);
    const std::size_t bytes_per_chunk = sizeof(float) * channels * kFramesPerChunk;

    for (int i = 0; i < 5; ++i) {
        if (pa_simple_read(simple, buffer.data(), bytes_per_chunk, &error_code) < 0) {
            std::cerr << "failed: pa_simple_read: " << pa_strerror(error_code) << "\n";
            pa_simple_free(simple);
            return 1;
        }
        std::cout << "chunk " << (i + 1) << ": rms=" << rms_of(buffer.data(), buffer.size()) << "\n";
    }

    pa_simple_free(simple);
    std::cout << "ok: monitor capture probe succeeded\n";
    return 0;
}
