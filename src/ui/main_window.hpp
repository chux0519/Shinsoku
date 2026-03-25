#pragma once

#include "core/app_state.hpp"

#include <QMainWindow>
#include <vector>

class QAction;
class QComboBox;
class QLabel;
class QPushButton;
class QSystemTrayIcon;

namespace ohmytypeless {

class HistoryWindow;
class SettingsWindow;

class MainWindow final : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(QWidget* parent = nullptr);
    ~MainWindow() override;

    void set_session_state(SessionState state);
    void set_status_text(const QString& text);
    void set_tray_available(bool available);
    void update_history(const QList<HistoryEntry>& entries);
    void set_profiles(const std::vector<std::pair<QString, QString>>& profiles, const QString& active_profile_id);
    void set_selection_command_available(bool available, const QString& reason = {});

    SettingsWindow* settings_window() const;
    HistoryWindow* history_window() const;

signals:
    void toggle_recording_requested();
    void arm_selection_command_requested();
    void register_hotkey_requested();
    void active_profile_changed_requested(const QString& profile_id);
    void show_history_requested();
    void show_settings_requested();
    void quit_requested();

private:
    void setup_tray();
    void refresh_tray_state(SessionState state);

    QLabel* state_badge_label_ = nullptr;
    QLabel* status_label_ = nullptr;
    QComboBox* profile_combo_ = nullptr;
    QPushButton* record_button_ = nullptr;
    QPushButton* selection_command_button_ = nullptr;
    QSystemTrayIcon* tray_icon_ = nullptr;
    QAction* tray_state_action_ = nullptr;
    SessionState tray_state_ = SessionState::Idle;
    SettingsWindow* settings_window_ = nullptr;
    HistoryWindow* history_window_ = nullptr;
};

}  // namespace ohmytypeless
