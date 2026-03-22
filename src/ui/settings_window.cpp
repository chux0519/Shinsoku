#include "ui/settings_window.hpp"

#include <QCheckBox>
#include <QComboBox>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QVBoxLayout>

namespace ohmytypeless {

SettingsWindow::SettingsWindow(QWidget* parent) : QWidget(parent) {
    setWindowTitle("Settings");
    resize(640, 420);

    auto* layout = new QVBoxLayout(this);
    auto* form = new QFormLayout();

    hotkey_edit_ = new QLineEdit("ctrl+alt+space", this);
    form->addRow("Global Hotkey", hotkey_edit_);

    input_device_combo_ = new QComboBox(this);
    form->addRow("Input Device", input_device_combo_);

    save_recordings_check_ = new QCheckBox("Save recordings as .wav", this);
    form->addRow("Recording", save_recordings_check_);

    recordings_dir_edit_ = new QLineEdit(this);
    form->addRow("Recordings Dir", recordings_dir_edit_);

    asr_base_url_edit_ = new QLineEdit(this);
    form->addRow("ASR Base URL", asr_base_url_edit_);

    asr_api_key_edit_ = new QLineEdit(this);
    asr_api_key_edit_->setEchoMode(QLineEdit::Password);
    form->addRow("ASR API Key", asr_api_key_edit_);

    asr_model_edit_ = new QLineEdit(this);
    form->addRow("ASR Model", asr_model_edit_);

    refine_enabled_check_ = new QCheckBox("Run second-pass text refine", this);
    form->addRow("Refine", refine_enabled_check_);

    refine_base_url_edit_ = new QLineEdit(this);
    form->addRow("Refine Base URL", refine_base_url_edit_);

    refine_api_key_edit_ = new QLineEdit(this);
    refine_api_key_edit_->setEchoMode(QLineEdit::Password);
    form->addRow("Refine API Key", refine_api_key_edit_);

    refine_model_edit_ = new QLineEdit(this);
    form->addRow("Refine Model", refine_model_edit_);

    layout->addLayout(form);

    auto* button = new QPushButton("Apply", this);
    layout->addWidget(button);

    status_label_ = new QLabel(this);
    status_label_->setWordWrap(true);
    layout->addWidget(status_label_);

    connect(button, &QPushButton::clicked, this, &SettingsWindow::apply_clicked);
}

QString SettingsWindow::hotkey_sequence() const {
    return hotkey_edit_->text().trimmed();
}

QString SettingsWindow::selected_input_device_id() const {
    return input_device_combo_->currentData().toString();
}

bool SettingsWindow::save_recordings_enabled() const {
    return save_recordings_check_->isChecked();
}

QString SettingsWindow::recordings_dir() const {
    return recordings_dir_edit_->text().trimmed();
}

QString SettingsWindow::asr_base_url() const {
    return asr_base_url_edit_->text().trimmed();
}

QString SettingsWindow::asr_api_key() const {
    return asr_api_key_edit_->text();
}

QString SettingsWindow::asr_model() const {
    return asr_model_edit_->text().trimmed();
}

bool SettingsWindow::refine_enabled() const {
    return refine_enabled_check_->isChecked();
}

QString SettingsWindow::refine_base_url() const {
    return refine_base_url_edit_->text().trimmed();
}

QString SettingsWindow::refine_api_key() const {
    return refine_api_key_edit_->text();
}

QString SettingsWindow::refine_model() const {
    return refine_model_edit_->text().trimmed();
}

void SettingsWindow::set_hotkey_sequence(const QString& text) {
    hotkey_edit_->setText(text);
}

void SettingsWindow::set_audio_devices(const QList<QPair<QString, QString>>& devices, const QString& selected_device_id) {
    input_device_combo_->clear();
    for (const auto& device : devices) {
        input_device_combo_->addItem(device.second, device.first);
    }

    const int index = input_device_combo_->findData(selected_device_id);
    if (index >= 0) {
        input_device_combo_->setCurrentIndex(index);
    } else if (input_device_combo_->count() > 0) {
        input_device_combo_->setCurrentIndex(0);
    }
}

void SettingsWindow::set_save_recordings_enabled(bool enabled) {
    save_recordings_check_->setChecked(enabled);
}

void SettingsWindow::set_recordings_dir(const QString& path) {
    recordings_dir_edit_->setText(path);
}

void SettingsWindow::set_asr_base_url(const QString& text) {
    asr_base_url_edit_->setText(text);
}

void SettingsWindow::set_asr_api_key(const QString& text) {
    asr_api_key_edit_->setText(text);
}

void SettingsWindow::set_asr_model(const QString& text) {
    asr_model_edit_->setText(text);
}

void SettingsWindow::set_refine_enabled(bool enabled) {
    refine_enabled_check_->setChecked(enabled);
}

void SettingsWindow::set_refine_base_url(const QString& text) {
    refine_base_url_edit_->setText(text);
}

void SettingsWindow::set_refine_api_key(const QString& text) {
    refine_api_key_edit_->setText(text);
}

void SettingsWindow::set_refine_model(const QString& text) {
    refine_model_edit_->setText(text);
}

void SettingsWindow::set_status_text(const QString& text) {
    status_label_->setText(text);
}

}  // namespace ohmytypeless
