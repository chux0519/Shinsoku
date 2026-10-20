#include "platform/process/device_adapter_runtime.hpp"

#include <nlohmann/json.hpp>

#include <QFileInfo>
#include <QProcessEnvironment>
#include <QStringList>

#include <algorithm>
#include <array>
#include <stdexcept>

#ifndef SHINSOKU_VERSION
#define SHINSOKU_VERSION "development"
#endif

namespace ohmytypeless {

namespace {

constexpr int kHandshakeTimeoutMs = 3000;

bool environment_name_is_sensitive(const QString& name) {
    const QString upper = name.toUpper();
    constexpr std::array suffixes{"_API_KEY", "_TOKEN", "_SECRET", "_PASSWORD"};
    return upper == "OPENAI_API_KEY" || upper == "SONIOX_API_KEY" ||
           upper == "BAILIAN_API_KEY" ||
           std::any_of(suffixes.cbegin(), suffixes.cend(), [&](const char* suffix) {
               return upper.endsWith(suffix);
           });
}

PushAudioStopReason stop_reason_from_string(const std::string& reason) {
    if (reason == "completed") {
        return PushAudioStopReason::Completed;
    }
    if (reason == "cancelled") {
        return PushAudioStopReason::Cancelled;
    }
    if (reason == "disconnected") {
        return PushAudioStopReason::Disconnected;
    }
    return PushAudioStopReason::Error;
}

}  // namespace

DeviceAdapterRuntime::DeviceAdapterRuntime(PushAudioSink& audio_sink, QObject* parent)
    : QObject(parent), audio_sink_(audio_sink) {
    process_.setProcessChannelMode(QProcess::SeparateChannels);
    handshake_timer_.setSingleShot(true);

    connect(&process_, &QProcess::readyReadStandardOutput, this,
            &DeviceAdapterRuntime::read_standard_output);
    connect(&process_, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (!stopping_ && error != QProcess::Crashed) {
            fail_runtime("adapter process error: " + process_.errorString().toStdString());
        }
    });
    connect(&process_, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [this](int exit_code, QProcess::ExitStatus exit_status) {
        handshake_timer_.stop();
        close_active_stream(failed_ ? PushAudioStopReason::Error
                                    : PushAudioStopReason::Disconnected);
        status_.running = false;
        status_.ready = false;
        if (!stopping_ && !failed_) {
            status_.last_error = exit_status == QProcess::CrashExit
                                     ? "adapter process crashed"
                                     : "adapter process exited unexpectedly with code " +
                                           std::to_string(exit_code);
        }
        update_status();
    });
    connect(&handshake_timer_, &QTimer::timeout, this, [this]() {
        if (!status_.ready) {
            fail_runtime("adapter did not complete its handshake within 3 seconds");
        }
    });
}

DeviceAdapterRuntime::~DeviceAdapterRuntime() {
    stop();
}

void DeviceAdapterRuntime::apply(const DeviceAdapterRuntimeConfig& config) {
    stop();
    config_ = config;
    status_ = {};
    status_.enabled = config.enabled;
    if (!config.enabled) {
        update_status();
        return;
    }

    if (config.executable_path.empty() || !config.executable_path.is_absolute()) {
        throw std::invalid_argument("device adapter executable must be an absolute path");
    }
    const QFileInfo executable(QString::fromStdWString(config.executable_path.wstring()));
    if (!executable.exists() || !executable.isFile() || !executable.isExecutable()) {
        throw std::invalid_argument("device adapter path is not an executable file");
    }
    const QString canonical_path = executable.canonicalFilePath();
    if (canonical_path.isEmpty()) {
        throw std::invalid_argument("device adapter executable cannot be resolved");
    }

    reset_protocol_state();
    status_.enabled = true;
    status_.executable_path = canonical_path.toStdString();
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    for (const QString& name : environment.keys()) {
        if (environment_name_is_sensitive(name)) {
            environment.remove(name);
        }
    }
    process_.setProcessEnvironment(environment);
    process_.setProgram(canonical_path);
    QStringList arguments;
    for (const std::string& argument : config.arguments) {
        arguments.push_back(QString::fromStdString(argument));
    }
    process_.setArguments(arguments);
    process_.start(QIODevice::ReadWrite);
    if (!process_.waitForStarted(2000)) {
        const std::string error = process_.errorString().toStdString();
        status_.last_error = "could not start adapter: " + error;
        update_status();
        throw std::runtime_error(status_.last_error);
    }

    status_.running = true;
    update_status();
    send_message({
        {"type", "host.hello"},
        {"protocol_version", kDeviceAdapterProtocolVersion},
        {"host", {{"name", "Shinsoku"}, {"version", SHINSOKU_VERSION}}},
        {"limits",
         {{"maximum_line_bytes", kDeviceAdapterMaximumLineBytes},
          {"maximum_chunk_samples", kDeviceAdapterMaximumChunkSamples}}},
    });
    handshake_timer_.start(kHandshakeTimeoutMs);
}

void DeviceAdapterRuntime::stop() {
    handshake_timer_.stop();
    stopping_ = true;
    if (process_.state() != QProcess::NotRunning) {
        send_message({{"type", "adapter.shutdown"}});
        process_.waitForBytesWritten(100);
        if (!process_.waitForFinished(750)) {
            process_.terminate();
            if (!process_.waitForFinished(250)) {
                process_.kill();
                process_.waitForFinished(250);
            }
        }
    }
    close_active_stream(PushAudioStopReason::Disconnected);
    status_.running = false;
    status_.ready = false;
    stopping_ = false;
    update_status();
}

DeviceAdapterRuntimeStatus DeviceAdapterRuntime::status() const {
    return status_;
}

void DeviceAdapterRuntime::reset_protocol_state() {
    validator_ = DeviceAdapterTraceValidator();
    stdout_buffer_.clear();
    devices_.clear();
    accepted_stream_id_.reset();
    rejected_stream_id_.reset();
    stopping_ = false;
    failed_ = false;
}

void DeviceAdapterRuntime::read_standard_output() {
    stdout_buffer_.append(process_.readAllStandardOutput());
    while (true) {
        const qsizetype newline = stdout_buffer_.indexOf('\n');
        if (newline < 0) {
            if (stdout_buffer_.size() > static_cast<qsizetype>(kDeviceAdapterMaximumLineBytes)) {
                fail_runtime("adapter emitted an unterminated line larger than 16 KiB");
            }
            return;
        }
        QByteArray line = stdout_buffer_.left(newline);
        stdout_buffer_.remove(0, newline + 1);
        if (line.endsWith('\r')) {
            line.chop(1);
        }
        process_line(line);
        if (failed_) {
            return;
        }
    }
}

void DeviceAdapterRuntime::process_line(const QByteArray& line) {
    const std::size_t previous_errors = validator_.report().errors.size();
    validator_.accept_line(std::string_view(line.constData(), static_cast<std::size_t>(line.size())));
    if (validator_.report().errors.size() != previous_errors) {
        fail_runtime("adapter protocol violation: " + validator_.report().errors.back());
        return;
    }
    try {
        process_event(nlohmann::json::parse(line.constData(), line.constData() + line.size()));
    } catch (const nlohmann::json::exception& exception) {
        fail_runtime("could not process validated adapter event: " + std::string(exception.what()));
    }
}

void DeviceAdapterRuntime::process_event(const nlohmann::json& message) {
    const std::string type = message.at("type").get<std::string>();
    if (type == "adapter.hello") {
        const auto& report = validator_.report();
        status_.adapter_id = report.adapter_id;
        status_.adapter_name = report.adapter_name;
        status_.adapter_version = report.adapter_version;
        status_.capabilities = report.capabilities;
        status_.declared_permissions = report.declared_permissions;
        status_.ready = true;
        handshake_timer_.stop();
        update_status();
        send_message({{"type", "device.discover"}});
        return;
    }
    if (type == "device.found") {
        const auto& device = message.at("device");
        devices_[device.at("id").get<std::string>()] = device.at("name").get<std::string>();
        return;
    }
    if (type == "discovery.finished") {
        if (!devices_.empty()) {
            send_message({{"type", "device.connect"}, {"device_id", devices_.cbegin()->first}});
        }
        update_status();
        return;
    }
    if (type == "device.status") {
        const std::string device_id = message.at("device_id").get<std::string>();
        const std::string state = message.at("state").get<std::string>();
        if (state == "connected") {
            status_.connected_device_id = device_id;
            status_.connected_device_name = devices_.at(device_id);
        } else if (status_.connected_device_id == device_id) {
            status_.connected_device_id.clear();
            status_.connected_device_name.clear();
        }
        update_status();
        return;
    }
    if (type == "button") {
        emit button_event(QString::fromStdString(message.at("device_id").get<std::string>()),
                          QString::fromStdString(message.at("action_id").get<std::string>()),
                          QString::fromStdString(message.at("event").get<std::string>()));
        return;
    }
    if (type == "audio.start") {
        const std::uint32_t stream_id = message.at("stream_id").get<std::uint32_t>();
        const std::string device_id = message.at("device_id").get<std::string>();
        PushAudioStreamInfo stream{
            .source_id = status_.adapter_id + "/" + device_id,
            .source_name = status_.adapter_name + " / " + devices_.at(device_id),
            .source_kind = "device_adapter",
            .requested_profile_id = message.value("profile_id", std::string{}),
            .stream_id = stream_id,
        };
        std::string error;
        if (audio_sink_.on_push_audio_start(stream, &error)) {
            accepted_stream_id_ = stream_id;
            send_message({{"type", "audio.accepted"}, {"stream_id", stream_id}});
        } else {
            rejected_stream_id_ = stream_id;
            send_message({{"type", "audio.rejected"}, {"stream_id", stream_id}, {"reason", error}});
        }
        return;
    }
    if (type == "audio.chunk") {
        const std::uint32_t stream_id = message.at("stream_id").get<std::uint32_t>();
        if (accepted_stream_id_ != stream_id) {
            return;
        }
        const auto samples = decode_device_adapter_pcm16le_base64(
            message.at("pcm16le_base64").get_ref<const std::string&>());
        std::string error;
        if (!samples.has_value() || !audio_sink_.on_push_audio_samples(stream_id, *samples, &error)) {
            close_active_stream(PushAudioStopReason::Error);
            rejected_stream_id_ = stream_id;
            send_message({{"type", "audio.rejected"}, {"stream_id", stream_id}, {"reason", error}});
        }
        return;
    }
    if (type == "audio.stop") {
        const std::uint32_t stream_id = message.at("stream_id").get<std::uint32_t>();
        if (accepted_stream_id_ == stream_id) {
            audio_sink_.on_push_audio_stop(
                stream_id, stop_reason_from_string(message.at("reason").get<std::string>()));
            accepted_stream_id_.reset();
        }
        if (rejected_stream_id_ == stream_id) {
            rejected_stream_id_.reset();
        }
    }
}

void DeviceAdapterRuntime::send_message(const nlohmann::json& message) {
    if (process_.state() == QProcess::NotRunning) {
        return;
    }
    const std::string encoded = message.dump() + "\n";
    process_.write(encoded.data(), static_cast<qint64>(encoded.size()));
}

void DeviceAdapterRuntime::fail_runtime(const std::string& message) {
    if (failed_) {
        return;
    }
    failed_ = true;
    handshake_timer_.stop();
    status_.last_error = message;
    close_active_stream(PushAudioStopReason::Error);
    status_.running = false;
    status_.ready = false;
    update_status();
    if (process_.state() != QProcess::NotRunning) {
        process_.kill();
    }
}

void DeviceAdapterRuntime::close_active_stream(PushAudioStopReason reason) {
    if (accepted_stream_id_.has_value()) {
        audio_sink_.on_push_audio_stop(*accepted_stream_id_, reason);
        accepted_stream_id_.reset();
    }
    rejected_stream_id_.reset();
}

void DeviceAdapterRuntime::update_status() {
    emit status_changed();
}

}  // namespace ohmytypeless
