#include "platform/qt/qt_hud_presenter.hpp"

#include <QApplication>
#include <QFile>
#include <QGuiApplication>
#include <QBuffer>
#include <QEvent>
#include <QEasingCurve>
#include <QGraphicsOpacityEffect>
#include <QLabel>
#include <QHBoxLayout>
#include <QLayout>
#include <QPainter>
#include <QPixmap>
#include <QScreen>
#include <QSizePolicy>
#include <QSvgRenderer>
#include <QStyleHints>
#include <QTimer>
#include <QVariantAnimation>
#include <QWidget>
#include <QFontMetrics>
#include <algorithm>
#include <array>
#include <cmath>

namespace ohmytypeless {

namespace {

class HudWaveformWidget final : public QWidget {
public:
    explicit HudWaveformWidget(QWidget* parent = nullptr) : QWidget(parent) {
        setObjectName("hudWaveform");
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
        constexpr qreal kTau = 6.28318530717958647692;
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

class HudProcessingDotsWidget final : public QWidget {
public:
    explicit HudProcessingDotsWidget(QWidget* parent = nullptr) : QWidget(parent) {
        setObjectName("hudProcessing");
        setFixedSize(20, 18);
    }

    void set_accent(const QColor& color) {
        accent_ = color;
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

        constexpr qreal kTau = 6.28318530717958647692;
        constexpr std::array<qreal, 3> offsets = {0.0, 0.17, 0.34};
        constexpr int dot_size = 4;
        constexpr int gap = 3;
        const int total_width = dot_size * 3 + gap * 2;
        const int x_origin = (width() - total_width) / 2;
        const int y_origin = (height() - dot_size) / 2;

        for (int i = 0; i < 3; ++i) {
            QColor dot_color = accent_;
            const qreal pulse = 0.35 + 0.65 * (0.5 + 0.5 * std::sin((phase_ + offsets[static_cast<std::size_t>(i)]) * kTau));
            dot_color.setAlphaF(pulse);
            painter.setBrush(dot_color);
            painter.drawEllipse(QRectF(x_origin + i * (dot_size + gap), y_origin, dot_size, dot_size));
        }
    }

private:
    QColor accent_ = QColor("#111315");
    qreal phase_ = 0.0;
};

QSize hud_size_for(QWidget* widget) {
    const QSize preferred = widget->sizeHint();
    const QSize minimum = widget->minimumSizeHint();
    return preferred.expandedTo(minimum);
}

bool is_persistent_hud_state(const QString& text) {
    return text == "Recording" || text == "Listening" || text == "Transcribing" || text == "Thinking";
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

int stable_hud_width(QLabel* label, const QString& text) {
    if (label == nullptr) {
        return 0;
    }

    if (is_persistent_hud_state(text)) {
        constexpr int kIconWidth = 20;
        constexpr int kSpacing = 10;
        constexpr int kPanelHorizontalPadding = 44;
        return persistent_label_width(label->font()) + kIconWidth + kSpacing + kPanelHorizontalPadding;
    }

    const QFontMetrics metrics(label->font());
    const int text_width = metrics.horizontalAdvance(text);
    constexpr int kIconWidth = 20;
    constexpr int kSpacing = 10;
    constexpr int kPanelHorizontalPadding = 44;
    constexpr int kMinimumWidth = 168;
    return std::max(kMinimumWidth, text_width + kIconWidth + kSpacing + kPanelHorizontalPadding);
}

QString load_hud_stylesheet(const QString& panel_background, const QString& panel_border, const QString& text_color) {
    QFile file(":/themes/hud.qss");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString();
    }

    QString style = QString::fromUtf8(file.readAll());
    style.replace("{{panel_bg}}", panel_background);
    style.replace("{{panel_border}}", panel_border);
    style.replace("{{text_color}}", text_color);
    return style;
}

QByteArray load_tinted_svg(const QString& icon_path, const QString& color) {
    QFile file(icon_path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }

    QByteArray svg = file.readAll();
    svg.replace("currentColor", color.toUtf8());
    return svg;
}

}  // namespace

QtHudPresenter::QtHudPresenter(QWidget* host_window, QObject* parent) : QObject(parent), host_window_(host_window) {
    if (host_window_ != nullptr) {
        host_window_->installEventFilter(this);
    }
}

void QtHudPresenter::apply_config(const HudConfig& config) {
    config_ = config;
    if (!config_.enabled) {
        hide();
    }
}

bool QtHudPresenter::supports_overlay_hud() const {
    return true;
}

bool QtHudPresenter::eventFilter(QObject* watched, QEvent* event) {
    if (watched == host_window_ && event != nullptr) {
        switch (event->type()) {
        case QEvent::Move:
        case QEvent::Resize:
        case QEvent::Show:
        case QEvent::WindowStateChange:
            for (auto& overlay : overlays_) {
                if (overlay.widget == nullptr) {
                    continue;
                }
                const QString text = overlay.label != nullptr ? overlay.label->text() : QString();
                reposition_overlay(overlay, overlay.widget->size(), is_persistent_hud_state(text));
            }
            break;
        default:
            break;
        }
    }
    return QObject::eventFilter(watched, event);
}

void QtHudPresenter::show_recording(bool command_mode) {
    if (!supports_overlay_hud()) {
        return;
    }
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    show_text(command_mode ? "Listening" : "Recording", dark ? "#f3f4f6" : "#111315", 0, command_mode);
}

void QtHudPresenter::show_transcribing() {
    if (!supports_overlay_hud()) {
        return;
    }
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    show_text("Transcribing", dark ? "#d1d5db" : "#1f2933", 0);
}

void QtHudPresenter::show_thinking() {
    if (!supports_overlay_hud()) {
        return;
    }
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    show_text("Thinking", dark ? "#cbd5e1" : "#374151", 0);
}

void QtHudPresenter::show_notice(const QString& text, int duration_ms) {
    if (!supports_overlay_hud()) {
        return;
    }
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    show_text(text, dark ? "#e5e7eb" : "#111315", duration_ms);
}

void QtHudPresenter::show_error(const QString& text, int duration_ms) {
    if (!supports_overlay_hud()) {
        return;
    }
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    show_text(text, dark ? "#fca5a5" : "#991b1b", duration_ms);
}

void QtHudPresenter::set_icon(const QString& icon_path, const QString& color, int size_px) {
    const QByteArray svg = load_tinted_svg(icon_path, color);
    if (svg.isEmpty()) {
        for (auto& overlay : overlays_) {
            if (overlay.icon != nullptr) {
                overlay.icon->clear();
            }
            if (overlay.waveform != nullptr) {
                overlay.waveform->hide();
            }
            if (overlay.processing != nullptr) {
                overlay.processing->hide();
            }
        }
        return;
    }

    QSvgRenderer renderer(svg);
    if (!renderer.isValid()) {
        for (auto& overlay : overlays_) {
            if (overlay.icon != nullptr) {
                overlay.icon->clear();
            }
            if (overlay.waveform != nullptr) {
                overlay.waveform->hide();
            }
            if (overlay.processing != nullptr) {
                overlay.processing->hide();
            }
        }
        return;
    }

    QPixmap pixmap(size_px, size_px);
    pixmap.fill(Qt::transparent);
    QPainter painter(&pixmap);
    renderer.render(&painter);

    for (auto& overlay : overlays_) {
        if (overlay.icon != nullptr) {
            overlay.icon->setPixmap(pixmap);
            overlay.icon->show();
        }
        if (overlay.waveform != nullptr) {
            overlay.waveform->hide();
        }
        if (overlay.processing != nullptr) {
            overlay.processing->hide();
        }
    }
}

void QtHudPresenter::hide() {
    stop_motion();
    for (auto& overlay : overlays_) {
        if (overlay.hide_timer != nullptr) {
            overlay.hide_timer->stop();
        }
        overlay.anchor_locked = false;
        if (overlay.widget != nullptr) {
            overlay.widget->hide();
        }
    }
}

void QtHudPresenter::rebuild_overlays() {
    hide();
    overlays_.clear();

    const QList<QScreen*> screens = QGuiApplication::screens();
    overlays_.reserve(static_cast<std::size_t>(screens.size()));
    for (QScreen* screen : screens) {
        if (screen == nullptr) {
            continue;
        }

        auto* widget = new QWidget();
        widget->setWindowFlag(Qt::FramelessWindowHint, true);
        widget->setWindowFlag(Qt::Tool, true);
        widget->setWindowFlag(Qt::WindowStaysOnTopHint, true);
        widget->setAttribute(Qt::WA_ShowWithoutActivating, true);
        widget->setAttribute(Qt::WA_TransparentForMouseEvents, true);
        widget->setAttribute(Qt::WA_TranslucentBackground, true);
        widget->setFocusPolicy(Qt::NoFocus);

        auto* layout = new QHBoxLayout(widget);
        layout->setContentsMargins(18, 18, 18, 18);
        layout->setSizeConstraint(QLayout::SetFixedSize);

        auto* panel = new QWidget(widget);
        panel->setObjectName("hudPanel");
        panel->setMinimumHeight(56);
        panel->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);
        auto* panel_layout = new QHBoxLayout(panel);
        panel_layout->setContentsMargins(22, 14, 22, 14);
        panel_layout->setSpacing(10);
        panel_layout->setSizeConstraint(QLayout::SetFixedSize);
        panel_layout->addStretch(1);

        auto* icon = new QLabel(panel);
        icon->setObjectName("hudIcon");
        icon->setAlignment(Qt::AlignCenter);
        icon->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);
        auto* icon_opacity = new QGraphicsOpacityEffect(icon);
        icon_opacity->setOpacity(0.96);
        icon->setGraphicsEffect(icon_opacity);
        panel_layout->addWidget(icon);

        auto* waveform = new HudWaveformWidget(panel);
        waveform->hide();
        panel_layout->addWidget(waveform);

        auto* processing = new HudProcessingDotsWidget(panel);
        processing->hide();
        panel_layout->addWidget(processing);

        auto* label = new QLabel(panel);
        label->setAlignment(Qt::AlignCenter);
        label->setWordWrap(false);
        label->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Preferred);
        auto* label_opacity = new QGraphicsOpacityEffect(label);
        label_opacity->setOpacity(1.0);
        label->setGraphicsEffect(label_opacity);
        panel_layout->addWidget(label);
        panel_layout->addStretch(1);
        layout->addWidget(panel);

        auto* timer = new QTimer(widget);
        timer->setSingleShot(true);
        connect(timer, &QTimer::timeout, widget, &QWidget::hide);

        auto* icon_pulse = new QVariantAnimation(widget);
        icon_pulse->setLoopCount(-1);
        auto* label_pulse = new QVariantAnimation(widget);
        label_pulse->setLoopCount(-1);

        overlays_.push_back(HudOverlay{
            .screen = screen,
            .widget = widget,
            .panel = panel,
            .icon = icon,
            .waveform = waveform,
            .processing = processing,
            .label = label,
            .hide_timer = timer,
            .icon_opacity = icon_opacity,
            .label_opacity = label_opacity,
            .icon_pulse = icon_pulse,
            .label_pulse = label_pulse,
            .anchor_center = {},
            .anchor_locked = false,
        });
    }
}

void QtHudPresenter::ensure_overlays() {
    const QList<QScreen*> screens = QGuiApplication::screens();
    const bool matches_screen_count = overlays_.size() == static_cast<std::size_t>(screens.size());
    if (matches_screen_count) {
        bool screens_match = true;
        for (std::size_t i = 0; i < overlays_.size(); ++i) {
            if (overlays_[i].screen != screens[static_cast<qsizetype>(i)]) {
                screens_match = false;
                break;
            }
        }
        if (screens_match) {
            return;
        }
    }

    rebuild_overlays();
}

void QtHudPresenter::reposition_overlay(HudOverlay& overlay, const QSize& size, bool persistent_state) {
    if (overlay.widget == nullptr || overlay.screen == nullptr) {
        return;
    }

    const QRect available = overlay.screen->availableGeometry();
    if (persistent_state) {
        if (!overlay.anchor_locked) {
            overlay.anchor_center = QPoint(available.x() + available.width() / 2,
                                           available.bottom() - config_.bottom_margin - (size.height() / 2));
            overlay.anchor_locked = true;
        }
    } else {
        overlay.anchor_center = QPoint(available.x() + available.width() / 2,
                                       available.bottom() - config_.bottom_margin - (size.height() / 2));
        overlay.anchor_locked = false;
    }

    const int x = overlay.anchor_center.x() - (size.width() / 2);
    const int y = overlay.anchor_center.y() - (size.height() / 2);
    const bool should_move = !persistent_state || !overlay.widget->isVisible() || !overlay.anchor_locked;
    if (should_move) {
        overlay.widget->move(x, y);
    }
}

void QtHudPresenter::show_text(const QString& text, const QString& accent, int duration_ms, bool command_mode) {
    if (!config_.enabled) {
        return;
    }
    ensure_overlays();
    if (overlays_.empty()) {
        return;
    }

    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    const QString panel_background = command_mode ? (dark ? "rgba(41, 45, 50, 244)" : "rgba(248, 249, 250, 244)")
                                                  : (dark ? "rgba(29, 33, 38, 244)" : "rgba(255, 255, 255, 244)");
    const QString panel_border = command_mode ? (dark ? "rgba(255,255,255,0.18)" : "rgba(17,19,21,0.18)")
                                              : (dark ? "rgba(255,255,255,0.10)" : "rgba(17,19,21,0.08)");
    const QString style = load_hud_stylesheet(panel_background, panel_border, accent);
    const bool waveform_mode = uses_waveform_indicator(text);
    const bool processing_mode = uses_processing_indicator(text);
    QString icon_path = ":/icons/audio-lines.svg";
    if (text.contains("error", Qt::CaseInsensitive)) {
        icon_path = ":/icons/triangle-alert.svg";
    }
    if (!waveform_mode && !processing_mode) {
        set_icon(icon_path, accent, 18);
    }
    start_motion(text);

    for (auto& overlay : overlays_) {
        if (overlay.widget == nullptr || overlay.panel == nullptr || overlay.label == nullptr || overlay.screen == nullptr) {
            continue;
        }

        overlay.label->setText(text);
        overlay.widget->setStyleSheet(style);
        if (overlay.waveform != nullptr) {
            if (waveform_mode) {
                auto* waveform = static_cast<HudWaveformWidget*>(overlay.waveform.data());
                waveform->set_accent(QColor(accent));
                waveform->set_command_mode(command_mode);
                waveform->show();
            } else {
                overlay.waveform->hide();
            }
        }
        if (overlay.processing != nullptr) {
            if (processing_mode) {
                auto* processing = static_cast<HudProcessingDotsWidget*>(overlay.processing.data());
                processing->set_accent(QColor(accent));
                processing->show();
            } else {
                overlay.processing->hide();
            }
        }
        if (overlay.icon != nullptr) {
            overlay.icon->setVisible(!waveform_mode && !processing_mode);
        }
        const int panel_width = stable_hud_width(overlay.label, text);
        if (is_persistent_hud_state(text)) {
            overlay.panel->setFixedWidth(panel_width);
            overlay.label->setFixedWidth(persistent_label_width(overlay.label->font()));
        } else {
            overlay.panel->setMinimumWidth(168);
            overlay.panel->setMaximumWidth(QWIDGETSIZE_MAX);
            overlay.panel->resize(panel_width, overlay.panel->height());
            overlay.label->setFixedWidth(overlay.label->sizeHint().width());
        }
        if (overlay.panel->layout() != nullptr) {
            overlay.panel->layout()->invalidate();
            overlay.panel->layout()->activate();
        }
        if (overlay.widget->layout() != nullptr) {
            overlay.widget->layout()->invalidate();
            overlay.widget->layout()->activate();
        }
        overlay.panel->adjustSize();
        overlay.widget->adjustSize();
        const QSize size = hud_size_for(overlay.widget);
        overlay.widget->resize(size);

        reposition_overlay(overlay, size, is_persistent_hud_state(text));
        overlay.widget->show();
        overlay.widget->raise();

        if (overlay.hide_timer != nullptr) {
            overlay.hide_timer->stop();
            if (duration_ms > 0) {
                overlay.anchor_locked = false;
                overlay.hide_timer->start(duration_ms);
            }
        }
    }
}

void QtHudPresenter::start_motion(const QString& text) {
    const bool waveform_mode = uses_waveform_indicator(text);
    const bool processing_mode = uses_processing_indicator(text);
    const bool active = waveform_mode || processing_mode;

    for (auto& overlay : overlays_) {
        if (overlay.icon_pulse == nullptr || overlay.icon_opacity == nullptr || overlay.label_pulse == nullptr ||
            overlay.label_opacity == nullptr) {
            continue;
        }

        overlay.icon_pulse->stop();
        overlay.label_pulse->stop();
        if (!active) {
            overlay.icon_opacity->setOpacity(0.96);
            overlay.label_opacity->setOpacity(1.0);
            if (overlay.waveform != nullptr) {
                overlay.waveform->update();
            }
            if (overlay.processing != nullptr) {
                overlay.processing->update();
            }
            continue;
        }

        QObject::disconnect(overlay.icon_pulse, nullptr, nullptr, nullptr);
        if (waveform_mode) {
            overlay.icon_pulse->setDuration(760);
            overlay.icon_pulse->setStartValue(0.0);
            overlay.icon_pulse->setEndValue(1.0);
            overlay.icon_pulse->setEasingCurve(QEasingCurve::InOutSine);
            overlay.icon_pulse->setDirection(QAbstractAnimation::Forward);
            QObject::connect(overlay.icon_pulse, &QVariantAnimation::valueChanged, overlay.widget, [waveform = overlay.waveform](const QVariant& value) {
                if (waveform != nullptr) {
                    static_cast<HudWaveformWidget*>(waveform.data())->set_phase(value.toDouble());
                }
            });
            overlay.icon_pulse->start();
        } else if (processing_mode) {
            overlay.icon_pulse->setDuration(text == "Thinking" ? 980 : 760);
            overlay.icon_pulse->setStartValue(0.0);
            overlay.icon_pulse->setEndValue(1.0);
            overlay.icon_pulse->setEasingCurve(QEasingCurve::InOutSine);
            overlay.icon_pulse->setDirection(QAbstractAnimation::Forward);
            QObject::connect(overlay.icon_pulse, &QVariantAnimation::valueChanged, overlay.widget, [processing = overlay.processing](const QVariant& value) {
                if (processing != nullptr) {
                    static_cast<HudProcessingDotsWidget*>(processing.data())->set_phase(value.toDouble());
                }
            });
            overlay.icon_pulse->start();
        }
        overlay.label_opacity->setOpacity(1.0);
    }
}

void QtHudPresenter::stop_motion() {
    for (auto& overlay : overlays_) {
        if (overlay.icon_pulse != nullptr) {
            overlay.icon_pulse->stop();
        }
        if (overlay.label_pulse != nullptr) {
            overlay.label_pulse->stop();
        }
        if (overlay.icon_opacity != nullptr) {
            overlay.icon_opacity->setOpacity(0.96);
        }
        if (overlay.label_opacity != nullptr) {
            overlay.label_opacity->setOpacity(1.0);
        }
        if (overlay.waveform != nullptr) {
            static_cast<HudWaveformWidget*>(overlay.waveform.data())->set_phase(0.0);
        }
        if (overlay.processing != nullptr) {
            static_cast<HudProcessingDotsWidget*>(overlay.processing.data())->set_phase(0.0);
        }
    }
}

}  // namespace ohmytypeless
