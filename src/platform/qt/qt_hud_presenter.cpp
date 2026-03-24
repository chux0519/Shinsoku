#include "platform/qt/qt_hud_presenter.hpp"

#include <QApplication>
#include <QFile>
#include <QGuiApplication>
#include <QBuffer>
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

namespace ohmytypeless {

namespace {

QSize hud_size_for(QWidget* widget) {
    const QSize preferred = widget->sizeHint();
    const QSize minimum = widget->minimumSizeHint();
    return preferred.expandedTo(minimum);
}

bool is_persistent_hud_state(const QString& text) {
    return text == "Recording" || text == "Listening" || text == "Transcribing" || text == "Thinking";
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
        constexpr int kIconWidth = 18;
        constexpr int kSpacing = 10;
        constexpr int kPanelHorizontalPadding = 44;
        return persistent_label_width(label->font()) + kIconWidth + kSpacing + kPanelHorizontalPadding;
    }

    const QFontMetrics metrics(label->font());
    const int text_width = metrics.horizontalAdvance(text);
    constexpr int kIconWidth = 18;
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

QtHudPresenter::QtHudPresenter(QObject* parent) : QObject(parent) {}

void QtHudPresenter::apply_config(const HudConfig& config) {
    config_ = config;
    if (!config_.enabled) {
        hide();
    }
}

void QtHudPresenter::show_recording(bool command_mode) {
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    show_text(command_mode ? "Listening" : "Recording", dark ? "#f3f4f6" : "#111315", 0, command_mode);
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

void QtHudPresenter::set_icon(const QString& icon_path, const QString& color, int size_px) {
    const QByteArray svg = load_tinted_svg(icon_path, color);
    if (svg.isEmpty()) {
        for (auto& overlay : overlays_) {
            if (overlay.icon != nullptr) {
                overlay.icon->clear();
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

        auto* label = new QLabel(panel);
        label->setAlignment(Qt::AlignCenter);
        label->setWordWrap(false);
        label->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Preferred);
        panel_layout->addWidget(label);
        panel_layout->addStretch(1);
        layout->addWidget(panel);

        auto* timer = new QTimer(widget);
        timer->setSingleShot(true);
        connect(timer, &QTimer::timeout, widget, &QWidget::hide);

        auto* icon_pulse = new QVariantAnimation(widget);
        icon_pulse->setLoopCount(-1);
        connect(icon_pulse, &QVariantAnimation::valueChanged, widget, [icon_opacity](const QVariant& value) {
            if (icon_opacity != nullptr) {
                icon_opacity->setOpacity(value.toDouble());
            }
        });

        overlays_.push_back(HudOverlay{
            .screen = screen,
            .widget = widget,
            .panel = panel,
            .icon = icon,
            .label = label,
            .hide_timer = timer,
            .icon_opacity = icon_opacity,
            .icon_pulse = icon_pulse,
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
    QString icon_path = ":/icons/audio-lines.svg";
    if (text == "Recording") {
        icon_path = ":/icons/mic.svg";
    } else if (text == "Listening") {
        icon_path = ":/icons/command.svg";
    } else if (text == "Thinking") {
        icon_path = ":/icons/sparkles.svg";
    } else if (text.contains("error", Qt::CaseInsensitive)) {
        icon_path = ":/icons/triangle-alert.svg";
    }
    set_icon(icon_path, accent, 18);
    start_motion(text);

    for (auto& overlay : overlays_) {
        if (overlay.widget == nullptr || overlay.panel == nullptr || overlay.label == nullptr || overlay.screen == nullptr) {
            continue;
        }

        overlay.label->setText(text);
        overlay.widget->setStyleSheet(style);
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

        const QRect available = overlay.screen->availableGeometry();
        if (is_persistent_hud_state(text)) {
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
        const bool should_move = !is_persistent_hud_state(text) || !overlay.widget->isVisible() || !overlay.anchor_locked;
        if (should_move) {
            overlay.widget->move(x, y);
        }
        overlay.widget->show();

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
    const bool breathing = text == "Recording" || text == "Listening";
    const bool active = breathing || text == "Transcribing" || text == "Thinking";

    for (auto& overlay : overlays_) {
        if (overlay.icon_pulse == nullptr || overlay.icon_opacity == nullptr) {
            continue;
        }

        overlay.icon_pulse->stop();
        if (!active) {
            overlay.icon_opacity->setOpacity(0.96);
            continue;
        }

        if (breathing) {
            overlay.icon_pulse->setDuration(1100);
            overlay.icon_pulse->setStartValue(0.42);
            overlay.icon_pulse->setKeyValueAt(0.5, 1.0);
            overlay.icon_pulse->setEndValue(0.42);
            overlay.icon_pulse->setEasingCurve(QEasingCurve::InOutSine);
        } else {
            overlay.icon_pulse->setDuration(760);
            overlay.icon_pulse->setStartValue(0.55);
            overlay.icon_pulse->setKeyValueAt(0.5, 1.0);
            overlay.icon_pulse->setEndValue(0.55);
            overlay.icon_pulse->setEasingCurve(QEasingCurve::InOutQuad);
        }
        overlay.icon_pulse->setDirection(QAbstractAnimation::Forward);
        overlay.icon_pulse->start();
    }
}

void QtHudPresenter::stop_motion() {
    for (auto& overlay : overlays_) {
        if (overlay.icon_pulse != nullptr) {
            overlay.icon_pulse->stop();
        }
        if (overlay.icon_opacity != nullptr) {
            overlay.icon_opacity->setOpacity(0.96);
        }
    }
}

}  // namespace ohmytypeless
