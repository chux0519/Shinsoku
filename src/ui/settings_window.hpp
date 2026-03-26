#pragma once

#include "core/app_config.hpp"

#include <QList>
#include <QPair>
#include <QWidget>

class QCheckBox;
class QComboBox;
class QDoubleSpinBox;
class QLabel;
class QListWidget;
class QLineEdit;
class QPlainTextEdit;
class QPushButton;
class QRadioButton;
class QStackedWidget;
class QSpinBox;
class QToolButton;

namespace ohmytypeless {

class SettingsWindow final : public QWidget {
    Q_OBJECT
public:
    explicit SettingsWindow(QWidget* parent = nullptr);

    QString hold_key() const;
    QString hands_free_chord_key() const;
    QString selection_command_trigger() const;
    QString active_profile_id() const;
    std::vector<ProfileConfig> profiles() const;
    QString audio_capture_mode() const;
    QString selected_input_device_id() const;
    bool save_recordings_enabled() const;
    QString recordings_dir() const;
    QString rotation_mode() const;
    int max_files() const;
    bool copy_to_clipboard_enabled() const;
    bool paste_to_focused_window_enabled() const;
    QString paste_keys() const;
    bool proxy_enabled() const;
    QString proxy_type() const;
    QString proxy_host() const;
    int proxy_port() const;
    QString proxy_username() const;
    QString proxy_password() const;
    QString asr_base_url() const;
    QString asr_api_key() const;
    QString asr_model() const;
    bool streaming_enabled() const;
    QString streaming_provider() const;
    QString streaming_language() const;
    bool refine_enabled() const;
    QString refine_base_url() const;
    QString refine_api_key() const;
    QString refine_model() const;
    QString refine_system_prompt() const;
    QString soniox_url() const;
    QString soniox_api_key() const;
    QString soniox_model() const;
    QString bailian_region() const;
    QString bailian_url() const;
    QString bailian_api_key() const;
    QString bailian_model() const;
    bool vad_enabled() const;
    double vad_threshold() const;
    int vad_min_speech_duration_ms() const;
    bool record_metadata_enabled() const;
    bool record_timing_enabled() const;
    bool hud_enabled() const;
    int hud_bottom_margin() const;

    void set_hold_key(const QString& text);
    void set_hands_free_chord_key(const QString& text);
    void set_selection_command_trigger(const QString& text);
    void set_profiles(const std::vector<ProfileConfig>& profiles, const QString& active_profile_id);
    void set_audio_capture_mode(const QString& text);
    void set_audio_devices(const QList<QPair<QString, QString>>& devices, const QString& selected_device_id);
    void set_save_recordings_enabled(bool enabled);
    void set_recordings_dir(const QString& path);
    void set_rotation_mode(const QString& mode);
    void set_max_files(int value);
    void set_copy_to_clipboard_enabled(bool enabled);
    void set_paste_to_focused_window_enabled(bool enabled);
    void set_paste_keys(const QString& keys);
    void set_proxy_enabled(bool enabled);
    void set_proxy_type(const QString& type);
    void set_proxy_host(const QString& text);
    void set_proxy_port(int value);
    void set_proxy_username(const QString& text);
    void set_proxy_password(const QString& text);
    void set_asr_base_url(const QString& text);
    void set_asr_api_key(const QString& text);
    void set_asr_model(const QString& text);
    void set_streaming_enabled(bool enabled);
    void set_streaming_provider(const QString& text);
    void set_streaming_language(const QString& text);
    void set_refine_enabled(bool enabled);
    void set_refine_base_url(const QString& text);
    void set_refine_api_key(const QString& text);
    void set_refine_model(const QString& text);
    void set_refine_system_prompt(const QString& text);
    void set_soniox_url(const QString& text);
    void set_soniox_api_key(const QString& text);
    void set_soniox_model(const QString& text);
    void set_bailian_region(const QString& text);
    void set_bailian_url(const QString& text);
    void set_bailian_api_key(const QString& text);
    void set_bailian_model(const QString& text);
    void set_vad_enabled(bool enabled);
    void set_vad_threshold(double value);
    void set_vad_min_speech_duration_ms(int value);
    void set_record_metadata_enabled(bool enabled);
    void set_record_timing_enabled(bool enabled);
    void set_hud_enabled(bool enabled);
    void set_hud_bottom_margin(int value);
    void set_global_hotkeys_available(bool available, const QString& reason = {});
    void set_auto_paste_available(bool available, const QString& reason = {});
    void set_system_audio_available(bool available, const QString& reason = {});
    void set_status_text(const QString& text);

signals:
    void apply_clicked();

private:
    void refresh_capability_dependent_controls();
    void refresh_profile_list();
    void load_profile_into_editor(int index);
    void store_editor_into_profile(int index);
    QString next_profile_id(const QString& seed) const;

    QListWidget* navigation_list_ = nullptr;
    QStackedWidget* page_stack_ = nullptr;
    QComboBox* hold_key_combo_ = nullptr;
    QComboBox* hands_free_chord_combo_ = nullptr;
    QComboBox* selection_command_trigger_combo_ = nullptr;
    QListWidget* profiles_list_ = nullptr;
    QPushButton* profile_new_button_ = nullptr;
    QPushButton* profile_duplicate_button_ = nullptr;
    QPushButton* profile_delete_button_ = nullptr;
    QLabel* active_profile_hint_label_ = nullptr;
    QLineEdit* profile_name_edit_ = nullptr;
    QComboBox* profile_kind_combo_ = nullptr;
    QCheckBox* profile_enabled_check_ = nullptr;
    QCheckBox* profile_prefer_streaming_check_ = nullptr;
    QComboBox* profile_streaming_provider_combo_ = nullptr;
    QLineEdit* profile_language_hint_edit_ = nullptr;
    QCheckBox* profile_transform_enabled_check_ = nullptr;
    QComboBox* profile_prompt_mode_combo_ = nullptr;
    QPlainTextEdit* profile_custom_prompt_edit_ = nullptr;
    QCheckBox* profile_copy_check_ = nullptr;
    QCheckBox* profile_paste_check_ = nullptr;
    QComboBox* profile_paste_keys_combo_ = nullptr;
    QPlainTextEdit* profile_notes_edit_ = nullptr;
    QComboBox* audio_capture_mode_combo_ = nullptr;
    QComboBox* input_device_combo_ = nullptr;
    QCheckBox* save_recordings_check_ = nullptr;
    QLineEdit* recordings_dir_edit_ = nullptr;
    QPushButton* recordings_dir_button_ = nullptr;
    QComboBox* rotation_mode_combo_ = nullptr;
    QSpinBox* max_files_spin_ = nullptr;
    QCheckBox* copy_to_clipboard_check_ = nullptr;
    QCheckBox* paste_to_focused_window_check_ = nullptr;
    QComboBox* paste_keys_combo_ = nullptr;
    QCheckBox* proxy_enabled_check_ = nullptr;
    QComboBox* proxy_type_combo_ = nullptr;
    QLineEdit* proxy_host_edit_ = nullptr;
    QSpinBox* proxy_port_spin_ = nullptr;
    QLineEdit* proxy_username_edit_ = nullptr;
    QLineEdit* proxy_password_edit_ = nullptr;
    QLineEdit* asr_base_url_edit_ = nullptr;
    QLineEdit* asr_api_key_edit_ = nullptr;
    QLineEdit* asr_model_edit_ = nullptr;
    QCheckBox* streaming_enabled_check_ = nullptr;
    QComboBox* streaming_provider_combo_ = nullptr;
    QLineEdit* streaming_language_edit_ = nullptr;
    QCheckBox* refine_enabled_check_ = nullptr;
    QLineEdit* refine_base_url_edit_ = nullptr;
    QLineEdit* refine_api_key_edit_ = nullptr;
    QLineEdit* refine_model_edit_ = nullptr;
    QPlainTextEdit* refine_system_prompt_edit_ = nullptr;
    QLineEdit* soniox_url_edit_ = nullptr;
    QLineEdit* soniox_api_key_edit_ = nullptr;
    QComboBox* soniox_model_combo_ = nullptr;
    QToolButton* soniox_help_button_ = nullptr;
    QComboBox* bailian_region_combo_ = nullptr;
    QLineEdit* bailian_url_edit_ = nullptr;
    QLineEdit* bailian_api_key_edit_ = nullptr;
    QComboBox* bailian_model_combo_ = nullptr;
    QToolButton* bailian_help_button_ = nullptr;
    QCheckBox* vad_enabled_check_ = nullptr;
    QDoubleSpinBox* vad_threshold_spin_ = nullptr;
    QSpinBox* vad_min_duration_spin_ = nullptr;
    QCheckBox* record_metadata_check_ = nullptr;
    QCheckBox* record_timing_check_ = nullptr;
    QCheckBox* hud_enabled_check_ = nullptr;
    QSpinBox* hud_bottom_margin_spin_ = nullptr;
    QLabel* status_label_ = nullptr;
    std::vector<ProfileConfig> profiles_;
    QString active_profile_id_;
    int profile_editor_index_ = -1;
    bool syncing_profiles_ = false;
    bool global_hotkeys_available_ = true;
    bool auto_paste_available_ = true;
    bool system_audio_available_ = true;
    QString global_hotkeys_reason_;
    QString auto_paste_reason_;
    QString system_audio_reason_;
};

}  // namespace ohmytypeless
