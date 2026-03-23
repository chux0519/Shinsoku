#pragma once

#include "core/app_config.hpp"
#include "core/app_state.hpp"
#include "core/audio_recorder.hpp"
#include "core/backend/asr_backend.hpp"
#include "core/backend/text_transform_backend.hpp"
#include "core/history_store.hpp"
#include "core/recording_store.hpp"
#include "core/task_types.hpp"

#include <QFutureWatcher>
#include <QObject>
#include <QtGlobal>

#include <nlohmann/json.hpp>

#include <atomic>
#include <filesystem>
#include <memory>
#include <optional>

namespace ohmytypeless {

class ClipboardService;
class GlobalHotkey;
class HudPresenter;
class MainWindow;
class SelectionService;

struct TranscriptionResult {
    quint64 job_id = 0;
    QString text;
    nlohmann::json meta = nlohmann::json::object();
    QString error_text;
    bool cancelled = false;
    std::optional<std::filesystem::path> audio_path;
};

class AppController final : public QObject {
    Q_OBJECT
public:
    AppController(MainWindow* window,
                  ClipboardService* clipboard,
                  SelectionService* selection,
                  GlobalHotkey* hotkey,
                  HudPresenter* hud,
                  QObject* parent = nullptr);

    void initialize();

private slots:
    void toggle_recording();
    void arm_selection_command();
    void apply_settings();
    void show_history();
    void show_settings();
    void quit_application();
    void on_hold_started();
    void on_hold_stopped();
    void on_hands_free_enabled();
    void on_hands_free_disabled();
    void on_hotkey_failed(const QString& reason);
    void copy_history_entry(qint64 id);
    void show_history_entry_details(qint64 id);
    void delete_history_entry(qint64 id, bool delete_audio_if_present);
    void load_older_history();

private:
    void start_recording(SessionState mode);
    void stop_recording();
    void set_state(SessionState state, const QString& status);
    void load_history();
    void refresh_audio_devices();
    void cancel_active_transcription();
    void on_transcription_finished();
    void transcribe_async(std::vector<float> samples, std::optional<std::filesystem::path> audio_path);
    void transcribe_selection_command_async(TextTask task,
                                            std::vector<float> samples,
                                            std::optional<std::filesystem::path> audio_path);

    MainWindow* window_ = nullptr;
    ClipboardService* clipboard_ = nullptr;
    SelectionService* selection_ = nullptr;
    GlobalHotkey* hotkey_ = nullptr;
    HudPresenter* hud_ = nullptr;
    AppConfig config_;
    AudioRecorder recorder_;
    std::unique_ptr<HistoryStore> history_store_;
    std::unique_ptr<RecordingStore> recording_store_;
    std::unique_ptr<AsrBackend> asr_backend_;
    std::unique_ptr<TextTransformBackend> refine_backend_;
    std::unique_ptr<QFutureWatcher<TranscriptionResult>> transcription_watcher_;
    std::shared_ptr<std::atomic_bool> transcription_cancel_flag_;
    QList<QPair<QString, QString>> audio_devices_;
    SessionState state_ = SessionState::Idle;
    QList<HistoryEntry> history_;
    std::optional<qint64> oldest_loaded_history_id_;
    quint64 next_transcription_job_id_ = 1;
    quint64 active_transcription_job_id_ = 0;
    bool shutting_down_ = false;
    CaptureMode pending_capture_mode_ = CaptureMode::Dictation;
    CaptureMode active_capture_mode_ = CaptureMode::Dictation;
    QString pending_selection_debug_info_;
};

}  // namespace ohmytypeless
