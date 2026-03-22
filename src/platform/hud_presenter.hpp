#pragma once

#include <QString>

namespace ohmytypeless {

class HudPresenter {
public:
    virtual ~HudPresenter() = default;

    virtual void show_recording() = 0;
    virtual void show_transcribing() = 0;
    virtual void show_notice(const QString& text, int duration_ms = 1500) = 0;
    virtual void show_error(const QString& text, int duration_ms = 2200) = 0;
    virtual void hide() = 0;
};

}  // namespace ohmytypeless
