#pragma once

#include "platform/hud_presenter.hpp"

#include <memory>

class QWidget;

namespace ohmytypeless {

class MacOSHudPresenter final : public HudPresenter {
public:
    explicit MacOSHudPresenter(QWidget* host_window = nullptr);
    ~MacOSHudPresenter() override;

    void apply_config(const HudConfig& config) override;
    bool supports_overlay_hud() const override;
    void show_recording(bool command_mode = false) override;
    void show_transcribing() override;
    void show_thinking() override;
    void show_notice(const QString& text, int duration_ms = 1500) override;
    void show_error(const QString& text, int duration_ms = 2200) override;
    void hide() override;

private:
    class Impl;
    std::unique_ptr<Impl> impl_;
};

}  // namespace ohmytypeless
