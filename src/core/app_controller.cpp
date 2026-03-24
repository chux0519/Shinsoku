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
#include "ui/settings_window.hpp"

#include <QApplication>
#include <QDir>
#include <QMessageBox>
#include <QCheckBox>
#include <QtConcurrent/QtConcurrent>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <exception>

namespace ohmytypeless {

namespace {

constexpr std::size_t kHistoryPageSize = 50;

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

}  // namespace

AppController::AppController(MainWindow* window,
                             ClipboardService* clipboard,
                             SelectionService* selection,
                             GlobalHotkey* hotkey,
                             HudPresenter* hud,
                             QObject* parent)
    : QObject(parent),
      window_(window),
      clipboard_(clipboard),
      selection_(selection),
      hotkey_(hotkey),
      hud_(hud),
      config_(load_config()),
      history_store_(std::make_unique<HistoryStore>(config_.history_db_path)),
      recording_store_(std::make_unique<RecordingStore>(config_.audio)),
      asr_backend_(make_asr_backend(config_)),
      refine_backend_(make_refine_backend(config_)),
      transcription_watcher_(std::make_unique<QFutureWatcher<TranscriptionResult>>()) {}

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

    window_->settings_window()->set_hold_key(QString::fromStdString(config_.hotkey.hold_key));
    window_->settings_window()->set_hands_free_chord_key(QString::fromStdString(config_.hotkey.hands_free_chord_key));
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
    window_->settings_window()->set_refine_enabled(config_.pipeline.refine.enabled);
    window_->settings_window()->set_refine_base_url(QString::fromStdString(config_.pipeline.refine.endpoint.base_url));
    window_->settings_window()->set_refine_api_key(QString::fromStdString(config_.pipeline.refine.endpoint.api_key));
    window_->settings_window()->set_refine_model(QString::fromStdString(config_.pipeline.refine.endpoint.model));
    window_->settings_window()->set_refine_system_prompt(QString::fromStdString(config_.pipeline.refine.system_prompt));
    window_->settings_window()->set_vad_enabled(config_.vad.enabled);
    window_->settings_window()->set_vad_threshold(config_.vad.threshold);
    window_->settings_window()->set_vad_min_speech_duration_ms(static_cast<int>(config_.vad.min_speech_duration_ms));
    window_->settings_window()->set_record_metadata_enabled(config_.observability.record_metadata);
    window_->settings_window()->set_record_timing_enabled(config_.observability.record_timing);
    window_->settings_window()->set_hud_enabled(config_.hud.enabled);
    window_->settings_window()->set_hud_bottom_margin(config_.hud.bottom_margin);

    hud_->apply_config(config_.hud);
    window_->set_session_state(state_);
    window_->set_status_text(
        QString("Ready. Hotkey: %1, Selection: %2").arg(hotkey_->backend_name(), selection_->backend_name()));
    window_->update_history(history_);
    window_->set_tray_available(true);

    connect(window_, &MainWindow::toggle_recording_requested, this, &AppController::toggle_recording);
    connect(window_, &MainWindow::arm_selection_command_requested, this, &AppController::arm_selection_command);
    connect(window_, &MainWindow::register_hotkey_requested, this, &AppController::apply_settings);
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
    config_.pipeline.refine.enabled = window_->settings_window()->refine_enabled();
    config_.pipeline.refine.endpoint.base_url = window_->settings_window()->refine_base_url().toStdString();
    config_.pipeline.refine.endpoint.api_key = window_->settings_window()->refine_api_key().toStdString();
    config_.pipeline.refine.endpoint.model = window_->settings_window()->refine_model().toStdString();
    config_.pipeline.refine.system_prompt = window_->settings_window()->refine_system_prompt().toStdString();
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

    recording_store_ = std::make_unique<RecordingStore>(config_.audio);
    asr_backend_ = make_asr_backend(config_);
    refine_backend_ = make_refine_backend(config_);
    hud_->apply_config(config_.hud);
    save_config(config_);

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

void AppController::quit_application() {
    shutting_down_ = true;
    hotkey_->unregister_hotkey();
    if (recorder_.is_recording()) {
        recorder_.stop();
    }

    if (transcription_watcher_->isRunning()) {
        cancel_active_transcription();
        window_->set_status_text("Stopping active transcription...");
        return;
    }

    QApplication::quit();
}

void AppController::on_hold_started() {
    start_recording(SessionState::Recording);
}

void AppController::on_hold_stopped() {
    if (state_ == SessionState::Recording) {
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
        recorder_.start(config_.audio.sample_rate, config_.audio.channels, config_.audio.input_device_id);
        const QString status = active_capture_mode_ == CaptureMode::SelectionCommand
                                   ? "Recording command for selected text."
                                   : (mode == SessionState::HandsFree ? "Hands-free recording." : "Recording started.");
        set_state(mode, status);
        hud_->show_recording();
    } catch (const std::exception& exception) {
        active_capture_mode_ = CaptureMode::Dictation;
        pending_capture_mode_ = CaptureMode::Dictation;
        on_hotkey_failed(QString::fromUtf8(exception.what()));
    }
}

void AppController::stop_recording() {
    if (state_ != SessionState::Recording && state_ != SessionState::HandsFree) {
        return;
    }

    set_state(SessionState::Transcribing, "Recording stopped. Processing local audio.");
    hud_->show_transcribing();

    try {
        const std::vector<float> samples = recorder_.stop();
        const AudioAnalysis analysis = analyze_audio(samples, config_.vad);
        if (should_skip_transcription(analysis, config_.vad)) {
            set_state(SessionState::Idle, "No speech detected.");
            hud_->show_notice("No speech detected");
            active_capture_mode_ = CaptureMode::Dictation;
            return;
        }

        const auto audio_path = recording_store_->save_recording(samples);
        const bool forced_selection_command = active_capture_mode_ == CaptureMode::SelectionCommand;
        const bool auto_detection_enabled = selection_->supports_automatic_detection();
        SelectionCaptureResult selection;
        if (forced_selection_command || auto_detection_enabled) {
            selection = selection_->capture_selection();
            pending_selection_debug_info_ = selection.debug_info;
        } else {
            pending_selection_debug_info_.clear();
        }

        if (selection.success) {
            active_capture_mode_ = CaptureMode::SelectionCommand;
            TextTask task;
            task.mode = CaptureMode::SelectionCommand;
            task.selected_text = selection.selected_text;
            transcribe_selection_command_async(std::move(task), samples, audio_path);
        } else if (forced_selection_command) {
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
            active_capture_mode_ = CaptureMode::Dictation;
            if (auto_detection_enabled && !selection.debug_info.isEmpty()) {
                window_->set_status_text(QString("No command selection detected. Falling back to dictation.\n%1").arg(selection.debug_info));
                window_->settings_window()->set_status_text(selection.debug_info);
            }
            transcribe_async(samples, audio_path);
        }
    } catch (const std::exception& exception) {
        active_capture_mode_ = CaptureMode::Dictation;
        on_hotkey_failed(QString::fromUtf8(exception.what()));
    }
}

void AppController::set_state(SessionState state, const QString& status) {
    state_ = state;
    window_->set_session_state(state_);
    window_->set_status_text(status);
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
    const auto devices = AudioRecorder::list_input_devices();
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
            pending_selection_debug_info_.clear();
            if (shutting_down_) {
            QApplication::quit();
            return;
        }

        set_state(SessionState::Idle, "Transcription cancelled.");
        hud_->show_notice("Transcription cancelled");
        return;
    }

    if (!result.error_text.isEmpty()) {
        history_store_->add_entry(QString("Transcription failed: %1").arg(result.error_text),
                                  result.audio_path,
                                  result.meta);
        load_history();
        clipboard_->clear_paste_session();
        active_capture_mode_ = CaptureMode::Dictation;
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
        const bool copied = active_capture_mode_ == CaptureMode::Dictation && config_.output.copy_to_clipboard;
            const bool pasted = active_capture_mode_ == CaptureMode::Dictation &&
                                config_.output.paste_to_focused_window && auto_paste_ok;
            if (active_capture_mode_ == CaptureMode::SelectionCommand) {
                hud_->show_notice("Selection command complete");
            } else if (copied || pasted) {
                hud_->show_notice(copied ? "Transcription copied" : "Transcription pasted");
            } else {
                hud_->show_notice("Transcription complete");
            }
        }
        clipboard_->clear_paste_session();
        active_capture_mode_ = CaptureMode::Dictation;
        pending_selection_debug_info_.clear();
    }

    if (shutting_down_) {
        QApplication::quit();
    }
}

void AppController::transcribe_selection_command_async(TextTask task,
                                                       std::vector<float> samples,
                                                       std::optional<std::filesystem::path> audio_path) {
    if (transcription_watcher_->isRunning()) {
        on_hotkey_failed("A transcription job is already running.");
        return;
    }

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
                const std::string instruction = asr_backend->transcribe(samples, cancel_flag.get());
                timing["asr_ms"] =
                    std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - asr_start).count();
                diagnostics["pipeline"] = "selection_command";
                diagnostics["asr"] = nlohmann::json{
                    {"provider", config_snapshot.pipeline.asr.provider},
                    {"model", config_snapshot.pipeline.asr.model},
                };

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
