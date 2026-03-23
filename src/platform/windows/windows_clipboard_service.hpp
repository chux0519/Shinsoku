#pragma once

#include "platform/clipboard_service.hpp"

class QClipboard;

namespace ohmytypeless {

class WindowsClipboardService final : public ClipboardService {
public:
    explicit WindowsClipboardService(QClipboard* clipboard);

    void begin_paste_session() override;
    void clear_paste_session() override;
    void copy_text(const QString& text) override;
    bool paste_text_to_last_target(const QString& text, const QString& paste_keys) override;
    QString last_debug_info() const override;

private:
    void set_debug_info(const QString& text);

    QClipboard* clipboard_ = nullptr;
    quintptr target_window_ = 0;
    quintptr target_focus_ = 0;
    unsigned long target_thread_id_ = 0;
    QString last_debug_info_;
};

}  // namespace ohmytypeless
