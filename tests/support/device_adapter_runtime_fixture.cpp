#include <nlohmann/json.hpp>

#include <cstdlib>
#include <iostream>
#include <string>

namespace {

void emit(const nlohmann::json& message) {
    std::cout << message.dump() << '\n' << std::flush;
}

}  // namespace

int main() {
    if (std::getenv("SHINSOKU_TEST_API_KEY") != nullptr) {
        return 3;
    }

    std::string line;
    while (std::getline(std::cin, line)) {
        const nlohmann::json message = nlohmann::json::parse(line);
        const std::string type = message.value("type", std::string{});
        if (type == "host.hello") {
            emit({
                {"type", "adapter.hello"},
                {"protocol_version", 1},
                {"adapter",
                 {{"id", "dev.shinsoku.test.runtime"},
                  {"name", "Runtime Fixture"},
                  {"version", "1.0.0"},
                  {"capabilities", {"discover", "connect", "audio.pcm16"}},
                  {"permissions", {"usb"}}}},
            });
        } else if (type == "device.discover") {
            emit({{"type", "device.found"},
                  {"device",
                   {{"id", "fixture-001"},
                    {"name", "Fixture Microphone"},
                    {"capabilities", {"audio.pcm16"}}}}});
            emit({{"type", "discovery.finished"}, {"device_count", 1}});
        } else if (type == "device.connect") {
            emit({{"type", "device.status"},
                  {"device_id", "fixture-001"},
                  {"state", "connected"}});
            emit({{"type", "audio.start"},
                  {"stream_id", 19},
                  {"device_id", "fixture-001"},
                  {"profile_id", "default"},
                  {"format",
                   {{"encoding", "pcm16le"}, {"sample_rate_hz", 16000}, {"channels", 1}}}});
            emit({{"type", "audio.chunk"},
                  {"stream_id", 19},
                  {"sequence", 0},
                  {"pcm16le_base64", "AIAAAP9/"}});
            emit({{"type", "audio.stop"},
                  {"stream_id", 19},
                  {"reason", "completed"},
                  {"total_samples", 3}});
        } else if (type == "adapter.shutdown") {
            emit({{"type", "adapter.goodbye"}});
            return 0;
        }
    }
    return 0;
}
