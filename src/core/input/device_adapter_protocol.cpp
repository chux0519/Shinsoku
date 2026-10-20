#include "core/input/device_adapter_protocol.hpp"

#include <mbedtls/base64.h>

#include <nlohmann/json.hpp>

#include <algorithm>
#include <array>
#include <limits>
#include <stdexcept>
#include <utility>

namespace ohmytypeless {

namespace {

bool valid_identifier(std::string_view value, std::size_t maximum_size) {
    if (value.empty() || value.size() > maximum_size) {
        return false;
    }
    return std::all_of(value.cbegin(), value.cend(), [](unsigned char character) {
        const bool ascii_alphanumeric = (character >= 'a' && character <= 'z') ||
                                        (character >= 'A' && character <= 'Z') ||
                                        (character >= '0' && character <= '9');
        return ascii_alphanumeric || character == '.' || character == '_' || character == '-';
    });
}

bool valid_display_text(std::string_view value, std::size_t maximum_size) {
    return !value.empty() && value.size() <= maximum_size &&
           std::all_of(value.cbegin(), value.cend(), [](unsigned char character) {
               return character >= 0x20U && character != 0x7FU;
           });
}

std::optional<std::string> required_string(const nlohmann::json& object,
                                           const char* key,
                                           std::size_t maximum_size) {
    if (!object.is_object() || !object.contains(key) || !object.at(key).is_string()) {
        return std::nullopt;
    }
    const std::string value = object.at(key).get<std::string>();
    return valid_display_text(value, maximum_size) ? std::optional<std::string>(value) : std::nullopt;
}

std::optional<std::uint32_t> required_uint32(const nlohmann::json& object, const char* key) {
    if (!object.is_object() || !object.contains(key) ||
        (!object.at(key).is_number_integer() && !object.at(key).is_number_unsigned())) {
        return std::nullopt;
    }
    if (object.at(key).is_number_unsigned()) {
        const std::uint64_t value = object.at(key).get<std::uint64_t>();
        return value <= std::numeric_limits<std::uint32_t>::max()
                   ? std::optional<std::uint32_t>(static_cast<std::uint32_t>(value))
                   : std::nullopt;
    }
    const std::int64_t value = object.at(key).get<std::int64_t>();
    return value >= 0 && value <= std::numeric_limits<std::uint32_t>::max()
               ? std::optional<std::uint32_t>(static_cast<std::uint32_t>(value))
               : std::nullopt;
}

std::vector<std::string> string_array(const nlohmann::json& object,
                                      const char* key,
                                      std::size_t maximum_items,
                                      bool* valid) {
    *valid = false;
    if (!object.contains(key) || !object.at(key).is_array() || object.at(key).size() > maximum_items) {
        return {};
    }
    std::vector<std::string> values;
    std::unordered_set<std::string> unique;
    for (const auto& item : object.at(key)) {
        if (!item.is_string()) {
            return {};
        }
        std::string value = item.get<std::string>();
        if (!valid_identifier(value, 64U) || !unique.insert(value).second) {
            return {};
        }
        values.push_back(std::move(value));
    }
    *valid = true;
    return values;
}

std::optional<std::vector<std::uint8_t>> decode_base64(std::string_view encoded) {
    if (encoded.empty() || encoded.size() % 4U != 0U || encoded.size() > 9000U) {
        return std::nullopt;
    }
    const auto padding = encoded.find('=');
    for (std::size_t index = 0; index < encoded.size(); ++index) {
        const unsigned char character = static_cast<unsigned char>(encoded[index]);
        const bool alphabet = (character >= 'a' && character <= 'z') ||
                              (character >= 'A' && character <= 'Z') ||
                              (character >= '0' && character <= '9') || character == '+' || character == '/';
        if (!alphabet && character != '=') {
            return std::nullopt;
        }
        if (padding != std::string_view::npos && index >= padding && character != '=') {
            return std::nullopt;
        }
    }
    if (padding != std::string_view::npos && encoded.size() - padding > 2U) {
        return std::nullopt;
    }

    std::vector<std::uint8_t> decoded((encoded.size() / 4U) * 3U);
    std::size_t output_size = 0;
    const int result = mbedtls_base64_decode(decoded.data(),
                                             decoded.size(),
                                             &output_size,
                                             reinterpret_cast<const unsigned char*>(encoded.data()),
                                             encoded.size());
    if (result != 0) {
        return std::nullopt;
    }
    decoded.resize(output_size);
    return decoded;
}

bool valid_stop_reason(std::string_view reason) {
    constexpr std::array reasons{"completed", "cancelled", "disconnected", "error"};
    return std::find(reasons.cbegin(), reasons.cend(), reason) != reasons.cend();
}

}  // namespace

nlohmann::json DeviceAdapterValidationReport::to_json() const {
    return {
        {"schema_version", 1},
        {"ok", ok},
        {"adapter",
         {{"id", adapter_id},
          {"name", adapter_name},
          {"version", adapter_version},
          {"capabilities", capabilities},
          {"declared_permissions", declared_permissions}}},
        {"summary",
         {{"lines", line_count},
          {"devices", device_count},
          {"audio_streams", audio_stream_count},
          {"audio_chunks", audio_chunk_count},
          {"audio_samples", audio_sample_count},
          {"button_events", button_event_count}}},
        {"errors", errors},
    };
}

DeviceAdapterTraceValidator::DeviceAdapterTraceValidator(bool require_audio_stream)
    : require_audio_stream_(require_audio_stream) {}

const DeviceAdapterValidationReport& DeviceAdapterTraceValidator::report() const {
    return report_;
}

void DeviceAdapterTraceValidator::accept_line(std::string_view line) {
    ++report_.line_count;
    if (finished_) {
        fail("line " + std::to_string(report_.line_count) + ": trace validation already finished");
        return;
    }
    if (line.empty() || line.size() > kDeviceAdapterMaximumLineBytes) {
        fail("line " + std::to_string(report_.line_count) + ": invalid line size");
        return;
    }
    try {
        const nlohmann::json message = nlohmann::json::parse(line);
        if (!message.is_object()) {
            fail("line " + std::to_string(report_.line_count) + ": event must be a JSON object");
            return;
        }
        accept_message(message);
    } catch (const nlohmann::json::exception& exception) {
        fail("line " + std::to_string(report_.line_count) + ": invalid JSON: " + exception.what());
    }
}

DeviceAdapterValidationReport DeviceAdapterTraceValidator::finish() {
    if (!finished_) {
        finished_ = true;
        if (!hello_received_) {
            fail("trace did not contain adapter.hello");
        }
        if (active_audio_.has_value()) {
            fail("trace ended with an active audio stream");
        }
        if (require_audio_stream_) {
            if (!capabilities_.contains("audio.pcm16")) {
                fail("full conformance requires the audio.pcm16 capability");
            }
            if (report_.audio_stream_count == 0U || report_.audio_chunk_count == 0U ||
                report_.audio_sample_count == 0U) {
                fail("full conformance requires one complete non-empty audio stream");
            }
        }
    }
    report_.ok = report_.errors.empty();
    return report_;
}

void DeviceAdapterTraceValidator::accept_message(const nlohmann::json& message) {
    const auto type = required_string(message, "type", 64U);
    if (!type.has_value() || !valid_identifier(*type, 64U)) {
        fail("line " + std::to_string(report_.line_count) + ": event type is invalid");
        return;
    }
    if (goodbye_received_) {
        fail("line " + std::to_string(report_.line_count) + ": event follows adapter.goodbye");
        return;
    }
    if (*type == "adapter.hello") {
        accept_hello(message);
        return;
    }
    if (!hello_received_) {
        fail("line " + std::to_string(report_.line_count) + ": adapter.hello must be first");
        return;
    }
    if (*type == "device.found") {
        accept_device_found(message);
    } else if (*type == "discovery.finished") {
        accept_discovery_finished(message);
    } else if (*type == "device.status") {
        accept_device_status(message);
    } else if (*type == "button") {
        accept_button(message);
    } else if (*type == "audio.start") {
        accept_audio_start(message);
    } else if (*type == "audio.chunk") {
        accept_audio_chunk(message);
    } else if (*type == "audio.stop") {
        accept_audio_stop(message);
    } else if (*type == "adapter.goodbye") {
        accept_goodbye(message);
    } else {
        fail("line " + std::to_string(report_.line_count) + ": unsupported adapter event '" + *type + "'");
    }
}

void DeviceAdapterTraceValidator::accept_hello(const nlohmann::json& message) {
    if (hello_received_ || report_.line_count != 1U) {
        fail("line " + std::to_string(report_.line_count) + ": adapter.hello must appear exactly once and first");
        return;
    }
    if (!message.contains("protocol_version") || !message.at("protocol_version").is_number_integer() ||
        message.at("protocol_version").get<int>() != kDeviceAdapterProtocolVersion ||
        !message.contains("adapter") || !message.at("adapter").is_object()) {
        fail("line 1: adapter.hello requires protocol version 1 and an adapter manifest");
        return;
    }

    const nlohmann::json& adapter = message.at("adapter");
    const auto id = required_string(adapter, "id", 128U);
    const auto name = required_string(adapter, "name", 160U);
    const auto version = required_string(adapter, "version", 64U);
    bool capabilities_valid = false;
    bool permissions_valid = false;
    std::vector<std::string> capabilities = string_array(adapter, "capabilities", 32U, &capabilities_valid);
    std::vector<std::string> permissions = string_array(adapter, "permissions", 32U, &permissions_valid);
    if (!id.has_value() || !valid_identifier(*id, 128U) || !name.has_value() || !version.has_value() ||
        !capabilities_valid || !permissions_valid) {
        fail("line 1: adapter manifest fields are invalid");
        return;
    }

    hello_received_ = true;
    report_.adapter_id = *id;
    report_.adapter_name = *name;
    report_.adapter_version = *version;
    report_.capabilities = std::move(capabilities);
    report_.declared_permissions = std::move(permissions);
    capabilities_.insert(report_.capabilities.cbegin(), report_.capabilities.cend());
}

void DeviceAdapterTraceValidator::accept_device_found(const nlohmann::json& message) {
    if (!message.contains("device") || !message.at("device").is_object()) {
        fail("line " + std::to_string(report_.line_count) + ": device.found requires a device object");
        return;
    }
    const nlohmann::json& device = message.at("device");
    const auto id = required_string(device, "id", 128U);
    const auto name = required_string(device, "name", 160U);
    bool capabilities_valid = false;
    const auto capabilities = string_array(device, "capabilities", 32U, &capabilities_valid);
    if (!id.has_value() || !valid_identifier(*id, 128U) || !name.has_value() || !capabilities_valid) {
        fail("line " + std::to_string(report_.line_count) + ": discovered device fields are invalid");
        return;
    }
    for (const std::string& capability : capabilities) {
        if (!capabilities_.contains(capability)) {
            fail("line " + std::to_string(report_.line_count) +
                 ": device advertises a capability absent from its adapter manifest");
            return;
        }
    }
    if (device.contains("battery_percent") &&
        (!device.at("battery_percent").is_number_integer() ||
         device.at("battery_percent").get<int>() < 0 || device.at("battery_percent").get<int>() > 100)) {
        fail("line " + std::to_string(report_.line_count) + ": battery_percent must be between 0 and 100");
        return;
    }
    if (device.contains("signal_dbm") &&
        (!device.at("signal_dbm").is_number_integer() || device.at("signal_dbm").get<int>() < -127 ||
         device.at("signal_dbm").get<int>() > 0)) {
        fail("line " + std::to_string(report_.line_count) + ": signal_dbm must be between -127 and 0");
        return;
    }
    if (device.contains("firmware") &&
        (!device.at("firmware").is_string() ||
         !valid_display_text(device.at("firmware").get_ref<const std::string&>(), 64U))) {
        fail("line " + std::to_string(report_.line_count) + ": firmware is invalid");
        return;
    }
    if (devices_.insert(*id).second) {
        report_.device_count = devices_.size();
    }
}

void DeviceAdapterTraceValidator::accept_discovery_finished(const nlohmann::json& message) {
    const auto count = required_uint32(message, "device_count");
    if (!count.has_value() || *count != devices_.size()) {
        fail("line " + std::to_string(report_.line_count) +
             ": discovery.finished device_count does not match device.found events");
    }
}

void DeviceAdapterTraceValidator::accept_device_status(const nlohmann::json& message) {
    const auto device_id = required_string(message, "device_id", 128U);
    const auto state = required_string(message, "state", 32U);
    constexpr std::array states{"disconnected", "connecting", "connected", "error"};
    if (!device_id.has_value() || !devices_.contains(*device_id) || !state.has_value() ||
        std::find(states.cbegin(), states.cend(), *state) == states.cend()) {
        fail("line " + std::to_string(report_.line_count) + ": device.status is invalid");
    }
}

void DeviceAdapterTraceValidator::accept_button(const nlohmann::json& message) {
    const auto device_id = required_string(message, "device_id", 128U);
    const auto action_id = required_string(message, "action_id", 160U);
    const auto event = required_string(message, "event", 16U);
    constexpr std::array events{"down", "up", "repeat"};
    if (!device_id.has_value() || !devices_.contains(*device_id) || !action_id.has_value() ||
        !valid_device_adapter_action_id(*action_id) || !event.has_value() ||
        std::find(events.cbegin(), events.cend(), *event) == events.cend()) {
        fail("line " + std::to_string(report_.line_count) + ": button event is invalid");
        return;
    }
    ++report_.button_event_count;
}

void DeviceAdapterTraceValidator::accept_audio_start(const nlohmann::json& message) {
    const auto stream_id = required_uint32(message, "stream_id");
    const auto device_id = required_string(message, "device_id", 128U);
    if (!capabilities_.contains("audio.pcm16") || active_audio_.has_value() || !stream_id.has_value() ||
        *stream_id == 0U || !device_id.has_value() || !devices_.contains(*device_id) ||
        !message.contains("format") || !message.at("format").is_object()) {
        fail("line " + std::to_string(report_.line_count) + ": audio.start is invalid");
        return;
    }
    const nlohmann::json& format = message.at("format");
    const auto encoding = required_string(format, "encoding", 32U);
    const auto sample_rate = required_uint32(format, "sample_rate_hz");
    const auto channels = required_uint32(format, "channels");
    if (!encoding.has_value() || *encoding != "pcm16le" || !sample_rate.has_value() || *sample_rate != 16000U ||
        !channels.has_value() || *channels != 1U) {
        fail("line " + std::to_string(report_.line_count) +
             ": adapter audio must be mono PCM16LE at 16 kHz");
        return;
    }
    if (message.contains("profile_id")) {
        if (!message.at("profile_id").is_string() ||
            !valid_identifier(message.at("profile_id").get_ref<const std::string&>(), 128U)) {
            fail("line " + std::to_string(report_.line_count) + ": audio.start profile_id is invalid");
            return;
        }
    }
    active_audio_ = ActiveAudioStream{.stream_id = *stream_id, .device_id = *device_id};
}

void DeviceAdapterTraceValidator::accept_audio_chunk(const nlohmann::json& message) {
    const auto stream_id = required_uint32(message, "stream_id");
    const auto sequence = required_uint32(message, "sequence");
    const auto encoded = required_string(message, "pcm16le_base64", 9000U);
    if (!active_audio_.has_value() || !stream_id.has_value() || *stream_id != active_audio_->stream_id ||
        !sequence.has_value() || *sequence != active_audio_->next_sequence || !encoded.has_value()) {
        fail("line " + std::to_string(report_.line_count) +
             ": audio.chunk stream or sequence is invalid");
        return;
    }
    const auto samples = decode_device_adapter_pcm16le_base64(*encoded);
    if (!samples.has_value()) {
        fail("line " + std::to_string(report_.line_count) +
             ": audio.chunk must contain 1 to 3200 PCM16 samples");
        return;
    }
    ++active_audio_->next_sequence;
    active_audio_->sample_count += samples->size();
    ++report_.audio_chunk_count;
    report_.audio_sample_count += samples->size();
}

void DeviceAdapterTraceValidator::accept_audio_stop(const nlohmann::json& message) {
    const auto stream_id = required_uint32(message, "stream_id");
    const auto reason = required_string(message, "reason", 32U);
    if (!active_audio_.has_value() || !stream_id.has_value() || *stream_id != active_audio_->stream_id ||
        !reason.has_value() || !valid_stop_reason(*reason)) {
        fail("line " + std::to_string(report_.line_count) + ": audio.stop is invalid");
        return;
    }
    if (message.contains("total_samples")) {
        const auto total_samples = required_uint32(message, "total_samples");
        if (!total_samples.has_value() || *total_samples != active_audio_->sample_count) {
            fail("line " + std::to_string(report_.line_count) +
                 ": audio.stop total_samples does not match audio chunks");
            return;
        }
    }
    ++report_.audio_stream_count;
    active_audio_.reset();
}

void DeviceAdapterTraceValidator::accept_goodbye(const nlohmann::json&) {
    if (active_audio_.has_value()) {
        fail("line " + std::to_string(report_.line_count) +
             ": adapter.goodbye cannot close an active audio stream");
        return;
    }
    goodbye_received_ = true;
}

void DeviceAdapterTraceValidator::fail(std::string message) {
    report_.errors.push_back(std::move(message));
}

bool valid_device_adapter_action_id(std::string_view action_id) {
    constexpr std::array exact{
        "voice.start",
        "voice.stop",
        "profile.next",
        "profile.previous",
        "transcript.copy-last",
        "insertion.undo",
        "key.backspace",
        "key.newline",
        "key.submit",
    };
    if (std::find(exact.cbegin(), exact.cend(), action_id) != exact.cend()) {
        return true;
    }
    constexpr std::array prefixes{"profile.select:", "workflow.run:"};
    for (const std::string_view prefix : prefixes) {
        if (action_id.starts_with(prefix)) {
            return valid_identifier(action_id.substr(prefix.size()), 128U);
        }
    }
    return false;
}

std::optional<std::vector<std::int16_t>> decode_device_adapter_pcm16le_base64(
    std::string_view encoded) {
    const auto bytes = decode_base64(encoded);
    if (!bytes.has_value() || bytes->empty() || bytes->size() % 2U != 0U ||
        bytes->size() / 2U > kDeviceAdapterMaximumChunkSamples) {
        return std::nullopt;
    }

    std::vector<std::int16_t> samples;
    samples.reserve(bytes->size() / 2U);
    for (std::size_t index = 0; index < bytes->size(); index += 2U) {
        const std::uint16_t value = static_cast<std::uint16_t>((*bytes)[index]) |
                                    (static_cast<std::uint16_t>((*bytes)[index + 1U]) << 8U);
        samples.push_back(static_cast<std::int16_t>(value));
    }
    return samples;
}

}  // namespace ohmytypeless
