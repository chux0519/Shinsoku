#pragma once

#include "platform/clipboard_service.hpp"

class QClipboard;

namespace ohmytypeless {

class MacOSClipboardService final : public ClipboardService {
public:
    explicit MacOSClipboardService(QClipboard* clipboard);

    bool supports_auto_paste() const override;
    void begin_paste_session() override;
    void clear_paste_session() override;
    void copy_text(const QString& text) override;
    bool paste_text_to_last_target(const QString& text, const QString& paste_keys) override;
    QString last_debug_info() const override;
    InputTargetContext input_target_context() const override;

private:
    void set_debug_info(const QString& text);

    QClipboard* clipboard_ = nullptr;
    pid_t target_pid_ = 0;
    InputTargetContext target_context_;
    QString last_debug_info_;
};

}  // namespace ohmytypeless
