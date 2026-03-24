#include "platform/qt/qt_selection_service.hpp"

#include <QClipboard>

namespace ohmytypeless {

QtSelectionService::QtSelectionService(QClipboard* clipboard) : clipboard_(clipboard) {}

QString QtSelectionService::backend_name() const {
    return "qt_stub";
}

bool QtSelectionService::supports_automatic_detection() const {
    return false;
}

SelectionCaptureResult QtSelectionService::capture_selection(bool allow_clipboard_fallback) {
    Q_UNUSED(clipboard_);
    Q_UNUSED(allow_clipboard_fallback);
    return SelectionCaptureResult{
        .success = false,
        .selected_text = {},
        .debug_info = "selection capture is not implemented for the Qt generic backend",
    };
}

bool QtSelectionService::replace_selection(const QString& text) {
    Q_UNUSED(text);
    return false;
}

QString QtSelectionService::last_debug_info() const {
    return "selection replace is not implemented for the Qt generic backend";
}

}  // namespace ohmytypeless
