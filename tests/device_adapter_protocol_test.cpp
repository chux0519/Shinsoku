#include "core/input/device_adapter_protocol.hpp"

#include <nlohmann/json.hpp>

#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

std::vector<std::string> valid_trace() {
    return {
        R"({"type":"adapter.hello","protocol_version":1,"adapter":{"id":"dev.shinsoku.test","name":"Test Adapter","version":"1.0.0","capabilities":["discover","connect","audio.pcm16","buttons"],"permissions":["bluetooth"]}})",
        R"({"type":"device.found","device":{"id":"remote-1","name":"Remote One","capabilities":["audio.pcm16","buttons"],"battery_percent":80,"signal_dbm":-42}})",
        R"({"type":"discovery.finished","device_count":1})",
        R"({"type":"device.status","device_id":"remote-1","state":"connected"})",
        R"({"type":"button","device_id":"remote-1","action_id":"workflow.run:meeting-notes","event":"down"})",
        R"({"type":"audio.start","stream_id":42,"device_id":"remote-1","profile_id":"default","format":{"encoding":"pcm16le","sample_rate_hz":16000,"channels":1}})",
        R"({"type":"audio.chunk","stream_id":42,"sequence":0,"pcm16le_base64":"AIAAAP9/"})",
        R"({"type":"audio.stop","stream_id":42,"reason":"completed","total_samples":3})",
        R"({"type":"adapter.goodbye"})",
    };
}

ohmytypeless::DeviceAdapterValidationReport validate(const std::vector<std::string>& lines,
                                                      bool require_audio = true) {
    ohmytypeless::DeviceAdapterTraceValidator validator(require_audio);
    for (const std::string& line : lines) {
        validator.accept_line(line);
    }
    return validator.finish();
}

void test_valid_full_trace() {
    const auto report = validate(valid_trace());
    require(report.ok && report.adapter_id == "dev.shinsoku.test" && report.device_count == 1U &&
                report.audio_stream_count == 1U && report.audio_chunk_count == 1U &&
                report.audio_sample_count == 3U && report.button_event_count == 1U,
            "a complete adapter trace must validate and report bounded event totals");
    const nlohmann::json output = report.to_json();
    require(output.at("ok") == true && output.at("summary").at("audio_samples") == 3,
            "the conformance report must have a stable structured JSON shape");
}

void test_sequence_and_audio_limits() {
    auto lines = valid_trace();
    lines[6] = R"({"type":"audio.chunk","stream_id":42,"sequence":1,"pcm16le_base64":"AIAAAP9/"})";
    const auto wrong_sequence = validate(lines);
    require(!wrong_sequence.ok && !wrong_sequence.errors.empty(),
            "a local adapter may not skip or reorder PCM chunks");

    lines = valid_trace();
    lines[6] = R"({"type":"audio.chunk","stream_id":42,"sequence":0,"pcm16le_base64":"not-base64"})";
    const auto malformed_audio = validate(lines);
    require(!malformed_audio.ok, "malformed Base64 audio must fail conformance");
}

void test_identity_and_lifecycle_rules() {
    auto lines = valid_trace();
    lines[0] = R"({"type":"adapter.hello","protocol_version":2,"adapter":{"id":"bad id","name":"Bad","version":"1","capabilities":[],"permissions":[]}})";
    require(!validate(lines).ok, "unsupported versions and unstable adapter IDs must be rejected");

    lines = valid_trace();
    lines.erase(lines.begin() + 7);
    require(!validate(lines).ok, "an adapter trace may not end or say goodbye with active audio");

    lines = valid_trace();
    lines[4] = R"({"type":"button","device_id":"remote-1","action_id":"shell.execute","event":"down"})";
    require(!validate(lines).ok, "adapters may report only host-owned stable action IDs");

    lines = valid_trace();
    lines[5] = R"({"type":"audio.start","stream_id":42,"device_id":"remote-1","profile_id":"bad profile\nvalue","format":{"encoding":"pcm16le","sample_rate_hz":16000,"channels":1}})";
    require(!validate(lines).ok, "remote Profile IDs must use stable identifier characters");
}

void test_manifest_only_mode() {
    const std::vector<std::string> lines{
        R"({"type":"adapter.hello","protocol_version":1,"adapter":{"id":"dev.shinsoku.buttons","name":"Button Adapter","version":"1.0","capabilities":["buttons"],"permissions":["bluetooth"]}})",
        R"({"type":"adapter.goodbye"})",
    };
    require(validate(lines, false).ok, "button-only adapters must pass manifest conformance without synthetic audio");
    require(!validate(lines, true).ok, "full audio conformance must require a non-empty PCM stream");
}

}  // namespace

int main() {
    try {
        test_valid_full_trace();
        test_sequence_and_audio_limits();
        test_identity_and_lifecycle_rules();
        test_manifest_only_mode();
        std::cout << "device_adapter_protocol_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << "device_adapter_protocol_tests: " << exception.what() << '\n';
        return 1;
    }
}
