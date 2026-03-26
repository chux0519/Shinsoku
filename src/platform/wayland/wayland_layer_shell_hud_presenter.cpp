#include "platform/wayland/wayland_layer_shell_hud_presenter.hpp"

#include "platform/qt/qt_hud_presenter.hpp"
#include "platform/wayland/qwayland_layer_shell_integration.hpp"
#include "platform/wayland/qwayland_layer_surface.hpp"

#include <QGraphicsOpacityEffect>
#include <QGuiApplication>
#include <QHBoxLayout>
#include <QLabel>
#include <QPainter>
#include <QStyleHints>
#include <QTimer>
#include <QVariantAnimation>
#include <QVBoxLayout>
#include <QWidget>
#include <QWindow>

#include <QtWaylandClient/private/qwaylandwindow_p.h>

#include <QEasingCurve>

#include <algorithm>
#include <array>
#include <cmath>
#include <memory>

namespace ohmytypeless {

namespace {
constexpr int kRecordingMinWidth = 212;
constexpr int kRecordingMinHeight = 56;
constexpr int kHudOuterPadding = 18;
constexpr int kIndicatorWidth = 20;
constexpr int kIndicatorSpacing = 10;
constexpr int kPanelHorizontalPadding = 44;
constexpr qreal kTau = 6.28318530717958647692;

class HudWaveformWidget final : public QWidget {
public:
    explicit HudWaveformWidget(QWidget* parent = nullptr) : QWidget(parent) {
        setFixedSize(20, 18);
    }

    void set_accent(const QColor& color) {
        accent_ = color;
        update();
    }

    void set_command_mode(bool enabled) {
        command_mode_ = enabled;
        update();
    }

    void set_phase(qreal phase) {
        phase_ = phase;
        update();
    }

protected:
    void paintEvent(QPaintEvent* event) override {
        Q_UNUSED(event);
        QPainter painter(this);
        painter.setRenderHint(QPainter::Antialiasing, true);
        painter.setPen(Qt::NoPen);

        QColor bar_color = accent_;
        bar_color.setAlphaF(command_mode_ ? 0.92 : 0.88);
        painter.setBrush(bar_color);

        constexpr std::array<qreal, 5> offsets = {0.0, 0.19, 0.37, 0.58, 0.81};
        constexpr std::array<qreal, 5> baselines = {0.36, 0.58, 0.8, 0.58, 0.36};
        constexpr int bar_width = 3;
        constexpr int spacing = 1;
        constexpr int min_height = 4;
        const int total_width = (bar_width * static_cast<int>(offsets.size())) +
                                (spacing * (static_cast<int>(offsets.size()) - 1));
        const int x_origin = (width() - total_width) / 2;
        const int center_y = height() / 2;

        for (int i = 0; i < static_cast<int>(offsets.size()); ++i) {
            const qreal wave = 0.5 + 0.5 * std::sin((phase_ + offsets[static_cast<std::size_t>(i)]) * kTau);
            const qreal amplitude = baselines[static_cast<std::size_t>(i)] + (wave * 0.34);
            const int bar_height = std::clamp(static_cast<int>(std::round(amplitude * height())), min_height, height());
            const int x = x_origin + i * (bar_width + spacing);
            const int y = center_y - (bar_height / 2);
            painter.drawRoundedRect(QRectF(x, y, bar_width, bar_height), 1.5, 1.5);
        }
    }

private:
    QColor accent_ = QColor("#111315");
    qreal phase_ = 0.0;
    bool command_mode_ = false;
};

QWaylandLayerSurface* active_layer_surface(QWindow* window) {
    if (window == nullptr) {
        return nullptr;
    }

    auto* wayland_window = dynamic_cast<QtWaylandClient::QWaylandWindow*>(window->handle());
    if (wayland_window == nullptr) {
        return nullptr;
    }

    return dynamic_cast<QWaylandLayerSurface*>(wayland_window->shellSurface());
}

bool uses_waveform_indicator(const QString& text) {
    return text == "Recording" || text == "Listening";
}

bool uses_processing_indicator(const QString& text) {
    return text == "Transcribing" || text == "Thinking";
}

int persistent_label_width(const QFont& font) {
    const QFontMetrics metrics(font);
    int width = 0;
    for (const QString& candidate : {QString("Recording"), QString("Listening"), QString("Transcribing"), QString("Thinking")}) {
        width = std::max(width, metrics.horizontalAdvance(candidate));
    }
    return width;
}

int stable_panel_width(QLabel* label, const QString& text) {
    if (label == nullptr) {
        return kRecordingMinWidth;
    }

    if (uses_waveform_indicator(text) || uses_processing_indicator(text)) {
        return std::max(kRecordingMinWidth,
                        persistent_label_width(label->font()) + kIndicatorWidth + kIndicatorSpacing + kPanelHorizontalPadding);
    }

    const QFontMetrics metrics(label->font());
    return std::max(kRecordingMinWidth,
                    metrics.horizontalAdvance(text) + kIndicatorWidth + kIndicatorSpacing + kPanelHorizontalPadding);
}

QScreen* target_screen_for_host(QWidget* host_window) {
    if (host_window != nullptr && host_window->windowHandle() != nullptr && host_window->windowHandle()->screen() != nullptr) {
        return host_window->windowHandle()->screen();
    }
    if (host_window != nullptr && host_window->screen() != nullptr) {
        return host_window->screen();
    }
    return QGuiApplication::primaryScreen();
}

}  // namespace

WaylandLayerShellHudPresenter::WaylandLayerShellHudPresenter(QWidget* host_window, QObject* parent)
    : QObject(parent), host_window_(host_window), fallback_(std::make_unique<QtHudPresenter>(host_window, this)) {}

WaylandLayerShellHudPresenter::~WaylandLayerShellHudPresenter() = default;

void WaylandLayerShellHudPresenter::apply_config(const HudConfig& config) {
    config_ = config;
    if (fallback_ != nullptr) {
        fallback_->apply_config(config);
    }
    if (!config_.enabled) {
        hide();
    }
    configure_layer_shell();
}

bool WaylandLayerShellHudPresenter::supports_overlay_hud() const {
    return layer_shell_ready_;
}

void WaylandLayerShellHudPresenter::show_recording(bool command_mode) {
    show_text(command_mode ? "Listening" : "Recording",
              QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark ? "#f3f4f6" : "#111315",
              0,
              command_mode);
}

void WaylandLayerShellHudPresenter::show_transcribing() {
    show_text("Transcribing",
              QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark ? "#d1d5db" : "#1f2933",
              0);
}

void WaylandLayerShellHudPresenter::show_thinking() {
    show_text("Thinking",
              QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark ? "#cbd5e1" : "#374151",
              0);
}

void WaylandLayerShellHudPresenter::show_notice(const QString& text, int duration_ms) {
    show_text(text,
              QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark ? "#e5e7eb" : "#111315",
              duration_ms);
}

void WaylandLayerShellHudPresenter::show_error(const QString& text, int duration_ms) {
    show_text(text,
              QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark ? "#fca5a5" : "#991b1b",
              duration_ms);
}

void WaylandLayerShellHudPresenter::hide() {
    active_text_.clear();
    active_accent_.clear();
    active_duration_ms_ = 0;
    active_command_mode_ = false;
    if (hide_timer_ != nullptr) {
        hide_timer_->stop();
    }
    if (motion_animation_ != nullptr) {
        motion_animation_->stop();
    }
    if (waveform_widget_ != nullptr) {
        static_cast<HudWaveformWidget*>(waveform_widget_.data())->set_phase(0.0);
        waveform_widget_->hide();
    }
    if (hud_widget_ != nullptr) {
        hud_widget_->hide();
    }
    if (fallback_ != nullptr) {
        fallback_->hide();
    }
}

void WaylandLayerShellHudPresenter::reset_window() {
    if (hud_widget_ != nullptr) {
        hud_widget_->hide();
        delete hud_widget_;
    }
    hud_window_ = nullptr;
    hud_widget_ = nullptr;
    panel_widget_ = nullptr;
    waveform_widget_ = nullptr;
    label_ = nullptr;
    label_opacity_ = nullptr;
    hide_timer_ = nullptr;
    motion_animation_ = nullptr;
    layer_shell_ready_ = false;
}

void WaylandLayerShellHudPresenter::sync_surface_geometry(const QSize& size, int attempts_remaining) {
    if (hud_widget_ == nullptr || hud_window_ == nullptr) {
        return;
    }

    if (QWaylandLayerSurface* layer_surface = active_layer_surface(hud_window_); layer_surface != nullptr) {
        layer_surface->set_desired_geometry(QMargins(), size);
        return;
    }

    if (attempts_remaining <= 0) {
        return;
    }

    QTimer::singleShot(16, hud_widget_, [this, size, attempts_remaining]() {
        sync_surface_geometry(size, attempts_remaining - 1);
    });
}

void WaylandLayerShellHudPresenter::ensure_window() {
    if (hud_widget_ != nullptr) {
        return;
    }

    hud_widget_ = new QWidget();
    hud_widget_->setWindowFlag(Qt::FramelessWindowHint, true);
    hud_widget_->setWindowFlag(Qt::Tool, true);
    hud_widget_->setWindowFlag(Qt::WindowDoesNotAcceptFocus, true);
    hud_widget_->setAttribute(Qt::WA_ShowWithoutActivating, true);
    hud_widget_->setAttribute(Qt::WA_TranslucentBackground, true);
    hud_widget_->setAttribute(Qt::WA_TransparentForMouseEvents, true);

    auto* root_layout = new QVBoxLayout(hud_widget_);
    root_layout->setContentsMargins(kHudOuterPadding, kHudOuterPadding, kHudOuterPadding,
                                    kHudOuterPadding + std::max(0, config_.bottom_margin));

    panel_widget_ = new QWidget(hud_widget_);
    panel_widget_->setObjectName("hudPanel");
    panel_widget_->setMinimumHeight(kRecordingMinHeight);
    auto* panel_layout = new QHBoxLayout(panel_widget_);
    panel_layout->setContentsMargins(22, 14, 22, 14);
    panel_layout->setSpacing(10);
    panel_layout->addStretch(1);

    waveform_widget_ = new HudWaveformWidget(panel_widget_);
    waveform_widget_->hide();
    panel_layout->addWidget(waveform_widget_);

    auto* processing_placeholder = new QWidget(panel_widget_);
    processing_placeholder->setFixedSize(kIndicatorWidth, 18);
    processing_placeholder->hide();
    panel_layout->addWidget(processing_placeholder);

    label_ = new QLabel(panel_widget_);
    label_->setAlignment(Qt::AlignCenter);
    label_opacity_ = new QGraphicsOpacityEffect(label_);
    label_opacity_->setOpacity(1.0);
    label_->setGraphicsEffect(label_opacity_);
    panel_layout->addWidget(label_);
    panel_layout->addStretch(1);
    root_layout->addWidget(panel_widget_);

    hide_timer_ = new QTimer(hud_widget_);
    hide_timer_->setSingleShot(true);
    connect(hide_timer_, &QTimer::timeout, hud_widget_, &QWidget::hide);

    motion_animation_ = new QVariantAnimation(hud_widget_);
    motion_animation_->setLoopCount(-1);

    hud_widget_->resize(260, 92);
    if (QScreen* target_screen = target_screen_for_host(host_window_); target_screen != nullptr) {
        hud_widget_->setScreen(target_screen);
    }
    hud_widget_->createWinId();
    hud_window_ = hud_widget_->windowHandle();
    configure_layer_shell();
}

void WaylandLayerShellHudPresenter::configure_layer_shell() {
    layer_shell_ready_ = false;
    if (!QGuiApplication::platformName().contains("wayland", Qt::CaseInsensitive) || hud_window_ == nullptr) {
        return;
    }

    auto* wayland_window = dynamic_cast<QtWaylandClient::QWaylandWindow*>(hud_window_->handle());
    if (wayland_window == nullptr) {
        return;
    }

    if (integration_ == nullptr) {
        auto* candidate = new QWaylandLayerShellIntegration();
        if (!candidate->initialize(wayland_window->display())) {
            delete candidate;
            return;
        }
        integration_ = candidate;
    }

    const QSize desired_size = panel_widget_ != nullptr ? panel_widget_->sizeHint().expandedTo(QSize(kRecordingMinWidth, kRecordingMinHeight))
                                                        : QSize(kRecordingMinWidth, kRecordingMinHeight);
    integration_->set_pending_surface_configuration(
        QWaylandLayerSurface::LayerOverlay,
        QWaylandLayerSurface::AnchorLeft | QWaylandLayerSurface::AnchorRight | QWaylandLayerSurface::AnchorBottom,
        QMargins(),
        -1,
        QWaylandLayerSurface::KeyboardInteractivityNone,
        QStringLiteral("ohmytypeless-hud"),
        QSize(desired_size.width() + (kHudOuterPadding * 2),
              desired_size.height() + (kHudOuterPadding * 2) + std::max(0, config_.bottom_margin)),
        target_screen_for_host(host_window_));
    wayland_window->setShellIntegration(integration_);
    layer_shell_ready_ = true;
}

void WaylandLayerShellHudPresenter::show_text(const QString& text, const QString& accent, int duration_ms, bool command_mode) {
    if (!config_.enabled) {
        return;
    }

    active_text_ = text;
    active_accent_ = accent;
    active_duration_ms_ = duration_ms;
    active_command_mode_ = command_mode;

    if (hud_widget_ != nullptr) {
        if (QScreen* target_screen = target_screen_for_host(host_window_); target_screen != nullptr &&
            hud_widget_->screen() != target_screen) {
            reset_window();
        }
    }

    ensure_window();
    if (!layer_shell_ready_) {
        reset_window();
        if (fallback_ != nullptr) {
            if (text == "Recording" || text == "Listening") {
                fallback_->show_recording(command_mode);
            } else if (text == "Transcribing") {
                fallback_->show_transcribing();
            } else if (text == "Thinking") {
                fallback_->show_thinking();
            } else if (accent == "#991b1b" || accent == "#fca5a5") {
                fallback_->show_error(text, duration_ms);
            } else {
                fallback_->show_notice(text, duration_ms);
            }
        }
        return;
    }

    if (label_ == nullptr || panel_widget_ == nullptr || hud_widget_ == nullptr) {
        return;
    }

    const bool waveform_mode = uses_waveform_indicator(text);
    const bool error_mode = accent == "#991b1b" || accent == "#fca5a5";

    label_->setText(text);
    label_->setVisible(true);
    apply_style(accent, command_mode, error_mode);

    if (waveform_widget_ != nullptr) {
        auto* waveform = static_cast<HudWaveformWidget*>(waveform_widget_.data());
        waveform->set_accent(QColor(accent));
        waveform->set_command_mode(command_mode);
        waveform->setVisible(waveform_mode);
    }

    if (motion_animation_ != nullptr) {
        motion_animation_->stop();
        QObject::disconnect(motion_animation_, nullptr, nullptr, nullptr);
        if (waveform_mode) {
            motion_animation_->setDuration(760);
            motion_animation_->setStartValue(0.0);
            motion_animation_->setEndValue(1.0);
            motion_animation_->setEasingCurve(QEasingCurve::InOutSine);
            QObject::connect(motion_animation_, &QVariantAnimation::valueChanged, hud_widget_, [waveform = waveform_widget_](const QVariant& value) {
                if (waveform != nullptr) {
                    static_cast<HudWaveformWidget*>(waveform.data())->set_phase(value.toDouble());
                }
            });
            motion_animation_->start();
        }
    }

    if (uses_waveform_indicator(text) || uses_processing_indicator(text)) {
        label_->setFixedWidth(persistent_label_width(label_->font()));
    } else {
        label_->setFixedWidth(label_->sizeHint().width());
    }
    label_->adjustSize();
    if (auto* root_layout = qobject_cast<QVBoxLayout*>(hud_widget_->layout()); root_layout != nullptr) {
        root_layout->setContentsMargins(kHudOuterPadding, kHudOuterPadding, kHudOuterPadding,
                                        kHudOuterPadding + std::max(0, config_.bottom_margin));
        root_layout->invalidate();
        root_layout->activate();
    }
    panel_widget_->adjustSize();
    hud_widget_->adjustSize();
    const int panel_width = waveform_mode ? kRecordingMinWidth : std::max(stable_panel_width(label_, text), kRecordingMinWidth);
    const QSize panel_size(panel_width, kRecordingMinHeight);
    panel_widget_->setFixedWidth(panel_size.width());
    panel_widget_->resize(panel_size);
    const QSize surface_size(panel_size.width() + (kHudOuterPadding * 2),
                             panel_size.height() + (kHudOuterPadding * 2) + std::max(0, config_.bottom_margin));
    hud_widget_->resize(surface_size);
    hud_widget_->show();
    sync_surface_geometry(surface_size);

    if (hide_timer_ != nullptr) {
        hide_timer_->stop();
        if (duration_ms > 0) {
            hide_timer_->start(duration_ms);
        }
    }
}

void WaylandLayerShellHudPresenter::apply_style(const QString& accent, bool command_mode, bool error) {
    if (hud_widget_ == nullptr) {
        return;
    }

    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    const QString panel_background = error ? (dark ? "rgba(61, 24, 24, 244)" : "rgba(255, 244, 244, 244)")
                                           : (command_mode ? (dark ? "rgba(41, 45, 50, 244)" : "rgba(248, 249, 250, 244)")
                                                           : (dark ? "rgba(29, 33, 38, 244)" : "rgba(255, 255, 255, 244)"));
    const QString panel_border = error ? (dark ? "rgba(252,165,165,0.32)" : "rgba(153,27,27,0.16)")
                                       : (command_mode ? (dark ? "rgba(255,255,255,0.18)" : "rgba(17,19,21,0.18)")
                                                       : (dark ? "rgba(255,255,255,0.10)" : "rgba(17,19,21,0.08)"));
    hud_widget_->setStyleSheet(QStringLiteral(
        "QWidget { background: transparent; border: none; }"
        "QWidget#hudPanel { background: %1; border: 1px solid %2; border-radius: 18px; }"
        "QLabel { color: %3; font-family: \"Noto Sans\", \"DejaVu Sans\", sans-serif; font-size: 14px; font-weight: 700; }")
                                  .arg(panel_background, panel_border, accent));
    if (label_opacity_ != nullptr) {
        label_opacity_->setOpacity(1.0);
    }
}

}  // namespace ohmytypeless
