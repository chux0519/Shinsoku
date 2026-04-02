#include "platform/macos/macos_selection_service.hpp"

#include "platform/macos/macos_input_utils.hpp"

#include <QClipboard>
#include <QCoreApplication>
#include <QStringList>
#include <QThread>

#import <ApplicationServices/ApplicationServices.h>

namespace ohmytypeless {

namespace {

QString qstring_from_cf_string(CFStringRef value) {
    if (value == nullptr) {
        return {};
    }

    const char* c_string = CFStringGetCStringPtr(value, kCFStringEncodingUTF8);
    if (c_string != nullptr) {
        return QString::fromUtf8(c_string);
    }

    const CFIndex length = CFStringGetLength(value);
    const CFIndex max_size =
        CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
    QByteArray buffer(static_cast<int>(max_size), Qt::Uninitialized);
    if (!CFStringGetCString(value, buffer.data(), max_size, kCFStringEncodingUTF8)) {
        return {};
    }
    return QString::fromUtf8(buffer.constData());
}

void append_debug(QStringList* lines, const QString& line) {
    if (lines != nullptr) {
        lines->append(line);
    }
}

QString selected_text_from_element(AXUIElementRef element, QStringList* debug_lines) {
    if (element == nullptr) {
        append_debug(debug_lines, "focused element is null");
        return {};
    }

    CFTypeRef selected_text = nullptr;
    const AXError selected_text_error = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute, &selected_text);
    append_debug(debug_lines, QString("AX selected_text error=%1").arg(static_cast<int>(selected_text_error)));
    if (selected_text_error == kAXErrorSuccess && selected_text != nullptr && CFGetTypeID(selected_text) == CFStringGetTypeID()) {
        const QString text = qstring_from_cf_string(static_cast<CFStringRef>(selected_text));
        CFRelease(selected_text);
        if (!text.isEmpty()) {
            append_debug(debug_lines, QString("AX selected_text length=%1").arg(text.size()));
            return text;
        }
    } else if (selected_text != nullptr) {
        CFRelease(selected_text);
    }

    CFTypeRef selected_range = nullptr;
    const AXError selected_range_error =
        AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute, &selected_range);
    append_debug(debug_lines, QString("AX selected_range error=%1").arg(static_cast<int>(selected_range_error)));
    if (selected_range_error != kAXErrorSuccess || selected_range == nullptr) {
        if (selected_range != nullptr) {
            CFRelease(selected_range);
        }
        return {};
    }

    CFTypeRef range_text = nullptr;
    const AXError string_for_range_error =
        AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute, selected_range, &range_text);
    append_debug(debug_lines, QString("AX string_for_range error=%1").arg(static_cast<int>(string_for_range_error)));
    CFRelease(selected_range);
    if (string_for_range_error == kAXErrorSuccess && range_text != nullptr && CFGetTypeID(range_text) == CFStringGetTypeID()) {
        const QString text = qstring_from_cf_string(static_cast<CFStringRef>(range_text));
        CFRelease(range_text);
        if (!text.isEmpty()) {
            append_debug(debug_lines, QString("AX range_text length=%1").arg(text.size()));
            return text;
        }
    } else if (range_text != nullptr) {
        CFRelease(range_text);
    }

    return {};
}

SelectionCaptureResult capture_via_accessibility(pid_t* pid_out) {
    QStringList debug_lines;
    if (!macos_preflight_accessibility_access() && !macos_request_accessibility_access()) {
        debug_lines << macos_accessibility_permission_reason();
        return SelectionCaptureResult{.success = false, .selected_text = {}, .debug_info = debug_lines.join('\n')};
    }

    AXUIElementRef system = AXUIElementCreateSystemWide();
    if (system == nullptr) {
        return SelectionCaptureResult{.success = false, .selected_text = {}, .debug_info = "AX system element creation failed"};
    }

    CFTypeRef focused = nullptr;
    const AXError focused_error = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute, &focused);
    debug_lines << QString("AX focused element error=%1").arg(static_cast<int>(focused_error));
    if (focused_error != kAXErrorSuccess || focused == nullptr || CFGetTypeID(focused) != AXUIElementGetTypeID()) {
        if (focused != nullptr) {
            CFRelease(focused);
        }
        CFRelease(system);
        return SelectionCaptureResult{.success = false, .selected_text = {}, .debug_info = debug_lines.join('\n')};
    }

    auto* focused_element = static_cast<AXUIElementRef>(focused);
    pid_t pid = 0;
    AXUIElementGetPid(focused_element, &pid);
    if (pid_out != nullptr) {
        *pid_out = pid;
    }
    debug_lines << QString("AX focused pid=%1").arg(pid);

    const QString text = selected_text_from_element(focused_element, &debug_lines);
    CFRelease(focused_element);
    CFRelease(system);

    return SelectionCaptureResult{
        .success = !text.trimmed().isEmpty(),
        .selected_text = text,
        .debug_info = debug_lines.join('\n'),
    };
}

SelectionCaptureResult capture_via_copy_shortcut(QClipboard* clipboard, pid_t pid) {
    QStringList debug_lines;
    if (clipboard == nullptr) {
        debug_lines << "clipboard backend is null";
        return SelectionCaptureResult{.success = false, .selected_text = {}, .debug_info = debug_lines.join('\n')};
    }

    const QString snapshot = clipboard->text(QClipboard::Clipboard);
    if (!macos_preflight_post_event_access() && !macos_request_post_event_access()) {
        debug_lines << macos_auto_paste_permission_reason();
        return SelectionCaptureResult{.success = false, .selected_text = {}, .debug_info = debug_lines.join('\n')};
    }

    macos_activate_process(pid, nullptr);

    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (source == nullptr) {
        debug_lines << "copy fallback failed: could not create CGEventSource";
        return SelectionCaptureResult{.success = false, .selected_text = {}, .debug_info = debug_lines.join('\n')};
    }

    CGEventRef down = CGEventCreateKeyboardEvent(source, static_cast<CGKeyCode>(8), true);
    CGEventRef up = CGEventCreateKeyboardEvent(source, static_cast<CGKeyCode>(8), false);
    if (down != nullptr) {
        CGEventSetFlags(down, kCGEventFlagMaskCommand);
        CGEventPost(kCGAnnotatedSessionEventTap, down);
        CFRelease(down);
    }
    if (up != nullptr) {
        CGEventSetFlags(up, kCGEventFlagMaskCommand);
        CGEventPost(kCGAnnotatedSessionEventTap, up);
        CFRelease(up);
    }
    CFRelease(source);

    QThread::msleep(120);
    QCoreApplication::processEvents();
    const QString copied = clipboard->text(QClipboard::Clipboard);
    clipboard->setText(snapshot, QClipboard::Clipboard);
    QCoreApplication::processEvents();

    debug_lines << QString("copy fallback length=%1").arg(copied.size());
    return SelectionCaptureResult{
        .success = !copied.trimmed().isEmpty(),
        .selected_text = copied,
        .debug_info = debug_lines.join('\n'),
    };
}

}  // namespace

MacOSSelectionService::MacOSSelectionService(QClipboard* clipboard) : clipboard_(clipboard) {}

QString MacOSSelectionService::backend_name() const {
    return "macos/accessibility";
}

bool MacOSSelectionService::supports_automatic_detection() const {
    return macos_preflight_accessibility_access();
}

bool MacOSSelectionService::supports_replacement() const {
    return macos_preflight_post_event_access();
}

SelectionCaptureResult MacOSSelectionService::capture_selection(bool allow_clipboard_fallback) {
    pid_t pid = 0;
    SelectionCaptureResult result = capture_via_accessibility(&pid);
    if (result.success) {
        last_target_pid_ = pid;
        set_debug_info(result.debug_info);
        return result;
    }

    if (allow_clipboard_fallback && pid != 0) {
        SelectionCaptureResult fallback = capture_via_copy_shortcut(clipboard_, pid);
        fallback.debug_info = result.debug_info.isEmpty() ? fallback.debug_info : QString("%1\n%2").arg(result.debug_info, fallback.debug_info);
        if (fallback.success) {
            last_target_pid_ = pid;
        }
        set_debug_info(fallback.debug_info);
        return fallback;
    }

    set_debug_info(result.debug_info);
    return result;
}

bool MacOSSelectionService::replace_selection(const QString& text, const QString& paste_keys) {
    if (clipboard_ == nullptr) {
        set_debug_info("replace failed: clipboard backend is null");
        return false;
    }

    clipboard_->setText(text, QClipboard::Clipboard);
    QCoreApplication::processEvents();

    QString debug_info;
    pid_t pid = last_target_pid_;
    if (pid == 0) {
        macos_capture_frontmost_external_process(&pid, &debug_info);
    }
    if (pid == 0) {
        set_debug_info(debug_info.isEmpty() ? "replace failed: no target app captured" : debug_info);
        return false;
    }

    const bool ok = macos_send_paste_shortcut(pid, paste_keys, &debug_info);
    set_debug_info(debug_info);
    return ok;
}

QString MacOSSelectionService::last_debug_info() const {
    return last_debug_info_;
}

void MacOSSelectionService::set_debug_info(const QString& text) const {
    last_debug_info_ = text;
}

}  // namespace ohmytypeless
