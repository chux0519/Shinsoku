#pragma once

#include "platform/selection_service.hpp"

class QClipboard;

namespace ohmytypeless {

class MacOSSelectionService final : public SelectionService {
public:
    explicit MacOSSelectionService(QClipboard* clipboard);

    QString backend_name() const override;
    bool supports_automatic_detection() const override;
    bool supports_replacement() const override;
    SelectionCaptureResult capture_selection(bool allow_clipboard_fallback = true) override;
    bool replace_selection(const QString& text, const QString& paste_keys) override;
    QString last_debug_info() const override;

private:
    void set_debug_info(const QString& text) const;

    QClipboard* clipboard_ = nullptr;
    mutable QString last_debug_info_;
    pid_t last_target_pid_ = 0;
};

}  // namespace ohmytypeless
