#pragma once

#include "core/app_config.hpp"
#include "core/app_state.hpp"
#include "core/backend/asr_backend.hpp"
#include "core/backend/streaming_asr_backend.hpp"
#include "core/backend/text_transform_backend.hpp"
#include "core/history_store.hpp"
#include "core/recording_store.hpp"
#include "core/task_types.hpp"
#include "platform/audio_capture_service.hpp"

#include <QFutureWatcher>
#include <QObject>
#include <QtGlobal>

#include <nlohmann/json.hpp>

#include <atomic>
#include <condition_variable>
#include <filesystem>
#include <memory>
#include <optional>
#include <thread>
#include <chrono>
#include <QTimer>

namespace ohmytypeless {

class ClipboardService;
class GlobalHotkey;
class HudPresenter;
class MainWindow;
class SelectionService;
class AudioCaptureService;

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
                  AudioCaptureService* audio_capture,
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
    void on_active_profile_changed(const QString& profile_id);
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
    bool should_use_streaming_dictation() const;
    void start_streaming_dictation();
    void stop_streaming_dictation(const std::vector<float>& samples, std::optional<std::filesystem::path> audio_path);
    void transcribe_streaming_result_async(QString transcript,
                                           std::optional<std::filesystem::path> audio_path,
                                           nlohmann::json streaming_meta);
    void load_history();
    void refresh_audio_devices();
    void cancel_active_transcription();
    void cancel_streaming_session();
    void discard_active_recording_for_shutdown();
    void on_transcription_finished();
    void transcribe_async(std::vector<float> samples, std::optional<std::filesystem::path> audio_path);
    void transcribe_selection_command_async(TextTask task,
                                            std::vector<float> samples,
                                            std::optional<std::filesystem::path> audio_path,
                                            nlohmann::json streaming_meta = nlohmann::json::object());
    bool uses_double_press_selection_command() const;
    bool uses_system_audio_capture() const;
    bool active_profile_is_meeting() const;
    QString active_profile_name() const;
    void refresh_capture_mode_ui();
    void apply_active_profile_overrides();

    MainWindow* window_ = nullptr;
    ClipboardService* clipboard_ = nullptr;
    AudioCaptureService* audio_capture_ = nullptr;
    SelectionService* selection_ = nullptr;
    GlobalHotkey* hotkey_ = nullptr;
    HudPresenter* hud_ = nullptr;
    AppConfig config_;
    std::unique_ptr<HistoryStore> history_store_;
    std::unique_ptr<RecordingStore> recording_store_;
    std::unique_ptr<AsrBackend> asr_backend_;
    std::unique_ptr<StreamingAsrBackend> streaming_asr_backend_;
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
    std::optional<QString> captured_selection_text_;
    QString pending_selection_debug_info_;
    std::chrono::steady_clock::time_point recording_started_at_{};
    QTimer* selection_command_upgrade_timer_ = nullptr;
    std::unique_ptr<StreamingAsrSession> streaming_session_;
    std::thread streaming_connect_thread_;
    std::thread streaming_pump_thread_;
    std::shared_ptr<std::atomic_bool> streaming_pump_cancel_flag_;
    mutable std::mutex streaming_mutex_;
    std::condition_variable streaming_condition_;
    QString streaming_partial_text_;
    QString streaming_final_text_;
    QString streaming_error_text_;
    bool streaming_closed_ = false;
    bool streaming_active_ = false;
    bool streaming_session_ready_ = false;
    std::size_t streaming_samples_sent_ = 0;
    std::size_t streaming_chunk_count_ = 0;
    std::size_t streaming_partial_update_count_ = 0;
    std::size_t streaming_final_update_count_ = 0;
    std::chrono::steady_clock::time_point streaming_started_at_{};
    std::optional<std::chrono::steady_clock::time_point> streaming_ready_at_;
};

}  // namespace ohmytypeless
