#pragma once

#include "platform/selection_service.hpp"

class QClipboard;

namespace ohmytypeless {

class WindowsSelectionService final : public SelectionService {
public:
    explicit WindowsSelectionService(QClipboard* clipboard);

    QString backend_name() const override;
    bool supports_automatic_detection() const override;
    SelectionCaptureResult capture_selection(bool allow_clipboard_fallback = true) override;
    bool replace_selection(const QString& text) override;
    QString last_debug_info() const override;

private:
    void set_debug_info(const QString& text);

    QClipboard* clipboard_ = nullptr;
    QString last_debug_info_;
};

}  // namespace ohmytypeless
