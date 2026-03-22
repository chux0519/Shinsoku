#include "core/app_controller.hpp"

#include "platform/clipboard_service.hpp"
#include "platform/global_hotkey.hpp"
#include "platform/hud_presenter.hpp"
#include "ui/main_window.hpp"
#include "ui/settings_window.hpp"
#include "ui/history_window.hpp"

#include <QApplication>
#include <QtConcurrent/QtConcurrent>

#include <algorithm>
#include <cmath>
#include <exception>

namespace ohmytypeless {

namespace {

std::string trim_copy(std::string value) {
    const auto begin = value.find_first_not_of(" \t\r\n");
    if (begin == std::string::npos) {
        return {};
    }
    const auto end = value.find_last_not_of(" \t\r\n");
    return value.substr(begin, end - begin + 1U);
}

struct AudioDiagnostics {
    double duration_seconds = 0.0;
    double rms = 0.0;
    double peak = 0.0;
};

AudioDiagnostics analyze_audio(const std::vector<float>& samples, std::uint32_t sample_rate, std::uint32_t channels) {
    AudioDiagnostics diagnostics;
    if (samples.empty() || sample_rate == 0 || channels == 0) {
        return diagnostics;
    }

    diagnostics.duration_seconds =
        static_cast<double>(samples.size()) / static_cast<double>(sample_rate * channels);

    double sum_squares = 0.0;
    double peak = 0.0;
    for (float sample : samples) {
        const double value = static_cast<double>(sample);
        sum_squares += value * value;
        peak = std::max(peak, std::abs(value));
    }

    diagnostics.rms = std::sqrt(sum_squares / static_cast<double>(samples.size()));
    diagnostics.peak = peak;
    return diagnostics;
}

bool looks_like_silence(const AudioDiagnostics& diagnostics) {
    return diagnostics.duration_seconds > 0.15 && diagnostics.peak < 0.001 && diagnostics.rms < 0.0002;
}

QString audio_summary(const AudioDiagnostics& diagnostics, bool saved) {
    return QString("capture %1s • rms=%2 peak=%3%4")
        .arg(diagnostics.duration_seconds, 0, 'f', 1)
        .arg(diagnostics.rms, 0, 'g', 3)
        .arg(diagnostics.peak, 0, 'g', 3)
        .arg(saved ? " • wav saved" : "");
}

}  // namespace

AppController::AppController(MainWindow* window,
                             ClipboardService* clipboard,
                             GlobalHotkey* hotkey,
                             HudPresenter* hud,
                             QObject* parent)
    : QObject(parent),
      window_(window),
      clipboard_(clipboard),
      hotkey_(hotkey),
      hud_(hud),
      config_(load_config()),
      history_store_(std::make_unique<HistoryStore>(config_.history_db_path)),
      recording_store_(std::make_unique<RecordingStore>(config_.audio)),
      transcription_watcher_(std::make_unique<QFutureWatcher<TranscriptionResult>>()) {}

void AppController::initialize() {
    seed_history();
    try {
        refresh_audio_devices();
    } catch (const std::exception& exception) {
        window_->settings_window()->set_status_text(QString::fromUtf8(exception.what()));
    }
    load_history();

    window_->settings_window()->set_hotkey_sequence(QString::fromStdString(config_.hotkey.sequence));
    window_->settings_window()->set_audio_devices(audio_devices_, QString::fromStdString(config_.audio.input_device_id));
    window_->settings_window()->set_save_recordings_enabled(config_.audio.save_recordings);
    window_->settings_window()->set_recordings_dir(QString::fromStdWString(config_.audio.recordings_dir.wstring()));
    window_->settings_window()->set_asr_base_url(QString::fromStdString(config_.pipeline.asr.base_url));
    window_->settings_window()->set_asr_api_key(QString::fromStdString(config_.pipeline.asr.api_key));
    window_->settings_window()->set_asr_model(QString::fromStdString(config_.pipeline.asr.model));
    window_->settings_window()->set_refine_enabled(config_.pipeline.refine.enabled);
    window_->settings_window()->set_refine_base_url(QString::fromStdString(config_.pipeline.refine.endpoint.base_url));
    window_->settings_window()->set_refine_api_key(QString::fromStdString(config_.pipeline.refine.endpoint.api_key));
    window_->settings_window()->set_refine_model(QString::fromStdString(config_.pipeline.refine.endpoint.model));

    window_->set_session_state(state_);
    window_->set_status_text(QString("Ready. Hotkey backend: %1").arg(hotkey_->backend_name()));
    window_->update_history(history_);
    window_->set_tray_available(true);

    connect(window_, &MainWindow::toggle_recording_requested, this, &AppController::toggle_recording);
    connect(window_, &MainWindow::copy_demo_text_requested, this, &AppController::copy_demo_text);
    connect(window_, &MainWindow::register_hotkey_requested, this, &AppController::apply_settings);
    connect(window_, &MainWindow::show_history_requested, this, &AppController::show_history);
    connect(window_, &MainWindow::show_settings_requested, this, &AppController::show_settings);
    connect(window_, &MainWindow::quit_requested, this, &AppController::quit_application);
    connect(window_->settings_window(), &SettingsWindow::apply_clicked, this, &AppController::apply_settings);
    connect(hotkey_, &GlobalHotkey::activated, this, &AppController::on_hotkey_activated);
    connect(hotkey_, &GlobalHotkey::registration_failed, this, &AppController::on_hotkey_failed);
    connect(transcription_watcher_.get(), &QFutureWatcher<TranscriptionResult>::finished, this,
            &AppController::on_transcription_finished);

    apply_settings();
}

void AppController::toggle_recording() {
    if (state_ == SessionState::Idle || state_ == SessionState::Error) {
        try {
            recorder_.start(config_.audio.sample_rate, config_.audio.channels, config_.audio.input_device_id);
            set_state(SessionState::Recording, "Recording started.");
            hud_->show_recording();
        } catch (const std::exception& exception) {
            on_hotkey_failed(QString::fromUtf8(exception.what()));
        }
        return;
    }

    if (state_ == SessionState::Recording || state_ == SessionState::HandsFree) {
        set_state(SessionState::Transcribing, "Recording stopped. Processing local audio.");
        hud_->show_transcribing();

        try {
            const std::vector<float> samples = recorder_.stop();
            const auto audio_path = recording_store_->save_recording(samples);
            const AudioDiagnostics diagnostics =
                analyze_audio(samples, config_.audio.sample_rate, config_.audio.channels);

            if (looks_like_silence(diagnostics)) {
                const QString text =
                    "Captured audio looks silent. The selected input device may be wrong, muted, or inaccessible.";
                const QString summary = audio_summary(diagnostics, audio_path.has_value());
                history_store_->add_entry(text, summary, audio_path);
                load_history();
                on_hotkey_failed("Recorded audio is effectively silent. Check the selected input device.");
                return;
            }

            transcribe_async(samples, audio_path);
        } catch (const std::exception& exception) {
            on_hotkey_failed(QString::fromUtf8(exception.what()));
        }
    }
}

void AppController::copy_demo_text() {
    const QString text = "OhMyTypeless clipboard path is wired through QClipboard.";
    clipboard_->copy_text(text);
    window_->set_status_text("Copied demo text to clipboard.");
    hud_->show_notice("Copied demo text");
}

void AppController::apply_settings() {
    const AppConfig defaults;
    config_.hotkey.sequence = trim_copy(window_->settings_window()->hotkey_sequence().toStdString());
    config_.audio.input_device_id = window_->settings_window()->selected_input_device_id().toStdString();
    config_.audio.save_recordings = window_->settings_window()->save_recordings_enabled();
    const QString recordings_dir_text = window_->settings_window()->recordings_dir();
    if (!recordings_dir_text.isEmpty()) {
        config_.audio.recordings_dir = std::filesystem::path(recordings_dir_text.toStdWString());
    }
    config_.pipeline.asr.base_url = trim_copy(window_->settings_window()->asr_base_url().toStdString());
    config_.pipeline.asr.api_key = trim_copy(window_->settings_window()->asr_api_key().toStdString());
    config_.pipeline.asr.model = trim_copy(window_->settings_window()->asr_model().toStdString());
    config_.pipeline.refine.enabled = window_->settings_window()->refine_enabled();
    config_.pipeline.refine.endpoint.base_url = trim_copy(window_->settings_window()->refine_base_url().toStdString());
    config_.pipeline.refine.endpoint.api_key = trim_copy(window_->settings_window()->refine_api_key().toStdString());
    config_.pipeline.refine.endpoint.model = trim_copy(window_->settings_window()->refine_model().toStdString());

    if (config_.pipeline.asr.base_url.empty()) {
        config_.pipeline.asr.base_url = defaults.pipeline.asr.base_url;
    }
    if (config_.pipeline.asr.model.empty()) {
        config_.pipeline.asr.model = defaults.pipeline.asr.model;
        window_->settings_window()->set_asr_model(QString::fromStdString(config_.pipeline.asr.model));
    }
    if (config_.pipeline.refine.endpoint.model.empty()) {
        config_.pipeline.refine.endpoint.model = defaults.pipeline.refine.endpoint.model;
        window_->settings_window()->set_refine_model(QString::fromStdString(config_.pipeline.refine.endpoint.model));
    }
    if (config_.pipeline.refine.system_prompt.empty()) {
        config_.pipeline.refine.system_prompt = defaults.pipeline.refine.system_prompt;
    }

    recording_store_ = std::make_unique<RecordingStore>(config_.audio);
    save_config(config_);

    const QString sequence = QString::fromStdString(config_.hotkey.sequence);
    if (hotkey_->register_hotkey(sequence)) {
        const QString status = QString("Settings applied. Hotkey: %1").arg(sequence);
        window_->settings_window()->set_status_text(status);
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

void AppController::on_hotkey_activated() {
    toggle_recording();
}

void AppController::on_hotkey_failed(const QString& reason) {
    window_->settings_window()->set_status_text(reason);
    set_state(SessionState::Error, reason);
    hud_->show_error(reason);
}

void AppController::set_state(SessionState state, const QString& status) {
    state_ = state;
    window_->set_session_state(state_);
    window_->set_status_text(status);
}

void AppController::seed_history() {
    if (history_store_->list_recent(1).isEmpty()) {
        history_store_->add_entry(
            "Bootstrap shell created. Real recording, config, and history persistence are now connected.",
            "bootstrap");
    }
}

void AppController::load_history() {
    history_ = history_store_->list_recent(100);
    window_->update_history(history_);
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
        if (shutting_down_) {
            QApplication::quit();
            return;
        }

        set_state(SessionState::Idle, "Transcription cancelled.");
        hud_->show_notice("Transcription cancelled");
        return;
    }

    if (!result.error_text.isEmpty()) {
        const QString failure_text = QString("Transcription failed: %1").arg(result.error_text);
        history_store_->add_entry(failure_text, "asr error", result.audio_path);
        load_history();
        on_hotkey_failed(result.error_text);
    } else {
        history_store_->add_entry(result.text, result.summary, result.audio_path);
        load_history();

        if (config_.output.copy_to_clipboard) {
            clipboard_->copy_text(result.text);
        }

        hud_->show_notice("Transcription copied");
        set_state(SessionState::Idle, "Ready.");
    }

    if (shutting_down_) {
        QApplication::quit();
    }
}

void AppController::transcribe_async(std::vector<float> samples, std::optional<std::filesystem::path> audio_path) {
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
        [config_snapshot, samples = std::move(samples), audio_path = std::move(audio_path), job_id, cancel_flag]() mutable {
            TranscriptionResult result;
            result.job_id = job_id;
            result.summary = "asr";
            result.audio_path = std::move(audio_path);

            try {
                AsrClient asr_client(config_snapshot);
                TextRefiner text_refiner(config_snapshot);

                std::string text = asr_client.transcribe(samples, cancel_flag.get());
                if (config_snapshot.pipeline.refine.enabled) {
                    text = text_refiner.refine(text, cancel_flag.get());
                    result.summary = "asr -> refine";
                }
                result.text = QString::fromStdString(text).trimmed();
                if (result.text.isEmpty()) {
                    throw std::runtime_error("transcription result is empty");
                }
            } catch (const std::exception& exception) {
                const QString message = QString::fromUtf8(exception.what());
                if (cancel_flag->load() && message == "request cancelled") {
                    result.cancelled = true;
                } else {
                    result.error_text = message;
                }
            }

            return result;
        }));
}

}  // namespace ohmytypeless
