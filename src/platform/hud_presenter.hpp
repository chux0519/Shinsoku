#pragma once

#include "core/app_config.hpp"

#include <QString>

namespace ohmytypeless {

class HudPresenter {
public:
    virtual ~HudPresenter() = default;

    virtual void apply_config(const HudConfig& config) = 0;
    virtual void show_recording(bool command_mode = false) = 0;
    virtual void show_transcribing() = 0;
    virtual void show_thinking() = 0;
    virtual void show_notice(const QString& text, int duration_ms = 1500) = 0;
    virtual void show_error(const QString& text, int duration_ms = 2200) = 0;
    virtual void hide() = 0;
};

}  // namespace ohmytypeless
