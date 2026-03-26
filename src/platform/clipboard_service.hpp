#pragma once

#include <QString>

namespace ohmytypeless {

class ClipboardService {
public:
    virtual ~ClipboardService() = default;
    virtual bool supports_auto_paste() const = 0;
    virtual void begin_paste_session() = 0;
    virtual void clear_paste_session() = 0;
    virtual void copy_text(const QString& text) = 0;
    virtual bool paste_text_to_last_target(const QString& text, const QString& paste_keys) = 0;
    virtual QString last_debug_info() const = 0;
};

}  // namespace ohmytypeless
