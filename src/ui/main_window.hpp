#pragma once

#include "core/app_state.hpp"

#include <QEvent>
#include <QKeyEvent>
#include <QCloseEvent>
#include <QMainWindow>
#include <vector>

class QAction;
class QComboBox;
class QLabel;
class QMenu;
class QPushButton;
class QSystemTrayIcon;

namespace ohmytypeless {

class HistoryWindow;
class MeetingTranscriptionWindow;
class SettingsWindow;

class MainWindow final : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(QWidget* parent = nullptr);
    ~MainWindow() override;

    void set_session_state(SessionState state);
    void set_status_text(const QString& text);
    void set_tray_available(bool available);
    void update_history(const std::vector<HistoryEntry>& entries);
    void set_profiles(const std::vector<std::pair<QString, QString>>& profiles, const QString& active_profile_id);
    void set_selection_command_available(bool available, const QString& reason = {});
    void set_tray_icon_theme(const QString& theme);
    void refresh_tray_icon();

    SettingsWindow* settings_window() const;
    HistoryWindow* history_window() const;
    MeetingTranscriptionWindow* meeting_window() const;
    void set_hotkey_passthrough_keys(const QString& hold_key_name, const QString& chord_key_name);
    bool nativeEvent(const QByteArray& event_type, void* message, qintptr* result) override;

signals:
    void toggle_recording_requested();
    void arm_selection_command_requested();
    void register_hotkey_requested();
    void active_profile_changed_requested(const QString& profile_id);
    void show_history_requested();
    void show_settings_requested();
    void quit_requested();

private:
    void closeEvent(QCloseEvent* event) override;
    bool eventFilter(QObject* watched, QEvent* event) override;
    static int qt_key_from_evdev_name(const QString& key_name);
    bool should_consume_hotkey_event(QKeyEvent* event) const;
    bool has_visible_app_window() const;
    void present_main_window();
    void setup_tray();
    void refresh_tray_state(SessionState state);

    QLabel* state_badge_label_ = nullptr;
    QLabel* status_label_ = nullptr;
    QComboBox* profile_combo_ = nullptr;
    QPushButton* record_button_ = nullptr;
    QPushButton* selection_command_button_ = nullptr;
    QSystemTrayIcon* tray_icon_ = nullptr;
    QMenu* tray_menu_ = nullptr;
    QAction* tray_state_action_ = nullptr;
    SessionState tray_state_ = SessionState::Idle;
    QString tray_icon_theme_ = "auto";
    QString last_tray_error_message_;
    SettingsWindow* settings_window_ = nullptr;
    HistoryWindow* history_window_ = nullptr;
    MeetingTranscriptionWindow* meeting_window_ = nullptr;
    int hold_qt_key_ = 0;
    int chord_qt_key_ = 0;
};

}  // namespace ohmytypeless
