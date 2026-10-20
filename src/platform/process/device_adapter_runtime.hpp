#pragma once

#include "core/input/device_adapter_protocol.hpp"
#include "core/input/push_audio_source.hpp"

#include <QObject>
#include <QProcess>
#include <QTimer>

#include <cstdint>
#include <filesystem>
#include <map>
#include <optional>
#include <string>
#include <vector>

namespace ohmytypeless {

struct DeviceAdapterRuntimeConfig {
    bool enabled = false;
    std::filesystem::path executable_path;
    std::vector<std::string> arguments;
};

struct DeviceAdapterRuntimeStatus {
    bool enabled = false;
    bool running = false;
    bool ready = false;
    std::string executable_path;
    std::string adapter_id;
    std::string adapter_name;
    std::string adapter_version;
    std::vector<std::string> capabilities;
    std::vector<std::string> declared_permissions;
    std::string connected_device_id;
    std::string connected_device_name;
    std::string last_error;
};

class DeviceAdapterRuntime final : public QObject {
    Q_OBJECT
public:
    explicit DeviceAdapterRuntime(PushAudioSink& audio_sink, QObject* parent = nullptr);
    ~DeviceAdapterRuntime() override;

    void apply(const DeviceAdapterRuntimeConfig& config);
    void stop();
    DeviceAdapterRuntimeStatus status() const;

signals:
    void status_changed();
    void button_event(const QString& device_id, const QString& action_id, const QString& event);

private:
    void reset_protocol_state();
    void read_standard_output();
    void process_line(const QByteArray& line);
    void process_event(const nlohmann::json& message);
    void send_message(const nlohmann::json& message);
    void fail_runtime(const std::string& message);
    void close_active_stream(PushAudioStopReason reason);
    void update_status();

    PushAudioSink& audio_sink_;
    QProcess process_;
    QTimer handshake_timer_;
    DeviceAdapterRuntimeConfig config_;
    DeviceAdapterRuntimeStatus status_;
    DeviceAdapterTraceValidator validator_;
    QByteArray stdout_buffer_;
    std::map<std::string, std::string> devices_;
    std::optional<std::uint32_t> accepted_stream_id_;
    std::optional<std::uint32_t> rejected_stream_id_;
    bool stopping_ = false;
    bool failed_ = false;
};

}  // namespace ohmytypeless
