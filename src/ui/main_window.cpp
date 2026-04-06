#include "ui/main_window.hpp"
#include "platform/hotkey_names.hpp"

#include "ui/history_window.hpp"
#include "ui/meeting_transcription_window.hpp"
#include "ui/settings_window.hpp"

#include <QAction>
#include <QApplication>
#include <QColor>
#include <QComboBox>
#include <QEvent>
#include <QFrame>
#include <QHBoxLayout>
#include <QLabel>
#include <QKeyEvent>
#include <QIcon>
#include <QMenu>
#include <QPainter>
#include <QPixmap>
#include <QPushButton>
#include <QStyleHints>
#include <QSvgRenderer>
#include <QStyle>
#include <QSystemTrayIcon>
#include <QVBoxLayout>
#include <QWidget>

#if defined(Q_OS_LINUX)
#include <xcb/xcb.h>
#endif

namespace ohmytypeless {

namespace {

QIcon icon_from_svg(const QString& path, int size) {
    QSvgRenderer renderer(path);
    if (!renderer.isValid()) {
        return {};
    }

    QPixmap pixmap(size, size);
    pixmap.fill(Qt::transparent);

    QPainter painter(&pixmap);
    renderer.render(&painter);
    return QIcon(pixmap);
}

QString tray_icon_path_for(SessionState state, const QString& theme) {
    const bool auto_prefers_light =
#if defined(Q_OS_MACOS) || defined(Q_OS_LINUX)
        true;
#else
        qApp->palette().color(QPalette::Window).lightness() < 128;
#endif
    const bool use_light_icons = theme == "light" || (theme == "auto" && auto_prefers_light);
    if (use_light_icons) {
        switch (state) {
        case SessionState::Idle:
            return ":/icons/square-bolt-light.svg";
        case SessionState::Recording:
        case SessionState::HandsFree:
        case SessionState::Transcribing:
            return ":/icons/square-bolt-tray-active-light.svg";
        case SessionState::Error:
            return ":/icons/square-bolt-tray-error-light.svg";
        }
    }

    switch (state) {
    case SessionState::Idle:
        return ":/icons/square-bolt.svg";
    case SessionState::Recording:
    case SessionState::HandsFree:
    case SessionState::Transcribing:
        return ":/icons/square-bolt-tray-active.svg";
    case SessionState::Error:
        return ":/icons/square-bolt-tray-error.svg";
    }
    return ":/icons/square-bolt.svg";
}

}  // namespace

MainWindow::MainWindow(QWidget* parent) : QMainWindow(parent) {
    setWindowTitle("Shinsoku");
    setWindowIcon(icon_from_svg(":/icons/square-bolt.svg", 256));
    resize(940, 620);
    setMinimumSize(820, 560);

    auto* central = new QWidget(this);
    central->setObjectName("mainRoot");
    auto* layout = new QVBoxLayout(central);
    layout->setContentsMargins(28, 24, 28, 24);
    layout->setSpacing(18);

    auto* hero = new QFrame(central);
    hero->setObjectName("heroCard");
    auto* hero_layout = new QVBoxLayout(hero);
    hero_layout->setContentsMargins(28, 24, 28, 24);
    hero_layout->setSpacing(10);

    auto* eyebrow = new QLabel("Desktop Dictation", hero);
    eyebrow->setObjectName("eyebrow");
    hero_layout->addWidget(eyebrow);

    auto* title = new QLabel("Fast capture, clean text, minimal friction.", hero);
    title->setObjectName("heroTitle");
    title->setWordWrap(true);
    hero_layout->addWidget(title);

    auto* help = new QLabel("Hold your configured key to record. Press the chord while holding to switch to hands-free mode, then let the result flow into your current editor.", hero);
    help->setObjectName("heroBody");
    help->setWordWrap(true);
    hero_layout->addWidget(help);

    auto* profile_row = new QWidget(hero);
    profile_row->setObjectName("inlineFieldRow");
    auto* profile_row_layout = new QHBoxLayout(profile_row);
    profile_row_layout->setContentsMargins(0, 4, 0, 0);
    profile_row_layout->setSpacing(10);
    auto* profile_label = new QLabel("Profile", profile_row);
    profile_label->setObjectName("eyebrow");
    profile_combo_ = new QComboBox(profile_row);
    profile_combo_->setObjectName("profileCombo");
    profile_combo_->setMinimumWidth(260);
    profile_row_layout->addWidget(profile_label);
    profile_row_layout->addWidget(profile_combo_, 1);
    hero_layout->addWidget(profile_row);
    layout->addWidget(hero);

    auto* status_card = new QFrame(central);
    status_card->setObjectName("statusCard");
    auto* status_layout = new QVBoxLayout(status_card);
    status_layout->setContentsMargins(24, 20, 24, 20);
    status_layout->setSpacing(10);

    state_badge_label_ = new QLabel("State: Idle", status_card);
    state_badge_label_->setObjectName("stateBadge");
    status_layout->addWidget(state_badge_label_, 0, Qt::AlignLeft);

    status_label_ = new QLabel("Ready.", status_card);
    status_label_->setObjectName("statusText");
    status_label_->setWordWrap(true);
    status_layout->addWidget(status_label_);
    layout->addWidget(status_card);

    auto* action_card = new QFrame(central);
    action_card->setObjectName("actionCard");
    auto* actions = new QHBoxLayout(action_card);
    actions->setContentsMargins(20, 20, 20, 20);
    actions->setSpacing(12);
    record_button_ = new QPushButton("Toggle Recording", action_card);
    record_button_->setObjectName("recordButton");
    selection_command_button_ = new QPushButton("Selection Command", action_card);
    auto* hotkey_button = new QPushButton("Apply Settings", action_card);
    auto* history_button = new QPushButton("History", action_card);
    auto* settings_button = new QPushButton("Settings", action_card);

    actions->addWidget(record_button_);
    actions->addWidget(selection_command_button_);
    actions->addWidget(hotkey_button);
    actions->addWidget(history_button);
    actions->addWidget(settings_button);
    layout->addWidget(action_card);

#if defined(SHINSOKU_ENABLE_TRAY_DEBUG)
    auto* debug_card = new QFrame(central);
    debug_card->setObjectName("statusCard");
    auto* debug_layout = new QVBoxLayout(debug_card);
    debug_layout->setContentsMargins(24, 18, 24, 18);
    debug_layout->setSpacing(10);

    auto* debug_title = new QLabel("Tray Debug", debug_card);
    debug_title->setObjectName("eyebrow");
    debug_layout->addWidget(debug_title);

    auto* debug_help = new QLabel(
        "Temporary controls for validating tray icon states and warning notifications without running the full recording flow.",
        debug_card);
    debug_help->setWordWrap(true);
    debug_help->setObjectName("statusText");
    debug_layout->addWidget(debug_help);

    auto* debug_actions = new QHBoxLayout();
    debug_actions->setSpacing(12);
    auto* tray_idle_button = new QPushButton("Tray Idle", debug_card);
    auto* tray_active_button = new QPushButton("Tray Active", debug_card);
    auto* tray_error_button = new QPushButton("Tray Error", debug_card);
    auto* tray_warning_button = new QPushButton("Warn Once", debug_card);
    debug_actions->addWidget(tray_idle_button);
    debug_actions->addWidget(tray_active_button);
    debug_actions->addWidget(tray_error_button);
    debug_actions->addWidget(tray_warning_button);
    debug_actions->addStretch();
    debug_layout->addLayout(debug_actions);
    layout->addWidget(debug_card);
#endif
    layout->addStretch();

    setCentralWidget(central);
    qApp->installEventFilter(this);

    settings_window_ = new SettingsWindow();
    history_window_ = new HistoryWindow();
    meeting_window_ = new MeetingTranscriptionWindow();

    if (qApp != nullptr && qApp->styleHints() != nullptr) {
        connect(qApp->styleHints(), &QStyleHints::colorSchemeChanged, this, [this](Qt::ColorScheme) {
            if (tray_icon_theme_ == "auto") {
                refresh_tray_state(tray_state_);
            }
        });
    }

    setup_tray();

    connect(record_button_, &QPushButton::clicked, this, &MainWindow::toggle_recording_requested);
    connect(selection_command_button_, &QPushButton::clicked, this, &MainWindow::arm_selection_command_requested);
    connect(hotkey_button, &QPushButton::clicked, this, &MainWindow::register_hotkey_requested);
    connect(history_button, &QPushButton::clicked, this, &MainWindow::show_history_requested);
    connect(settings_button, &QPushButton::clicked, this, &MainWindow::show_settings_requested);
#if defined(SHINSOKU_ENABLE_TRAY_DEBUG)
    connect(tray_idle_button, &QPushButton::clicked, this, [this]() {
        set_session_state(SessionState::Idle);
        set_status_text("Tray debug: idle state.");
    });
    connect(tray_active_button, &QPushButton::clicked, this, [this]() {
        set_session_state(SessionState::Transcribing);
        set_status_text("Tray debug: active state.");
    });
    connect(tray_error_button, &QPushButton::clicked, this, [this]() {
        set_session_state(SessionState::Error);
        set_status_text("Tray debug: simulated warning state.");
    });
    connect(tray_warning_button, &QPushButton::clicked, this, [this]() {
        set_session_state(SessionState::Error);
        set_status_text("Tray debug warning notification.");
    });
#endif
    connect(profile_combo_, &QComboBox::currentTextChanged, this, [this](const QString&) {
        emit active_profile_changed_requested(profile_combo_->currentData().toString());
    });
}

MainWindow::~MainWindow() {
    delete settings_window_;
    delete history_window_;
    delete meeting_window_;
}

void MainWindow::closeEvent(QCloseEvent* event) {
    if (event == nullptr) {
        return;
    }

    if (tray_icon_ != nullptr && tray_icon_->isVisible()) {
        hide();
        event->ignore();
        return;
    }

    QMainWindow::closeEvent(event);
}

void MainWindow::set_session_state(SessionState state) {
    tray_state_ = state;
    if (state != SessionState::Error) {
        last_tray_error_message_.clear();
    }
    QString text = "State: ";
    switch (state) {
    case SessionState::Idle:
        text += "Idle";
        record_button_->setText("Start Recording");
        break;
    case SessionState::Recording:
        text += "Recording";
        record_button_->setText("Stop Recording");
        break;
    case SessionState::HandsFree:
        text += "Hands Free";
        record_button_->setText("Stop Recording");
        break;
    case SessionState::Transcribing:
        text += "Transcribing";
        record_button_->setText("Start Recording");
        break;
    case SessionState::Error:
        text += "Error";
        record_button_->setText("Start Recording");
        break;
    }

    if (state_badge_label_ != nullptr) {
        state_badge_label_->setText(text);
    }

    if (tray_state_action_ != nullptr) {
        tray_state_action_->setText(text);
    }

    refresh_tray_state(state);
}

void MainWindow::set_status_text(const QString& text) {
    status_label_->setText(text);
    if (tray_icon_ != nullptr && tray_state_ == SessionState::Error && tray_icon_->isVisible() &&
        text != last_tray_error_message_) {
        last_tray_error_message_ = text;
        tray_icon_->showMessage("Shinsoku Warning", text, QSystemTrayIcon::Warning, 6000);
    }
}

void MainWindow::set_tray_available(bool available) {
    if (tray_icon_ != nullptr) {
        tray_icon_->setVisible(available);
        if (available) {
            refresh_tray_state(tray_state_);
        }
    }
}

void MainWindow::update_history(const std::vector<HistoryEntry>& entries) {
    if (history_window_ != nullptr) {
        history_window_->set_entries(entries);
    }
}

void MainWindow::set_profiles(const std::vector<std::pair<QString, QString>>& profiles, const QString& active_profile_id) {
    if (profile_combo_ == nullptr) {
        return;
    }

    profile_combo_->blockSignals(true);
    profile_combo_->clear();
    for (const auto& [id, name] : profiles) {
        profile_combo_->addItem(name, id);
    }
    const int active_index = profile_combo_->findData(active_profile_id);
    if (active_index >= 0) {
        profile_combo_->setCurrentIndex(active_index);
    } else if (profile_combo_->count() > 0) {
        profile_combo_->setCurrentIndex(0);
    }
    profile_combo_->blockSignals(false);
}

void MainWindow::set_selection_command_available(bool available, const QString& reason) {
    if (selection_command_button_ == nullptr) {
        return;
    }
    selection_command_button_->setEnabled(available);
    selection_command_button_->setToolTip(reason);
}

void MainWindow::set_tray_icon_theme(const QString& theme) {
    const QString normalized = theme.trimmed().toLower();
    if (normalized == "light" || normalized == "dark") {
        tray_icon_theme_ = normalized;
    } else {
        tray_icon_theme_ = "auto";
    }
    refresh_tray_state(tray_state_);
}

void MainWindow::refresh_tray_icon() {
    refresh_tray_state(tray_state_);
}

SettingsWindow* MainWindow::settings_window() const {
    return settings_window_;
}

HistoryWindow* MainWindow::history_window() const {
    return history_window_;
}

MeetingTranscriptionWindow* MainWindow::meeting_window() const {
    return meeting_window_;
}

void MainWindow::set_hotkey_passthrough_keys(const QString& hold_key_name, const QString& chord_key_name) {
    hold_qt_key_ = qt_key_from_evdev_name(hold_key_name);
    chord_qt_key_ = qt_key_from_evdev_name(chord_key_name);
}

bool MainWindow::eventFilter(QObject* watched, QEvent* event) {
    Q_UNUSED(watched);
    if (event == nullptr || (hold_qt_key_ == 0 && chord_qt_key_ == 0)) {
        return QMainWindow::eventFilter(watched, event);
    }

    if (event->type() != QEvent::KeyPress && event->type() != QEvent::KeyRelease && event->type() != QEvent::ShortcutOverride) {
        return QMainWindow::eventFilter(watched, event);
    }

    auto* key_event = static_cast<QKeyEvent*>(event);
    auto* focus = QApplication::focusWidget();
    if (focus == nullptr || !this->isAncestorOf(focus)) {
        return QMainWindow::eventFilter(watched, event);
    }

    if (should_consume_hotkey_event(key_event)) {
        if (event->type() == QEvent::KeyPress || event->type() == QEvent::ShortcutOverride) {
            for (QComboBox* combo : this->findChildren<QComboBox*>()) {
                combo->hidePopup();
            }
        }
        key_event->accept();
        return true;
    }

    return QMainWindow::eventFilter(watched, event);
}

bool MainWindow::nativeEvent(const QByteArray& event_type, void* message, qintptr* result) {
    Q_UNUSED(result);
#if defined(Q_OS_LINUX)
    if (event_type == "xcb_generic_event_t" && message != nullptr && (hold_qt_key_ != 0 || chord_qt_key_ != 0)) {
        auto* event = static_cast<xcb_generic_event_t*>(message);
        const uint8_t response_type = event->response_type & 0x7f;
        if (response_type == XCB_KEY_PRESS || response_type == XCB_KEY_RELEASE) {
            for (QComboBox* combo : this->findChildren<QComboBox*>()) {
                combo->hidePopup();
            }
        }
    }
#endif
    return QMainWindow::nativeEvent(event_type, message, result);
}

int MainWindow::qt_key_from_evdev_name(const QString& key_name) {
    const QString normalized = canonical_hotkey_name(key_name);
    if (normalized == "right_alt" || normalized == "left_alt") {
        return Qt::Key_Alt;
    }
    if (normalized == "space") {
        return Qt::Key_Space;
    }
    if (normalized == "right_ctrl" || normalized == "left_ctrl") {
        return Qt::Key_Control;
    }
    if (normalized == "right_shift" || normalized == "left_shift") {
        return Qt::Key_Shift;
    }
    if (normalized == "left_meta" || normalized == "right_meta") {
        return Qt::Key_Meta;
    }
    if (normalized == "menu") {
        return Qt::Key_Menu;
    }
    return 0;
}

bool MainWindow::should_consume_hotkey_event(QKeyEvent* event) const {
    if (event == nullptr) {
        return false;
    }

    if (event->key() == chord_qt_key_) {
        return chord_qt_key_ != 0;
    }

    if (hold_qt_key_ == Qt::Key_Alt) {
        return event->key() == Qt::Key_Alt || (event->modifiers() & Qt::AltModifier) != 0;
    }
    if (hold_qt_key_ == Qt::Key_Control) {
        return event->key() == Qt::Key_Control || (event->modifiers() & Qt::ControlModifier) != 0;
    }
    if (hold_qt_key_ == Qt::Key_Shift) {
        return event->key() == Qt::Key_Shift || (event->modifiers() & Qt::ShiftModifier) != 0;
    }

    return event->key() == hold_qt_key_;
}

void MainWindow::present_main_window() {
    if (isMinimized()) {
        showNormal();
    } else {
        show();
    }
    raise();
    activateWindow();
}

void MainWindow::setup_tray() {
    if (!QSystemTrayIcon::isSystemTrayAvailable()) {
        return;
    }

    tray_icon_ = new QSystemTrayIcon(this);
    tray_icon_->setIcon(icon_from_svg(tray_icon_path_for(SessionState::Idle, tray_icon_theme_), 32));

    auto* menu = new QMenu(this);
    menu->setWindowFlag(Qt::FramelessWindowHint, true);
    menu->setAttribute(Qt::WA_TranslucentBackground, true);
    menu->setAttribute(Qt::WA_NoSystemBackground, true);
    tray_state_action_ = menu->addAction("State: Idle");
    tray_state_action_->setEnabled(false);

    menu->addSeparator();
    menu->addAction("Show Main Window", this, [this]() { present_main_window(); });
    menu->addAction("Show History", this, [this]() { emit show_history_requested(); });
    menu->addAction("Settings", this, [this]() { emit show_settings_requested(); });
    menu->addSeparator();
    menu->addAction("Quit", this, [this]() { emit quit_requested(); });

    tray_icon_->setContextMenu(menu);
    tray_icon_->show();
    refresh_tray_state(tray_state_);

    connect(tray_icon_, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick) {
            present_main_window();
        }
    });
}

void MainWindow::refresh_tray_state(SessionState state) {
    if (tray_icon_ == nullptr) {
        return;
    }

    QString title = "Shinsoku";
    QIcon icon = icon_from_svg(tray_icon_path_for(state, tray_icon_theme_), 32);
    switch (state) {
    case SessionState::Idle:
        title = "Shinsoku";
        icon = icon_from_svg(tray_icon_path_for(state, tray_icon_theme_), 32);
        break;
    case SessionState::Recording:
    case SessionState::HandsFree:
    case SessionState::Transcribing:
        title = "Shinsoku Active";
        icon = icon_from_svg(tray_icon_path_for(state, tray_icon_theme_), 32);
        break;
    case SessionState::Error:
        title = "Shinsoku Error";
        icon = icon_from_svg(tray_icon_path_for(state, tray_icon_theme_), 32);
        break;
    }

    tray_icon_->setIcon(icon);
    tray_icon_->setToolTip(title);
}
}  // namespace ohmytypeless
