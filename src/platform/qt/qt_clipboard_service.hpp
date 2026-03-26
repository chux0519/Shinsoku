#pragma once

#include "platform/clipboard_service.hpp"

class QClipboard;

namespace ohmytypeless {

class QtClipboardService final : public ClipboardService {
public:
    explicit QtClipboardService(QClipboard* clipboard);

    bool supports_auto_paste() const override;
    void begin_paste_session() override;
    void clear_paste_session() override;
    void copy_text(const QString& text) override;
    bool paste_text_to_last_target(const QString& text, const QString& paste_keys) override;
    QString last_debug_info() const override;

private:
    QClipboard* clipboard_ = nullptr;
};

}  // namespace ohmytypeless
