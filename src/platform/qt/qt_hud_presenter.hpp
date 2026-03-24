#pragma once

#include "platform/hud_presenter.hpp"

#include <QObject>
#include <QPoint>
#include <QPointer>
#include <vector>

class QLabel;
class QScreen;
class QWidget;
class QTimer;
class QGraphicsOpacityEffect;
class QVariantAnimation;

namespace ohmytypeless {

class QtHudPresenter final : public QObject, public HudPresenter {
    Q_OBJECT
public:
    explicit QtHudPresenter(QObject* parent = nullptr);

    void apply_config(const HudConfig& config) override;
    void show_recording(bool command_mode = false) override;
    void show_transcribing() override;
    void show_thinking() override;
    void show_notice(const QString& text, int duration_ms = 1500) override;
    void show_error(const QString& text, int duration_ms = 2200) override;
    void hide() override;

private:
    struct HudOverlay {
        QPointer<QScreen> screen;
        QPointer<QWidget> widget;
        QPointer<QWidget> panel;
        QPointer<QLabel> icon;
        QPointer<QWidget> waveform;
        QPointer<QWidget> processing;
        QPointer<QLabel> label;
        QPointer<QTimer> hide_timer;
        QPointer<QGraphicsOpacityEffect> icon_opacity;
        QPointer<QGraphicsOpacityEffect> label_opacity;
        QPointer<QVariantAnimation> icon_pulse;
        QPointer<QVariantAnimation> label_pulse;
        QPoint anchor_center;
        bool anchor_locked = false;
    };

    void rebuild_overlays();
    void ensure_overlays();
    void show_text(const QString& text, const QString& accent, int duration_ms, bool command_mode = false);
    void set_icon(const QString& icon_path, const QString& color, int size_px);
    void start_motion(const QString& text);
    void stop_motion();

    std::vector<HudOverlay> overlays_;
    HudConfig config_;
};

}  // namespace ohmytypeless
