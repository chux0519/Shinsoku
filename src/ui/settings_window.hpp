#pragma once

#include <QList>
#include <QPair>
#include <QWidget>

class QCheckBox;
class QComboBox;
class QDoubleSpinBox;
class QLabel;
class QLineEdit;
class QPlainTextEdit;
class QPushButton;
class QSpinBox;

namespace ohmytypeless {

class SettingsWindow final : public QWidget {
    Q_OBJECT
public:
    explicit SettingsWindow(QWidget* parent = nullptr);

    QString hold_key() const;
    QString hands_free_chord_key() const;
    QString selected_input_device_id() const;
    bool save_recordings_enabled() const;
    QString recordings_dir() const;
    QString rotation_mode() const;
    int max_files() const;
    bool copy_to_clipboard_enabled() const;
    bool paste_to_focused_window_enabled() const;
    QString paste_keys() const;
    QString asr_base_url() const;
    QString asr_api_key() const;
    QString asr_model() const;
    bool refine_enabled() const;
    QString refine_base_url() const;
    QString refine_api_key() const;
    QString refine_model() const;
    QString refine_system_prompt() const;
    bool vad_enabled() const;
    double vad_threshold() const;
    int vad_min_speech_duration_ms() const;
    bool record_metadata_enabled() const;
    bool record_timing_enabled() const;
    bool hud_enabled() const;
    int hud_bottom_margin() const;

    void set_hold_key(const QString& text);
    void set_hands_free_chord_key(const QString& text);
    void set_audio_devices(const QList<QPair<QString, QString>>& devices, const QString& selected_device_id);
    void set_save_recordings_enabled(bool enabled);
    void set_recordings_dir(const QString& path);
    void set_rotation_mode(const QString& mode);
    void set_max_files(int value);
    void set_copy_to_clipboard_enabled(bool enabled);
    void set_paste_to_focused_window_enabled(bool enabled);
    void set_paste_keys(const QString& keys);
    void set_asr_base_url(const QString& text);
    void set_asr_api_key(const QString& text);
    void set_asr_model(const QString& text);
    void set_refine_enabled(bool enabled);
    void set_refine_base_url(const QString& text);
    void set_refine_api_key(const QString& text);
    void set_refine_model(const QString& text);
    void set_refine_system_prompt(const QString& text);
    void set_vad_enabled(bool enabled);
    void set_vad_threshold(double value);
    void set_vad_min_speech_duration_ms(int value);
    void set_record_metadata_enabled(bool enabled);
    void set_record_timing_enabled(bool enabled);
    void set_hud_enabled(bool enabled);
    void set_hud_bottom_margin(int value);
    void set_status_text(const QString& text);

signals:
    void apply_clicked();

private:
    QComboBox* hold_key_combo_ = nullptr;
    QComboBox* hands_free_chord_combo_ = nullptr;
    QComboBox* input_device_combo_ = nullptr;
    QCheckBox* save_recordings_check_ = nullptr;
    QLineEdit* recordings_dir_edit_ = nullptr;
    QPushButton* recordings_dir_button_ = nullptr;
    QComboBox* rotation_mode_combo_ = nullptr;
    QSpinBox* max_files_spin_ = nullptr;
    QCheckBox* copy_to_clipboard_check_ = nullptr;
    QCheckBox* paste_to_focused_window_check_ = nullptr;
    QComboBox* paste_keys_combo_ = nullptr;
    QLineEdit* asr_base_url_edit_ = nullptr;
    QLineEdit* asr_api_key_edit_ = nullptr;
    QLineEdit* asr_model_edit_ = nullptr;
    QCheckBox* refine_enabled_check_ = nullptr;
    QLineEdit* refine_base_url_edit_ = nullptr;
    QLineEdit* refine_api_key_edit_ = nullptr;
    QLineEdit* refine_model_edit_ = nullptr;
    QPlainTextEdit* refine_system_prompt_edit_ = nullptr;
    QCheckBox* vad_enabled_check_ = nullptr;
    QDoubleSpinBox* vad_threshold_spin_ = nullptr;
    QSpinBox* vad_min_duration_spin_ = nullptr;
    QCheckBox* record_metadata_check_ = nullptr;
    QCheckBox* record_timing_check_ = nullptr;
    QCheckBox* hud_enabled_check_ = nullptr;
    QSpinBox* hud_bottom_margin_spin_ = nullptr;
    QLabel* status_label_ = nullptr;
};

}  // namespace ohmytypeless
