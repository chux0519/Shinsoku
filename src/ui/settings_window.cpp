#include "ui/settings_window.hpp"
#include "platform/hotkey_names.hpp"

#include <algorithm>

#include <QCheckBox>
#include <QAbstractItemView>
#include <QComboBox>
#include <QDesktopServices>
#include <QDoubleSpinBox>
#include <QFrame>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QListWidget>
#include <QLineEdit>
#include <QMenu>
#include <QFileDialog>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QScrollArea>
#include <QSizePolicy>
#include <QStackedWidget>
#include <QStandardItemModel>
#include <QSpinBox>
#include <QToolButton>
#include <QUrl>
#include <QVBoxLayout>

namespace ohmytypeless {

namespace {

constexpr auto kBailianFunAsrWebSocketUrl = "https://help.aliyun.com/zh/model-studio/fun-asr-realtime-websocket-api";

const QStringList kSonioxModels = {
    "stt-rt-preview",
};

const QStringList kBailianChinaModels = {
    "fun-asr-realtime",
    "fun-asr-realtime-2026-02-28",
    "fun-asr-realtime-2025-11-07",
    "fun-asr-realtime-2025-09-15",
    "fun-asr-flash-8k-realtime",
    "fun-asr-flash-8k-realtime-2026-01-28",
    "gummy-realtime-v1",
    "gummy-chat-v1",
    "paraformer-realtime-v2",
    "paraformer-realtime-v1",
    "paraformer-realtime-8k-v2",
    "paraformer-realtime-8k-v1",
};

const QStringList kBailianIntlModels = {
    "fun-asr-realtime",
    "fun-asr-realtime-2025-11-07",
};

QString profile_hint_text(const QString& profile_id, const QString& input_source) {
    if (input_source == "system") {
        return QString("Selected profile ID: %1. It is intended for live caption workflows and pairs naturally with System Audio (Loopback) and the Live Caption window.")
            .arg(profile_id);
    }
    return QString("Selected profile ID: %1. It is intended for dictation-style workflows and can enable transform or paste behavior.")
        .arg(profile_id);
}

QString slugify_profile_id(QString text) {
    text = text.trimmed().toLower();
    QString out;
    out.reserve(text.size());
    bool previous_dash = false;
    for (const QChar ch : text) {
        if (ch.isLetterOrNumber()) {
            out += ch;
            previous_dash = false;
            continue;
        }
        if (!previous_dash && !out.isEmpty()) {
            out += '-';
            previous_dash = true;
        }
    }
    while (out.endsWith('-')) {
        out.chop(1);
    }
    return out.isEmpty() ? QStringLiteral("profile") : out;
}

void apply_model_tooltips(QComboBox* combo) {
    if (combo == nullptr) {
        return;
    }
    for (int i = 0; i < combo->count(); ++i) {
        const QString model = combo->itemText(i);
        QString tooltip;
        if (model == "stt-rt-preview") {
            tooltip = "Soniox current real-time model. Best for low-latency streaming experiments.";
        } else if (model.startsWith("fun-asr-flash-8k")) {
            tooltip = "Optimized for 8 kHz / telephony audio. Prefer this for narrowband call-quality audio.";
        } else if (model.startsWith("fun-asr-realtime")) {
            tooltip = "General-purpose Bailian real-time ASR. Best default for live wideband dictation.";
        } else if (model.startsWith("gummy-realtime")) {
            tooltip = "Conversation-oriented real-time speech model for spoken interaction flows.";
        } else if (model.startsWith("gummy-chat")) {
            tooltip = "Dialogue-oriented speech model family. Better suited to conversational turn-taking.";
        } else if (model.startsWith("paraformer-realtime-8k")) {
            tooltip = "Legacy Paraformer real-time model for 8 kHz / telephony scenarios.";
        } else if (model.startsWith("paraformer-realtime")) {
            tooltip = "Legacy Paraformer real-time model family kept for compatibility.";
        } else {
            tooltip = "See the official provider documentation for exact behavior and tradeoffs.";
        }
        combo->setItemData(i, tooltip, Qt::ToolTipRole);
    }
}

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

void configure_combo_popup(QComboBox* combo, int max_visible_items = 10) {
    if (combo == nullptr) {
        return;
    }
    combo->setMaxVisibleItems(max_visible_items);
    if (auto* view = combo->view(); view != nullptr) {
        view->setFrameShape(QFrame::NoFrame);
        view->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
    }
}

QComboBox* make_key_combo(QWidget* parent) {
    auto* combo = new QComboBox(parent);
    combo->addItem("Right Alt", "right_alt");
    combo->addItem("Left Alt", "left_alt");
    combo->addItem("Space", "space");
    combo->addItem("Right Ctrl", "right_ctrl");
    combo->addItem("Left Ctrl", "left_ctrl");
    combo->addItem("Right Shift", "right_shift");
    combo->addItem("Left Shift", "left_shift");
    combo->addItem("Menu", "menu");
    combo->addItem("Compose", "compose");
    combo->addItem("Right Meta", "right_meta");
    combo->addItem("Left Meta", "left_meta");
    combo->setItemData(combo->findData("right_alt"),
                       QString("Right Alt may still trigger menus in some Linux/Wayland apps. Prefer a Ctrl key when possible."),
                       Qt::ToolTipRole);
    combo->setItemData(combo->findData("left_alt"),
                       QString("Left Alt usually conflicts with application menus on Linux/Wayland. Prefer a Ctrl key instead."),
                       Qt::ToolTipRole);
    configure_combo_popup(combo);
    return combo;
}

QWidget* make_combo_with_button(QComboBox** combo_out,
                                QPushButton** button_out,
                                const QString& button_text,
                                QWidget* parent) {
    auto* row = new QWidget(parent);
    row->setObjectName("inlineFieldRow");
    auto* layout = new QHBoxLayout(row);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(8);

    auto* combo = make_key_combo(row);
    auto* button = new QPushButton(button_text, row);
    button->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);
    layout->addWidget(combo, 1);
    layout->addWidget(button);

    if (combo_out != nullptr) {
        *combo_out = combo;
    }
    if (button_out != nullptr) {
        *button_out = button;
    }
    return row;
}

void set_combo_by_value(QComboBox* combo, const QString& value) {
    const int index = combo->findData(value);
    if (index >= 0) {
        combo->setCurrentIndex(index);
    }
}

void set_device_combo_items(QComboBox* combo, const QList<QPair<QString, QString>>& devices, const QString& selected_device_id) {
    if (combo == nullptr) {
        return;
    }
    combo->clear();
    for (const auto& device : devices) {
        combo->addItem(device.second, device.first);
    }

    const int index = combo->findData(selected_device_id);
    if (index >= 0) {
        combo->setCurrentIndex(index);
    } else if (combo->count() > 0) {
        combo->setCurrentIndex(0);
    }
}

void ensure_key_combo_value(QComboBox* combo, const QString& value) {
    if (combo == nullptr || value.trimmed().isEmpty()) {
        return;
    }
    const QString canonical = canonical_hotkey_name(value);
    if (combo->findData(canonical) < 0) {
        combo->addItem(display_hotkey_name(canonical), canonical);
    }
    set_combo_by_value(combo, canonical);
}

void set_combo_text_if_present(QComboBox* combo, const QString& value) {
    const int index = combo->findText(value);
    if (index >= 0) {
        combo->setCurrentIndex(index);
    }
}

void set_combo_item_enabled(QComboBox* combo, const QString& value, bool enabled, const QString& tooltip = {}) {
    if (combo == nullptr) {
        return;
    }

    const int index = combo->findData(value);
    if (index < 0) {
        return;
    }

    auto* model = qobject_cast<QStandardItemModel*>(combo->model());
    if (model == nullptr) {
        return;
    }

    if (QStandardItem* item = model->item(index); item != nullptr) {
        item->setEnabled(enabled);
        item->setToolTip(tooltip);
    }
}

QWidget* make_model_row(QComboBox** combo_out, QToolButton** help_out, const QStringList& items, QWidget* parent) {
    auto* row = new QWidget(parent);
    row->setObjectName("inlineFieldRow");
    auto* layout = new QHBoxLayout(row);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(8);

    auto* combo = new QComboBox(row);
    combo->addItems(items);
    apply_model_tooltips(combo);
    combo->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Preferred);
    configure_combo_popup(combo);
    auto* help = new QToolButton(row);
    help->setObjectName("helpButton");
    help->setText("?");
    help->setToolTip("Open provider model guide");

    layout->addWidget(combo, 1);
    layout->addWidget(help);

    if (combo_out != nullptr) {
        *combo_out = combo;
    }
    if (help_out != nullptr) {
        *help_out = help;
    }
    return row;
}

void refresh_bailian_model_combo(QComboBox* combo, const QString& region, const QString& preferred_model) {
    if (combo == nullptr) {
        return;
    }
    const QString current = preferred_model.isEmpty() ? combo->currentText() : preferred_model;
    const QStringList models = region == "intl-singapore" ? kBailianIntlModels : kBailianChinaModels;

    combo->blockSignals(true);
    combo->clear();
    combo->addItems(models);
    apply_model_tooltips(combo);
    set_combo_text_if_present(combo, current);
    combo->blockSignals(false);
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
    navigation_list_->addItems({"General", "Providers", "Transform", "Network", "Profiles", "Advanced"});
    sidebar_layout->addWidget(navigation_list_, 1);
    shell_layout->addWidget(sidebar);

    page_stack_ = new QStackedWidget(this);
    page_stack_->setObjectName("settingsPageHost");
    shell_layout->addWidget(page_stack_, 1);

    QVBoxLayout* general_layout = nullptr;
    QVBoxLayout* profiles_layout = nullptr;
    QVBoxLayout* transform_layout = nullptr;
    QVBoxLayout* network_layout = nullptr;
    QVBoxLayout* providers_layout = nullptr;
    QVBoxLayout* advanced_layout = nullptr;
    page_stack_->addWidget(make_page_shell(page_stack_, &general_layout));
    page_stack_->addWidget(make_page_shell(page_stack_, &providers_layout));
    page_stack_->addWidget(make_page_shell(page_stack_, &transform_layout));
    page_stack_->addWidget(make_page_shell(page_stack_, &network_layout));
    page_stack_->addWidget(make_page_shell(page_stack_, &profiles_layout));
    page_stack_->addWidget(make_page_shell(page_stack_, &advanced_layout));

    insert_section_before_stretch(general_layout,
                                  make_info_card("Workspace Control",
                                                 "Keep the main workflow in one place.",
                                                 "General now covers hotkeys, audio input, output routing, voice "
                                                 "activity detection, and the HUD so the core workflow is easier to scan.",
                                                 this));

    insert_section_before_stretch(profiles_layout,
                                  make_info_card("Workflow Profiles",
                                                 "Use profiles as workflow presets, not full settings copies.",
                                                 "Profiles are the right place for workflow intent such as dictation, "
                                                 "live caption behavior, transform behavior, and output "
                                                 "preferences.",
                                                 this));

    auto* profiles_editor_shell = new QWidget(this);
    auto* profiles_editor_layout = new QHBoxLayout(profiles_editor_shell);
    profiles_editor_layout->setContentsMargins(0, 0, 0, 0);
    profiles_editor_layout->setSpacing(16);

    auto* profiles_sidebar = new QGroupBox("Profiles", profiles_editor_shell);
    profiles_sidebar->setObjectName("sectionCard");
    profiles_sidebar->setFixedWidth(300);
    auto* profiles_sidebar_layout = new QVBoxLayout(profiles_sidebar);
    profiles_sidebar_layout->setContentsMargins(18, 22, 18, 18);
    profiles_sidebar_layout->setSpacing(12);
    profiles_sidebar_layout->addSpacing(8);

    profile_new_button_ = new QPushButton("New Profile", profiles_sidebar);
    profiles_sidebar_layout->addWidget(profile_new_button_);

    profiles_list_ = new QListWidget(profiles_sidebar);
    profiles_list_->setObjectName("settingsNav");
    profiles_list_->setSpacing(8);
    profiles_list_->setContextMenuPolicy(Qt::CustomContextMenu);
    profiles_sidebar_layout->addWidget(profiles_list_, 1);

    profiles_editor_layout->addWidget(profiles_sidebar);

    auto* profile_editor_card = new QGroupBox("Selected Profile", profiles_editor_shell);
    profile_editor_card->setObjectName("sectionCard");
    auto* profile_editor_layout = new QVBoxLayout(profile_editor_card);
    profile_editor_layout->setContentsMargins(22, 26, 22, 22);
    profile_editor_layout->setSpacing(14);

    active_profile_hint_label_ = new QLabel(profile_editor_card);
    active_profile_hint_label_->setObjectName("headerBody");
    active_profile_hint_label_->setWordWrap(true);
    profile_editor_layout->addWidget(active_profile_hint_label_);

    profile_name_edit_ = new QLineEdit(profile_editor_card);
    profile_input_source_combo_ = new QComboBox(profile_editor_card);
    profile_input_source_combo_->addItem("Microphone", "microphone");
    profile_input_source_combo_->addItem("System Audio (Loopback)", "system");
    profile_input_device_combo_ = new QComboBox(profile_editor_card);
    profile_prefer_streaming_check_ = new QCheckBox("Prefer streaming ASR", profile_editor_card);
    profile_streaming_provider_combo_ = new QComboBox(profile_editor_card);
    profile_streaming_provider_combo_->addItem("None", "none");
    profile_streaming_provider_combo_->addItem("Soniox", "soniox");
    profile_streaming_provider_combo_->addItem("Bailian", "bailian");
    profile_language_hint_edit_ = new QLineEdit(profile_editor_card);
    profile_language_hint_edit_->setPlaceholderText("Optional language hint, e.g. en");
    profile_transform_enabled_check_ = new QCheckBox("Enable text transform", profile_editor_card);
    profile_prompt_mode_combo_ = new QComboBox(profile_editor_card);
    profile_prompt_mode_combo_->addItem("Inherit global prompt", "inherit_global");
    profile_prompt_mode_combo_->addItem("Use custom prompt", "custom");
    profile_custom_prompt_edit_ = new QPlainTextEdit(profile_editor_card);
    profile_custom_prompt_edit_->setMinimumHeight(120);
    profile_copy_check_ = new QCheckBox("Copy result to clipboard", profile_editor_card);
    profile_paste_check_ = new QCheckBox("Paste into focused window", profile_editor_card);
    profile_paste_keys_combo_ = new QComboBox(profile_editor_card);
    profile_paste_keys_combo_->addItems({"ctrl+shift+v", "ctrl+v", "shift+insert"});
    profile_notes_edit_ = new QPlainTextEdit(profile_editor_card);
    profile_notes_edit_->setMinimumHeight(90);
    configure_combo_popup(profile_input_source_combo_);
    configure_combo_popup(profile_input_device_combo_, 14);
    configure_combo_popup(profile_streaming_provider_combo_);
    configure_combo_popup(profile_prompt_mode_combo_);
    configure_combo_popup(profile_paste_keys_combo_);

    QFormLayout* profile_identity_form = nullptr;
    auto* profile_identity_section = make_section("Profile", profile_editor_card, &profile_identity_form);
    profile_identity_form->addRow("Name", profile_name_edit_);
    profile_identity_form->addRow("Notes", profile_notes_edit_);
    profile_editor_layout->addWidget(profile_identity_section);

    QFormLayout* profile_input_form = nullptr;
    auto* profile_input_section = make_section("Input", profile_editor_card, &profile_input_form);
    profile_input_form->addRow("Input Source", profile_input_source_combo_);
    profile_input_form->addRow("Input Device", profile_input_device_combo_);
    profile_input_form->addRow("Streaming", profile_prefer_streaming_check_);
    profile_input_form->addRow("Streaming Provider", profile_streaming_provider_combo_);
    profile_input_form->addRow("Language Hint", profile_language_hint_edit_);
    profile_editor_layout->addWidget(profile_input_section);

    QFormLayout* profile_transform_form = nullptr;
    auto* profile_transform_section = make_section("Transform", profile_editor_card, &profile_transform_form);
    profile_transform_form->addRow("Enabled", profile_transform_enabled_check_);
    profile_transform_form->addRow("Prompt Source", profile_prompt_mode_combo_);
    profile_transform_form->addRow("Custom Prompt", profile_custom_prompt_edit_);
    profile_editor_layout->addWidget(profile_transform_section);

    QFormLayout* profile_output_form = nullptr;
    auto* profile_output_section = make_section("Output", profile_editor_card, &profile_output_form);
    profile_output_form->addRow("Clipboard", profile_copy_check_);
    profile_output_form->addRow("Auto Paste", profile_paste_check_);
    profile_output_form->addRow("Paste Keys", profile_paste_keys_combo_);
    profile_editor_layout->addWidget(profile_output_section);
    profiles_editor_layout->addWidget(profile_editor_card, 1);

    insert_section_before_stretch(profiles_layout, profiles_editor_shell);

    QFormLayout* hotkey_form = nullptr;
    auto* hotkey_section = make_section("Hotkey", this, &hotkey_form);
    auto* hold_key_row = make_combo_with_button(&hold_key_combo_, &hold_key_record_button_, "Record...", hotkey_section);
    auto* chord_key_row =
        make_combo_with_button(&hands_free_chord_combo_, &hands_free_chord_record_button_, "Record...", hotkey_section);
    selection_command_trigger_combo_ = new QComboBox(hotkey_section);
    selection_command_trigger_combo_->addItem("Button Only", "button_only");
    selection_command_trigger_combo_->addItem("Double-Press Hold Key", "double_press_hold");
    configure_combo_popup(selection_command_trigger_combo_);
    hotkey_form->addRow("Hold Key", hold_key_row);
    hotkey_form->addRow("Hands-free Chord", chord_key_row);
    hotkey_form->addRow("Command Trigger", selection_command_trigger_combo_);
    insert_section_before_stretch(general_layout, hotkey_section);

    QFormLayout* audio_form = nullptr;
    auto* audio_section = make_section("Capture", this, &audio_form);
    audio_capture_mode_combo_ = new QComboBox(audio_section);
    audio_capture_mode_combo_->addItem("Microphone", "microphone");
    audio_capture_mode_combo_->addItem("System Audio (Loopback)", "system");
    input_device_combo_ = new QComboBox(audio_section);
    configure_combo_popup(audio_capture_mode_combo_);
    configure_combo_popup(input_device_combo_, 14);
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
    configure_combo_popup(rotation_mode_combo_);
    max_files_spin_ = new QSpinBox(audio_section);
    max_files_spin_->setRange(1, 100000);
    max_files_spin_->setValue(50);
    audio_form->addRow("Input Source", audio_capture_mode_combo_);
    audio_form->addRow("Input Device", input_device_combo_);
    audio_form->addRow("Recording", save_recordings_check_);
    audio_form->addRow("Recordings Dir", recordings_dir_row);
    audio_form->addRow("Rotation Mode", rotation_mode_combo_);
    audio_form->addRow("Max Files", max_files_spin_);
    insert_section_before_stretch(general_layout, audio_section);

    QFormLayout* output_form = nullptr;
    auto* output_section = make_section("Output", this, &output_form);
    copy_to_clipboard_check_ = new QCheckBox("Copy text to clipboard", output_section);
    paste_to_focused_window_check_ = new QCheckBox("Paste into focused window", output_section);
    paste_keys_combo_ = new QComboBox(output_section);
    paste_keys_combo_->addItem("ctrl+shift+v");
    paste_keys_combo_->addItem("ctrl+v");
    paste_keys_combo_->addItem("shift+insert");
    configure_combo_popup(paste_keys_combo_);
    output_form->addRow("Clipboard", copy_to_clipboard_check_);
    output_form->addRow("Auto Paste", paste_to_focused_window_check_);
    output_form->addRow("Paste Keys", paste_keys_combo_);
    insert_section_before_stretch(general_layout, output_section);

    QFormLayout* appearance_form = nullptr;
    auto* appearance_section = make_section("Appearance", this, &appearance_form);
    app_theme_combo_ = new QComboBox(appearance_section);
    app_theme_combo_->addItem("Follow System", "system");
    app_theme_combo_->addItem("Light", "light");
    app_theme_combo_->addItem("Dark", "dark");
    configure_combo_popup(app_theme_combo_);
    tray_icon_theme_combo_ = new QComboBox(appearance_section);
    tray_icon_theme_combo_->addItem("Auto", "auto");
    tray_icon_theme_combo_->addItem("Light Icon", "light");
    tray_icon_theme_combo_->addItem("Dark Icon", "dark");
    configure_combo_popup(tray_icon_theme_combo_);
    appearance_form->addRow("App Theme", app_theme_combo_);
    appearance_form->addRow("Tray Icon Theme", tray_icon_theme_combo_);
    insert_section_before_stretch(general_layout, appearance_section);

    QFormLayout* network_form = nullptr;
    auto* network_section = make_section("Proxy", this, &network_form);
    proxy_enabled_check_ = new QCheckBox("Route HTTP requests through a proxy", network_section);
    proxy_type_combo_ = new QComboBox(network_section);
    proxy_type_combo_->addItem("HTTP", "http");
    proxy_type_combo_->addItem("SOCKS5", "socks5");
    configure_combo_popup(proxy_type_combo_);
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
    insert_section_before_stretch(general_layout, vad_section);

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
                                  make_info_card("Provider Control",
                                                 "Choose current providers first, then configure them.",
                                                 "This page is the home for active provider selection, endpoint URLs, "
                                                 "API keys, and provider-specific details. Workflow intent stays in "
                                                 "Profiles and global workflow knobs stay in General/Transform.",
                                                 this));

    QFormLayout* provider_selection_form = nullptr;
    auto* provider_selection_section = make_section("Current Providers", this, &provider_selection_form);
    asr_provider_combo_ = new QComboBox(provider_selection_section);
    asr_provider_combo_->addItem("OpenAI-Compatible", "openai");
    streaming_enabled_check_ = new QCheckBox("Enable real-time streaming ASR", provider_selection_section);
    streaming_provider_combo_ = new QComboBox(provider_selection_section);
    streaming_provider_combo_->addItem("None", "none");
    streaming_provider_combo_->addItem("Soniox", "soniox");
    streaming_provider_combo_->addItem("Bailian", "bailian");
    streaming_language_edit_ = new QLineEdit(provider_selection_section);
    streaming_language_edit_->setPlaceholderText("Optional language hint, e.g. en");
    refine_provider_combo_ = new QComboBox(provider_selection_section);
    refine_provider_combo_->addItem("OpenAI-Compatible", "openai");
    configure_combo_popup(asr_provider_combo_);
    configure_combo_popup(streaming_provider_combo_);
    configure_combo_popup(refine_provider_combo_);
    provider_selection_form->addRow("Batch Transcription", asr_provider_combo_);
    provider_selection_form->addRow("Streaming Enabled", streaming_enabled_check_);
    provider_selection_form->addRow("Streaming Provider", streaming_provider_combo_);
    provider_selection_form->addRow("Streaming Language", streaming_language_edit_);
    provider_selection_form->addRow("Text Transform", refine_provider_combo_);
    insert_section_before_stretch(providers_layout, provider_selection_section);

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
    auto* soniox_model_row = make_model_row(&soniox_model_combo_, &soniox_help_button_, kSonioxModels, soniox_section);
    soniox_help_button_->setToolTip("Open Soniox documentation.\nThe current app integration targets the low-latency real-time preview model.");
    soniox_form->addRow("WebSocket URL", soniox_url_edit_);
    soniox_form->addRow("API Key", soniox_api_key_edit_);
    soniox_form->addRow("Model", soniox_model_row);
    insert_section_before_stretch(providers_layout, soniox_section);

    QFormLayout* bailian_form = nullptr;
    auto* bailian_section = make_section("Bailian Streaming", this, &bailian_form);
    bailian_region_combo_ = new QComboBox(bailian_section);
    bailian_region_combo_->addItem("China Mainland (Beijing)", "cn-beijing");
    bailian_region_combo_->addItem("International (Singapore)", "intl-singapore");
    configure_combo_popup(bailian_region_combo_);
    bailian_url_edit_ = new QLineEdit(bailian_section);
    bailian_api_key_edit_ = new QLineEdit(bailian_section);
    bailian_api_key_edit_->setEchoMode(QLineEdit::Password);
    auto* bailian_model_row =
        make_model_row(&bailian_model_combo_, &bailian_help_button_, kBailianChinaModels, bailian_section);
    bailian_help_button_->setToolTip(
        "Open the official Bailian real-time ASR docs.\n"
        "fun-asr-realtime is the safest default.\n"
        "flash-8k is for telephony audio.\n"
        "gummy focuses more on conversational interaction.\n"
        "paraformer models are older compatibility options.");
    bailian_form->addRow("Region", bailian_region_combo_);
    bailian_form->addRow("WebSocket URL", bailian_url_edit_);
    bailian_form->addRow("API Key", bailian_api_key_edit_);
    bailian_form->addRow("Model", bailian_model_row);
    insert_section_before_stretch(providers_layout, bailian_section);

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
    connect(audio_capture_mode_combo_, &QComboBox::currentTextChanged, this, [this](const QString&) {
        mark_global_workflow_settings_edited();
        refresh_capability_dependent_controls();
    });
    connect(input_device_combo_, &QComboBox::currentTextChanged, this, [this](const QString&) {
        mark_global_workflow_settings_edited();
    });
    connect(audio_capture_mode_combo_, &QComboBox::activated, this, [this](int) {
        emit audio_capture_mode_changed(audio_capture_mode());
    });
    connect(profile_input_source_combo_, &QComboBox::activated, this, [this](int) {
        emit profile_audio_capture_mode_changed(profile_input_source_combo_->currentData().toString());
    });
    connect(streaming_enabled_check_, &QCheckBox::toggled, this, [this](bool) {
        mark_global_workflow_settings_edited();
        refresh_capability_dependent_controls();
    });
    connect(streaming_provider_combo_, &QComboBox::currentTextChanged, this, [this](const QString&) {
        mark_global_workflow_settings_edited();
    });
    connect(streaming_language_edit_, &QLineEdit::textChanged, this, [this](const QString&) {
        mark_global_workflow_settings_edited();
    });
    connect(refine_enabled_check_, &QCheckBox::toggled, this, [this](bool) {
        mark_global_workflow_settings_edited();
    });
    connect(hold_key_record_button_, &QPushButton::clicked, this, &SettingsWindow::record_hold_key_requested);
    connect(hands_free_chord_record_button_, &QPushButton::clicked, this, &SettingsWindow::record_hands_free_chord_requested);
    connect(paste_to_focused_window_check_, &QCheckBox::toggled, this, [this](bool) {
        mark_global_workflow_settings_edited();
        refresh_capability_dependent_controls();
    });
    connect(copy_to_clipboard_check_, &QCheckBox::toggled, this, [this](bool) {
        mark_global_workflow_settings_edited();
    });
    connect(paste_keys_combo_, &QComboBox::currentTextChanged, this, [this](const QString&) {
        mark_global_workflow_settings_edited();
    });
    connect(soniox_help_button_, &QToolButton::clicked, this, []() {
        QDesktopServices::openUrl(QUrl("https://docs.soniox.com"));
    });
    connect(bailian_help_button_, &QToolButton::clicked, this, []() {
        QDesktopServices::openUrl(QUrl(kBailianFunAsrWebSocketUrl));
    });
    connect(bailian_region_combo_, &QComboBox::currentTextChanged, this, [this](const QString&) {
        const QString region = bailian_region_combo_->currentData().toString();
        if (region == "intl-singapore") {
            bailian_url_edit_->setText("wss://dashscope-intl.aliyuncs.com/api-ws/v1/inference/");
        } else {
            bailian_url_edit_->setText("wss://dashscope.aliyuncs.com/api-ws/v1/inference/");
        }
        refresh_bailian_model_combo(bailian_model_combo_, region, QString());
    });
    connect(profiles_list_, &QListWidget::currentRowChanged, this, [this](int row) {
        if (syncing_profiles_) {
            return;
        }
        if (profile_editor_index_ >= 0) {
            store_editor_into_profile(profile_editor_index_);
        }
        load_profile_into_editor(row);
    });
    const auto duplicate_profile_at = [this](int row) {
        if (row < 0 || row >= static_cast<int>(profiles_.size())) {
            return;
        }
        if (profile_editor_index_ >= 0) {
            store_editor_into_profile(profile_editor_index_);
        }
        ProfileConfig copy = profiles_[static_cast<std::size_t>(row)];
        copy.id = next_profile_id(QString::fromStdString(copy.id)).toStdString();
        copy.name += " Copy";
        profiles_.push_back(copy);
        refresh_profile_list();
        profiles_list_->setCurrentRow(static_cast<int>(profiles_.size()) - 1);
    };

    const auto delete_profile_at = [this](int row) {
        if (profiles_.size() <= 1U) {
            return;
        }
        if (row < 0 || row >= static_cast<int>(profiles_.size())) {
            return;
        }
        const QString removed_id = QString::fromStdString(profiles_[static_cast<std::size_t>(row)].id);
        profiles_.erase(profiles_.begin() + row);
        if (active_profile_id_ == removed_id && !profiles_.empty()) {
            active_profile_id_ = QString::fromStdString(profiles_.front().id);
        }
        refresh_profile_list();
        profiles_list_->setCurrentRow(std::min(row, static_cast<int>(profiles_.size()) - 1));
    };

    connect(profile_new_button_, &QPushButton::clicked, this, [this]() {
        if (profile_editor_index_ >= 0) {
            store_editor_into_profile(profile_editor_index_);
        }
        ProfileConfig profile;
        profile.id = next_profile_id("profile").toStdString();
        profile.name = "New Profile";
        profile.output.paste_keys = "ctrl+shift+v";
        profiles_.push_back(profile);
        active_profile_id_ = QString::fromStdString(profile.id);
        refresh_profile_list();
        profiles_list_->setCurrentRow(static_cast<int>(profiles_.size()) - 1);
    });
    connect(profiles_list_, &QListWidget::customContextMenuRequested, this, [this, duplicate_profile_at, delete_profile_at](const QPoint& pos) {
        const int row = profiles_list_->indexAt(pos).row();
        if (row < 0 || row >= static_cast<int>(profiles_.size())) {
            return;
        }
        profiles_list_->setCurrentRow(row);

        QMenu menu(this);
        QAction* edit_action = menu.addAction("Edit");
        QAction* duplicate_action = menu.addAction("Duplicate");
        QAction* delete_action = menu.addAction("Delete");
        delete_action->setEnabled(profiles_.size() > 1U);

        QAction* chosen = menu.exec(profiles_list_->viewport()->mapToGlobal(pos));
        if (chosen == edit_action) {
            profile_name_edit_->setFocus(Qt::OtherFocusReason);
            profile_name_edit_->selectAll();
        } else if (chosen == duplicate_action) {
            duplicate_profile_at(row);
        } else if (chosen == delete_action) {
            delete_profile_at(row);
        }
    });
    connect(profile_input_source_combo_, &QComboBox::currentTextChanged, this, [this](const QString&) {
        mark_profile_workflow_settings_edited();
        if (syncing_profiles_ || profile_editor_index_ < 0 || profile_editor_index_ >= static_cast<int>(profiles_.size())) {
            return;
        }
        const QString profile_id = QString::fromStdString(profiles_[static_cast<std::size_t>(profile_editor_index_)].id);
        active_profile_hint_label_->setText(
            profile_hint_text(profile_id, profile_input_source_combo_->currentData().toString()));
    });
    connect(profile_input_device_combo_, &QComboBox::currentTextChanged, this, [this](const QString&) {
        mark_profile_workflow_settings_edited();
    });
    connect(profile_prefer_streaming_check_, &QCheckBox::toggled, this, [this](bool) {
        mark_profile_workflow_settings_edited();
    });
    connect(profile_streaming_provider_combo_, &QComboBox::currentTextChanged, this, [this](const QString&) {
        mark_profile_workflow_settings_edited();
    });
    connect(profile_language_hint_edit_, &QLineEdit::textChanged, this, [this](const QString&) {
        mark_profile_workflow_settings_edited();
    });
    connect(profile_transform_enabled_check_, &QCheckBox::toggled, this, [this](bool) {
        mark_profile_workflow_settings_edited();
    });
    connect(profile_copy_check_, &QCheckBox::toggled, this, [this](bool) {
        mark_profile_workflow_settings_edited();
    });
    connect(profile_paste_check_, &QCheckBox::toggled, this, [this](bool) {
        mark_profile_workflow_settings_edited();
    });
    connect(profile_paste_keys_combo_, &QComboBox::currentTextChanged, this, [this](const QString&) {
        mark_profile_workflow_settings_edited();
    });
    connect(navigation_list_, &QListWidget::currentRowChanged, page_stack_, &QStackedWidget::setCurrentIndex);
    refresh_bailian_model_combo(bailian_model_combo_, bailian_region_combo_->currentData().toString(), QString());
    bailian_url_edit_->setText("wss://dashscope.aliyuncs.com/api-ws/v1/inference/");
    navigation_list_->setCurrentRow(0);
    refresh_capability_dependent_controls();
}

QString SettingsWindow::hold_key() const {
    return hold_key_combo_->currentData().toString();
}

QString SettingsWindow::hands_free_chord_key() const {
    return hands_free_chord_combo_->currentData().toString();
}

QString SettingsWindow::selection_command_trigger() const {
    return selection_command_trigger_combo_->currentData().toString();
}

QString SettingsWindow::active_profile_id() const {
    if (profile_editor_index_ >= 0 && profile_editor_index_ < static_cast<int>(profiles_.size())) {
        return QString::fromStdString(profiles_[static_cast<std::size_t>(profile_editor_index_)].id);
    }
    return active_profile_id_;
}

std::vector<ProfileConfig> SettingsWindow::profiles() const {
    auto snapshot = profiles_;
    if (profile_editor_index_ >= 0 && profile_editor_index_ < static_cast<int>(snapshot.size())) {
        ProfileConfig& profile = snapshot[static_cast<std::size_t>(profile_editor_index_)];
        profile.name = profile_name_edit_->text().trimmed().toStdString();
        profile.capture.input_source = profile_input_source_combo_->currentData().toString().toStdString();
        profile.capture.input_device_id = profile_input_device_combo_->currentData().toString().toStdString();
        profile.capture.prefer_streaming = profile_prefer_streaming_check_->isChecked();
        profile.capture.preferred_streaming_provider = profile_streaming_provider_combo_->currentData().toString().toStdString();
        profile.capture.language_hint = profile_language_hint_edit_->text().trimmed().toStdString();
        profile.transform.enabled = profile_transform_enabled_check_->isChecked();
        profile.transform.prompt_mode = profile_prompt_mode_combo_->currentData().toString().toStdString();
        profile.transform.custom_prompt = profile_custom_prompt_edit_->toPlainText().trimmed().toStdString();
        profile.output.copy_to_clipboard = profile_copy_check_->isChecked();
        profile.output.paste_to_focused_window = profile_paste_check_->isChecked();
        profile.output.paste_keys = profile_paste_keys_combo_->currentText().toStdString();
        profile.notes = profile_notes_edit_->toPlainText().trimmed().toStdString();
    }
    return snapshot;
}

QString SettingsWindow::audio_capture_mode() const {
    return audio_capture_mode_combo_->currentData().toString();
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

QString SettingsWindow::app_theme() const {
    return app_theme_combo_->currentData().toString();
}

QString SettingsWindow::tray_icon_theme() const {
    return tray_icon_theme_combo_->currentData().toString();
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

QString SettingsWindow::asr_provider() const {
    return asr_provider_combo_->currentData().toString();
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

SettingsWindow::WorkflowEditSource SettingsWindow::workflow_edit_source() const {
    return workflow_edit_source_;
}

bool SettingsWindow::refine_enabled() const {
    return refine_enabled_check_->isChecked();
}

QString SettingsWindow::refine_provider() const {
    return refine_provider_combo_->currentData().toString();
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
    return soniox_model_combo_->currentText();
}

QString SettingsWindow::bailian_region() const {
    return bailian_region_combo_->currentData().toString();
}

QString SettingsWindow::bailian_url() const {
    return bailian_url_edit_->text().trimmed();
}

QString SettingsWindow::bailian_api_key() const {
    return bailian_api_key_edit_->text();
}

QString SettingsWindow::bailian_model() const {
    return bailian_model_combo_->currentText();
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
    ensure_key_combo_value(hold_key_combo_, text);
}

void SettingsWindow::set_hands_free_chord_key(const QString& text) {
    ensure_key_combo_value(hands_free_chord_combo_, text);
}

void SettingsWindow::set_selection_command_trigger(const QString& text) {
    set_combo_by_value(selection_command_trigger_combo_, text);
}

void SettingsWindow::set_profiles(const std::vector<ProfileConfig>& profiles, const QString& active_profile_id) {
    profiles_ = profiles;
    active_profile_id_ = active_profile_id;
    if (profiles_.empty()) {
        ProfileConfig profile;
        profiles_.push_back(profile);
        active_profile_id_ = QString::fromStdString(profile.id);
    }
    profile_editor_index_ = -1;
    refresh_profile_list();
    int active_index = 0;
    for (std::size_t i = 0; i < profiles_.size(); ++i) {
        if (QString::fromStdString(profiles_[i].id) == active_profile_id_) {
            active_index = static_cast<int>(i);
            break;
        }
    }
    profiles_list_->setCurrentRow(active_index);
}

void SettingsWindow::set_audio_capture_mode(const QString& text) {
    suppress_workflow_edit_tracking_ = true;
    set_combo_by_value(audio_capture_mode_combo_, text);
    suppress_workflow_edit_tracking_ = false;
    refresh_capability_dependent_controls();
}

void SettingsWindow::set_audio_devices(const QList<QPair<QString, QString>>& devices, const QString& selected_device_id) {
    suppress_workflow_edit_tracking_ = true;
    set_device_combo_items(input_device_combo_, devices, selected_device_id);
    if (profile_input_source_combo_ != nullptr && profile_input_source_combo_->currentData().toString() == "microphone") {
        set_device_combo_items(profile_input_device_combo_, devices, selected_device_id);
    }
    suppress_workflow_edit_tracking_ = false;
    refresh_capability_dependent_controls();
}

void SettingsWindow::set_profile_audio_devices(const QList<QPair<QString, QString>>& devices, const QString& selected_device_id) {
    set_device_combo_items(profile_input_device_combo_, devices, selected_device_id);
    const bool uses_microphone = profile_input_source_combo_ != nullptr &&
                                 profile_input_source_combo_->currentData().toString() != "system";
    profile_input_device_combo_->setEnabled(uses_microphone);
    profile_input_device_combo_->setToolTip(
        uses_microphone ? QString() : QString("System Audio uses the default playback output instead of a microphone input device."));
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
    suppress_workflow_edit_tracking_ = true;
    copy_to_clipboard_check_->setChecked(enabled);
    suppress_workflow_edit_tracking_ = false;
}

void SettingsWindow::set_paste_to_focused_window_enabled(bool enabled) {
    suppress_workflow_edit_tracking_ = true;
    paste_to_focused_window_check_->setChecked(enabled);
    suppress_workflow_edit_tracking_ = false;
    refresh_capability_dependent_controls();
}

void SettingsWindow::set_paste_keys(const QString& keys) {
    suppress_workflow_edit_tracking_ = true;
    const int index = paste_keys_combo_->findText(keys);
    if (index >= 0) {
        paste_keys_combo_->setCurrentIndex(index);
    }
    suppress_workflow_edit_tracking_ = false;
}

void SettingsWindow::set_app_theme(const QString& theme) {
    set_combo_by_value(app_theme_combo_, theme);
}

void SettingsWindow::set_tray_icon_theme(const QString& theme) {
    set_combo_by_value(tray_icon_theme_combo_, theme);
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

void SettingsWindow::set_asr_provider(const QString& text) {
    set_combo_by_value(asr_provider_combo_, text);
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
    suppress_workflow_edit_tracking_ = true;
    streaming_enabled_check_->setChecked(enabled);
    suppress_workflow_edit_tracking_ = false;
}

void SettingsWindow::set_streaming_provider(const QString& text) {
    suppress_workflow_edit_tracking_ = true;
    set_combo_by_value(streaming_provider_combo_, text);
    suppress_workflow_edit_tracking_ = false;
}

void SettingsWindow::set_streaming_language(const QString& text) {
    suppress_workflow_edit_tracking_ = true;
    streaming_language_edit_->setText(text);
    suppress_workflow_edit_tracking_ = false;
}

void SettingsWindow::set_refine_enabled(bool enabled) {
    suppress_workflow_edit_tracking_ = true;
    refine_enabled_check_->setChecked(enabled);
    suppress_workflow_edit_tracking_ = false;
}

void SettingsWindow::set_refine_provider(const QString& text) {
    set_combo_by_value(refine_provider_combo_, text);
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
    set_combo_text_if_present(soniox_model_combo_, text);
}

void SettingsWindow::set_bailian_region(const QString& text) {
    set_combo_by_value(bailian_region_combo_, text);
    refresh_bailian_model_combo(bailian_model_combo_, bailian_region_combo_->currentData().toString(), QString());
}

void SettingsWindow::set_bailian_url(const QString& text) {
    bailian_url_edit_->setText(text);
}

void SettingsWindow::set_bailian_api_key(const QString& text) {
    bailian_api_key_edit_->setText(text);
}

void SettingsWindow::set_bailian_model(const QString& text) {
    refresh_bailian_model_combo(bailian_model_combo_, bailian_region_combo_->currentData().toString(), text);
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

void SettingsWindow::set_global_hotkeys_available(bool available, const QString& reason) {
    global_hotkeys_available_ = available;
    global_hotkeys_reason_ = reason;
    hold_key_combo_->setEnabled(available);
    hands_free_chord_combo_->setEnabled(available);
    if (hold_key_record_button_ != nullptr) {
        hold_key_record_button_->setEnabled(available);
        hold_key_record_button_->setToolTip(reason);
    }
    if (hands_free_chord_record_button_ != nullptr) {
        hands_free_chord_record_button_->setEnabled(available);
        hands_free_chord_record_button_->setToolTip(reason);
    }
    selection_command_trigger_combo_->setEnabled(available);
    hold_key_combo_->setToolTip(reason);
    hands_free_chord_combo_->setToolTip(reason);
    selection_command_trigger_combo_->setToolTip(reason);
}

void SettingsWindow::set_auto_paste_available(bool available, const QString& reason) {
    auto_paste_available_ = available;
    auto_paste_reason_ = reason;
    refresh_capability_dependent_controls();
}

void SettingsWindow::set_system_audio_available(bool available, const QString& reason) {
    system_audio_available_ = available;
    system_audio_reason_ = reason;
    set_combo_item_enabled(audio_capture_mode_combo_, "system", available, reason);
    if (!available && audio_capture_mode_combo_->currentData().toString() == "system") {
        set_combo_by_value(audio_capture_mode_combo_, "microphone");
    }
    audio_capture_mode_combo_->setToolTip(reason);
    refresh_capability_dependent_controls();
}

void SettingsWindow::set_status_text(const QString& text) {
    status_label_->setText(text);
    status_label_->setVisible(!text.trimmed().isEmpty());
}

void SettingsWindow::mark_global_workflow_settings_edited() {
    if (suppress_workflow_edit_tracking_) {
        return;
    }
    workflow_edit_source_ = WorkflowEditSource::Global;
}

void SettingsWindow::mark_profile_workflow_settings_edited() {
    if (suppress_workflow_edit_tracking_ || syncing_profiles_) {
        return;
    }
    workflow_edit_source_ = WorkflowEditSource::Profile;
}

void SettingsWindow::set_record_button_state(QPushButton* button, bool active) {
    if (button == nullptr) {
        return;
    }
    button->setText(active ? "Press Key..." : "Record...");
}

void SettingsWindow::set_recording_hold_key(bool active) {
    hold_key_combo_->setEnabled(!active && global_hotkeys_available_);
    hands_free_chord_combo_->setEnabled(!active && global_hotkeys_available_);
    if (hold_key_record_button_ != nullptr) {
        hold_key_record_button_->setEnabled(global_hotkeys_available_);
    }
    if (hands_free_chord_record_button_ != nullptr) {
        hands_free_chord_record_button_->setEnabled(!active);
    }
    set_record_button_state(hold_key_record_button_, active);
    if (active) {
        hold_key_record_button_->setFocus(Qt::OtherFocusReason);
        set_status_text("Recording Hold Key. Press the key you want to use. Existing hotkeys are temporarily suspended for 5 seconds.");
    }
}

void SettingsWindow::set_recording_hands_free_chord(bool active) {
    hold_key_combo_->setEnabled(!active && global_hotkeys_available_);
    hands_free_chord_combo_->setEnabled(!active && global_hotkeys_available_);
    if (hold_key_record_button_ != nullptr) {
        hold_key_record_button_->setEnabled(!active);
    }
    if (hands_free_chord_record_button_ != nullptr) {
        hands_free_chord_record_button_->setEnabled(global_hotkeys_available_);
    }
    set_record_button_state(hands_free_chord_record_button_, active);
    if (active) {
        hands_free_chord_record_button_->setFocus(Qt::OtherFocusReason);
        set_status_text("Recording Hands-free Chord. Press the key you want to use. Existing hotkeys are temporarily suspended for 5 seconds.");
    }
}

void SettingsWindow::apply_recorded_hold_key(const QString& key_name) {
    ensure_key_combo_value(hold_key_combo_, key_name);
    set_record_button_state(hold_key_record_button_, false);
    hold_key_combo_->setEnabled(global_hotkeys_available_);
    hands_free_chord_combo_->setEnabled(global_hotkeys_available_);
    if (hands_free_chord_record_button_ != nullptr) {
        hands_free_chord_record_button_->setEnabled(true);
    }
    if (hold_key_record_button_ != nullptr) {
        hold_key_record_button_->setEnabled(true);
    }
}

void SettingsWindow::apply_recorded_hands_free_chord(const QString& key_name) {
    ensure_key_combo_value(hands_free_chord_combo_, key_name);
    set_record_button_state(hands_free_chord_record_button_, false);
    hold_key_combo_->setEnabled(global_hotkeys_available_);
    hands_free_chord_combo_->setEnabled(global_hotkeys_available_);
    if (hold_key_record_button_ != nullptr) {
        hold_key_record_button_->setEnabled(true);
    }
    if (hands_free_chord_record_button_ != nullptr) {
        hands_free_chord_record_button_->setEnabled(true);
    }
}

void SettingsWindow::refresh_capability_dependent_controls() {
    const bool uses_microphone = audio_capture_mode_combo_->currentData().toString() != "system";
    input_device_combo_->setEnabled(uses_microphone);
    input_device_combo_->setToolTip(
        uses_microphone ? QString() : QString("System Audio uses the default playback output instead of a microphone input device."));
    if (!system_audio_available_) {
        audio_capture_mode_combo_->setToolTip(system_audio_reason_);
    } else {
        audio_capture_mode_combo_->setToolTip({});
    }

    paste_to_focused_window_check_->setEnabled(auto_paste_available_);
    paste_to_focused_window_check_->setToolTip(auto_paste_available_ ? QString() : auto_paste_reason_);
    paste_keys_combo_->setEnabled(auto_paste_available_ && paste_to_focused_window_check_->isChecked());
    paste_keys_combo_->setToolTip(auto_paste_available_ ? QString() : auto_paste_reason_);

    const bool streaming_controls_enabled = streaming_enabled_check_ != nullptr && streaming_enabled_check_->isChecked();
    if (streaming_provider_combo_ != nullptr) {
        streaming_provider_combo_->setEnabled(streaming_controls_enabled);
    }
    if (streaming_language_edit_ != nullptr) {
        streaming_language_edit_->setEnabled(streaming_controls_enabled);
    }
}

void SettingsWindow::refresh_profile_list() {
    syncing_profiles_ = true;
    profiles_list_->clear();
    for (const auto& profile : profiles_) {
        profiles_list_->addItem(profile_list_label(profile));
    }
    syncing_profiles_ = false;
}

QString SettingsWindow::profile_list_label(const ProfileConfig& profile) const {
    QString label = QString::fromStdString(profile.name).trimmed();
    if (label.isEmpty()) {
        label = "Untitled Profile";
    }
    if (profile.id == active_profile_id_) {
        label = "* " + label;
    }
    constexpr int kMaxProfileLabelLength = 24;
    if (label.size() > kMaxProfileLabelLength) {
        label = label.left(kMaxProfileLabelLength - 1) + QStringLiteral("…");
    }
    return label;
}

void SettingsWindow::load_profile_into_editor(int index) {
    if (index < 0 || index >= static_cast<int>(profiles_.size())) {
        profile_editor_index_ = -1;
        return;
    }

    syncing_profiles_ = true;
    profile_editor_index_ = index;
    const ProfileConfig& profile = profiles_[static_cast<std::size_t>(index)];
    active_profile_id_ = QString::fromStdString(profile.id);
    active_profile_hint_label_->setText(
        profile_hint_text(QString::fromStdString(profile.id), QString::fromStdString(profile.capture.input_source)));
    profile_name_edit_->setText(QString::fromStdString(profile.name));
    set_combo_by_value(profile_input_source_combo_, QString::fromStdString(profile.capture.input_source));
    profile_prefer_streaming_check_->setChecked(profile.capture.prefer_streaming);
    set_combo_by_value(profile_streaming_provider_combo_, QString::fromStdString(profile.capture.preferred_streaming_provider));
    profile_language_hint_edit_->setText(QString::fromStdString(profile.capture.language_hint));
    profile_transform_enabled_check_->setChecked(profile.transform.enabled);
    set_combo_by_value(profile_prompt_mode_combo_, QString::fromStdString(profile.transform.prompt_mode));
    profile_custom_prompt_edit_->setPlainText(QString::fromStdString(profile.transform.custom_prompt));
    profile_copy_check_->setChecked(profile.output.copy_to_clipboard);
    profile_paste_check_->setChecked(profile.output.paste_to_focused_window);
    set_combo_text_if_present(profile_paste_keys_combo_, QString::fromStdString(profile.output.paste_keys));
    profile_notes_edit_->setPlainText(QString::fromStdString(profile.notes));
    refresh_profile_list();
    syncing_profiles_ = false;
}

void SettingsWindow::store_editor_into_profile(int index) {
    if (syncing_profiles_ || index < 0 || index >= static_cast<int>(profiles_.size())) {
        return;
    }

    ProfileConfig& profile = profiles_[static_cast<std::size_t>(index)];
    profile.name = profile_name_edit_->text().trimmed().toStdString();
    profile.capture.input_source = profile_input_source_combo_->currentData().toString().toStdString();
    profile.capture.input_device_id = profile_input_device_combo_->currentData().toString().toStdString();
    profile.capture.prefer_streaming = profile_prefer_streaming_check_->isChecked();
    profile.capture.preferred_streaming_provider = profile_streaming_provider_combo_->currentData().toString().toStdString();
    profile.capture.language_hint = profile_language_hint_edit_->text().trimmed().toStdString();
    profile.transform.enabled = profile_transform_enabled_check_->isChecked();
    profile.transform.prompt_mode = profile_prompt_mode_combo_->currentData().toString().toStdString();
    profile.transform.custom_prompt = profile_custom_prompt_edit_->toPlainText().trimmed().toStdString();
    profile.output.copy_to_clipboard = profile_copy_check_->isChecked();
    profile.output.paste_to_focused_window = profile_paste_check_->isChecked();
    profile.output.paste_keys = profile_paste_keys_combo_->currentText().toStdString();
    profile.notes = profile_notes_edit_->toPlainText().trimmed().toStdString();
    if (profile.name.empty()) {
        profile.name = "Untitled Profile";
    }
    active_profile_id_ = QString::fromStdString(profile.id);
    refresh_profile_list();
}

QString SettingsWindow::next_profile_id(const QString& seed) const {
    const QString base = slugify_profile_id(seed);
    QString candidate = base;
    int suffix = 2;
    while (std::any_of(profiles_.begin(), profiles_.end(), [&](const ProfileConfig& profile) {
        return QString::fromStdString(profile.id) == candidate;
    })) {
        candidate = QString("%1-%2").arg(base).arg(suffix++);
    }
    return candidate;
}
}  // namespace ohmytypeless
