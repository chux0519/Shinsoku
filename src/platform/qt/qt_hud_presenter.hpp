#pragma once

#include "platform/hud_presenter.hpp"

#include <QObject>
#include <QPointer>
#include <vector>

class QLabel;
class QScreen;
class QWidget;
class QTimer;

namespace ohmytypeless {

class QtHudPresenter final : public QObject, public HudPresenter {
    Q_OBJECT
public:
    explicit QtHudPresenter(QObject* parent = nullptr);

    void apply_config(const HudConfig& config) override;
    void show_recording() override;
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
        QPointer<QLabel> label;
        QPointer<QTimer> hide_timer;
    };

    void rebuild_overlays();
    void ensure_overlays();
    void show_text(const QString& text, const QString& accent, int duration_ms);

    std::vector<HudOverlay> overlays_;
    HudConfig config_;
};

}  // namespace ohmytypeless
