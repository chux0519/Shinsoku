#include "ui/main_window.hpp"

#include "ui/history_window.hpp"
#include "ui/settings_window.hpp"

#include <QAction>
#include <QApplication>
#include <QFrame>
#include <QHBoxLayout>
#include <QLabel>
#include <QMenu>
#include <QPushButton>
#include <QStyle>
#include <QSystemTrayIcon>
#include <QVBoxLayout>
#include <QWidget>

namespace ohmytypeless {

MainWindow::MainWindow(QWidget* parent) : QMainWindow(parent) {
    setWindowTitle("OhMyTypeless");
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
    auto* hotkey_button = new QPushButton("Apply Settings", action_card);
    auto* history_button = new QPushButton("History", action_card);
    auto* settings_button = new QPushButton("Settings", action_card);

    actions->addWidget(record_button_);
    actions->addWidget(hotkey_button);
    actions->addWidget(history_button);
    actions->addWidget(settings_button);
    layout->addWidget(action_card);
    layout->addStretch();

    setCentralWidget(central);

    settings_window_ = new SettingsWindow();
    history_window_ = new HistoryWindow();

    setup_tray();

    connect(record_button_, &QPushButton::clicked, this, &MainWindow::toggle_recording_requested);
    connect(hotkey_button, &QPushButton::clicked, this, &MainWindow::register_hotkey_requested);
    connect(history_button, &QPushButton::clicked, this, &MainWindow::show_history_requested);
    connect(settings_button, &QPushButton::clicked, this, &MainWindow::show_settings_requested);
}

MainWindow::~MainWindow() {
    delete settings_window_;
    delete history_window_;
}

void MainWindow::set_session_state(SessionState state) {
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
}

void MainWindow::set_status_text(const QString& text) {
    status_label_->setText(text);
}

void MainWindow::set_tray_available(bool available) {
    if (tray_icon_ != nullptr) {
        tray_icon_->setVisible(available);
    }
}

void MainWindow::update_history(const QList<HistoryEntry>& entries) {
    if (history_window_ != nullptr) {
        history_window_->set_entries(entries);
    }
}

SettingsWindow* MainWindow::settings_window() const {
    return settings_window_;
}

HistoryWindow* MainWindow::history_window() const {
    return history_window_;
}

void MainWindow::setup_tray() {
    if (!QSystemTrayIcon::isSystemTrayAvailable()) {
        return;
    }

    tray_icon_ = new QSystemTrayIcon(this);
    tray_icon_->setIcon(style()->standardIcon(QStyle::SP_MediaVolume));

    auto* menu = new QMenu(this);
    tray_state_action_ = menu->addAction("State: Idle");
    tray_state_action_->setEnabled(false);

    menu->addSeparator();
    menu->addAction("Show History", this, [this]() { emit show_history_requested(); });
    menu->addAction("Settings", this, [this]() { emit show_settings_requested(); });
    menu->addSeparator();
    menu->addAction("Quit", this, [this]() { emit quit_requested(); });

    tray_icon_->setContextMenu(menu);
    tray_icon_->show();

    connect(tray_icon_, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick) {
            showNormal();
            raise();
            activateWindow();
        }
    });
}

}  // namespace ohmytypeless
