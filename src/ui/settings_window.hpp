#pragma once

#include <QList>
#include <QPair>
#include <QWidget>

class QCheckBox;
class QComboBox;
class QLabel;
class QLineEdit;

namespace ohmytypeless {

class SettingsWindow final : public QWidget {
    Q_OBJECT
public:
    explicit SettingsWindow(QWidget* parent = nullptr);

    QString hotkey_sequence() const;
    QString selected_input_device_id() const;
    bool save_recordings_enabled() const;
    QString recordings_dir() const;
    QString asr_base_url() const;
    QString asr_api_key() const;
    QString asr_model() const;
    bool refine_enabled() const;
    QString refine_base_url() const;
    QString refine_api_key() const;
    QString refine_model() const;
    void set_hotkey_sequence(const QString& text);
    void set_audio_devices(const QList<QPair<QString, QString>>& devices, const QString& selected_device_id);
    void set_save_recordings_enabled(bool enabled);
    void set_recordings_dir(const QString& path);
    void set_asr_base_url(const QString& text);
    void set_asr_api_key(const QString& text);
    void set_asr_model(const QString& text);
    void set_refine_enabled(bool enabled);
    void set_refine_base_url(const QString& text);
    void set_refine_api_key(const QString& text);
    void set_refine_model(const QString& text);
    void set_status_text(const QString& text);

signals:
    void apply_clicked();

private:
    QLineEdit* hotkey_edit_ = nullptr;
    QComboBox* input_device_combo_ = nullptr;
    QCheckBox* save_recordings_check_ = nullptr;
    QLineEdit* recordings_dir_edit_ = nullptr;
    QLineEdit* asr_base_url_edit_ = nullptr;
    QLineEdit* asr_api_key_edit_ = nullptr;
    QLineEdit* asr_model_edit_ = nullptr;
    QCheckBox* refine_enabled_check_ = nullptr;
    QLineEdit* refine_base_url_edit_ = nullptr;
    QLineEdit* refine_api_key_edit_ = nullptr;
    QLineEdit* refine_model_edit_ = nullptr;
    QLabel* status_label_ = nullptr;
};

}  // namespace ohmytypeless
