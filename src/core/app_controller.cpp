#include "core/app_controller.hpp"

#include "core/backend/backend_factory.hpp"
#include "core/task_types.hpp"
#include "platform/clipboard_service.hpp"
#include "platform/global_hotkey.hpp"
#include "platform/hud_presenter.hpp"
#include "platform/selection_service.hpp"
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
#include <thread>

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
    details["created_at"] = entry.created_at.toStdString();
    details["text"] = entry.text.toStdString();
    if (entry.audio_path.has_value()) {
        details["audio_path"] = entry.audio_path->toStdString();
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

std::vector<std::pair<QString, QString>> profile_items_for_ui(const AppConfig& config) {
    std::vector<std::pair<QString, QString>> items;
    items.reserve(config.profiles.items.size());
    for (const auto& profile : config.profiles.items) {
        items.emplace_back(QString::fromStdString(profile.id), QString::fromStdString(profile.name));
    }
    return items;
}

AudioCaptureMode audio_capture_mode_from_config(const AppConfig& config) {
    return config.audio.capture_mode == "system" ? AudioCaptureMode::SystemLoopback : AudioCaptureMode::Microphone;
}

nlohmann::json capture_context_meta(const AppConfig& config) {
    nlohmann::json input = {
        {"capture_mode", config.audio.capture_mode},
        {"sample_rate", config.audio.sample_rate},
        {"channels", config.audio.channels},
    };
    if (config.audio.capture_mode == "microphone") {
        input["device_id"] = config.audio.input_device_id;
    } else {
        input["device"] = "default_system_output";
    }

    return {
        {"input", std::move(input)},
        {"profile", {{"id", config.profiles.active_profile_id}}},
    };
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

void AppController::apply_active_profile_overrides() {
    if (config_.profiles.items.empty()) {
        return;
    }

    auto profile_it = std::find_if(config_.profiles.items.begin(),
                                   config_.profiles.items.end(),
                                   [&](const ProfileConfig& profile) {
                                       return profile.id == config_.profiles.active_profile_id;
                                   });
    if (profile_it == config_.profiles.items.end()) {
        profile_it = config_.profiles.items.begin();
        config_.profiles.active_profile_id = profile_it->id;
    }

    const ProfileConfig& profile = *profile_it;
    config_.pipeline.streaming.enabled = profile.capture.prefer_streaming;
    config_.pipeline.streaming.provider = profile.capture.preferred_streaming_provider.empty()
                                              ? std::string("none")
                                              : profile.capture.preferred_streaming_provider;
    config_.pipeline.streaming.language = profile.capture.language_hint;
    config_.pipeline.refine.enabled = profile.transform.enabled;
    if (profile.transform.prompt_mode == "custom" && !profile.transform.custom_prompt.empty()) {
        config_.pipeline.refine.system_prompt = profile.transform.custom_prompt;
    }
    config_.output.copy_to_clipboard = profile.output.copy_to_clipboard;
    config_.output.paste_to_focused_window = profile.output.paste_to_focused_window;
    if (!profile.output.paste_keys.empty()) {
        config_.output.paste_keys = profile.output.paste_keys;
    }
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
      history_store_(std::make_unique<HistoryStore>(config_.history_db_path)),
      recording_store_(std::make_unique<RecordingStore>(config_.audio)),
      asr_backend_(make_asr_backend(config_)),
      streaming_asr_backend_(make_streaming_asr_backend(config_)),
      refine_backend_(make_refine_backend(config_)),
      transcription_watcher_(std::make_unique<QFutureWatcher<TranscriptionResult>>()) {
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
    try {
        refresh_audio_devices();
    } catch (const std::exception& exception) {
        startup_warning = QString("Audio device enumeration failed: %1").arg(QString::fromUtf8(exception.what()));
        window_->settings_window()->set_status_text(startup_warning);
        hud_->show_error("Audio device enumeration failed");
    }
    load_history();
    apply_active_profile_overrides();

    window_->settings_window()->set_hold_key(QString::fromStdString(config_.hotkey.hold_key));
    window_->settings_window()->set_hands_free_chord_key(QString::fromStdString(config_.hotkey.hands_free_chord_key));
    window_->settings_window()->set_selection_command_trigger(QString::fromStdString(config_.hotkey.selection_command_trigger));
    window_->settings_window()->set_profiles(config_.profiles.items, QString::fromStdString(config_.profiles.active_profile_id));
    window_->settings_window()->set_audio_capture_mode(QString::fromStdString(config_.audio.capture_mode));
    window_->settings_window()->set_audio_devices(audio_devices_, QString::fromStdString(config_.audio.input_device_id));
    window_->settings_window()->set_save_recordings_enabled(config_.audio.save_recordings);
    window_->settings_window()->set_recordings_dir(display_path(config_.audio.recordings_dir));
    window_->settings_window()->set_rotation_mode(QString::fromStdString(config_.audio.rotation.mode));
    window_->settings_window()->set_max_files(static_cast<int>(config_.audio.rotation.max_files.value_or(50U)));
    window_->settings_window()->set_copy_to_clipboard_enabled(config_.output.copy_to_clipboard);
    window_->settings_window()->set_paste_to_focused_window_enabled(config_.output.paste_to_focused_window);
    window_->settings_window()->set_paste_keys(QString::fromStdString(config_.output.paste_keys));
    window_->settings_window()->set_proxy_enabled(config_.network.proxy.enabled);
    window_->settings_window()->set_proxy_type(QString::fromStdString(config_.network.proxy.type));
    window_->settings_window()->set_proxy_host(QString::fromStdString(config_.network.proxy.host));
    window_->settings_window()->set_proxy_port(config_.network.proxy.port);
    window_->settings_window()->set_proxy_username(QString::fromStdString(config_.network.proxy.username));
    window_->settings_window()->set_proxy_password(QString::fromStdString(config_.network.proxy.password));
    window_->settings_window()->set_asr_base_url(QString::fromStdString(config_.pipeline.asr.base_url));
    window_->settings_window()->set_asr_api_key(QString::fromStdString(config_.pipeline.asr.api_key));
    window_->settings_window()->set_asr_model(QString::fromStdString(config_.pipeline.asr.model));
    window_->settings_window()->set_streaming_enabled(config_.pipeline.streaming.enabled);
    window_->settings_window()->set_streaming_provider(QString::fromStdString(config_.pipeline.streaming.provider));
    window_->settings_window()->set_streaming_language(QString::fromStdString(config_.pipeline.streaming.language));
    window_->settings_window()->set_refine_enabled(config_.pipeline.refine.enabled);
    window_->settings_window()->set_refine_base_url(QString::fromStdString(config_.pipeline.refine.endpoint.base_url));
    window_->settings_window()->set_refine_api_key(QString::fromStdString(config_.pipeline.refine.endpoint.api_key));
    window_->settings_window()->set_refine_model(QString::fromStdString(config_.pipeline.refine.endpoint.model));
    window_->settings_window()->set_refine_system_prompt(QString::fromStdString(config_.pipeline.refine.system_prompt));
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

    apply_settings();

    if (!startup_warning.isEmpty()) {
        window_->set_status_text(startup_warning);
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
    config_.audio.capture_mode = window_->settings_window()->audio_capture_mode().toStdString();
    config_.audio.input_device_id = window_->settings_window()->selected_input_device_id().toStdString();
    config_.audio.save_recordings = window_->settings_window()->save_recordings_enabled();
    if (!window_->settings_window()->recordings_dir().isEmpty()) {
        config_.audio.recordings_dir = std::filesystem::path(window_->settings_window()->recordings_dir().toStdWString());
    }
    config_.audio.rotation.mode = window_->settings_window()->rotation_mode().toStdString();
    config_.audio.rotation.max_files = static_cast<std::size_t>(window_->settings_window()->max_files());
    config_.output.copy_to_clipboard = window_->settings_window()->copy_to_clipboard_enabled();
    config_.output.paste_to_focused_window = window_->settings_window()->paste_to_focused_window_enabled();
    config_.output.paste_keys = window_->settings_window()->paste_keys().toStdString();
    config_.network.proxy.enabled = window_->settings_window()->proxy_enabled();
    config_.network.proxy.type = window_->settings_window()->proxy_type().toStdString();
    config_.network.proxy.host = window_->settings_window()->proxy_host().toStdString();
    config_.network.proxy.port = window_->settings_window()->proxy_port();
    config_.network.proxy.username = window_->settings_window()->proxy_username().toStdString();
    config_.network.proxy.password = window_->settings_window()->proxy_password().toStdString();
    config_.pipeline.asr.base_url = window_->settings_window()->asr_base_url().toStdString();
    config_.pipeline.asr.api_key = window_->settings_window()->asr_api_key().toStdString();
    config_.pipeline.asr.model = window_->settings_window()->asr_model().toStdString();
    config_.pipeline.streaming.enabled = window_->settings_window()->streaming_enabled();
    config_.pipeline.streaming.provider = window_->settings_window()->streaming_provider().toStdString();
    config_.pipeline.streaming.language = window_->settings_window()->streaming_language().toStdString();
    config_.pipeline.refine.enabled = window_->settings_window()->refine_enabled();
    config_.pipeline.refine.endpoint.base_url = window_->settings_window()->refine_base_url().toStdString();
    config_.pipeline.refine.endpoint.api_key = window_->settings_window()->refine_api_key().toStdString();
    config_.pipeline.refine.endpoint.model = window_->settings_window()->refine_model().toStdString();
    config_.pipeline.refine.system_prompt = window_->settings_window()->refine_system_prompt().toStdString();
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
    if (config_.pipeline.refine.system_prompt.empty()) {
        config_.pipeline.refine.system_prompt = defaults.pipeline.refine.system_prompt;
    }
    if (config_.pipeline.streaming.provider.empty()) {
        config_.pipeline.streaming.provider = defaults.pipeline.streaming.provider;
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

    apply_active_profile_overrides();

    refresh_audio_devices();
    window_->settings_window()->set_audio_capture_mode(QString::fromStdString(config_.audio.capture_mode));
    window_->settings_window()->set_audio_devices(audio_devices_, QString::fromStdString(config_.audio.input_device_id));
    refresh_capture_mode_ui();

    recording_store_ = std::make_unique<RecordingStore>(config_.audio);
    asr_backend_ = make_asr_backend(config_);
    streaming_asr_backend_ = make_streaming_asr_backend(config_);
    refine_backend_ = make_refine_backend(config_);
    hud_->apply_config(config_.hud);
    save_config(config_);
    window_->set_profiles(profile_items_for_ui(config_), QString::fromStdString(config_.profiles.active_profile_id));
    window_->settings_window()->set_profiles(config_.profiles.items, QString::fromStdString(config_.profiles.active_profile_id));

    if (hotkey_->register_hotkeys(QString::fromStdString(config_.hotkey.hold_key),
                                  QString::fromStdString(config_.hotkey.hands_free_chord_key))) {
        const QString status = QString("Settings applied. Hold: %1, chord: %2")
                                   .arg(QString::fromStdString(config_.hotkey.hold_key),
                                        QString::fromStdString(config_.hotkey.hands_free_chord_key));
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

void AppController::on_active_profile_changed(const QString& profile_id) {
    if (profile_id.trimmed().isEmpty()) {
        return;
    }

    config_.profiles.active_profile_id = profile_id.toStdString();
    apply_active_profile_overrides();
    asr_backend_ = make_asr_backend(config_);
    streaming_asr_backend_ = make_streaming_asr_backend(config_);
    refine_backend_ = make_refine_backend(config_);
    save_config(config_);
    window_->settings_window()->set_profiles(config_.profiles.items, profile_id);
    refresh_capture_mode_ui();
    const auto profile_it = std::find_if(config_.profiles.items.begin(),
                                         config_.profiles.items.end(),
                                         [&](const ProfileConfig& profile) {
                                             return profile.id == config_.profiles.active_profile_id;
                                         });
    const QString profile_name = profile_it != config_.profiles.items.end() ? QString::fromStdString(profile_it->name)
                                                                             : profile_id;
    const QString status = QString("Active profile: %1").arg(profile_name);
    window_->set_status_text(status);
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
    if (!uses_system_audio_capture() && uses_double_press_selection_command() && state_ == SessionState::Recording &&
        active_capture_mode_ == CaptureMode::Dictation &&
        selection_command_upgrade_timer_ != nullptr && selection_command_upgrade_timer_->isActive()) {
        selection_command_upgrade_timer_->stop();
        const SelectionCaptureResult selection = selection_->capture_selection(true);
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
    if (state_ == SessionState::Recording) {
        set_state(SessionState::HandsFree, "Hands-free recording.");
        hud_->show_recording();
    }
}

void AppController::on_hands_free_disabled() {
    if (state_ == SessionState::HandsFree) {
        stop_recording();
    }
}

void AppController::on_hotkey_failed(const QString& reason) {
    window_->settings_window()->set_status_text(reason);
    set_state(SessionState::Error, reason);
    hud_->show_error(reason);
}

void AppController::copy_history_entry(qint64 id) {
    const auto entry = history_store_->get_entry(id);
    if (!entry.has_value()) {
        return;
    }

    clipboard_->copy_text(entry->text);
    window_->set_status_text("Copied history entry.");
    hud_->show_notice("Copied history entry");
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
            std::filesystem::remove(std::filesystem::path(entry->audio_path->toStdWString()), error);
        }
    }

    history_store_->delete_entry(id);
    load_history();
}

void AppController::load_older_history() {
    if (!oldest_loaded_history_id_.has_value()) {
        return;
    }

    const QList<HistoryEntry> older = history_store_->list_before_id(*oldest_loaded_history_id_, kHistoryPageSize);
    if (older.isEmpty()) {
        window_->history_window()->set_load_older_visible(false);
        return;
    }

    oldest_loaded_history_id_ = older.back().id;
    history_.append(older);
    window_->history_window()->append_entries(older);
    window_->history_window()->set_load_older_visible(older.size() == static_cast<qsizetype>(kHistoryPageSize));
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
        const std::string device_id = config_.audio.capture_mode == "system" ? std::string{} : config_.audio.input_device_id;
        audio_capture_->start(config_.audio.sample_rate,
                              config_.audio.channels,
                              device_id,
                              audio_capture_mode_from_config(config_));
        if (should_use_streaming_dictation()) {
            start_streaming_dictation();
        }
        const QString status = active_capture_mode_ == CaptureMode::SelectionCommand
                                   ? "Listening for selected-text command."
                                   : (mode == SessionState::HandsFree ? "Hands-free recording." : "Recording started.");
        set_state(mode, status);
        hud_->show_recording(active_capture_mode_ == CaptureMode::SelectionCommand);
        if (active_profile_is_meeting()) {
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

    set_state(SessionState::Transcribing, "Recording stopped. Processing local audio.");
    hud_->show_transcribing();
    if (active_profile_is_meeting()) {
        window_->meeting_window()->set_session_state(SessionState::Transcribing);
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
            task.selected_text = selection.selected_text;
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
    return config_.hotkey.selection_command_trigger == "double_press_hold";
}

bool AppController::uses_system_audio_capture() const {
    return config_.audio.capture_mode == "system";
}

bool AppController::active_profile_is_meeting() const {
    const auto profile_it = std::find_if(config_.profiles.items.begin(),
                                         config_.profiles.items.end(),
                                         [&](const ProfileConfig& profile) {
                                             return profile.id == config_.profiles.active_profile_id;
                                         });
    return profile_it != config_.profiles.items.end() && profile_it->kind == "meeting";
}

QString AppController::active_profile_name() const {
    const auto profile_it = std::find_if(config_.profiles.items.begin(),
                                         config_.profiles.items.end(),
                                         [&](const ProfileConfig& profile) {
                                             return profile.id == config_.profiles.active_profile_id;
                                         });
    return profile_it != config_.profiles.items.end() ? QString::fromStdString(profile_it->name) : QString();
}

void AppController::refresh_capture_mode_ui() {
    const bool selection_available = !uses_system_audio_capture() && !active_profile_is_meeting();
    const QString reason = selection_available ? QString()
                                              : (uses_system_audio_capture()
                                                     ? QString("Selection command requires microphone capture. "
                                                               "System audio mode is intended for meeting transcription.")
                                                     : QString("Meeting transcription profiles use the dedicated transcript window instead of selection-command workflows."));
    window_->set_selection_command_available(selection_available, reason);
    window_->meeting_window()->set_profile_name(active_profile_name());
}

bool AppController::should_use_streaming_dictation() const {
    if (!config_.pipeline.streaming.enabled || streaming_asr_backend_ == nullptr) {
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
    const bool meeting_profile_active = active_profile_is_meeting();

    StreamingAsrCallbacks callbacks;
    callbacks.on_session_started = [this]() {
        {
            std::lock_guard lock(streaming_mutex_);
            streaming_session_ready_ = true;
        }
        streaming_ready_at_ = std::chrono::steady_clock::now();
        streaming_condition_.notify_all();
    };
    callbacks.on_partial_text = [this, meeting_profile_active](std::string text) {
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
        if (meeting_profile_active) {
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
        {
            std::lock_guard lock(streaming_mutex_);
            streaming_error_text_ = QString::fromStdString(std::move(error));
        }
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
            .sample_rate_hz = config_.audio.sample_rate,
            .channel_count = static_cast<std::uint16_t>(config_.audio.channels),
        },
        .language = config_.pipeline.streaming.language.empty()
                        ? std::nullopt
                        : std::optional<std::string>(config_.pipeline.streaming.language),
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
        static_cast<std::int64_t>((1000.0 * static_cast<double>(samples.size())) / static_cast<double>(config_.audio.sample_rate));
    {
        std::lock_guard lock(streaming_mutex_);
        streaming_meta["streaming"] = {
            {"backend", streaming_asr_backend_ != nullptr ? streaming_asr_backend_->name() : std::string()},
            {"provider", config_.pipeline.streaming.provider},
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
        history_store_->add_entry(QString("Streaming transcription failed: %1").arg(error_text),
                                  audio_path,
                                  nlohmann::json{{"diagnostics", {{"error", error_text.toStdString()}}}, {"streaming", streaming_meta["streaming"]}});
        load_history();
        on_hotkey_failed(error_text);
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
        task.selected_text = captured_selection_text_.value_or(QString());
        task.spoken_instruction = final_text.trimmed();
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

    const AppConfig config_snapshot = config_;
    const quint64 job_id = next_transcription_job_id_++;
    active_transcription_job_id_ = job_id;
    transcription_cancel_flag_ = std::make_shared<std::atomic_bool>(false);
    const auto cancel_flag = transcription_cancel_flag_;

    transcription_watcher_->setFuture(QtConcurrent::run(
        [config_snapshot,
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
                    const auto refine_start = std::chrono::steady_clock::now();
                    text = refine_backend->transform(TextTransformRequest{
                        .input_text = text,
                        .instruction = "refine",
                    }, cancel_flag.get());
                    timing["refine_ms"] =
                        std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - refine_start).count();
                    diagnostics["refine"] = {
                        {"provider", config_snapshot.pipeline.refine.endpoint.provider},
                        {"model", config_snapshot.pipeline.refine.endpoint.model},
                    };
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
    if (history_.isEmpty()) {
        oldest_loaded_history_id_.reset();
    } else {
        oldest_loaded_history_id_ = history_.back().id;
    }
    window_->update_history(history_);
    window_->history_window()->set_load_older_visible(history_.size() == static_cast<qsizetype>(kHistoryPageSize));
}

void AppController::refresh_audio_devices() {
    audio_devices_.clear();
    if (config_.audio.capture_mode == "system") {
        audio_devices_.append(qMakePair(QString(), QString("Default system output")));
        return;
    }
    const auto devices = audio_capture_->list_input_devices();
    for (const auto& device : devices) {
        QString label = QString::fromStdString(device.name);
        if (device.is_default) {
            label += " [default]";
        }
        audio_devices_.append({QString::fromStdString(device.id), label});
    }

    if (audio_devices_.isEmpty()) {
        config_.audio.input_device_id.clear();
        return;
    }

    const QString configured_id = QString::fromStdString(config_.audio.input_device_id);
    const bool found = std::any_of(audio_devices_.cbegin(), audio_devices_.cend(), [&configured_id](const auto& device) {
        return device.first == configured_id;
    });

    if (!found) {
        config_.audio.input_device_id = audio_devices_.front().first.toStdString();
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
    if (active_profile_is_meeting()) {
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
        if (active_profile_is_meeting()) {
            window_->meeting_window()->set_session_state(SessionState::Idle);
            window_->meeting_window()->clear_live_text();
        }
        return;
    }

    if (!result.error_text.isEmpty()) {
        history_store_->add_entry(QString("Transcription failed: %1").arg(result.error_text),
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
            replaced_selection = selection_->replace_selection(result.text);
            replace_debug = selection_->last_debug_info();
        } else if (config_.output.copy_to_clipboard) {
            clipboard_->copy_text(result.text);
        }
        bool auto_paste_ok = true;
        QString auto_paste_debug;
        if (active_capture_mode_ == CaptureMode::Dictation && config_.output.paste_to_focused_window) {
            auto_paste_ok = clipboard_->paste_text_to_last_target(result.text, QString::fromStdString(config_.output.paste_keys));
            auto_paste_debug = clipboard_->last_debug_info();
        }

        history_store_->add_entry(result.text, result.audio_path, result.meta);
        load_history();

        set_state(SessionState::Idle, "Ready.");
        if (active_profile_is_meeting()) {
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
        } else if (config_.output.paste_to_focused_window && !auto_paste_ok) {
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

    const AppConfig config_snapshot = config_;
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

                std::string instruction = task.spoken_instruction.trimmed().toStdString();
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
                        .input_text = task.selected_text.toStdString(),
                        .instruction = instruction,
                        .context = std::optional<std::string>("Rewrite the selected text according to the spoken instruction."),
                    },
                    cancel_flag.get());
                timing["transform_ms"] =
                    std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - transform_start).count();
                diagnostics["transform"] = nlohmann::json{
                    {"provider", config_snapshot.pipeline.refine.endpoint.provider},
                    {"model", config_snapshot.pipeline.refine.endpoint.model},
                    {"instruction", instruction},
                };

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
                    {"source_text", task.selected_text.toStdString()},
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

    const AppConfig config_snapshot = config_;
    const QString selection_debug_info = pending_selection_debug_info_;
    const std::string selection_backend_name = selection_->backend_name().toStdString();
    const quint64 job_id = next_transcription_job_id_++;
    active_transcription_job_id_ = job_id;
    transcription_cancel_flag_ = std::make_shared<std::atomic_bool>(false);
    const auto cancel_flag = transcription_cancel_flag_;

    transcription_watcher_->setFuture(QtConcurrent::run(
        [config_snapshot,
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
                    const auto refine_start = std::chrono::steady_clock::now();
                    text = refine_backend->transform(TextTransformRequest{
                        .input_text = text,
                        .instruction = "refine",
                    }, cancel_flag.get());
                    timing["refine_ms"] = std::chrono::duration_cast<std::chrono::milliseconds>(
                                              std::chrono::steady_clock::now() - refine_start)
                                              .count();
                    diagnostics["refine"] = nlohmann::json{
                        {"provider", config_snapshot.pipeline.refine.endpoint.provider},
                        {"model", config_snapshot.pipeline.refine.endpoint.model},
                    };
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
