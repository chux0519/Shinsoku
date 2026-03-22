#pragma once

#include <QString>

namespace ohmytypeless {

class ClipboardService {
public:
    virtual ~ClipboardService() = default;
    virtual void copy_text(const QString& text) = 0;
};

}  // namespace ohmytypeless
