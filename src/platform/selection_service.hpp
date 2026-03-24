#pragma once

#include <QString>

namespace ohmytypeless {

struct SelectionCaptureResult {
    bool success = false;
    QString selected_text;
    QString debug_info;
};

class SelectionService {
public:
    virtual ~SelectionService() = default;
    virtual QString backend_name() const = 0;
    virtual bool supports_automatic_detection() const = 0;
    virtual SelectionCaptureResult capture_selection() = 0;
    virtual bool replace_selection(const QString& text) = 0;
    virtual QString last_debug_info() const = 0;
};

}  // namespace ohmytypeless
