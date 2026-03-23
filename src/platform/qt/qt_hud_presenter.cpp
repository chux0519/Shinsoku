#include "platform/qt/qt_hud_presenter.hpp"

#include <QApplication>
#include <QGuiApplication>
#include <QLabel>
#include <QHBoxLayout>
#include <QScreen>
#include <QStyleHints>
#include <QTimer>
#include <QWidget>

namespace ohmytypeless {

namespace {

QSize hud_size_for(QWidget* widget) {
    const QSize preferred = widget->sizeHint();
    const QSize minimum = widget->minimumSizeHint();
    return preferred.expandedTo(minimum);
}

}  // namespace

QtHudPresenter::QtHudPresenter(QObject* parent) : QObject(parent) {}

void QtHudPresenter::apply_config(const HudConfig& config) {
    config_ = config;
    if (!config_.enabled) {
        hide();
    }
}

void QtHudPresenter::show_recording() {
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    show_text("Recording", dark ? "#f3f4f6" : "#111315", 0);
}

void QtHudPresenter::show_transcribing() {
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    show_text("Transcribing", dark ? "#d1d5db" : "#1f2933", 0);
}

void QtHudPresenter::show_thinking() {
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    show_text("Thinking", dark ? "#cbd5e1" : "#374151", 0);
}

void QtHudPresenter::show_notice(const QString& text, int duration_ms) {
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    show_text(text, dark ? "#e5e7eb" : "#111315", duration_ms);
}

void QtHudPresenter::show_error(const QString& text, int duration_ms) {
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    show_text(text, dark ? "#fca5a5" : "#991b1b", duration_ms);
}

void QtHudPresenter::hide() {
    if (hide_timer_ != nullptr) {
        hide_timer_->stop();
    }
    if (widget_ != nullptr) {
        widget_->hide();
    }
}

void QtHudPresenter::ensure_widget() {
    if (widget_ != nullptr) {
        return;
    }

    auto* widget = new QWidget();
    widget->setWindowFlag(Qt::FramelessWindowHint, true);
    widget->setWindowFlag(Qt::Tool, true);
    widget->setWindowFlag(Qt::WindowStaysOnTopHint, true);
    widget->setAttribute(Qt::WA_ShowWithoutActivating, true);
    widget->setAttribute(Qt::WA_TransparentForMouseEvents, true);
    widget->setAttribute(Qt::WA_TranslucentBackground, true);

    auto* layout = new QHBoxLayout(widget);
    layout->setContentsMargins(18, 18, 18, 18);

    auto* panel = new QWidget(widget);
    panel->setObjectName("hudPanel");
    auto* panel_layout = new QHBoxLayout(panel);
    panel_layout->setContentsMargins(20, 14, 20, 14);

    auto* label = new QLabel(panel);
    label->setAlignment(Qt::AlignCenter);
    label->setWordWrap(true);
    panel_layout->addWidget(label);
    layout->addWidget(panel);

    auto* timer = new QTimer(widget);
    timer->setSingleShot(true);
    connect(timer, &QTimer::timeout, widget, &QWidget::hide);

    widget_ = widget;
    panel_ = panel;
    label_ = label;
    hide_timer_ = timer;
}

void QtHudPresenter::show_text(const QString& text, const QString& accent, int duration_ms) {
    if (!config_.enabled) {
        return;
    }
    ensure_widget();
    if (widget_ == nullptr || panel_ == nullptr || label_ == nullptr) {
        return;
    }

    label_->setText(text);
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    widget_->setStyleSheet(
        QString(
            "QWidget { background: transparent; }"
            "#hudPanel {"
            "background-color: %1;"
            "border: 1px solid %2;"
            "border-radius: 18px;"
            "}"
            "QLabel {"
            "background: transparent;"
            "color: %3;"
            "font-size: 14px;"
            "font-weight: 700;"
            "padding: 0;"
            "}")
            .arg(dark ? "rgba(29, 33, 38, 244)" : "rgba(255, 255, 255, 244)",
                 dark ? "rgba(255,255,255,0.10)" : "rgba(17,19,21,0.08)",
                 accent));
    const QSize size = hud_size_for(widget_);
    widget_->resize(size);

    QScreen* screen = QGuiApplication::primaryScreen();
    if (screen != nullptr) {
        const QRect available = screen->availableGeometry();
        const int x = available.x() + (available.width() - size.width()) / 2;
        const int y = available.bottom() - size.height() - config_.bottom_margin;
        widget_->move(x, y);
    }

    widget_->show();

    if (hide_timer_ != nullptr) {
        hide_timer_->stop();
        if (duration_ms > 0) {
            hide_timer_->start(duration_ms);
        }
    }
}

}  // namespace ohmytypeless
