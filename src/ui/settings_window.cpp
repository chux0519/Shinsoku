#include "ui/settings_window.hpp"

#include <QCheckBox>
#include <QComboBox>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QFileDialog>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QScrollArea>
#include <QSpinBox>
#include <QVBoxLayout>

namespace ohmytypeless {

namespace {

QGroupBox* make_section(const QString& title, QWidget* parent, QFormLayout** form_out) {
    auto* box = new QGroupBox(title, parent);
    box->setObjectName("sectionCard");
    auto* layout = new QFormLayout(box);
    layout->setContentsMargins(22, 26, 22, 22);
    layout->setHorizontalSpacing(18);
    layout->setVerticalSpacing(14);
    layout->setFieldGrowthPolicy(QFormLayout::ExpandingFieldsGrow);
    box->setLayout(layout);
    if (form_out != nullptr) {
        *form_out = layout;
    }
    return box;
}

QComboBox* make_key_combo(QWidget* parent) {
    auto* combo = new QComboBox(parent);
    combo->addItem("Right Alt", "KEY_RIGHTALT");
    combo->addItem("Left Alt", "KEY_LEFTALT");
    combo->addItem("Space", "KEY_SPACE");
    combo->addItem("Right Ctrl", "KEY_RIGHTCTRL");
    combo->addItem("Left Ctrl", "KEY_LEFTCTRL");
    combo->addItem("Right Shift", "KEY_RIGHTSHIFT");
    combo->addItem("Left Shift", "KEY_LEFTSHIFT");
    return combo;
}

void set_combo_by_value(QComboBox* combo, const QString& value) {
    const int index = combo->findData(value);
    if (index >= 0) {
        combo->setCurrentIndex(index);
    }
}

}  // namespace

SettingsWindow::SettingsWindow(QWidget* parent) : QWidget(parent) {
    setWindowTitle("Settings");
    resize(760, 720);
    setMinimumSize(720, 640);

    auto* root_layout = new QVBoxLayout(this);
    root_layout->setContentsMargins(22, 20, 22, 20);
    root_layout->setSpacing(16);
    auto* scroll = new QScrollArea(this);
    scroll->setWidgetResizable(true);
    root_layout->addWidget(scroll);

    auto* content = new QWidget(scroll);
    auto* content_layout = new QVBoxLayout(content);
    content_layout->setContentsMargins(4, 4, 4, 4);
    content_layout->setSpacing(16);
    scroll->setWidget(content);

    auto* header_card = new QGroupBox(content);
    header_card->setObjectName("headerCard");
    auto* header_layout = new QVBoxLayout(header_card);
    header_layout->setContentsMargins(24, 22, 24, 22);
    header_layout->setSpacing(8);
    auto* header_eyebrow = new QLabel("Workspace Control", header_card);
    header_eyebrow->setObjectName("headerEyebrow");
    auto* header_title = new QLabel("Tune capture, output, and refinement in one place.", header_card);
    header_title->setObjectName("headerTitle");
    header_title->setWordWrap(true);
    auto* header_body = new QLabel("The defaults are optimized for quick dictation. Adjust routing, observability, and cleanup behavior here without digging through config files.", header_card);
    header_body->setObjectName("headerBody");
    header_body->setWordWrap(true);
    header_layout->addWidget(header_eyebrow);
    header_layout->addWidget(header_title);
    header_layout->addWidget(header_body);
    content_layout->addWidget(header_card);

    QFormLayout* hotkey_form = nullptr;
    auto* hotkey_section = make_section("Hotkey", content, &hotkey_form);
    hold_key_combo_ = make_key_combo(hotkey_section);
    hands_free_chord_combo_ = make_key_combo(hotkey_section);
    hotkey_form->addRow("Hold Key", hold_key_combo_);
    hotkey_form->addRow("Hands-free Chord", hands_free_chord_combo_);
    content_layout->addWidget(hotkey_section);

    QFormLayout* audio_form = nullptr;
    auto* audio_section = make_section("Audio", content, &audio_form);
    input_device_combo_ = new QComboBox(audio_section);
    save_recordings_check_ = new QCheckBox("Save recordings as .wav", audio_section);
    auto* recordings_dir_row = new QWidget(audio_section);
    recordings_dir_row->setObjectName("inlineFieldRow");
    auto* recordings_dir_layout = new QHBoxLayout(recordings_dir_row);
    recordings_dir_layout->setContentsMargins(0, 0, 0, 0);
    recordings_dir_edit_ = new QLineEdit(recordings_dir_row);
    recordings_dir_button_ = new QPushButton("Choose", recordings_dir_row);
    recordings_dir_layout->addWidget(recordings_dir_edit_);
    recordings_dir_layout->addWidget(recordings_dir_button_);
    rotation_mode_combo_ = new QComboBox(audio_section);
    rotation_mode_combo_->addItem("disabled");
    rotation_mode_combo_->addItem("max_files");
    max_files_spin_ = new QSpinBox(audio_section);
    max_files_spin_->setRange(1, 100000);
    max_files_spin_->setValue(50);
    audio_form->addRow("Input Device", input_device_combo_);
    audio_form->addRow("Recording", save_recordings_check_);
    audio_form->addRow("Recordings Dir", recordings_dir_row);
    audio_form->addRow("Rotation Mode", rotation_mode_combo_);
    audio_form->addRow("Max Files", max_files_spin_);
    content_layout->addWidget(audio_section);

    QFormLayout* output_form = nullptr;
    auto* output_section = make_section("Output", content, &output_form);
    copy_to_clipboard_check_ = new QCheckBox("Copy text to clipboard", output_section);
    paste_to_focused_window_check_ = new QCheckBox("Paste into focused window", output_section);
    paste_keys_combo_ = new QComboBox(output_section);
    paste_keys_combo_->addItem("ctrl+shift+v");
    paste_keys_combo_->addItem("ctrl+v");
    paste_keys_combo_->addItem("shift+insert");
    output_form->addRow("Clipboard", copy_to_clipboard_check_);
    output_form->addRow("Auto Paste", paste_to_focused_window_check_);
    output_form->addRow("Paste Keys", paste_keys_combo_);
    content_layout->addWidget(output_section);

    QFormLayout* network_form = nullptr;
    auto* network_section = make_section("Network", content, &network_form);
    proxy_enabled_check_ = new QCheckBox("Route HTTP requests through a proxy", network_section);
    proxy_type_combo_ = new QComboBox(network_section);
    proxy_type_combo_->addItem("HTTP", "http");
    proxy_type_combo_->addItem("SOCKS5", "socks5");
    proxy_host_edit_ = new QLineEdit(network_section);
    proxy_port_spin_ = new QSpinBox(network_section);
    proxy_port_spin_->setRange(1, 65535);
    proxy_port_spin_->setValue(8080);
    proxy_username_edit_ = new QLineEdit(network_section);
    proxy_password_edit_ = new QLineEdit(network_section);
    proxy_password_edit_->setEchoMode(QLineEdit::Password);
    network_form->addRow("Enabled", proxy_enabled_check_);
    network_form->addRow("Type", proxy_type_combo_);
    network_form->addRow("Host", proxy_host_edit_);
    network_form->addRow("Port", proxy_port_spin_);
    network_form->addRow("Username", proxy_username_edit_);
    network_form->addRow("Password", proxy_password_edit_);
    content_layout->addWidget(network_section);

    QFormLayout* asr_form = nullptr;
    auto* asr_section = make_section("ASR", content, &asr_form);
    asr_base_url_edit_ = new QLineEdit(asr_section);
    asr_api_key_edit_ = new QLineEdit(asr_section);
    asr_api_key_edit_->setEchoMode(QLineEdit::Password);
    asr_model_edit_ = new QLineEdit(asr_section);
    asr_form->addRow("Base URL", asr_base_url_edit_);
    asr_form->addRow("API Key", asr_api_key_edit_);
    asr_form->addRow("Model", asr_model_edit_);
    content_layout->addWidget(asr_section);

    QFormLayout* refine_form = nullptr;
    auto* refine_section = make_section("Refine", content, &refine_form);
    refine_enabled_check_ = new QCheckBox("Run second-pass text refine", refine_section);
    refine_base_url_edit_ = new QLineEdit(refine_section);
    refine_api_key_edit_ = new QLineEdit(refine_section);
    refine_api_key_edit_->setEchoMode(QLineEdit::Password);
    refine_model_edit_ = new QLineEdit(refine_section);
    refine_system_prompt_edit_ = new QPlainTextEdit(refine_section);
    refine_system_prompt_edit_->setMinimumHeight(140);
    refine_form->addRow("Enabled", refine_enabled_check_);
    refine_form->addRow("Base URL", refine_base_url_edit_);
    refine_form->addRow("API Key", refine_api_key_edit_);
    refine_form->addRow("Model", refine_model_edit_);
    refine_form->addRow("System Prompt", refine_system_prompt_edit_);
    content_layout->addWidget(refine_section);

    QFormLayout* vad_form = nullptr;
    auto* vad_section = make_section("VAD", content, &vad_form);
    vad_enabled_check_ = new QCheckBox("Skip silence-only recordings", vad_section);
    vad_threshold_spin_ = new QDoubleSpinBox(vad_section);
    vad_threshold_spin_->setRange(0.0, 1.0);
    vad_threshold_spin_->setSingleStep(0.05);
    vad_threshold_spin_->setDecimals(2);
    vad_min_duration_spin_ = new QSpinBox(vad_section);
    vad_min_duration_spin_->setRange(20, 5000);
    vad_min_duration_spin_->setValue(100);
    vad_form->addRow("Enabled", vad_enabled_check_);
    vad_form->addRow("Threshold", vad_threshold_spin_);
    vad_form->addRow("Min Speech (ms)", vad_min_duration_spin_);
    content_layout->addWidget(vad_section);

    QFormLayout* observability_form = nullptr;
    auto* observability_section = make_section("Observability", content, &observability_form);
    record_metadata_check_ = new QCheckBox("Store pipeline metadata in history", observability_section);
    record_timing_check_ = new QCheckBox("Store timing in history", observability_section);
    observability_form->addRow("Metadata", record_metadata_check_);
    observability_form->addRow("Timing", record_timing_check_);
    content_layout->addWidget(observability_section);

    QFormLayout* hud_form = nullptr;
    auto* hud_section = make_section("HUD", content, &hud_form);
    hud_enabled_check_ = new QCheckBox("Show overlay while recording/transcribing", hud_section);
    hud_bottom_margin_spin_ = new QSpinBox(hud_section);
    hud_bottom_margin_spin_->setRange(0, 400);
    hud_bottom_margin_spin_->setValue(104);
    hud_form->addRow("Enabled", hud_enabled_check_);
    hud_form->addRow("Bottom Margin", hud_bottom_margin_spin_);
    content_layout->addWidget(hud_section);

    auto* actions = new QHBoxLayout();
    actions->addStretch();
    auto* button = new QPushButton("Apply", this);
    button->setObjectName("applyButton");
    actions->addWidget(button);
    root_layout->addLayout(actions);

    status_label_ = new QLabel(this);
    status_label_->setObjectName("statusBanner");
    status_label_->setWordWrap(true);
    root_layout->addWidget(status_label_);

    connect(button, &QPushButton::clicked, this, &SettingsWindow::apply_clicked);
    connect(recordings_dir_button_, &QPushButton::clicked, this, [this]() {
        const QString selected = QFileDialog::getExistingDirectory(this, "Choose Recordings Directory", recordings_dir());
        if (!selected.isEmpty()) {
            recordings_dir_edit_->setText(selected);
        }
    });
}

QString SettingsWindow::hold_key() const {
    return hold_key_combo_->currentData().toString();
}

QString SettingsWindow::hands_free_chord_key() const {
    return hands_free_chord_combo_->currentData().toString();
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

QString SettingsWindow::rotation_mode() const {
    return rotation_mode_combo_->currentText();
}

int SettingsWindow::max_files() const {
    return max_files_spin_->value();
}

bool SettingsWindow::copy_to_clipboard_enabled() const {
    return copy_to_clipboard_check_->isChecked();
}

bool SettingsWindow::paste_to_focused_window_enabled() const {
    return paste_to_focused_window_check_->isChecked();
}

QString SettingsWindow::paste_keys() const {
    return paste_keys_combo_->currentText();
}

bool SettingsWindow::proxy_enabled() const {
    return proxy_enabled_check_->isChecked();
}

QString SettingsWindow::proxy_type() const {
    return proxy_type_combo_->currentData().toString();
}

QString SettingsWindow::proxy_host() const {
    return proxy_host_edit_->text().trimmed();
}

int SettingsWindow::proxy_port() const {
    return proxy_port_spin_->value();
}

QString SettingsWindow::proxy_username() const {
    return proxy_username_edit_->text().trimmed();
}

QString SettingsWindow::proxy_password() const {
    return proxy_password_edit_->text();
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

QString SettingsWindow::refine_system_prompt() const {
    return refine_system_prompt_edit_->toPlainText().trimmed();
}

bool SettingsWindow::vad_enabled() const {
    return vad_enabled_check_->isChecked();
}

double SettingsWindow::vad_threshold() const {
    return vad_threshold_spin_->value();
}

int SettingsWindow::vad_min_speech_duration_ms() const {
    return vad_min_duration_spin_->value();
}

bool SettingsWindow::record_metadata_enabled() const {
    return record_metadata_check_->isChecked();
}

bool SettingsWindow::record_timing_enabled() const {
    return record_timing_check_->isChecked();
}

bool SettingsWindow::hud_enabled() const {
    return hud_enabled_check_->isChecked();
}

int SettingsWindow::hud_bottom_margin() const {
    return hud_bottom_margin_spin_->value();
}

void SettingsWindow::set_hold_key(const QString& text) {
    set_combo_by_value(hold_key_combo_, text);
}

void SettingsWindow::set_hands_free_chord_key(const QString& text) {
    set_combo_by_value(hands_free_chord_combo_, text);
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

void SettingsWindow::set_rotation_mode(const QString& mode) {
    const int index = rotation_mode_combo_->findText(mode);
    if (index >= 0) {
        rotation_mode_combo_->setCurrentIndex(index);
    }
}

void SettingsWindow::set_max_files(int value) {
    max_files_spin_->setValue(value);
}

void SettingsWindow::set_copy_to_clipboard_enabled(bool enabled) {
    copy_to_clipboard_check_->setChecked(enabled);
}

void SettingsWindow::set_paste_to_focused_window_enabled(bool enabled) {
    paste_to_focused_window_check_->setChecked(enabled);
}

void SettingsWindow::set_paste_keys(const QString& keys) {
    const int index = paste_keys_combo_->findText(keys);
    if (index >= 0) {
        paste_keys_combo_->setCurrentIndex(index);
    }
}

void SettingsWindow::set_proxy_enabled(bool enabled) {
    proxy_enabled_check_->setChecked(enabled);
}

void SettingsWindow::set_proxy_type(const QString& type) {
    set_combo_by_value(proxy_type_combo_, type);
}

void SettingsWindow::set_proxy_host(const QString& text) {
    proxy_host_edit_->setText(text);
}

void SettingsWindow::set_proxy_port(int value) {
    proxy_port_spin_->setValue(value);
}

void SettingsWindow::set_proxy_username(const QString& text) {
    proxy_username_edit_->setText(text);
}

void SettingsWindow::set_proxy_password(const QString& text) {
    proxy_password_edit_->setText(text);
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

void SettingsWindow::set_refine_system_prompt(const QString& text) {
    refine_system_prompt_edit_->setPlainText(text);
}

void SettingsWindow::set_vad_enabled(bool enabled) {
    vad_enabled_check_->setChecked(enabled);
}

void SettingsWindow::set_vad_threshold(double value) {
    vad_threshold_spin_->setValue(value);
}

void SettingsWindow::set_vad_min_speech_duration_ms(int value) {
    vad_min_duration_spin_->setValue(value);
}

void SettingsWindow::set_record_metadata_enabled(bool enabled) {
    record_metadata_check_->setChecked(enabled);
}

void SettingsWindow::set_record_timing_enabled(bool enabled) {
    record_timing_check_->setChecked(enabled);
}

void SettingsWindow::set_hud_enabled(bool enabled) {
    hud_enabled_check_->setChecked(enabled);
}

void SettingsWindow::set_hud_bottom_margin(int value) {
    hud_bottom_margin_spin_->setValue(value);
}

void SettingsWindow::set_status_text(const QString& text) {
    status_label_->setText(text);
}

}  // namespace ohmytypeless
