#include "platform/qt/qt_hud_presenter.hpp"

#include <QApplication>
#include <QGuiApplication>
#include <QLabel>
#include <QScreen>
#include <QTimer>
#include <QVBoxLayout>
#include <QWidget>

namespace ohmytypeless {

namespace {

QString base_style(const QString& accent) {
    return QString(
               "QWidget {"
               "background-color: rgba(20, 22, 26, 232);"
               "border: 1px solid rgba(255, 255, 255, 24);"
               "border-radius: 14px;"
               "}"
               "QLabel {"
               "color: %1;"
               "font-size: 14px;"
               "font-weight: 600;"
               "padding: 10px 16px;"
               "}")
        .arg(accent);
}

}  // namespace

QtHudPresenter::QtHudPresenter(QObject* parent) : QObject(parent) {}

void QtHudPresenter::show_recording() {
    show_text("Recording", base_style("#57d38c"), 0);
}

void QtHudPresenter::show_transcribing() {
    show_text("Transcribing", base_style("#8cb6ff"), 0);
}

void QtHudPresenter::show_notice(const QString& text, int duration_ms) {
    show_text(text, base_style("#d9dde7"), duration_ms);
}

void QtHudPresenter::show_error(const QString& text, int duration_ms) {
    show_text(text, base_style("#ff6e6e"), duration_ms);
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

    auto* layout = new QVBoxLayout(widget);
    layout->setContentsMargins(0, 0, 0, 0);

    auto* label = new QLabel(widget);
    label->setAlignment(Qt::AlignCenter);
    layout->addWidget(label);

    auto* timer = new QTimer(widget);
    timer->setSingleShot(true);
    connect(timer, &QTimer::timeout, widget, &QWidget::hide);

    widget_ = widget;
    label_ = label;
    hide_timer_ = timer;
}

void QtHudPresenter::show_text(const QString& text, const QString& style_sheet, int duration_ms) {
    ensure_widget();
    if (widget_ == nullptr || label_ == nullptr) {
        return;
    }

    label_->setText(text);
    widget_->setStyleSheet(style_sheet);
    widget_->adjustSize();

    QScreen* screen = QGuiApplication::primaryScreen();
    if (screen != nullptr) {
        const QRect available = screen->availableGeometry();
        const QSize size = widget_->sizeHint();
        const int x = available.x() + (available.width() - size.width()) / 2;
        const int y = available.bottom() - size.height() - 96;
        widget_->setGeometry(x, y, size.width(), size.height());
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
