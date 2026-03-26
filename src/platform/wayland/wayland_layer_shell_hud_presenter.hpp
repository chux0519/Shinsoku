#pragma once

#include "platform/hud_presenter.hpp"

#include <QColor>
#include <QObject>
#include <QPointer>

class QGraphicsOpacityEffect;
class QLabel;
class QTimer;
class QVariantAnimation;
class QWidget;
class QWindow;

namespace ohmytypeless {

class QWaylandLayerShellIntegration;

class QtHudPresenter;

class WaylandLayerShellHudPresenter final : public QObject, public HudPresenter {
    Q_OBJECT
public:
    explicit WaylandLayerShellHudPresenter(QWidget* host_window = nullptr, QObject* parent = nullptr);
    ~WaylandLayerShellHudPresenter() override;

    void apply_config(const HudConfig& config) override;
    bool supports_overlay_hud() const override;
    void show_recording(bool command_mode = false) override;
    void show_transcribing() override;
    void show_thinking() override;
    void show_notice(const QString& text, int duration_ms = 1500) override;
    void show_error(const QString& text, int duration_ms = 2200) override;
    void hide() override;

private:
    void ensure_window();
    void configure_layer_shell();
    void show_text(const QString& text, const QString& accent, int duration_ms, bool command_mode = false);
    void apply_style(const QString& accent, bool command_mode, bool error = false);
    void reset_window();
    void sync_surface_geometry(const QSize& size, int attempts_remaining = 4);

    HudConfig config_;
    QPointer<QWidget> host_window_;
    QPointer<QWidget> hud_widget_;
    QPointer<QWidget> panel_widget_;
    QPointer<QWidget> waveform_widget_;
    QPointer<QLabel> label_;
    QPointer<QTimer> hide_timer_;
    QPointer<QWindow> hud_window_;
    QPointer<QGraphicsOpacityEffect> label_opacity_;
    QPointer<QVariantAnimation> motion_animation_;
    std::unique_ptr<QtHudPresenter> fallback_;
    QWaylandLayerShellIntegration* integration_ = nullptr;
    bool layer_shell_ready_ = false;
    QString active_text_;
    QString active_accent_;
    int active_duration_ms_ = 0;
    bool active_command_mode_ = false;
};

}  // namespace ohmytypeless
