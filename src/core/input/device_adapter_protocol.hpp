#pragma once

#include <nlohmann/json_fwd.hpp>

#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_set>
#include <vector>

namespace ohmytypeless {

inline constexpr int kDeviceAdapterProtocolVersion = 1;
inline constexpr std::size_t kDeviceAdapterMaximumLineBytes = 16U * 1024U;
inline constexpr std::size_t kDeviceAdapterMaximumChunkSamples = 3200U;

struct DeviceAdapterValidationReport {
    bool ok = false;
    std::string adapter_id;
    std::string adapter_name;
    std::string adapter_version;
    std::vector<std::string> capabilities;
    std::vector<std::string> declared_permissions;
    std::size_t line_count = 0;
    std::size_t device_count = 0;
    std::size_t audio_stream_count = 0;
    std::size_t audio_chunk_count = 0;
    std::size_t audio_sample_count = 0;
    std::size_t button_event_count = 0;
    std::vector<std::string> errors;

    nlohmann::json to_json() const;
};

class DeviceAdapterTraceValidator {
public:
    explicit DeviceAdapterTraceValidator(bool require_audio_stream = false);

    void accept_line(std::string_view line);
    const DeviceAdapterValidationReport& report() const;
    DeviceAdapterValidationReport finish();

private:
    struct ActiveAudioStream {
        std::uint32_t stream_id = 0;
        std::string device_id;
        std::uint32_t next_sequence = 0;
        std::size_t sample_count = 0;
    };

    void accept_message(const nlohmann::json& message);
    void accept_hello(const nlohmann::json& message);
    void accept_device_found(const nlohmann::json& message);
    void accept_discovery_finished(const nlohmann::json& message);
    void accept_device_status(const nlohmann::json& message);
    void accept_button(const nlohmann::json& message);
    void accept_audio_start(const nlohmann::json& message);
    void accept_audio_chunk(const nlohmann::json& message);
    void accept_audio_stop(const nlohmann::json& message);
    void accept_goodbye(const nlohmann::json& message);
    void fail(std::string message);

    bool require_audio_stream_ = false;
    bool hello_received_ = false;
    bool goodbye_received_ = false;
    bool finished_ = false;
    std::unordered_set<std::string> capabilities_;
    std::unordered_set<std::string> devices_;
    std::optional<ActiveAudioStream> active_audio_;
    DeviceAdapterValidationReport report_;
};

bool valid_device_adapter_action_id(std::string_view action_id);
std::optional<std::vector<std::int16_t>> decode_device_adapter_pcm16le_base64(
    std::string_view encoded);

}  // namespace ohmytypeless
