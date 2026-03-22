#pragma once

#include "core/app_config.hpp"
#include "core/app_state.hpp"
#include "core/audio_recorder.hpp"
#include "core/asr_client.hpp"
#include "core/history_store.hpp"
#include "core/recording_store.hpp"
#include "core/text_refiner.hpp"

#include <QFutureWatcher>
#include <QObject>
#include <QtGlobal>

#include <atomic>
#include <filesystem>
#include <memory>
#include <optional>

namespace ohmytypeless {

class ClipboardService;
class GlobalHotkey;
class HudPresenter;
class MainWindow;

struct TranscriptionResult {
    quint64 job_id = 0;
    QString text;
    QString summary;
    QString error_text;
    bool cancelled = false;
    std::optional<std::filesystem::path> audio_path;
};

class AppController final : public QObject {
    Q_OBJECT
public:
    AppController(MainWindow* window,
                  ClipboardService* clipboard,
                  GlobalHotkey* hotkey,
                  HudPresenter* hud,
                  QObject* parent = nullptr);

    void initialize();

private slots:
    void toggle_recording();
    void copy_demo_text();
    void apply_settings();
    void show_history();
    void show_settings();
    void quit_application();
    void on_hotkey_activated();
    void on_hotkey_failed(const QString& reason);

private:
    void set_state(SessionState state, const QString& status);
    void seed_history();
    void load_history();
    void refresh_audio_devices();
    void cancel_active_transcription();
    void on_transcription_finished();
    void transcribe_async(std::vector<float> samples, std::optional<std::filesystem::path> audio_path);

    MainWindow* window_ = nullptr;
    ClipboardService* clipboard_ = nullptr;
    GlobalHotkey* hotkey_ = nullptr;
    HudPresenter* hud_ = nullptr;
    AppConfig config_;
    AudioRecorder recorder_;
    std::unique_ptr<HistoryStore> history_store_;
    std::unique_ptr<RecordingStore> recording_store_;
    std::unique_ptr<QFutureWatcher<TranscriptionResult>> transcription_watcher_;
    std::shared_ptr<std::atomic_bool> transcription_cancel_flag_;
    QList<QPair<QString, QString>> audio_devices_;
    SessionState state_ = SessionState::Idle;
    QList<HistoryEntry> history_;
    quint64 next_transcription_job_id_ = 1;
    quint64 active_transcription_job_id_ = 0;
    bool shutting_down_ = false;
};

}  // namespace ohmytypeless
