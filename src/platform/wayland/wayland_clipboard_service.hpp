#pragma once

#include "platform/clipboard_service.hpp"

class QClipboard;

namespace ohmytypeless {

class WaylandClipboardService final : public ClipboardService {
public:
    explicit WaylandClipboardService(QClipboard* clipboard);

    bool supports_auto_paste() const override;
    void begin_paste_session() override;
    void clear_paste_session() override;
    void copy_text(const QString& text) override;
    bool paste_text_to_last_target(const QString& text, const QString& paste_keys) override;
    QString last_debug_info() const override;

private:
    bool has_required_tools() const;
    bool run_wtype_key_combo(const QString& key_combo) const;
    void set_debug_info(const QString& text) const;

    QClipboard* clipboard_ = nullptr;
    mutable QString last_debug_info_;
};

}  // namespace ohmytypeless
