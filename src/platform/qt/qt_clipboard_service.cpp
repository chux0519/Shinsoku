#include "platform/qt/qt_clipboard_service.hpp"

#include <QClipboard>

namespace ohmytypeless {

QtClipboardService::QtClipboardService(QClipboard* clipboard) : clipboard_(clipboard) {}

void QtClipboardService::copy_text(const QString& text) {
    if (clipboard_ == nullptr) {
        return;
    }
    clipboard_->setText(text, QClipboard::Clipboard);
}

}  // namespace ohmytypeless
