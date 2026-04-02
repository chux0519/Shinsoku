#include "platform/macos/macos_clipboard_service.hpp"

#include "platform/macos/macos_input_utils.hpp"

#include <QClipboard>
#include <QCoreApplication>

namespace ohmytypeless {

MacOSClipboardService::MacOSClipboardService(QClipboard* clipboard) : clipboard_(clipboard) {}

bool MacOSClipboardService::supports_auto_paste() const {
    return macos_preflight_post_event_access();
}

void MacOSClipboardService::begin_paste_session() {
    QString debug_info;
    pid_t pid = 0;
    if (macos_capture_frontmost_external_process(&pid, &debug_info)) {
        target_pid_ = pid;
    } else {
        target_pid_ = 0;
    }
    set_debug_info(debug_info);
}

void MacOSClipboardService::clear_paste_session() {
    target_pid_ = 0;
    last_debug_info_.clear();
}

void MacOSClipboardService::copy_text(const QString& text) {
    if (clipboard_ == nullptr) {
        return;
    }
    clipboard_->setText(text, QClipboard::Clipboard);
}

bool MacOSClipboardService::paste_text_to_last_target(const QString& text, const QString& paste_keys) {
    if (clipboard_ == nullptr) {
        set_debug_info("paste failed: clipboard backend is null");
        return false;
    }

    copy_text(text);
    QCoreApplication::processEvents();

    QString debug_info;
    pid_t pid = target_pid_;
    if (pid == 0) {
        macos_capture_frontmost_external_process(&pid, &debug_info);
    }
    if (pid == 0) {
        set_debug_info(debug_info.isEmpty() ? "paste failed: no external target application captured" : debug_info);
        return false;
    }

    const bool ok = macos_send_paste_shortcut(pid, paste_keys, &debug_info);
    set_debug_info(debug_info);
    return ok;
}

QString MacOSClipboardService::last_debug_info() const {
    return last_debug_info_;
}

void MacOSClipboardService::set_debug_info(const QString& text) {
    last_debug_info_ = text;
}

}  // namespace ohmytypeless
