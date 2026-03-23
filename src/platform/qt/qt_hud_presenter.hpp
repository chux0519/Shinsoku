#pragma once

#include "platform/hud_presenter.hpp"

#include <QObject>
#include <QPointer>

class QLabel;
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
    void ensure_widget();
    void show_text(const QString& text, const QString& accent, int duration_ms);

    QPointer<QWidget> widget_;
    QPointer<QWidget> panel_;
    QPointer<QLabel> label_;
    QPointer<QTimer> hide_timer_;
    HudConfig config_;
};

}  // namespace ohmytypeless
