#include "ui/main_window.hpp"

#include "ui/history_window.hpp"
#include "ui/settings_window.hpp"

#include <QAction>
#include <QApplication>
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
    resize(720, 420);

    auto* central = new QWidget(this);
    auto* layout = new QVBoxLayout(central);

    auto* title = new QLabel("Windows-first Qt shell for the Potatype rewrite", central);
    title->setWordWrap(true);
    layout->addWidget(title);

    state_label_ = new QLabel("State: Idle", central);
    layout->addWidget(state_label_);

    status_label_ = new QLabel("No activity yet.", central);
    status_label_->setWordWrap(true);
    layout->addWidget(status_label_);

    auto* actions = new QHBoxLayout();
    record_button_ = new QPushButton("Toggle Recording", central);
    auto* hotkey_button = new QPushButton("Apply Settings", central);
    auto* clipboard_button = new QPushButton("Copy Demo Text", central);
    auto* history_button = new QPushButton("History", central);
    auto* settings_button = new QPushButton("Settings", central);

    actions->addWidget(record_button_);
    actions->addWidget(hotkey_button);
    actions->addWidget(clipboard_button);
    actions->addWidget(history_button);
    actions->addWidget(settings_button);
    layout->addLayout(actions);

    setCentralWidget(central);

    settings_window_ = new SettingsWindow();
    history_window_ = new HistoryWindow();

    setup_tray();

    connect(record_button_, &QPushButton::clicked, this, &MainWindow::toggle_recording_requested);
    connect(hotkey_button, &QPushButton::clicked, this, &MainWindow::register_hotkey_requested);
    connect(clipboard_button, &QPushButton::clicked, this, &MainWindow::copy_demo_text_requested);
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

    state_label_->setText(text);

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
