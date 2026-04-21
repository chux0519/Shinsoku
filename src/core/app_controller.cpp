#include "core/app_controller.hpp"

#include "core/backend/backend_factory.hpp"
#include "core/runtime_profile.hpp"
#include "core/task_types.hpp"
#include "platform/clipboard_service.hpp"
#include "platform/global_hotkey.hpp"
#include "platform/hotkey_names.hpp"
#include "platform/hud_presenter.hpp"
#include "platform/selection_service.hpp"
#include "ui/app_theme.hpp"
#include "ui/history_details_dialog.hpp"
#include "ui/history_window.hpp"
#include "ui/main_window.hpp"
#include "ui/meeting_transcription_window.hpp"
#include "ui/settings_window.hpp"

#include <QApplication>
#include <QDateTime>
#include <QDir>
#include <QMessageBox>
#include <QCheckBox>
#include <QtConcurrent/QtConcurrent>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <exception>
#include <QStringList>
#include <thread>

#ifdef Q_OS_MACOS
#include "platform/macos/macos_input_utils.hpp"
#endif

namespace ohmytypeless {

namespace {

constexpr std::size_t kHistoryPageSize = 50;
constexpr auto kSelectionCommandTapMax = std::chrono::milliseconds(350);
constexpr auto kSelectionCommandWindow = std::chrono::milliseconds(1200);

struct AudioAnalysis {
    bool has_speech = false;
    double speech_duration_seconds = 0.0;
    double speech_ratio = 0.0;
    double rms = 0.0;
};

float calculate_rms(std::span<const float> samples) {
    if (samples.empty()) {
        return 0.0f;
    }

    float sum_squares = 0.0f;
    for (float sample : samples) {
        sum_squares += sample * sample;
    }
    return std::sqrt(sum_squares / static_cast<float>(samples.size()));
}

float map_threshold_to_energy(float config_threshold) {
    const float t = std::clamp(config_threshold, 0.0f, 1.0f);
    return 0.001f * std::pow(100.0f, t);
}

AudioAnalysis analyze_audio(const std::vector<float>& samples, const VadConfig& config) {
    AudioAnalysis analysis;
    if (samples.empty()) {
        return analysis;
    }

    constexpr std::size_t kFrameMs = 20;
    const std::size_t frame_size = kFixedSampleRate * kFrameMs / 1000;
    const float threshold = map_threshold_to_energy(config.threshold);
    std::size_t speech_frames = 0;
    std::size_t total_frames = 0;
    float total_energy = 0.0f;

    for (std::size_t offset = 0; offset < samples.size(); offset += frame_size) {
        const std::size_t remaining = samples.size() - offset;
        const std::size_t frame_len = std::min(frame_size, remaining);
        const float rms = calculate_rms(std::span<const float>(samples.data() + offset, frame_len));
        total_energy += rms;
        ++total_frames;
        if (rms >= threshold) {
            ++speech_frames;
        }
    }

    analysis.rms = total_frames > 0 ? static_cast<double>(total_energy) / static_cast<double>(total_frames) : 0.0;
    analysis.speech_duration_seconds = static_cast<double>(speech_frames * kFrameMs) / 1000.0;
    analysis.speech_ratio = total_frames > 0 ? static_cast<double>(speech_frames) / static_cast<double>(total_frames) : 0.0;
    analysis.has_speech = analysis.speech_duration_seconds >= (static_cast<double>(config.min_speech_duration_ms) / 1000.0);
    return analysis;
}

bool should_skip_transcription(const AudioAnalysis& analysis, const VadConfig& config) {
    return config.enabled && !analysis.has_speech;
}

QString pretty_details(const HistoryEntry& entry) {
    nlohmann::json details = nlohmann::json::object();
    details["id"] = entry.id;
    details["created_at"] = entry.created_at;
    details["text"] = entry.text;
    if (entry.audio_path.has_value()) {
        details["audio_path"] = entry.audio_path->generic_string();
    }
    details["meta"] = entry.meta;
    return QString::fromStdString(details.dump(2));
}

QString display_path(const std::filesystem::path& path) {
    return QDir::cleanPath(QString::fromStdWString(path.generic_wstring()));
}

std::string streaming_model_name(const AppConfig& config) {
    if (config.pipeline.streaming.provider == "bailian") {
        return config.providers.bailian.model;
    }
    if (config.pipeline.streaming.provider == "soniox") {
        return config.providers.soniox.model;
    }
    return {};
}

std::string endpoint_provider_name(const EndpointConfig& endpoint) {
    if (endpoint.base_url.find("dashscope.aliyuncs.com") != std::string::npos ||
        endpoint.base_url.find("dashscope-intl.aliyuncs.com") != std::string::npos) {
        return "bailian";
    }
    return endpoint.provider.empty() ? "openai-compatible" : endpoint.provider;
}

nlohmann::json text_transform_diagnostics_json(const TextTransformDiagnostics& diagnostics) {
    return {
        {"provider", endpoint_provider_name(EndpointConfig{
                         .provider = diagnostics.provider,
                         .base_url = diagnostics.base_url,
                         .api_key = "",
                         .model = diagnostics.model,
                     })},
        {"base_url", diagnostics.base_url},
        {"url", diagnostics.url},
        {"model", diagnostics.model},
        {"request_format", diagnostics.request_format},
        {"http_status", diagnostics.http_status},
        {"wall_ms", diagnostics.wall_ms},
        {"curl_total_ms", diagnostics.curl_total_ms},
        {"curl_name_lookup_ms", diagnostics.curl_name_lookup_ms},
        {"curl_connect_ms", diagnostics.curl_connect_ms},
        {"curl_tls_handshake_ms", diagnostics.curl_tls_handshake_ms},
        {"curl_pretransfer_ms", diagnostics.curl_pretransfer_ms},
        {"curl_starttransfer_ms", diagnostics.curl_starttransfer_ms},
        {"request_bytes", diagnostics.request_bytes},
        {"response_bytes", diagnostics.response_bytes},
        {"user_content_chars", diagnostics.user_content_chars},
        {"system_prompt_chars", diagnostics.system_prompt_chars},
        {"output_chars", diagnostics.output_chars},
    };
}

AudioCaptureMode audio_capture_mode_from_config(const AppConfig& config) {
    return config.audio.capture_mode == "system" ? AudioCaptureMode::SystemLoopback : AudioCaptureMode::Microphone;
}

std::vector<std::pair<QString, QString>> profile_items_for_ui(const AppConfig& config) {
    std::vector<std::pair<QString, QString>> items;
    const auto core_items = profile_items(config);
    items.reserve(core_items.size());
    for (const auto& [id, name] : core_items) {
        items.emplace_back(QString::fromStdString(id), QString::fromStdString(name));
    }
    return items;
}

QString global_hotkey_unavailable_reason() {
#ifdef Q_OS_MACOS
    return macos_global_hotkey_permission_reason();
#else
    return "Global hotkeys are not available on this platform yet. Use the main window controls instead.";
#endif
}

QString wayland_hotkey_permission_reason() {
    return "Wayland hotkeys need read access to /dev/input/event*. Add your user to the input group or grant equivalent permissions, then restart the app.";
}

QString auto_paste_unavailable_reason() {
#ifdef Q_OS_MACOS
    return macos_auto_paste_permission_reason();
#else
    return "Auto paste to the focused app is not available on this platform yet.";
#endif
}

QString system_audio_unavailable_reason() {
    return "System audio capture is not available on this platform yet.";
}

QString selection_command_unavailable_reason(const SelectionService* selection) {
#ifdef Q_OS_MACOS
    if (selection != nullptr && selection->backend_name().contains("macos", Qt::CaseInsensitive)) {
        return macos_accessibility_permission_reason();
    }
#endif
    return "Selection command is not available on this platform yet.";
}

std::vector<std::byte> encode_pcm16(std::span<const float> samples) {
    std::vector<std::byte> bytes(samples.size() * sizeof(std::int16_t));
    auto* out = reinterpret_cast<std::int16_t*>(bytes.data());
    for (std::size_t i = 0; i < samples.size(); ++i) {
        const float clamped = std::clamp(samples[i], -1.0f, 1.0f);
        out[i] = static_cast<std::int16_t>(clamped * 32767.0f);
    }
    return bytes;
}

}  // namespace

void AppController::rebuild_runtime_config() {
    runtime_config_ = derive_runtime_config(config_);
}

AppController::AppController(MainWindow* window,
                             ClipboardService* clipboard,
                             AudioCaptureService* audio_capture,
                             SelectionService* selection,
                             GlobalHotkey* hotkey,
                             HudPresenter* hud,
                             QObject* parent)
    : QObject(parent),
      window_(window),
      clipboard_(clipboard),
      audio_capture_(audio_capture),
      selection_(selection),
      hotkey_(hotkey),
      hud_(hud),
      config_(load_config()),
      runtime_config_(config_),
      history_store_(std::make_unique<HistoryStore>(config_.history_db_path)),
      recording_store_(std::make_unique<RecordingStore>(config_.audio)),
      asr_backend_(make_asr_backend(runtime_config_)),
      streaming_asr_backend_(make_streaming_asr_backend(runtime_config_)),
      refine_backend_(make_refine_backend(runtime_config_)),
      transcription_watcher_(std::make_unique<QFutureWatcher<TranscriptionResult>>()),
      recorded_key_watcher_(std::make_unique<QFutureWatcher<RecordedKeyResult>>()) {
    selection_command_upgrade_timer_ = new QTimer(this);
    selection_command_upgrade_timer_->setSingleShot(true);
    connect(selection_command_upgrade_timer_, &QTimer::timeout, this, [this]() {
        if (state_ == SessionState::Recording && active_capture_mode_ == CaptureMode::Dictation) {
            stop_recording();
        }
    });
}

void AppController::initialize() {
    QString startup_warning;
    rebuild_runtime_config();
    QString capability_notice;
    enforce_platform_capabilities(&capability_notice);
    try {
        refresh_audio_devices();
    } catch (const std::exception& exception) {
        startup_warning = QString("Audio device enumeration failed: %1").arg(QString::fromUtf8(exception.what()));
        window_->settings_window()->set_status_text(startup_warning);
        hud_->show_error("Audio device enumeration failed");
    }
    load_history();
    sync_platform_capability_ui();

    window_->settings_window()->set_hold_key(QString::fromStdString(config_.hotkey.hold_key));
    window_->settings_window()->set_hands_free_chord_key(QString::fromStdString(config_.hotkey.hands_free_chord_key));
    window_->settings_window()->set_selection_command_trigger(QString::fromStdString(config_.hotkey.selection_command_trigger));
    window_->settings_window()->set_profiles(config_.profiles.items, QString::fromStdString(config_.profiles.active_profile_id));
    preview_profile_audio_devices_for_mode(QString::fromStdString(runtime_config_.audio.capture_mode));
    window_->settings_window()->set_save_recordings_enabled(config_.audio.save_recordings);
    window_->settings_window()->set_recordings_dir(display_path(config_.audio.recordings_dir));
    window_->settings_window()->set_rotation_mode(QString::fromStdString(config_.audio.rotation.mode));
    window_->settings_window()->set_max_files(static_cast<int>(config_.audio.rotation.max_files.value_or(50U)));
    window_->settings_window()->set_app_theme(QString::fromStdString(config_.appearance.app_theme));
    window_->settings_window()->set_tray_icon_theme(QString::fromStdString(config_.appearance.tray_icon_theme));
    window_->settings_window()->set_proxy_enabled(config_.network.proxy.enabled);
    window_->settings_window()->set_proxy_type(QString::fromStdString(config_.network.proxy.type));
    window_->settings_window()->set_proxy_host(QString::fromStdString(config_.network.proxy.host));
    window_->settings_window()->set_proxy_port(config_.network.proxy.port);
    window_->settings_window()->set_proxy_username(QString::fromStdString(config_.network.proxy.username));
    window_->settings_window()->set_proxy_password(QString::fromStdString(config_.network.proxy.password));
    window_->settings_window()->set_asr_provider(QString::fromStdString(config_.pipeline.asr.provider));
    window_->settings_window()->set_asr_base_url(QString::fromStdString(config_.pipeline.asr.base_url));
    window_->settings_window()->set_asr_api_key(QString::fromStdString(config_.pipeline.asr.api_key));
    window_->settings_window()->set_asr_model(QString::fromStdString(config_.pipeline.asr.model));
    window_->settings_window()->set_refine_provider(QString::fromStdString(config_.pipeline.refine.endpoint.provider));
    window_->settings_window()->set_refine_base_url(QString::fromStdString(config_.pipeline.refine.endpoint.base_url));
    window_->settings_window()->set_refine_api_key(QString::fromStdString(config_.pipeline.refine.endpoint.api_key));
    window_->settings_window()->set_refine_model(QString::fromStdString(config_.pipeline.refine.endpoint.model));
    window_->settings_window()->set_soniox_url(QString::fromStdString(config_.providers.soniox.url));
    window_->settings_window()->set_soniox_api_key(QString::fromStdString(config_.providers.soniox.api_key));
    window_->settings_window()->set_soniox_model(QString::fromStdString(config_.providers.soniox.model));
    window_->settings_window()->set_bailian_region(QString::fromStdString(config_.providers.bailian.region));
    window_->settings_window()->set_bailian_url(QString::fromStdString(config_.providers.bailian.url));
    window_->settings_window()->set_bailian_api_key(QString::fromStdString(config_.providers.bailian.api_key));
    window_->settings_window()->set_bailian_model(QString::fromStdString(config_.providers.bailian.model));
    window_->settings_window()->set_vad_enabled(config_.vad.enabled);
    window_->settings_window()->set_vad_threshold(config_.vad.threshold);
    window_->settings_window()->set_vad_min_speech_duration_ms(static_cast<int>(config_.vad.min_speech_duration_ms));
    window_->settings_window()->set_record_metadata_enabled(config_.observability.record_metadata);
    window_->settings_window()->set_record_timing_enabled(config_.observability.record_timing);
    window_->settings_window()->set_hud_enabled(config_.hud.enabled);
    window_->settings_window()->set_hud_bottom_margin(config_.hud.bottom_margin);
    window_->set_profiles(profile_items_for_ui(config_), QString::fromStdString(config_.profiles.active_profile_id));
    set_app_theme_preference(*qApp, QString::fromStdString(config_.appearance.app_theme));
    window_->set_tray_icon_theme(QString::fromStdString(config_.appearance.tray_icon_theme));

    hud_->apply_config(config_.hud);
    window_->set_session_state(state_);
    window_->set_status_text(
        QString("Ready. Hotkey: %1, Selection: %2").arg(hotkey_->backend_name(), selection_->backend_name()));
    window_->update_history(history_);
    window_->set_tray_available(true);
    window_->meeting_window()->set_profile_name(active_profile_name());
    window_->meeting_window()->set_session_state(SessionState::Idle);
    refresh_capture_mode_ui();

    connect(window_, &MainWindow::toggle_recording_requested, this, &AppController::toggle_recording);
    connect(window_, &MainWindow::arm_selection_command_requested, this, &AppController::arm_selection_command);
    connect(window_, &MainWindow::register_hotkey_requested, this, &AppController::apply_settings);
    connect(window_, &MainWindow::active_profile_changed_requested, this, &AppController::on_active_profile_changed);
    connect(window_, &MainWindow::show_history_requested, this, &AppController::show_history);
    connect(window_, &MainWindow::show_settings_requested, this, &AppController::show_settings);
    connect(window_, &MainWindow::quit_requested, this, &AppController::quit_application);
    connect(window_->settings_window(), &SettingsWindow::apply_clicked, this, &AppController::apply_settings);
    connect(window_->settings_window(), &SettingsWindow::profile_audio_capture_mode_changed, this,
            &AppController::preview_profile_audio_devices_for_mode);
    connect(window_->settings_window(), &SettingsWindow::record_hold_key_requested, this, &AppController::on_record_hold_key_requested);
    connect(window_->settings_window(),
            &SettingsWindow::record_hands_free_chord_requested,
            this,
            &AppController::on_record_hands_free_chord_requested);
    connect(window_->history_window(), &HistoryWindow::copy_entry_requested, this, &AppController::copy_history_entry);
    connect(window_->history_window(), &HistoryWindow::show_details_requested, this, &AppController::show_history_entry_details);
    connect(window_->history_window(), &HistoryWindow::delete_entry_requested, this, &AppController::delete_history_entry);
    connect(window_->history_window(), &HistoryWindow::load_older_requested, this, &AppController::load_older_history);
    connect(hotkey_, &GlobalHotkey::hold_started, this, &AppController::on_hold_started);
    connect(hotkey_, &GlobalHotkey::hold_stopped, this, &AppController::on_hold_stopped);
    connect(hotkey_, &GlobalHotkey::hands_free_enabled, this, &AppController::on_hands_free_enabled);
    connect(hotkey_, &GlobalHotkey::hands_free_disabled, this, &AppController::on_hands_free_disabled);
    connect(hotkey_, &GlobalHotkey::registration_failed, this, &AppController::on_hotkey_failed);
    connect(transcription_watcher_.get(), &QFutureWatcher<TranscriptionResult>::finished, this,
            &AppController::on_transcription_finished);
    connect(recorded_key_watcher_.get(), &QFutureWatcher<RecordedKeyResult>::finished, this, [this]() {
        finish_hotkey_capture(recorded_key_watcher_->result());
    });

    apply_settings();

    QStringList notices;
    if (!startup_warning.isEmpty()) {
        notices << startup_warning;
    }
    if (!capability_notice.isEmpty()) {
        notices << capability_notice;
    }
    if (!notices.isEmpty()) {
        const QString joined = notices.join('\n');
        window_->set_status_text(joined);
        window_->settings_window()->set_status_text(joined);
    }
}

void AppController::toggle_recording() {
    if (state_ == SessionState::Idle || state_ == SessionState::Error) {
        start_recording(SessionState::Recording);
    } else if (state_ == SessionState::Recording || state_ == SessionState::HandsFree) {
        stop_recording();
    }
}

void AppController::arm_selection_command() {
    if (state_ != SessionState::Idle && state_ != SessionState::Error) {
        return;
    }
    if (selection_ == nullptr || !selection_->supports_automatic_detection() || !selection_->supports_replacement()) {
        const QString status = "Selection command is not available on this platform yet.";
        window_->set_status_text(status);
        window_->settings_window()->set_status_text(status);
        hud_->show_error("Selection command unavailable");
        return;
    }
    if (uses_system_audio_capture()) {
        const QString status = "Selection command is unavailable while capturing system audio.";
        window_->set_status_text(status);
        window_->settings_window()->set_status_text(status);
        hud_->show_error("Selection command unavailable");
        return;
    }

    pending_capture_mode_ = CaptureMode::SelectionCommand;
    const QString status =
        "Selection command armed. Return to the target app, keep the text selected, then use the normal recording hotkey.";
    window_->set_status_text(status);
    window_->settings_window()->set_status_text(status);
    hud_->show_notice("Selection command armed");
}

void AppController::apply_settings() {
    const AppConfig defaults;

    config_.hotkey.hold_key = window_->settings_window()->hold_key().toStdString();
    config_.hotkey.hands_free_chord_key = window_->settings_window()->hands_free_chord_key().toStdString();
    config_.hotkey.selection_command_trigger = window_->settings_window()->selection_command_trigger().toStdString();
    config_.profiles.active_profile_id = window_->settings_window()->active_profile_id().toStdString();
    config_.profiles.items = window_->settings_window()->profiles();
    config_.audio.save_recordings = window_->settings_window()->save_recordings_enabled();
    if (!window_->settings_window()->recordings_dir().isEmpty()) {
        config_.audio.recordings_dir = std::filesystem::path(window_->settings_window()->recordings_dir().toStdWString());
    }
    config_.audio.rotation.mode = window_->settings_window()->rotation_mode().toStdString();
    config_.audio.rotation.max_files = static_cast<std::size_t>(window_->settings_window()->max_files());
    config_.appearance.app_theme = window_->settings_window()->app_theme().toStdString();
    config_.appearance.tray_icon_theme = window_->settings_window()->tray_icon_theme().toStdString();
    config_.network.proxy.enabled = window_->settings_window()->proxy_enabled();
    config_.network.proxy.type = window_->settings_window()->proxy_type().toStdString();
    config_.network.proxy.host = window_->settings_window()->proxy_host().toStdString();
    config_.network.proxy.port = window_->settings_window()->proxy_port();
    config_.network.proxy.username = window_->settings_window()->proxy_username().toStdString();
    config_.network.proxy.password = window_->settings_window()->proxy_password().toStdString();
    config_.pipeline.asr.provider = window_->settings_window()->asr_provider().toStdString();
    config_.pipeline.asr.base_url = window_->settings_window()->asr_base_url().toStdString();
    config_.pipeline.asr.api_key = window_->settings_window()->asr_api_key().toStdString();
    config_.pipeline.asr.model = window_->settings_window()->asr_model().toStdString();
    config_.pipeline.refine.endpoint.provider = window_->settings_window()->refine_provider().toStdString();
    config_.pipeline.refine.endpoint.base_url = window_->settings_window()->refine_base_url().toStdString();
    config_.pipeline.refine.endpoint.api_key = window_->settings_window()->refine_api_key().toStdString();
    config_.pipeline.refine.endpoint.model = window_->settings_window()->refine_model().toStdString();
    config_.providers.soniox.url = window_->settings_window()->soniox_url().toStdString();
    config_.providers.soniox.api_key = window_->settings_window()->soniox_api_key().toStdString();
    config_.providers.soniox.model = window_->settings_window()->soniox_model().toStdString();
    config_.providers.bailian.region = window_->settings_window()->bailian_region().toStdString();
    config_.providers.bailian.url = window_->settings_window()->bailian_url().toStdString();
    config_.providers.bailian.api_key = window_->settings_window()->bailian_api_key().toStdString();
    config_.providers.bailian.model = window_->settings_window()->bailian_model().toStdString();
    config_.vad.enabled = window_->settings_window()->vad_enabled();
    config_.vad.threshold = static_cast<float>(window_->settings_window()->vad_threshold());
    config_.vad.min_speech_duration_ms = static_cast<std::uint32_t>(window_->settings_window()->vad_min_speech_duration_ms());
    config_.observability.record_metadata = window_->settings_window()->record_metadata_enabled();
    config_.observability.record_timing = window_->settings_window()->record_timing_enabled();
    config_.hud.enabled = window_->settings_window()->hud_enabled();
    config_.hud.bottom_margin = window_->settings_window()->hud_bottom_margin();

    if (config_.pipeline.asr.base_url.empty()) {
        config_.pipeline.asr.base_url = defaults.pipeline.asr.base_url;
    }
    if (config_.pipeline.asr.model.empty()) {
        config_.pipeline.asr.model = defaults.pipeline.asr.model;
    }
    if (config_.pipeline.refine.endpoint.model.empty()) {
        config_.pipeline.refine.endpoint.model = defaults.pipeline.refine.endpoint.model;
    }
    if (config_.providers.soniox.url.empty()) {
        config_.providers.soniox.url = defaults.providers.soniox.url;
    }
    if (config_.providers.soniox.model.empty()) {
        config_.providers.soniox.model = defaults.providers.soniox.model;
    }
    if (config_.providers.bailian.region.empty()) {
        config_.providers.bailian.region = defaults.providers.bailian.region;
    }
    if (config_.providers.bailian.url.empty()) {
        config_.providers.bailian.url = defaults.providers.bailian.url;
    }
    if (config_.providers.bailian.model.empty()) {
        config_.providers.bailian.model = defaults.providers.bailian.model;
    }

    rebuild_runtime_config();
    QString capability_notice;
    enforce_platform_capabilities(&capability_notice);
    sync_platform_capability_ui();

    refresh_audio_devices();
    set_app_theme_preference(*qApp, QString::fromStdString(config_.appearance.app_theme));
    window_->set_tray_icon_theme(QString::fromStdString(config_.appearance.tray_icon_theme));
    preview_profile_audio_devices_for_mode(QString::fromStdString(runtime_config_.audio.capture_mode));
    refresh_capture_mode_ui();

    recording_store_ = std::make_unique<RecordingStore>(config_.audio);
    asr_backend_ = make_asr_backend(runtime_config_);
    streaming_asr_backend_ = make_streaming_asr_backend(runtime_config_);
    refine_backend_ = make_refine_backend(runtime_config_);
    hud_->apply_config(config_.hud);
    save_config(config_);
    window_->set_profiles(profile_items_for_ui(config_), QString::fromStdString(config_.profiles.active_profile_id));
    window_->settings_window()->set_profiles(config_.profiles.items, QString::fromStdString(config_.profiles.active_profile_id));
    preview_profile_audio_devices_for_mode(QString::fromStdString(runtime_config_.audio.capture_mode));
    window_->set_hotkey_passthrough_keys(hotkey_->hold_key_name(), hotkey_->chord_key_name());

    if (!hotkey_->supports_global_hotkeys()) {
        const QString status = capability_notice.isEmpty() ? global_hotkey_unavailable_reason() : capability_notice;
        window_->set_status_text(status);
        window_->settings_window()->set_status_text(status);
        hud_->show_notice("Settings applied");
        return;
    }

    if (hotkey_->register_hotkeys(QString::fromStdString(config_.hotkey.hold_key),
                                  QString::fromStdString(config_.hotkey.hands_free_chord_key))) {
        const QString status = QString("Settings applied. Hold: %1, chord: %2")
                                   .arg(QString::fromStdString(config_.hotkey.hold_key),
                                        QString::fromStdString(config_.hotkey.hands_free_chord_key));
        if (!capability_notice.isEmpty()) {
            window_->settings_window()->set_status_text(capability_notice);
        }
        window_->set_status_text(status);
        hud_->show_notice(status);
    }
}

void AppController::show_history() {
    window_->history_window()->show();
    window_->history_window()->raise();
    window_->history_window()->activateWindow();
}

void AppController::show_settings() {
    window_->settings_window()->show();
    window_->settings_window()->raise();
    window_->settings_window()->activateWindow();
}

void AppController::on_record_hold_key_requested() {
    capture_hotkey_async(RecordedKeyResult::Target::HoldKey);
}

void AppController::on_record_hands_free_chord_requested() {
    capture_hotkey_async(RecordedKeyResult::Target::HandsFreeChord);
}

void AppController::on_active_profile_changed(const QString& profile_id) {
    if (profile_id.trimmed().isEmpty()) {
        return;
    }

    const auto profile_it = std::find_if(config_.profiles.items.begin(),
                                         config_.profiles.items.end(),
                                         [&](const ProfileConfig& profile) {
                                             return profile.id == profile_id.toStdString();
                                         });
    if (profile_it == config_.profiles.items.end()) {
        return;
    }

    config_.profiles.active_profile_id = profile_id.toStdString();
    rebuild_runtime_config();
    QString capability_notice;
    enforce_platform_capabilities(&capability_notice);
    sync_platform_capability_ui();
    asr_backend_ = make_asr_backend(runtime_config_);
    streaming_asr_backend_ = make_streaming_asr_backend(runtime_config_);
    refine_backend_ = make_refine_backend(runtime_config_);
    save_config(config_);
    window_->settings_window()->set_profiles(config_.profiles.items, profile_id);
    refresh_audio_devices();
    preview_profile_audio_devices_for_mode(QString::fromStdString(runtime_config_.audio.capture_mode));
    refresh_capture_mode_ui();
    const auto active_profile_it = std::find_if(config_.profiles.items.begin(),
                                                config_.profiles.items.end(),
                                                [&](const ProfileConfig& profile) {
                                                    return profile.id == config_.profiles.active_profile_id;
                                                });
    const QString profile_name = active_profile_it != config_.profiles.items.end() ? QString::fromStdString(active_profile_it->name)
                                                                                    : profile_id;
    const QString input_source = runtime_config_.audio.capture_mode == "system" ? "System Audio (Loopback)" : "Microphone";
    const QString status = QString("Active profile: %1\nInput Source: %2").arg(profile_name, input_source);
    window_->set_status_text(capability_notice.isEmpty() ? status : QString("%1\n%2").arg(status, capability_notice));
    window_->meeting_window()->set_profile_name(profile_name);
}

void AppController::quit_application() {
    if (shutting_down_) {
        return;
    }
    shutting_down_ = true;
    if (selection_command_upgrade_timer_ != nullptr) {
        selection_command_upgrade_timer_->stop();
    }
    hud_->hide();
    window_->set_tray_available(false);
    window_->meeting_window()->hide();
    window_->history_window()->hide();
    window_->settings_window()->hide();
    window_->hide();

    QTimer::singleShot(0, this, [this]() {
        hotkey_->unregister_hotkey();
        if (state_ == SessionState::Recording || state_ == SessionState::HandsFree) {
            stop_recording();
            return;
        }
        if ((audio_capture_ != nullptr && audio_capture_->is_recording()) || streaming_session_ != nullptr) {
            discard_active_recording_for_shutdown();
        }

        if (transcription_watcher_->isRunning()) {
            return;
        }

        QApplication::quit();
    });
}

void AppController::on_hold_started() {
    if (hotkeys_temporarily_suspended_) {
        return;
    }
    if (!uses_system_audio_capture() && uses_double_press_selection_command() && state_ == SessionState::Recording &&
        active_capture_mode_ == CaptureMode::Dictation &&
        selection_command_upgrade_timer_ != nullptr && selection_command_upgrade_timer_->isActive()) {
        selection_command_upgrade_timer_->stop();
        // Double-press upgrade should only succeed when a real selection exists.
        // Clipboard-copy fallback can produce false positives on Wayland even
        // when the target app has no active selection. On macOS, however,
        // Electron/WebView editors such as VS Code often fail if we probe the
        // selection at the instant of the second key press. Defer macOS capture
        // until stop_recording(), where the existing selection-command path can
        // use AX first and then the guarded clipboard fallback.
        if (selection_->backend_name().startsWith("macos/")) {
            active_capture_mode_ = CaptureMode::SelectionCommand;
            captured_selection_text_.reset();
            pending_selection_debug_info_ = "macOS selection capture deferred until recording stops.";
            set_state(SessionState::Recording, "Listening for selected-text command.");
            hud_->show_recording(true);
            return;
        }

        const SelectionCaptureResult selection = selection_->capture_selection(false);
        pending_selection_debug_info_ = selection.debug_info;
        if (selection.success && !selection.selected_text.trimmed().isEmpty()) {
            active_capture_mode_ = CaptureMode::SelectionCommand;
            captured_selection_text_ = selection.selected_text;
            set_state(SessionState::Recording, "Listening for selected-text command.");
            hud_->show_recording(true);
            return;
        }

        selection_command_upgrade_timer_->start(static_cast<int>(kSelectionCommandWindow.count()));
        hud_->show_error("No selected text captured");
        return;
    }
    start_recording(SessionState::Recording);
}

void AppController::on_hold_stopped() {
    if (hotkeys_temporarily_suspended_) {
        return;
    }
    if (state_ == SessionState::Recording) {
        if (!uses_system_audio_capture() && uses_double_press_selection_command() && active_capture_mode_ == CaptureMode::Dictation &&
            selection_command_upgrade_timer_ != nullptr) {
            const auto elapsed =
                std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - recording_started_at_);
            if (elapsed <= kSelectionCommandTapMax || selection_command_upgrade_timer_->isActive()) {
                selection_command_upgrade_timer_->start(static_cast<int>(kSelectionCommandWindow.count()));
                return;
            }
        }
        stop_recording();
    }
}

void AppController::on_hands_free_enabled() {
    if (hotkeys_temporarily_suspended_) {
        return;
    }
    if (state_ == SessionState::Recording) {
        set_state(SessionState::HandsFree, "Hands-free recording.");
        hud_->show_recording();
    }
}

void AppController::on_hands_free_disabled() {
    if (hotkeys_temporarily_suspended_) {
        return;
    }
    if (state_ == SessionState::HandsFree) {
        stop_recording();
    }
}

void AppController::on_hotkey_failed(const QString& reason) {
    window_->settings_window()->set_status_text(reason);
    set_state(SessionState::Error, reason);
    hud_->show_error(reason);
}

void AppController::capture_hotkey_async(RecordedKeyResult::Target target) {
    if (recorded_key_watcher_ != nullptr && recorded_key_watcher_->isRunning()) {
        window_->settings_window()->set_status_text("A key capture is already in progress.");
        return;
    }
    if (hotkey_ == nullptr || !hotkey_->supports_key_capture()) {
        window_->settings_window()->set_status_text("Key capture is not available on this platform/backend.");
        return;
    }
    if (state_ == SessionState::Recording || state_ == SessionState::HandsFree || state_ == SessionState::Transcribing) {
        window_->settings_window()->set_status_text("Stop the current recording before capturing a new hotkey.");
        return;
    }

    hotkeys_temporarily_suspended_ = true;
    hotkey_->unregister_hotkey();
    if (target == RecordedKeyResult::Target::HoldKey) {
        window_->settings_window()->set_recording_hold_key(true);
    } else {
        window_->settings_window()->set_recording_hands_free_chord(true);
    }

    recorded_key_watcher_->setFuture(QtConcurrent::run([this, target]() {
        RecordedKeyResult result;
        result.target = target;
        if (hotkey_ == nullptr) {
            result.error_text = "Hotkey backend is unavailable.";
            return result;
        }

        QString error_message;
        result.key_name = hotkey_->capture_next_key(5000, &error_message);
        result.error_text = error_message;
        return result;
    }));
}

void AppController::finish_hotkey_capture(const RecordedKeyResult& result) {
    if (result.target == RecordedKeyResult::Target::HoldKey) {
        window_->settings_window()->set_recording_hold_key(false);
    } else {
        window_->settings_window()->set_recording_hands_free_chord(false);
    }

    if (!result.key_name.isEmpty()) {
        const QString display_name = display_hotkey_name(result.key_name);
        if (result.target == RecordedKeyResult::Target::HoldKey) {
            window_->settings_window()->apply_recorded_hold_key(result.key_name);
            window_->settings_window()->set_status_text(
                QString("Captured Hold Key: %1 (%2). Click Apply to save it.").arg(display_name, result.key_name));
        } else {
            window_->settings_window()->apply_recorded_hands_free_chord(result.key_name);
            window_->settings_window()->set_status_text(
                QString("Captured Hands-free Chord: %1 (%2). Click Apply to save it.").arg(display_name, result.key_name));
        }
    } else if (!result.error_text.isEmpty()) {
        window_->settings_window()->set_status_text(QString("Key capture failed: %1").arg(result.error_text));
    } else {
        window_->settings_window()->set_status_text("Key capture failed.");
    }

    hotkeys_temporarily_suspended_ = false;
    if (hotkey_ != nullptr && hotkey_->supports_global_hotkeys()) {
        hotkey_->register_hotkeys(QString::fromStdString(config_.hotkey.hold_key),
                                  QString::fromStdString(config_.hotkey.hands_free_chord_key));
    }
}

void AppController::copy_history_entry(qint64 id) {
    const auto entry = history_store_->get_entry(id);
    if (!entry.has_value()) {
        return;
    }

    clipboard_->copy_text(QString::fromStdString(entry->text));
    window_->set_status_text("Copied history entry.");
    hud_->show_notice("Copied");
}

void AppController::show_history_entry_details(qint64 id) {
    const auto entry = history_store_->get_entry(id);
    if (!entry.has_value()) {
        return;
    }

    auto* dialog = new HistoryDetailsDialog(window_->history_window());
    dialog->setAttribute(Qt::WA_DeleteOnClose, true);
    dialog->set_entry(
        QString("Structured metadata for entry %1.").arg(entry->id),
        pretty_details(*entry));
    dialog->open();
}

void AppController::delete_history_entry(qint64 id, bool delete_audio_if_present) {
    QMessageBox confirm(window_->history_window());
    confirm.setWindowTitle("Delete History Entry");
    confirm.setIcon(QMessageBox::Warning);
    confirm.setText("Delete this history entry?");
    confirm.setInformativeText("This cannot be undone.");
    confirm.setStandardButtons(QMessageBox::Cancel | QMessageBox::Ok);
    confirm.setDefaultButton(QMessageBox::Cancel);

    QCheckBox* delete_audio_box = nullptr;
    if (delete_audio_if_present) {
        delete_audio_box = new QCheckBox("Also delete the saved recording file", &confirm);
        confirm.setCheckBox(delete_audio_box);
    }

    if (confirm.exec() != QMessageBox::Ok) {
        return;
    }

    if (delete_audio_box != nullptr && delete_audio_box->isChecked()) {
        if (const auto entry = history_store_->get_entry(id); entry.has_value() && entry->audio_path.has_value()) {
            std::error_code error;
            std::filesystem::remove(*entry->audio_path, error);
        }
    }

    history_store_->delete_entry(id);
    load_history();
}

void AppController::load_older_history() {
    if (!oldest_loaded_history_id_.has_value()) {
        return;
    }

    const std::vector<HistoryEntry> older = history_store_->list_before_id(*oldest_loaded_history_id_, kHistoryPageSize);
    if (older.empty()) {
        window_->history_window()->set_load_older_visible(false);
        return;
    }

    oldest_loaded_history_id_ = older.back().id;
    history_.insert(history_.end(), older.begin(), older.end());
    window_->history_window()->append_entries(older);
    window_->history_window()->set_load_older_visible(older.size() == kHistoryPageSize);
}

void AppController::start_recording(SessionState mode) {
    if (state_ != SessionState::Idle && state_ != SessionState::Error) {
        return;
    }

    try {
        clipboard_->begin_paste_session();
        active_capture_mode_ = pending_capture_mode_;
        pending_capture_mode_ = CaptureMode::Dictation;
        recording_started_at_ = std::chrono::steady_clock::now();
        captured_selection_text_.reset();
        pending_selection_debug_info_.clear();
        const bool forced_selection_command = active_capture_mode_ == CaptureMode::SelectionCommand;
        if (forced_selection_command &&
            (selection_ == nullptr || !selection_->supports_automatic_detection() || !selection_->supports_replacement())) {
            clipboard_->clear_paste_session();
            active_capture_mode_ = CaptureMode::Dictation;
            pending_capture_mode_ = CaptureMode::Dictation;
            on_hotkey_failed(selection_command_unavailable_reason(selection_));
            return;
        }
        if (forced_selection_command) {
            const SelectionCaptureResult selection = selection_->capture_selection(true);
            pending_selection_debug_info_ = selection.debug_info;
            if (selection.success) {
                active_capture_mode_ = CaptureMode::SelectionCommand;
                captured_selection_text_ = selection.selected_text;
            }
        }
        if (forced_selection_command &&
            (!captured_selection_text_.has_value() || captured_selection_text_->trimmed().isEmpty())) {
            clipboard_->clear_paste_session();
            active_capture_mode_ = CaptureMode::Dictation;
            const QString status = pending_selection_debug_info_.isEmpty()
                                       ? "No selected text captured."
                                       : QString("No selected text captured.\n%1").arg(pending_selection_debug_info_);
            set_state(SessionState::Error, status);
            window_->settings_window()->set_status_text(status);
            hud_->show_error("No selected text captured");
            return;
        }
        const std::string device_id =
            runtime_config_.audio.capture_mode == "system" ? std::string{} : runtime_config_.audio.input_device_id;
        audio_capture_->start(runtime_config_.audio.sample_rate,
                              runtime_config_.audio.channels,
                              device_id,
                              audio_capture_mode_from_config(runtime_config_));
        if (should_use_streaming_dictation()) {
            start_streaming_dictation();
        }
        const QString status = active_capture_mode_ == CaptureMode::SelectionCommand
                                   ? "Listening for selected-text command."
                                   : (mode == SessionState::HandsFree ? "Hands-free recording." : "Recording started.");
        set_state(mode, status);
        hud_->show_recording(active_capture_mode_ == CaptureMode::SelectionCommand);
        if (should_use_live_caption_window()) {
            window_->meeting_window()->show();
            window_->meeting_window()->raise();
            window_->meeting_window()->activateWindow();
            window_->meeting_window()->set_session_state(mode);
            window_->meeting_window()->clear_live_text();
        }
    } catch (const std::exception& exception) {
        active_capture_mode_ = CaptureMode::Dictation;
        captured_selection_text_.reset();
        pending_selection_debug_info_.clear();
        pending_capture_mode_ = CaptureMode::Dictation;
        on_hotkey_failed(QString::fromUtf8(exception.what()));
    }
}

void AppController::stop_recording() {
    if (state_ != SessionState::Recording && state_ != SessionState::HandsFree) {
        return;
    }

    if (selection_command_upgrade_timer_ != nullptr) {
        selection_command_upgrade_timer_->stop();
    }

    if (should_use_live_caption_window()) {
        set_state(SessionState::Idle, "Live caption stopped.");
        hud_->hide();
        window_->meeting_window()->set_session_state(SessionState::Idle);
    } else {
        set_state(SessionState::Transcribing, "Recording stopped. Processing local audio.");
        hud_->show_transcribing();
    }

    try {
        const std::vector<float> samples = audio_capture_->stop();
        const AudioAnalysis analysis = analyze_audio(samples, config_.vad);
        if (should_skip_transcription(analysis, config_.vad)) {
            if (streaming_session_ != nullptr) {
                if (streaming_pump_cancel_flag_) {
                    streaming_pump_cancel_flag_->store(true);
                }
                if (streaming_pump_thread_.joinable()) {
                    streaming_pump_thread_.join();
                }
                if (streaming_connect_thread_.joinable()) {
                    streaming_connect_thread_.join();
                }
                streaming_session_->cancel();
                streaming_session_.reset();
                streaming_active_ = false;
            }
            set_state(SessionState::Idle, "No speech detected.");
            hud_->show_notice("No speech detected");
            clipboard_->clear_paste_session();
            active_capture_mode_ = CaptureMode::Dictation;
            captured_selection_text_.reset();
            pending_selection_debug_info_.clear();
            return;
        }

        const auto audio_path = recording_store_->save_recording(samples);
        if (streaming_session_ != nullptr) {
            stop_streaming_dictation(samples, audio_path);
            return;
        }
        SelectionCaptureResult selection;
        if (captured_selection_text_.has_value()) {
            selection.success = true;
            selection.selected_text = *captured_selection_text_;
            selection.debug_info = pending_selection_debug_info_;
        } else {
            const bool forced_selection_command = active_capture_mode_ == CaptureMode::SelectionCommand;
            if (forced_selection_command) {
                selection = selection_->capture_selection(true);
                pending_selection_debug_info_ = selection.debug_info;
            } else {
                pending_selection_debug_info_.clear();
            }
        }

        const bool forced_selection_command = active_capture_mode_ == CaptureMode::SelectionCommand;
        if (selection.success) {
            captured_selection_text_.reset();
            active_capture_mode_ = CaptureMode::SelectionCommand;
            TextTask task;
            task.mode = CaptureMode::SelectionCommand;
            task.selected_text = selection.selected_text.toStdString();
            transcribe_selection_command_async(std::move(task), samples, audio_path);
        } else if (forced_selection_command) {
            captured_selection_text_.reset();
            active_capture_mode_ = CaptureMode::SelectionCommand;
            const QString status = selection.debug_info.isEmpty()
                                       ? "No selected text captured."
                                       : QString("No selected text captured.\n%1").arg(selection.debug_info);
            set_state(SessionState::Error, status);
            window_->settings_window()->set_status_text(status);
            hud_->show_error("No selected text captured");
            clipboard_->clear_paste_session();
            active_capture_mode_ = CaptureMode::Dictation;
            return;
        } else {
            captured_selection_text_.reset();
            active_capture_mode_ = CaptureMode::Dictation;
            transcribe_async(samples, audio_path);
        }
    } catch (const std::exception& exception) {
        active_capture_mode_ = CaptureMode::Dictation;
        captured_selection_text_.reset();
        on_hotkey_failed(QString::fromUtf8(exception.what()));
    }
}

void AppController::set_state(SessionState state, const QString& status) {
    state_ = state;
    window_->set_session_state(state_);
    window_->set_status_text(status);
}

bool AppController::uses_double_press_selection_command() const {
    return config_.hotkey.selection_command_trigger == "double_press_hold" && selection_ != nullptr &&
           selection_->supports_automatic_detection() && selection_->supports_replacement();
}

bool AppController::uses_system_audio_capture() const {
    return runtime_config_.audio.capture_mode == "system";
}

bool AppController::active_profile_is_live_caption() const {
    return active_profile_uses_system_audio(config_);
}

bool AppController::should_use_live_caption_window() const {
    return uses_system_audio_capture() || active_profile_is_live_caption();
}

QString AppController::active_profile_name() const {
    return QString::fromStdString(active_profile_display_name(config_));
}

void AppController::enforce_platform_capabilities(QString* notice) {
    QStringList notes;
    auto profile_it = std::find_if(config_.profiles.items.begin(),
                                   config_.profiles.items.end(),
                                   [&](const ProfileConfig& profile) {
                                       return profile.id == config_.profiles.active_profile_id;
                                   });

    if (runtime_config_.audio.capture_mode == "system" &&
        profile_it != config_.profiles.items.end() &&
        (audio_capture_ == nullptr || !audio_capture_->supports_capture_mode(AudioCaptureMode::SystemLoopback))) {
        profile_it->capture.input_source = "microphone";
        notes << system_audio_unavailable_reason() + " Switched back to microphone capture.";
    }

    if (runtime_config_.output.paste_to_focused_window &&
        profile_it != config_.profiles.items.end() &&
        (clipboard_ == nullptr || !clipboard_->supports_auto_paste())) {
        profile_it->output.paste_to_focused_window = false;
        notes << auto_paste_unavailable_reason();
    }

    rebuild_runtime_config();

    if (notice != nullptr) {
        *notice = notes.join('\n');
    }
}

void AppController::sync_platform_capability_ui() {
    QString hotkey_reason;
    const bool hotkeys_available = hotkey_ != nullptr && hotkey_->supports_global_hotkeys();
    if (hotkey_ != nullptr && !hotkeys_available) {
        const QString backend_name = hotkey_->backend_name();
        hotkey_reason = backend_name.contains("wayland", Qt::CaseInsensitive) ? wayland_hotkey_permission_reason()
                                                                               : global_hotkey_unavailable_reason();
    }
    window_->settings_window()->set_global_hotkeys_available(hotkeys_available, hotkey_reason);
    window_->settings_window()->set_auto_paste_available(
        clipboard_ != nullptr && clipboard_->supports_auto_paste(),
        clipboard_ != nullptr && !clipboard_->supports_auto_paste() ? auto_paste_unavailable_reason() : QString());
    window_->settings_window()->set_system_audio_available(
        audio_capture_ != nullptr && audio_capture_->supports_capture_mode(AudioCaptureMode::SystemLoopback),
        audio_capture_ != nullptr && !audio_capture_->supports_capture_mode(AudioCaptureMode::SystemLoopback)
            ? system_audio_unavailable_reason()
            : QString());
}

void AppController::refresh_capture_mode_ui() {
    const bool selection_backend_ready = selection_ != nullptr && selection_->supports_automatic_detection() &&
                                         selection_->supports_replacement();
    const bool selection_available = selection_backend_ready && !uses_system_audio_capture() && !active_profile_is_live_caption();
    QString reason;
    if (!selection_backend_ready) {
        reason = selection_command_unavailable_reason(selection_);
    } else if (uses_system_audio_capture()) {
        reason = "Selection command requires microphone capture. System audio mode is intended for live caption workflows.";
    } else if (active_profile_is_live_caption()) {
        reason = "Live caption profiles use the dedicated live caption window instead of selection-command workflows.";
    }
    window_->set_selection_command_available(selection_available, reason);
    window_->meeting_window()->set_profile_name(active_profile_name());
}

bool AppController::should_use_streaming_dictation() const {
    if (!runtime_config_.pipeline.streaming.enabled || streaming_asr_backend_ == nullptr) {
        return false;
    }

    if (active_capture_mode_ == CaptureMode::Dictation) {
        return true;
    }

    return active_capture_mode_ == CaptureMode::SelectionCommand && captured_selection_text_.has_value() &&
           !captured_selection_text_->trimmed().isEmpty();
}

void AppController::start_streaming_dictation() {
    streaming_session_ = streaming_asr_backend_->create_session();
    if (!streaming_session_) {
        throw std::runtime_error("streaming backend session creation failed");
    }

    streaming_pump_cancel_flag_ = std::make_shared<std::atomic_bool>(false);
    streaming_samples_sent_ = 0;
    streaming_chunk_count_ = 0;
    streaming_partial_update_count_ = 0;
    streaming_final_update_count_ = 0;
    streaming_started_at_ = std::chrono::steady_clock::now();
    streaming_ready_at_.reset();
    {
        std::lock_guard lock(streaming_mutex_);
        streaming_partial_text_.clear();
        streaming_final_text_.clear();
        streaming_error_text_.clear();
        streaming_closed_ = false;
        streaming_session_ready_ = false;
    }
    streaming_active_ = true;
    const bool live_caption_active = should_use_live_caption_window();

    StreamingAsrCallbacks callbacks;
    callbacks.on_session_started = [this]() {
        {
            std::lock_guard lock(streaming_mutex_);
            streaming_session_ready_ = true;
        }
        streaming_ready_at_ = std::chrono::steady_clock::now();
        streaming_condition_.notify_all();
    };
    callbacks.on_partial_text = [this, live_caption_active](std::string text) {
        const QString partial = QString::fromStdString(std::move(text));
        {
            std::lock_guard lock(streaming_mutex_);
            streaming_partial_text_ = partial;
            ++streaming_partial_update_count_;
        }
        QMetaObject::invokeMethod(
            window_,
            [window = window_, partial]() {
                window->set_status_text(partial.isEmpty() ? "Streaming dictation..." : partial);
            },
            Qt::QueuedConnection);
        if (live_caption_active) {
            QMetaObject::invokeMethod(
                window_->meeting_window(),
                [meeting_window = window_->meeting_window(), partial]() {
                    meeting_window->set_live_text(partial);
                },
                Qt::QueuedConnection);
        }
    };
    callbacks.on_final_text = [this](std::string text) {
        std::lock_guard lock(streaming_mutex_);
        streaming_final_text_ = QString::fromStdString(std::move(text));
        ++streaming_final_update_count_;
    };
    callbacks.on_error = [this](std::string error) {
        const QString error_text = QString::fromStdString(std::move(error));
        {
            std::lock_guard lock(streaming_mutex_);
            streaming_error_text_ = error_text;
        }
        QMetaObject::invokeMethod(
            window_,
            [window = window_, error_text]() {
                window->set_status_text(QString("Streaming error: %1").arg(error_text));
            },
            Qt::QueuedConnection);
        QMetaObject::invokeMethod(
            window_->settings_window(),
            [settings = window_->settings_window(), error_text]() {
                settings->set_status_text(QString("Streaming error: %1").arg(error_text));
            },
            Qt::QueuedConnection);
        QMetaObject::invokeMethod(
            window_,
            [hud = hud_, error_text]() {
                hud->show_error(error_text);
            },
            Qt::QueuedConnection);
        streaming_condition_.notify_all();
    };
    callbacks.on_session_closed = [this]() {
        {
            std::lock_guard lock(streaming_mutex_);
            streaming_closed_ = true;
        }
        streaming_condition_.notify_all();
    };

    const StreamingAsrStartOptions start_options{
        .audio_format = StreamingAudioFormat{
            .encoding = StreamingAudioEncoding::Pcm16Le,
            .sample_rate_hz = runtime_config_.audio.sample_rate,
            .channel_count = static_cast<std::uint16_t>(runtime_config_.audio.channels),
        },
        .language = runtime_config_.pipeline.streaming.language.empty()
                        ? std::nullopt
                        : std::optional<std::string>(runtime_config_.pipeline.streaming.language),
        .emit_partial_results = true,
    };

    streaming_connect_thread_ = std::thread([this, start_options, callbacks = std::move(callbacks)]() mutable {
        if (streaming_session_ != nullptr) {
            streaming_session_->start(start_options, std::move(callbacks));
        }
    });

    streaming_pump_thread_ = std::thread([this, cancel_flag = streaming_pump_cancel_flag_]() {
        while (!cancel_flag->load()) {
            bool ready = false;
            {
                std::lock_guard lock(streaming_mutex_);
                ready = streaming_session_ready_;
            }
            if (!ready) {
                std::this_thread::sleep_for(std::chrono::milliseconds(20));
                continue;
            }
            const std::vector<float> chunk = audio_capture_->take_pending_samples();
            if (!chunk.empty() && streaming_session_ != nullptr) {
                std::vector<std::byte> bytes = encode_pcm16(chunk);
                streaming_session_->push_audio(bytes);
                {
                    std::lock_guard lock(streaming_mutex_);
                    streaming_samples_sent_ += chunk.size();
                    ++streaming_chunk_count_;
                }
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(40));
        }
    });
}

void AppController::stop_streaming_dictation(const std::vector<float>& samples,
                                             std::optional<std::filesystem::path> audio_path) {
    const auto stop_started_at = std::chrono::steady_clock::now();
    if (streaming_connect_thread_.joinable()) {
        streaming_connect_thread_.join();
    }
    bool session_ready = false;
    {
        std::lock_guard lock(streaming_mutex_);
        session_ready = streaming_session_ready_;
    }
    if (streaming_pump_cancel_flag_) {
        streaming_pump_cancel_flag_->store(true);
    }
    if (streaming_pump_thread_.joinable()) {
        streaming_pump_thread_.join();
    }

    std::size_t samples_sent = 0;
    {
        std::lock_guard lock(streaming_mutex_);
        samples_sent = streaming_samples_sent_;
    }
    if (streaming_session_ != nullptr && session_ready && samples_sent < samples.size()) {
        const std::span<const float> remainder(samples.data() + samples_sent, samples.size() - samples_sent);
        std::vector<std::byte> bytes = encode_pcm16(remainder);
        streaming_session_->push_audio(bytes);
        {
            std::lock_guard lock(streaming_mutex_);
            streaming_samples_sent_ += remainder.size();
            ++streaming_chunk_count_;
        }
    }

    if (streaming_session_ != nullptr && session_ready) {
        streaming_session_->finish();
    }

    QString final_text;
    QString error_text;
    {
        std::unique_lock lock(streaming_mutex_);
        streaming_condition_.wait_for(lock, std::chrono::seconds(10),
                                      [this]() { return streaming_closed_ || !streaming_error_text_.isEmpty(); });
        final_text = streaming_final_text_.isEmpty() ? streaming_partial_text_ : streaming_final_text_;
        error_text = streaming_error_text_;
    }

    nlohmann::json streaming_meta = nlohmann::json::object();
    const auto stop_finished_at = std::chrono::steady_clock::now();
    const auto connect_ms = streaming_ready_at_.has_value()
                                ? std::chrono::duration_cast<std::chrono::milliseconds>(*streaming_ready_at_ - streaming_started_at_).count()
                                : -1;
    const auto stop_wait_ms =
        std::chrono::duration_cast<std::chrono::milliseconds>(stop_finished_at - stop_started_at).count();
    const auto total_audio_ms =
        static_cast<std::int64_t>((1000.0 * static_cast<double>(samples.size())) / static_cast<double>(runtime_config_.audio.sample_rate));
    {
        std::lock_guard lock(streaming_mutex_);
        streaming_meta["streaming"] = {
            {"backend", streaming_asr_backend_ != nullptr ? streaming_asr_backend_->name() : std::string()},
            {"provider", runtime_config_.pipeline.streaming.provider},
            {"session_ready", session_ready},
            {"connect_ms", connect_ms},
            {"stop_wait_ms", stop_wait_ms},
            {"audio_ms", total_audio_ms},
            {"samples_sent", streaming_samples_sent_},
            {"chunk_count", streaming_chunk_count_},
            {"partial_updates", streaming_partial_update_count_},
            {"final_updates", streaming_final_update_count_},
        };
    }
    if (streaming_session_ != nullptr) {
        streaming_meta["streaming"]["provider_runtime"] = streaming_session_->runtime_diagnostics();
    }

    if (streaming_session_ != nullptr) {
        streaming_session_->cancel();
        streaming_session_.reset();
    }
    streaming_active_ = false;

    if (!error_text.isEmpty()) {
        clipboard_->clear_paste_session();
        active_capture_mode_ = CaptureMode::Dictation;
        captured_selection_text_.reset();
        pending_selection_debug_info_.clear();
        history_store_->add_entry(QString("Streaming transcription failed: %1").arg(error_text).toStdString(),
                                  audio_path,
                                  nlohmann::json{{"diagnostics", {{"error", error_text.toStdString()}}}, {"streaming", streaming_meta["streaming"]}});
        load_history();
        on_hotkey_failed(error_text);
        return;
    }

    if (should_use_live_caption_window()) {
        const QString text = final_text.trimmed();
        if (!text.isEmpty()) {
            window_->meeting_window()->append_transcript_segment(
                QDateTime::currentDateTime().toString("HH:mm:ss"),
                text);
            history_store_->add_entry(text.toStdString(),
                                      audio_path,
                                      nlohmann::json{{"diagnostics", {{"pipeline", "live_caption"}}},
                                                     {"streaming", streaming_meta.value("streaming", nlohmann::json::object())}});
            load_history();
        }
        window_->meeting_window()->set_session_state(SessionState::Idle);
        window_->meeting_window()->clear_live_text();
        set_state(SessionState::Idle, text.isEmpty() ? "Live caption stopped." : "Live caption saved.");
        hud_->hide();
        clipboard_->clear_paste_session();
        active_capture_mode_ = CaptureMode::Dictation;
        captured_selection_text_.reset();
        pending_selection_debug_info_.clear();
        return;
    }

    if (final_text.trimmed().isEmpty()) {
        clipboard_->clear_paste_session();
        active_capture_mode_ = CaptureMode::Dictation;
        captured_selection_text_.reset();
        pending_selection_debug_info_.clear();
        history_store_->add_entry("Streaming transcription returned no text.",
                                  audio_path,
                                  nlohmann::json{{"diagnostics", {{"error", "Streaming transcription returned no text."}}}, {"streaming", streaming_meta["streaming"]}});
        load_history();
        on_hotkey_failed("Streaming transcription returned no text.");
        return;
    }

    if (active_capture_mode_ == CaptureMode::SelectionCommand) {
        if (!captured_selection_text_.has_value() || captured_selection_text_->trimmed().isEmpty()) {
            const SelectionCaptureResult selection = selection_->capture_selection(true);
            pending_selection_debug_info_ = selection.debug_info;
            if (selection.success && !selection.selected_text.trimmed().isEmpty()) {
                captured_selection_text_ = selection.selected_text;
            }
        }
        if (!captured_selection_text_.has_value() || captured_selection_text_->trimmed().isEmpty()) {
            clipboard_->clear_paste_session();
            active_capture_mode_ = CaptureMode::Dictation;
            pending_selection_debug_info_.clear();
            history_store_->add_entry("Selection command could not find selected text.",
                                      audio_path,
                                      nlohmann::json{{"diagnostics", {{"error", "Selection command could not find selected text."}}},
                                                     {"streaming", streaming_meta["streaming"]}});
            load_history();
            on_hotkey_failed("No selected text captured.");
            return;
        }
        TextTask task;
        task.mode = CaptureMode::SelectionCommand;
        task.selected_text = captured_selection_text_.value_or(QString()).toStdString();
        task.spoken_instruction = final_text.trimmed().toStdString();
        transcribe_selection_command_async(std::move(task), {}, std::move(audio_path), std::move(streaming_meta));
        return;
    }

    transcribe_streaming_result_async(final_text.trimmed(), std::move(audio_path), std::move(streaming_meta));
}

void AppController::transcribe_streaming_result_async(QString transcript,
                                                      std::optional<std::filesystem::path> audio_path,
                                                      nlohmann::json streaming_meta) {
    if (transcription_watcher_->isRunning()) {
        on_hotkey_failed("A transcription job is already running.");
        return;
    }

    const AppConfig config_snapshot = runtime_config_;
    const quint64 job_id = next_transcription_job_id_++;
    active_transcription_job_id_ = job_id;
    transcription_cancel_flag_ = std::make_shared<std::atomic_bool>(false);
    const auto cancel_flag = transcription_cancel_flag_;

    transcription_watcher_->setFuture(QtConcurrent::run(
        [window = window_,
         hud = hud_,
         config_snapshot,
         transcript = std::move(transcript),
         audio_path = std::move(audio_path),
         streaming_meta = std::move(streaming_meta),
         job_id,
         cancel_flag]() mutable {
            TranscriptionResult result;
            result.job_id = job_id;
            result.audio_path = std::move(audio_path);

            try {
                std::unique_ptr<TextTransformBackend> refine_backend = make_refine_backend(config_snapshot);

                nlohmann::json meta = nlohmann::json::object();
                nlohmann::json diagnostics = nlohmann::json::object();
                nlohmann::json timing = nlohmann::json::object();
                diagnostics["pipeline"] = "streaming_asr_refine";
                diagnostics["asr"] = {
                    {"provider", config_snapshot.pipeline.streaming.provider},
                    {"model", streaming_model_name(config_snapshot)},
                };
                diagnostics.update(capture_context_meta(config_snapshot));

                std::string text = transcript.toStdString();
                if (config_snapshot.pipeline.refine.enabled) {
                    QMetaObject::invokeMethod(
                        window,
                        [window, hud]() {
                            window->set_status_text("Thinking...");
                            hud->show_thinking();
                        },
                        Qt::QueuedConnection);
                    const auto refine_start = std::chrono::steady_clock::now();
                    text = refine_backend->transform(TextTransformRequest{
                        .input_text = text,
                        .instruction = "refine",
                        .context = std::nullopt,
                    }, cancel_flag.get());
                    const auto refine_http_diagnostics = refine_backend->last_diagnostics();
                    timing["refine_ms"] =
                        std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - refine_start).count();
                    diagnostics["refine"] = {
                        {"provider", endpoint_provider_name(config_snapshot.pipeline.refine.endpoint)},
                        {"model", config_snapshot.pipeline.refine.endpoint.model},
                    };
                    if (refine_http_diagnostics.has_value()) {
                        diagnostics["refine"]["http"] = text_transform_diagnostics_json(*refine_http_diagnostics);
                    }
                }
                if (streaming_meta.contains("streaming")) {
                    diagnostics["streaming"] = streaming_meta["streaming"];
                    const auto& runtime = streaming_meta["streaming"];
                    if (runtime.contains("provider_runtime") && runtime["provider_runtime"].contains("total_audio_proc_ms")) {
                        timing["asr_ms"] = runtime["provider_runtime"]["total_audio_proc_ms"];
                    } else if (runtime.contains("audio_ms")) {
                        timing["asr_ms"] = runtime["audio_ms"];
                    }
                    if (runtime.contains("connect_ms") && runtime["connect_ms"].is_number_integer() &&
                        runtime["connect_ms"].get<int>() >= 0) {
                        timing["connect_ms"] = runtime["connect_ms"];
                    }
                    if (runtime.contains("stop_wait_ms")) {
                        timing["stop_wait_ms"] = runtime["stop_wait_ms"];
                    }
                }
                if (!timing.empty()) {
                    std::int64_t total_ms = 0;
                    if (timing.contains("asr_ms")) {
                        total_ms += timing["asr_ms"].get<std::int64_t>();
                    }
                    if (timing.contains("refine_ms")) {
                        total_ms += timing["refine_ms"].get<std::int64_t>();
                    }
                    if (timing.contains("connect_ms")) {
                        total_ms += timing["connect_ms"].get<std::int64_t>();
                    }
                    if (timing.contains("stop_wait_ms")) {
                        total_ms += timing["stop_wait_ms"].get<std::int64_t>();
                    }
                    timing["total"] = total_ms;
                    diagnostics["timing"] = timing;
                }

                result.text = QString::fromStdString(text).trimmed();
                if (result.text.isEmpty()) {
                    throw std::runtime_error("streaming transcription result is empty");
                }
                if (config_snapshot.observability.record_metadata) {
                    meta["diagnostics"] = diagnostics;
                    meta["streaming"] = streaming_meta.value("streaming", nlohmann::json::object());
                    result.meta = std::move(meta);
                }
            } catch (const std::exception& exception) {
                const QString message = QString::fromUtf8(exception.what());
                if (cancel_flag->load() && message == "request cancelled") {
                    result.cancelled = true;
                } else {
                    result.error_text = message;
                    result.meta = nlohmann::json{
                        {"summary", "streaming transcription failed"},
                        {"diagnostics", {{"error", message.toStdString()}}},
                        {"streaming", streaming_meta.value("streaming", nlohmann::json::object())},
                    };
                }
            }

            return result;
        }));
}

void AppController::load_history() {
    history_ = history_store_->list_recent(kHistoryPageSize);
    if (history_.empty()) {
        oldest_loaded_history_id_.reset();
    } else {
        oldest_loaded_history_id_ = history_.back().id;
    }
    window_->update_history(history_);
    window_->history_window()->set_load_older_visible(history_.size() == kHistoryPageSize);
}

void AppController::preview_profile_audio_devices_for_mode(const QString& capture_mode) {
    if (window_ == nullptr || window_->settings_window() == nullptr || audio_capture_ == nullptr) {
        return;
    }

    QList<QPair<QString, QString>> devices;
    QString selected_device_id;

    if (capture_mode == "system") {
        devices.append(qMakePair(QString(), QString("Default system output")));
    } else {
        const auto devices_raw = audio_capture_->list_input_devices();
        for (const auto& device : devices_raw) {
            QString label = QString::fromStdString(device.name);
            if (device.is_default) {
                label += " [default]";
            }
            devices.append({QString::fromStdString(device.id), label});
        }

        const auto profile_it = std::find_if(config_.profiles.items.begin(),
                                             config_.profiles.items.end(),
                                             [&](const ProfileConfig& profile) {
                                                 return profile.id == config_.profiles.active_profile_id;
                                             });
        if (profile_it != config_.profiles.items.end()) {
            const QString preferred_id = QString::fromStdString(profile_it->capture.input_device_id);
            const bool found = std::any_of(devices.cbegin(), devices.cend(), [&preferred_id](const auto& device) {
                return device.first == preferred_id;
            });
            if (found) {
                selected_device_id = preferred_id;
            }
        }
        if (selected_device_id.isEmpty() && !devices.isEmpty()) {
            selected_device_id = devices.front().first;
        }
    }

    window_->settings_window()->set_profile_audio_devices(devices, selected_device_id);
}

void AppController::refresh_audio_devices() {
    auto profile_it = std::find_if(config_.profiles.items.begin(),
                                   config_.profiles.items.end(),
                                   [&](const ProfileConfig& profile) {
                                       return profile.id == config_.profiles.active_profile_id;
                                   });
    if (runtime_config_.audio.capture_mode == "system" || profile_it == config_.profiles.items.end()) {
        return;
    }
    const auto devices = audio_capture_->list_input_devices();
    if (devices.empty()) {
        profile_it->capture.input_device_id.clear();
        rebuild_runtime_config();
        return;
    }

    const QString configured_id = QString::fromStdString(profile_it->capture.input_device_id);
    const bool found = std::any_of(devices.cbegin(), devices.cend(), [&configured_id](const auto& device) {
        return QString::fromStdString(device.id) == configured_id;
    });

    if (!found) {
        profile_it->capture.input_device_id = devices.front().id;
        rebuild_runtime_config();
    }
}

void AppController::cancel_active_transcription() {
    if (transcription_cancel_flag_) {
        transcription_cancel_flag_->store(true);
    }
}

void AppController::cancel_streaming_session() {
    if (streaming_pump_cancel_flag_) {
        streaming_pump_cancel_flag_->store(true);
    }
    if (streaming_pump_thread_.joinable()) {
        streaming_pump_thread_.join();
    }
    if (streaming_connect_thread_.joinable()) {
        streaming_connect_thread_.join();
    }
    if (streaming_session_ != nullptr) {
        streaming_session_->cancel();
        streaming_session_.reset();
    }
    streaming_active_ = false;
    {
        std::lock_guard lock(streaming_mutex_);
        streaming_closed_ = true;
        streaming_session_ready_ = false;
        streaming_partial_text_.clear();
        streaming_final_text_.clear();
        streaming_error_text_.clear();
    }
}

void AppController::discard_active_recording_for_shutdown() {
    cancel_streaming_session();
    if (audio_capture_ != nullptr && audio_capture_->is_recording()) {
        try {
            audio_capture_->stop();
        } catch (...) {
        }
    }
    clipboard_->clear_paste_session();
    captured_selection_text_.reset();
    pending_selection_debug_info_.clear();
    pending_capture_mode_ = CaptureMode::Dictation;
    active_capture_mode_ = CaptureMode::Dictation;
    hud_->hide();
    set_state(SessionState::Idle, "Shutting down...");
    if (should_use_live_caption_window()) {
        window_->meeting_window()->set_session_state(SessionState::Idle);
        window_->meeting_window()->clear_live_text();
    }
}

void AppController::on_transcription_finished() {
    const TranscriptionResult result = transcription_watcher_->result();
    transcription_cancel_flag_.reset();

    if (result.job_id != active_transcription_job_id_) {
        return;
    }

    active_transcription_job_id_ = 0;

        if (result.cancelled) {
            clipboard_->clear_paste_session();
            active_capture_mode_ = CaptureMode::Dictation;
            captured_selection_text_.reset();
            pending_selection_debug_info_.clear();
            if (shutting_down_) {
            QApplication::quit();
            return;
        }

        set_state(SessionState::Idle, "Transcription cancelled.");
        hud_->hide();
        if (should_use_live_caption_window()) {
            window_->meeting_window()->set_session_state(SessionState::Idle);
            window_->meeting_window()->clear_live_text();
        }
        return;
    }

    if (!result.error_text.isEmpty()) {
        history_store_->add_entry(QString("Transcription failed: %1").arg(result.error_text).toStdString(),
                                  result.audio_path,
                                  result.meta);
        load_history();
        clipboard_->clear_paste_session();
        active_capture_mode_ = CaptureMode::Dictation;
        captured_selection_text_.reset();
        pending_selection_debug_info_.clear();
        on_hotkey_failed(result.error_text);
    } else {
        bool replaced_selection = false;
        QString replace_debug;
        if (active_capture_mode_ == CaptureMode::SelectionCommand) {
            replaced_selection = selection_->replace_selection(result.text, QString::fromStdString(runtime_config_.output.paste_keys));
            replace_debug = selection_->last_debug_info();
        } else if (runtime_config_.output.copy_to_clipboard) {
            clipboard_->copy_text(result.text);
        }
        bool auto_paste_ok = true;
        QString auto_paste_debug;
        if (active_capture_mode_ == CaptureMode::Dictation && runtime_config_.output.paste_to_focused_window) {
            auto_paste_ok = clipboard_->paste_text_to_last_target(result.text, QString::fromStdString(runtime_config_.output.paste_keys));
            auto_paste_debug = clipboard_->last_debug_info();
        }

        history_store_->add_entry(result.text.toStdString(), result.audio_path, result.meta);
        load_history();

        set_state(SessionState::Idle, "Ready.");
        if (should_use_live_caption_window()) {
            window_->meeting_window()->set_session_state(SessionState::Idle);
            window_->meeting_window()->append_transcript_segment(
                QDateTime::currentDateTime().toString("HH:mm:ss"),
                result.text);
            window_->meeting_window()->clear_live_text();
        }

        if (active_capture_mode_ == CaptureMode::SelectionCommand && !replaced_selection) {
            const QString status =
                replace_debug.isEmpty() ? "Selection replace failed." : QString("Selection replace failed.\n%1").arg(replace_debug);
            window_->set_status_text(status);
            window_->settings_window()->set_status_text(status);
            hud_->show_error("Selection replace failed");
        } else if (runtime_config_.output.paste_to_focused_window && !auto_paste_ok) {
            const QString status = auto_paste_debug.isEmpty() ? "Auto paste failed." : QString("Auto paste failed.\n%1").arg(auto_paste_debug);
            window_->set_status_text(status);
            window_->settings_window()->set_status_text(status);
            hud_->show_error("Auto paste failed");
        } else {
            hud_->hide();
        }
        clipboard_->clear_paste_session();
        active_capture_mode_ = CaptureMode::Dictation;
        captured_selection_text_.reset();
        pending_selection_debug_info_.clear();
    }

    if (shutting_down_) {
        QApplication::quit();
    }
}

void AppController::transcribe_selection_command_async(TextTask task,
                                                       std::vector<float> samples,
                                                       std::optional<std::filesystem::path> audio_path,
                                                       nlohmann::json streaming_meta) {
    if (transcription_watcher_->isRunning()) {
        on_hotkey_failed("A transcription job is already running.");
        return;
    }

    set_state(SessionState::Transcribing, "Thinking.");
    hud_->show_thinking();

    const AppConfig config_snapshot = runtime_config_;
    const std::string selection_backend_name = selection_->backend_name().toStdString();
    const QString selection_debug_info = pending_selection_debug_info_;
    const quint64 job_id = next_transcription_job_id_++;
    active_transcription_job_id_ = job_id;
    transcription_cancel_flag_ = std::make_shared<std::atomic_bool>(false);
    const auto cancel_flag = transcription_cancel_flag_;

    transcription_watcher_->setFuture(QtConcurrent::run(
        [config_snapshot,
         selection_backend_name,
         selection_debug_info,
         task = std::move(task),
         samples = std::move(samples),
         audio_path = std::move(audio_path),
         streaming_meta = std::move(streaming_meta),
         job_id,
         cancel_flag]() mutable {
            TranscriptionResult result;
            result.job_id = job_id;
            result.audio_path = std::move(audio_path);

            try {
                std::unique_ptr<TextTransformBackend> refine_backend = make_refine_backend(config_snapshot);

                nlohmann::json meta = nlohmann::json::object();
                nlohmann::json diagnostics = nlohmann::json::object();
                nlohmann::json timing = nlohmann::json::object();

                std::string instruction = QString::fromStdString(task.spoken_instruction).trimmed().toStdString();
                if (instruction.empty()) {
                    std::unique_ptr<AsrBackend> asr_backend = make_asr_backend(config_snapshot);
                    const auto asr_start = std::chrono::steady_clock::now();
                    instruction = asr_backend->transcribe(samples, cancel_flag.get());
                    timing["asr_ms"] =
                        std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - asr_start).count();
                    diagnostics["pipeline"] = "selection_command";
                    diagnostics["asr"] = nlohmann::json{
                        {"provider", config_snapshot.pipeline.asr.provider},
                        {"model", config_snapshot.pipeline.asr.model},
                    };
                    diagnostics.update(capture_context_meta(config_snapshot));
                } else {
                    diagnostics["pipeline"] = "streaming_selection_command";
                    diagnostics["asr"] = nlohmann::json{
                        {"provider", config_snapshot.pipeline.streaming.provider},
                        {"model", streaming_model_name(config_snapshot)},
                    };
                    diagnostics.update(capture_context_meta(config_snapshot));
                    if (streaming_meta.contains("streaming")) {
                        diagnostics["streaming"] = streaming_meta["streaming"];
                        const auto& runtime = streaming_meta["streaming"];
                        if (runtime.contains("provider_runtime") && runtime["provider_runtime"].contains("total_audio_proc_ms")) {
                            timing["asr_ms"] = runtime["provider_runtime"]["total_audio_proc_ms"];
                        } else if (runtime.contains("audio_ms")) {
                            timing["asr_ms"] = runtime["audio_ms"];
                        }
                        if (runtime.contains("connect_ms") && runtime["connect_ms"].is_number_integer() &&
                            runtime["connect_ms"].get<int>() >= 0) {
                            timing["connect_ms"] = runtime["connect_ms"];
                        }
                        if (runtime.contains("stop_wait_ms")) {
                            timing["stop_wait_ms"] = runtime["stop_wait_ms"];
                        }
                    }
                }

                const auto transform_start = std::chrono::steady_clock::now();
                const std::string transformed = refine_backend->transform(
                    TextTransformRequest{
                        .input_text = task.selected_text,
                        .instruction = instruction,
                        .context = std::optional<std::string>("Rewrite the selected text according to the spoken instruction."),
                    },
                    cancel_flag.get());
                const auto transform_http_diagnostics = refine_backend->last_diagnostics();
                timing["transform_ms"] =
                    std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - transform_start).count();
                diagnostics["transform"] = nlohmann::json{
                    {"provider", endpoint_provider_name(config_snapshot.pipeline.refine.endpoint)},
                    {"model", config_snapshot.pipeline.refine.endpoint.model},
                    {"instruction", instruction},
                };
                if (transform_http_diagnostics.has_value()) {
                    diagnostics["transform"]["http"] = text_transform_diagnostics_json(*transform_http_diagnostics);
                }

                long long total_ms = 0;
                for (auto it = timing.begin(); it != timing.end(); ++it) {
                    if (it.value().is_number_integer()) {
                        total_ms += it.value().get<long long>();
                    }
                }
                timing["total"] = total_ms;
                if (config_snapshot.observability.record_timing) {
                    diagnostics["timing"] = timing;
                }
                meta["diagnostics"] = diagnostics;
                if (streaming_meta.contains("streaming")) {
                    meta["streaming"] = streaming_meta["streaming"];
                }
                meta["selection"] = {
                    {"source_text", task.selected_text},
                    {"spoken_instruction", instruction},
                    {"capture_backend", selection_backend_name},
                    {"capture_debug", selection_debug_info.toStdString()},
                };

                result.text = QString::fromStdString(transformed).trimmed();
                if (result.text.isEmpty()) {
                    throw std::runtime_error("selection command result is empty");
                }
                if (config_snapshot.observability.record_metadata) {
                    result.meta = std::move(meta);
                }
            } catch (const std::exception& exception) {
                const QString message = QString::fromUtf8(exception.what());
                if (cancel_flag->load() && message == "request cancelled") {
                    result.cancelled = true;
                } else {
                    result.error_text = message;
                    result.meta = nlohmann::json{
                        {"summary", "selection command failed"},
                        {"diagnostics", {{"error", message.toStdString()}}},
                    };
                }
            }

            return result;
        }));
}

void AppController::transcribe_async(std::vector<float> samples, std::optional<std::filesystem::path> audio_path) {
    if (transcription_watcher_->isRunning()) {
        on_hotkey_failed("A transcription job is already running.");
        return;
    }

    const AppConfig config_snapshot = runtime_config_;
    const QString selection_debug_info = pending_selection_debug_info_;
    const std::string selection_backend_name = selection_->backend_name().toStdString();
    const quint64 job_id = next_transcription_job_id_++;
    active_transcription_job_id_ = job_id;
    transcription_cancel_flag_ = std::make_shared<std::atomic_bool>(false);
    const auto cancel_flag = transcription_cancel_flag_;

    transcription_watcher_->setFuture(QtConcurrent::run(
        [window = window_,
         hud = hud_,
         config_snapshot,
         selection_debug_info,
         selection_backend_name,
         samples = std::move(samples),
         audio_path = std::move(audio_path),
         job_id,
         cancel_flag]() mutable {
            TranscriptionResult result;
            result.job_id = job_id;
            result.audio_path = std::move(audio_path);

            try {
                std::unique_ptr<AsrBackend> asr_backend = make_asr_backend(config_snapshot);
                std::unique_ptr<TextTransformBackend> refine_backend = make_refine_backend(config_snapshot);

                nlohmann::json meta = nlohmann::json::object();
                nlohmann::json diagnostics = nlohmann::json::object();
                nlohmann::json timing = nlohmann::json::object();

                const auto asr_start = std::chrono::steady_clock::now();
                std::string text = asr_backend->transcribe(samples, cancel_flag.get());
                timing["asr_ms"] =
                    std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - asr_start).count();
                diagnostics["pipeline"] = "asr_refine";
                diagnostics["asr"] = nlohmann::json{
                    {"provider", config_snapshot.pipeline.asr.provider},
                    {"model", config_snapshot.pipeline.asr.model},
                };
                diagnostics.update(capture_context_meta(config_snapshot));

                if (config_snapshot.pipeline.refine.enabled) {
                    QMetaObject::invokeMethod(
                        window,
                        [window, hud]() {
                            window->set_status_text("Thinking...");
                            hud->show_thinking();
                        },
                        Qt::QueuedConnection);
                    const auto refine_start = std::chrono::steady_clock::now();
                    text = refine_backend->transform(TextTransformRequest{
                        .input_text = text,
                        .instruction = "refine",
                        .context = std::nullopt,
                    }, cancel_flag.get());
                    const auto refine_http_diagnostics = refine_backend->last_diagnostics();
                    timing["refine_ms"] = std::chrono::duration_cast<std::chrono::milliseconds>(
                                              std::chrono::steady_clock::now() - refine_start)
                                              .count();
                    diagnostics["refine"] = nlohmann::json{
                        {"provider", endpoint_provider_name(config_snapshot.pipeline.refine.endpoint)},
                        {"model", config_snapshot.pipeline.refine.endpoint.model},
                    };
                    if (refine_http_diagnostics.has_value()) {
                        diagnostics["refine"]["http"] = text_transform_diagnostics_json(*refine_http_diagnostics);
                    }
                }

                long long total_ms = 0;
                for (auto it = timing.begin(); it != timing.end(); ++it) {
                    if (it.value().is_number_integer()) {
                        total_ms += it.value().get<long long>();
                    }
                }
                timing["total"] = total_ms;
                if (config_snapshot.observability.record_timing) {
                    diagnostics["timing"] = timing;
                }
                meta["diagnostics"] = diagnostics;
                if (!selection_debug_info.isEmpty()) {
                    meta["selection_detection"] = {
                        {"capture_backend", selection_backend_name},
                        {"capture_debug", selection_debug_info.toStdString()},
                    };
                }

                result.text = QString::fromStdString(text).trimmed();
                if (result.text.isEmpty()) {
                    throw std::runtime_error("transcription result is empty");
                }
                if (config_snapshot.observability.record_metadata) {
                    result.meta = std::move(meta);
                }
            } catch (const std::exception& exception) {
                const QString message = QString::fromUtf8(exception.what());
                if (cancel_flag->load() && message == "request cancelled") {
                    result.cancelled = true;
                } else {
                    result.error_text = message;
                    result.meta = nlohmann::json{
                        {"summary", "transcription failed"},
                        {"diagnostics", {{"error", message.toStdString()}}},
                    };
                }
            }

            return result;
        }));
}

}  // namespace ohmytypeless
