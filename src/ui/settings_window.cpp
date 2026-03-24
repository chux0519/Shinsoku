#include "ui/settings_window.hpp"

#include <QCheckBox>
#include <QComboBox>
#include <QDoubleSpinBox>
#include <QFrame>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QListWidget>
#include <QLineEdit>
#include <QFileDialog>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QScrollArea>
#include <QSizePolicy>
#include <QStackedWidget>
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

QWidget* make_page_shell(QWidget* parent, QVBoxLayout** content_layout_out) {
    auto* scroll = new QScrollArea(parent);
    scroll->setWidgetResizable(true);
    scroll->setFrameShape(QFrame::NoFrame);

    auto* content = new QWidget(scroll);
    auto* content_layout = new QVBoxLayout(content);
    content_layout->setContentsMargins(4, 4, 4, 4);
    content_layout->setSpacing(16);
    content_layout->addStretch();
    scroll->setWidget(content);

    if (content_layout_out != nullptr) {
        *content_layout_out = content_layout;
    }
    return scroll;
}

void insert_section_before_stretch(QVBoxLayout* layout, QWidget* section) {
    layout->insertWidget(layout->count() - 1, section);
}

QWidget* make_info_card(const QString& eyebrow,
                        const QString& title,
                        const QString& body,
                        QWidget* parent) {
    auto* card = new QGroupBox(parent);
    card->setObjectName("headerCard");
    auto* layout = new QVBoxLayout(card);
    layout->setContentsMargins(24, 22, 24, 22);
    layout->setSpacing(8);

    auto* eyebrow_label = new QLabel(eyebrow, card);
    eyebrow_label->setObjectName("headerEyebrow");
    auto* title_label = new QLabel(title, card);
    title_label->setObjectName("headerTitle");
    title_label->setWordWrap(true);
    auto* body_label = new QLabel(body, card);
    body_label->setObjectName("headerBody");
    body_label->setWordWrap(true);

    layout->addWidget(eyebrow_label);
    layout->addWidget(title_label);
    layout->addWidget(body_label);
    return card;
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
    resize(980, 720);
    setMinimumSize(900, 640);

    auto* root_layout = new QVBoxLayout(this);
    root_layout->setContentsMargins(22, 20, 22, 20);
    root_layout->setSpacing(16);

    auto* shell_layout = new QHBoxLayout();
    shell_layout->setSpacing(16);
    root_layout->addLayout(shell_layout, 1);

    auto* sidebar = new QWidget(this);
    sidebar->setObjectName("settingsSidebar");
    sidebar->setFixedWidth(220);
    auto* sidebar_layout = new QVBoxLayout(sidebar);
    sidebar_layout->setContentsMargins(14, 16, 14, 16);
    sidebar_layout->setSpacing(10);

    auto* sidebar_title = new QLabel("Settings", sidebar);
    sidebar_title->setObjectName("settingsSidebarTitle");
    sidebar_layout->addWidget(sidebar_title);

    navigation_list_ = new QListWidget(sidebar);
    navigation_list_->setObjectName("settingsNav");
    navigation_list_->setSpacing(8);
    navigation_list_->setAlternatingRowColors(false);
    navigation_list_->setUniformItemSizes(true);
    navigation_list_->addItems({"General", "Audio", "ASR", "Transform", "Network", "Providers", "Advanced"});
    sidebar_layout->addWidget(navigation_list_, 1);
    shell_layout->addWidget(sidebar);

    page_stack_ = new QStackedWidget(this);
    page_stack_->setObjectName("settingsPageHost");
    shell_layout->addWidget(page_stack_, 1);

    QVBoxLayout* general_layout = nullptr;
    QVBoxLayout* audio_layout = nullptr;
    QVBoxLayout* asr_layout = nullptr;
    QVBoxLayout* transform_layout = nullptr;
    QVBoxLayout* network_layout = nullptr;
    QVBoxLayout* providers_layout = nullptr;
    QVBoxLayout* advanced_layout = nullptr;
    page_stack_->addWidget(make_page_shell(page_stack_, &general_layout));
    page_stack_->addWidget(make_page_shell(page_stack_, &audio_layout));
    page_stack_->addWidget(make_page_shell(page_stack_, &asr_layout));
    page_stack_->addWidget(make_page_shell(page_stack_, &transform_layout));
    page_stack_->addWidget(make_page_shell(page_stack_, &network_layout));
    page_stack_->addWidget(make_page_shell(page_stack_, &providers_layout));
    page_stack_->addWidget(make_page_shell(page_stack_, &advanced_layout));

    insert_section_before_stretch(general_layout,
                                  make_info_card("Workspace Control",
                                                 "Tune capture, output, and on-screen behavior.",
                                                 "General settings cover hotkeys, clipboard routing, and the HUD. "
                                                 "Audio, providers, and network routing now live in dedicated pages.",
                                                 this));

    QFormLayout* hotkey_form = nullptr;
    auto* hotkey_section = make_section("Hotkey", this, &hotkey_form);
    hold_key_combo_ = make_key_combo(hotkey_section);
    hands_free_chord_combo_ = make_key_combo(hotkey_section);
    hotkey_form->addRow("Hold Key", hold_key_combo_);
    hotkey_form->addRow("Hands-free Chord", hands_free_chord_combo_);
    insert_section_before_stretch(general_layout, hotkey_section);

    QFormLayout* audio_form = nullptr;
    auto* audio_section = make_section("Capture", this, &audio_form);
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
    insert_section_before_stretch(audio_layout,
                                  make_info_card("Audio Input",
                                                 "Choose capture devices and retention behavior.",
                                                 "These settings control where audio comes from, whether recordings "
                                                 "are stored, and how old files are rotated.",
                                                 this));
    insert_section_before_stretch(audio_layout, audio_section);

    QFormLayout* output_form = nullptr;
    auto* output_section = make_section("Output", this, &output_form);
    copy_to_clipboard_check_ = new QCheckBox("Copy text to clipboard", output_section);
    paste_to_focused_window_check_ = new QCheckBox("Paste into focused window", output_section);
    paste_keys_combo_ = new QComboBox(output_section);
    paste_keys_combo_->addItem("ctrl+shift+v");
    paste_keys_combo_->addItem("ctrl+v");
    paste_keys_combo_->addItem("shift+insert");
    output_form->addRow("Clipboard", copy_to_clipboard_check_);
    output_form->addRow("Auto Paste", paste_to_focused_window_check_);
    output_form->addRow("Paste Keys", paste_keys_combo_);
    insert_section_before_stretch(general_layout, output_section);

    QFormLayout* network_form = nullptr;
    auto* network_section = make_section("Proxy", this, &network_form);
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
    insert_section_before_stretch(network_layout,
                                  make_info_card("Network Routing",
                                                 "Route outbound requests through a proxy.",
                                                 "This page currently applies to the existing HTTP backends and gives "
                                                 "future streaming providers a stable transport home.",
                                                 this));
    insert_section_before_stretch(network_layout, network_section);

    QFormLayout* asr_form = nullptr;
    auto* asr_section = make_section("Transcription Flow", this, &asr_form);
    auto* asr_mode_label = new QLabel(
        "Batch transcription is active today. Streaming backend support is being prepared and can be enabled here once a provider is configured.",
        asr_section);
    asr_mode_label->setWordWrap(true);
    asr_mode_label->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Preferred);
    asr_form->addRow(asr_mode_label);
    streaming_enabled_check_ = new QCheckBox("Enable real-time streaming ASR", asr_section);
    streaming_provider_combo_ = new QComboBox(asr_section);
    streaming_provider_combo_->addItem("None", "none");
    streaming_provider_combo_->addItem("Soniox", "soniox");
    streaming_language_edit_ = new QLineEdit(asr_section);
    streaming_language_edit_->setPlaceholderText("Optional language hint, e.g. en");
    asr_form->addRow("Streaming", streaming_enabled_check_);
    asr_form->addRow("Provider", streaming_provider_combo_);
    asr_form->addRow("Language", streaming_language_edit_);
    insert_section_before_stretch(asr_layout,
                                  make_info_card("Speech Recognition",
                                                 "Manage transcription backends and capture heuristics.",
                                                 "This page is reserved for workflow-level ASR choices. Provider "
                                                 "credentials and endpoint details now live under Providers.",
                                                 this));
    insert_section_before_stretch(asr_layout, asr_section);

    QFormLayout* refine_form = nullptr;
    auto* refine_section = make_section("Text Transform", this, &refine_form);
    refine_enabled_check_ = new QCheckBox("Run second-pass text refine", refine_section);
    refine_system_prompt_edit_ = new QPlainTextEdit(refine_section);
    refine_system_prompt_edit_->setMinimumHeight(140);
    refine_form->addRow("Enabled", refine_enabled_check_);
    refine_form->addRow("System Prompt", refine_system_prompt_edit_);
    insert_section_before_stretch(transform_layout,
                                  make_info_card("Text Transform",
                                                 "Configure command-mode and second-pass text processing.",
                                                 "Workflow-level transform behavior stays here. Provider endpoint and "
                                                 "credential details now live under Providers.",
                                                 this));
    insert_section_before_stretch(transform_layout, refine_section);

    QFormLayout* vad_form = nullptr;
    auto* vad_section = make_section("Voice Activity Detection", this, &vad_form);
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
    insert_section_before_stretch(audio_layout, vad_section);

    QFormLayout* observability_form = nullptr;
    auto* observability_section = make_section("Observability", this, &observability_form);
    record_metadata_check_ = new QCheckBox("Store pipeline metadata in history", observability_section);
    record_timing_check_ = new QCheckBox("Store timing in history", observability_section);
    observability_form->addRow("Metadata", record_metadata_check_);
    observability_form->addRow("Timing", record_timing_check_);
    insert_section_before_stretch(advanced_layout,
                                  make_info_card("Advanced Controls",
                                                 "Keep diagnostics and experimental knobs out of the main flow.",
                                                 "This page is the home for observability today and can absorb future "
                                                 "advanced provider flags later.",
                                                 this));
    insert_section_before_stretch(advanced_layout, observability_section);

    QFormLayout* hud_form = nullptr;
    auto* hud_section = make_section("HUD", this, &hud_form);
    hud_enabled_check_ = new QCheckBox("Show overlay while recording/transcribing", hud_section);
    hud_bottom_margin_spin_ = new QSpinBox(hud_section);
    hud_bottom_margin_spin_->setRange(0, 400);
    hud_bottom_margin_spin_->setValue(104);
    hud_form->addRow("Enabled", hud_enabled_check_);
    hud_form->addRow("Bottom Margin", hud_bottom_margin_spin_);
    insert_section_before_stretch(general_layout, hud_section);

    insert_section_before_stretch(providers_layout,
                                  make_info_card("Provider Profiles",
                                                 "Provider-specific settings live here.",
                                                 "Common workflow settings stay on the other pages. Endpoint URLs, "
                                                 "API keys, and provider-specific knobs belong here so Soniox, "
                                                 "Bailian, and offline backends can expand without reshaping the whole UI.",
                                                 this));

    QFormLayout* openai_asr_form = nullptr;
    auto* openai_asr_section = make_section("OpenAI-Compatible Batch ASR", this, &openai_asr_form);
    asr_base_url_edit_ = new QLineEdit(openai_asr_section);
    asr_api_key_edit_ = new QLineEdit(openai_asr_section);
    asr_api_key_edit_->setEchoMode(QLineEdit::Password);
    asr_model_edit_ = new QLineEdit(openai_asr_section);
    openai_asr_form->addRow("Base URL", asr_base_url_edit_);
    openai_asr_form->addRow("API Key", asr_api_key_edit_);
    openai_asr_form->addRow("Model", asr_model_edit_);
    insert_section_before_stretch(providers_layout, openai_asr_section);

    QFormLayout* openai_transform_form = nullptr;
    auto* openai_transform_section = make_section("OpenAI-Compatible Text Transform", this, &openai_transform_form);
    refine_base_url_edit_ = new QLineEdit(openai_transform_section);
    refine_api_key_edit_ = new QLineEdit(openai_transform_section);
    refine_api_key_edit_->setEchoMode(QLineEdit::Password);
    refine_model_edit_ = new QLineEdit(openai_transform_section);
    openai_transform_form->addRow("Base URL", refine_base_url_edit_);
    openai_transform_form->addRow("API Key", refine_api_key_edit_);
    openai_transform_form->addRow("Model", refine_model_edit_);
    insert_section_before_stretch(providers_layout, openai_transform_section);

    QFormLayout* soniox_form = nullptr;
    auto* soniox_section = make_section("Soniox Streaming", this, &soniox_form);
    soniox_url_edit_ = new QLineEdit(soniox_section);
    soniox_api_key_edit_ = new QLineEdit(soniox_section);
    soniox_api_key_edit_->setEchoMode(QLineEdit::Password);
    soniox_model_edit_ = new QLineEdit(soniox_section);
    soniox_form->addRow("WebSocket URL", soniox_url_edit_);
    soniox_form->addRow("API Key", soniox_api_key_edit_);
    soniox_form->addRow("Model", soniox_model_edit_);
    insert_section_before_stretch(providers_layout, soniox_section);

    insert_section_before_stretch(providers_layout,
                                  make_info_card("Upcoming Providers",
                                                 "Bailian and offline profiles will land here next.",
                                                 "This area is intentionally ready for provider-specific cards so future "
                                                 "websocket and local inference settings stay modular.",
                                                 this));

    auto* actions = new QHBoxLayout();
    actions->addStretch();
    auto* button = new QPushButton("Apply", this);
    button->setObjectName("applyButton");
    actions->addWidget(button);
    root_layout->addLayout(actions);

    status_label_ = new QLabel(this);
    status_label_->setObjectName("statusBanner");
    status_label_->setWordWrap(true);
    status_label_->setVisible(false);
    root_layout->addWidget(status_label_);

    connect(button, &QPushButton::clicked, this, &SettingsWindow::apply_clicked);
    connect(recordings_dir_button_, &QPushButton::clicked, this, [this]() {
        const QString selected = QFileDialog::getExistingDirectory(this, "Choose Recordings Directory", recordings_dir());
        if (!selected.isEmpty()) {
            recordings_dir_edit_->setText(selected);
        }
    });
    connect(navigation_list_, &QListWidget::currentRowChanged, page_stack_, &QStackedWidget::setCurrentIndex);
    navigation_list_->setCurrentRow(0);
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

bool SettingsWindow::streaming_enabled() const {
    return streaming_enabled_check_->isChecked();
}

QString SettingsWindow::streaming_provider() const {
    return streaming_provider_combo_->currentData().toString();
}

QString SettingsWindow::streaming_language() const {
    return streaming_language_edit_->text().trimmed();
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

QString SettingsWindow::soniox_url() const {
    return soniox_url_edit_->text().trimmed();
}

QString SettingsWindow::soniox_api_key() const {
    return soniox_api_key_edit_->text();
}

QString SettingsWindow::soniox_model() const {
    return soniox_model_edit_->text().trimmed();
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

void SettingsWindow::set_streaming_enabled(bool enabled) {
    streaming_enabled_check_->setChecked(enabled);
}

void SettingsWindow::set_streaming_provider(const QString& text) {
    set_combo_by_value(streaming_provider_combo_, text);
}

void SettingsWindow::set_streaming_language(const QString& text) {
    streaming_language_edit_->setText(text);
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

void SettingsWindow::set_soniox_url(const QString& text) {
    soniox_url_edit_->setText(text);
}

void SettingsWindow::set_soniox_api_key(const QString& text) {
    soniox_api_key_edit_->setText(text);
}

void SettingsWindow::set_soniox_model(const QString& text) {
    soniox_model_edit_->setText(text);
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
    status_label_->setVisible(!text.trimmed().isEmpty());
}

}  // namespace ohmytypeless
