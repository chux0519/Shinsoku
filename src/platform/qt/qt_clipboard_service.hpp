#pragma once

#include "platform/clipboard_service.hpp"

class QClipboard;

namespace ohmytypeless {

class QtClipboardService final : public ClipboardService {
public:
    explicit QtClipboardService(QClipboard* clipboard);

    void copy_text(const QString& text) override;

private:
    QClipboard* clipboard_ = nullptr;
};

}  // namespace ohmytypeless
