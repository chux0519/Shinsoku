#include "platform/qt/qt_clipboard_service.hpp"

#include <QClipboard>

namespace ohmytypeless {

QtClipboardService::QtClipboardService(QClipboard* clipboard) : clipboard_(clipboard) {}

void QtClipboardService::begin_paste_session() {}

void QtClipboardService::clear_paste_session() {}

void QtClipboardService::copy_text(const QString& text) {
    if (clipboard_ == nullptr) {
        return;
    }
    clipboard_->setText(text, QClipboard::Clipboard);
}

bool QtClipboardService::paste_text_to_last_target(const QString& text, const QString& paste_keys) {
    Q_UNUSED(paste_keys);
    copy_text(text);
    return false;
}

QString QtClipboardService::last_debug_info() const {
    return "auto paste is not implemented for the Qt generic clipboard backend";
}

}  // namespace ohmytypeless
