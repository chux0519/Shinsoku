#include "platform/macos/macos_selection_service.hpp"

#include "platform/macos/macos_input_utils.hpp"

#include <QClipboard>
#include <QCoreApplication>
#include <QSet>
#include <QStringList>
#include <QThread>

#import <ApplicationServices/ApplicationServices.h>

#include <QUuid>

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

QString describe_attribute_string(AXUIElementRef element, CFStringRef attribute) {
    if (element == nullptr || attribute == nullptr) {
        return {};
    }

    CFTypeRef value = nullptr;
    const AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
    if (error != kAXErrorSuccess || value == nullptr) {
        if (value != nullptr) {
            CFRelease(value);
        }
        return {};
    }
    QString result;
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        result = qstring_from_cf_string(static_cast<CFStringRef>(value));
    }
    CFRelease(value);
    return result;
}

QString describe_element(AXUIElementRef element) {
    const QString role = describe_attribute_string(element, kAXRoleAttribute);
    const QString subrole = describe_attribute_string(element, kAXSubroleAttribute);
    if (!role.isEmpty() && !subrole.isEmpty()) {
        return QString("%1/%2").arg(role, subrole);
    }
    if (!role.isEmpty()) {
        return role;
    }
    if (!subrole.isEmpty()) {
        return subrole;
    }
    return "unknown";
}

QString selected_text_from_element(AXUIElementRef element, QStringList* debug_lines, const QString& label) {
    if (element == nullptr) {
        append_debug(debug_lines, QString("%1 element is null").arg(label));
        return {};
    }

    append_debug(debug_lines, QString("AX inspect %1 role=%2").arg(label, describe_element(element)));

    CFTypeRef selected_text = nullptr;
    const AXError selected_text_error = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute, &selected_text);
    append_debug(debug_lines, QString("AX %1 selected_text error=%2").arg(label).arg(static_cast<int>(selected_text_error)));
    if (selected_text_error == kAXErrorSuccess && selected_text != nullptr && CFGetTypeID(selected_text) == CFStringGetTypeID()) {
        const QString text = qstring_from_cf_string(static_cast<CFStringRef>(selected_text));
        CFRelease(selected_text);
        if (!text.isEmpty()) {
            append_debug(debug_lines, QString("AX %1 selected_text length=%2").arg(label).arg(text.size()));
            return text;
        }
    } else if (selected_text != nullptr) {
        CFRelease(selected_text);
    }

    CFTypeRef selected_range = nullptr;
    const AXError selected_range_error =
        AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute, &selected_range);
    append_debug(debug_lines, QString("AX %1 selected_range error=%2").arg(label).arg(static_cast<int>(selected_range_error)));
    if (selected_range_error != kAXErrorSuccess || selected_range == nullptr) {
        if (selected_range != nullptr) {
            CFRelease(selected_range);
        }
        return {};
    }

    CFTypeRef range_text = nullptr;
    const AXError string_for_range_error =
        AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute, selected_range, &range_text);
    append_debug(debug_lines, QString("AX %1 string_for_range error=%2").arg(label).arg(static_cast<int>(string_for_range_error)));
    CFRelease(selected_range);
    if (string_for_range_error == kAXErrorSuccess && range_text != nullptr && CFGetTypeID(range_text) == CFStringGetTypeID()) {
        const QString text = qstring_from_cf_string(static_cast<CFStringRef>(range_text));
        CFRelease(range_text);
        if (!text.isEmpty()) {
            append_debug(debug_lines, QString("AX %1 range_text length=%2").arg(label).arg(text.size()));
            return text;
        }
    } else if (range_text != nullptr) {
        CFRelease(range_text);
    }

    CFTypeRef marker_range = nullptr;
    const AXError marker_range_error =
        AXUIElementCopyAttributeValue(element, CFSTR("AXSelectedTextMarkerRange"), &marker_range);
    append_debug(debug_lines, QString("AX %1 selected_text_marker_range error=%2").arg(label).arg(static_cast<int>(marker_range_error)));
    if (marker_range_error != kAXErrorSuccess || marker_range == nullptr) {
        if (marker_range != nullptr) {
            CFRelease(marker_range);
        }
        return {};
    }

    CFTypeRef marker_range_text = nullptr;
    const AXError string_for_marker_range_error =
        AXUIElementCopyParameterizedAttributeValue(element, CFSTR("AXStringForTextMarkerRange"), marker_range, &marker_range_text);
    append_debug(debug_lines,
                 QString("AX %1 string_for_text_marker_range error=%2")
                     .arg(label)
                     .arg(static_cast<int>(string_for_marker_range_error)));
    CFRelease(marker_range);
    if (string_for_marker_range_error == kAXErrorSuccess && marker_range_text != nullptr &&
        CFGetTypeID(marker_range_text) == CFStringGetTypeID()) {
        const QString text = qstring_from_cf_string(static_cast<CFStringRef>(marker_range_text));
        CFRelease(marker_range_text);
        if (!text.isEmpty()) {
            append_debug(debug_lines, QString("AX %1 marker_range_text length=%2").arg(label).arg(text.size()));
            return text;
        }
    } else if (marker_range_text != nullptr) {
        CFRelease(marker_range_text);
    }

    return {};
}

QString selected_text_from_tree(AXUIElementRef element,
                                QStringList* debug_lines,
                                const QString& label,
                                int depth,
                                int* visited_count,
                                QSet<quintptr>* visited);

QString selected_text_from_attribute_element(AXUIElementRef element,
                                            CFStringRef attribute,
                                            QStringList* debug_lines,
                                            const QString& label) {
    if (element == nullptr || attribute == nullptr) {
        return {};
    }

    CFTypeRef value = nullptr;
    const AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
    append_debug(debug_lines, QString("AX %1 copy error=%2").arg(label).arg(static_cast<int>(error)));
    if (error != kAXErrorSuccess || value == nullptr || CFGetTypeID(value) != AXUIElementGetTypeID()) {
        if (value != nullptr) {
            CFRelease(value);
        }
        return {};
    }

    auto* child = static_cast<AXUIElementRef>(value);
    int visited_count = 0;
    QSet<quintptr> visited;
    const QString text = selected_text_from_tree(child, debug_lines, label, 5, &visited_count, &visited);
    CFRelease(child);
    return text;
}

QString selected_text_from_tree(AXUIElementRef element,
                                QStringList* debug_lines,
                                const QString& label,
                                int depth,
                                int* visited_count,
                                QSet<quintptr>* visited) {
    if (element == nullptr || visited_count == nullptr || visited == nullptr || depth < 0 || *visited_count > 80) {
        return {};
    }

    const quintptr key = reinterpret_cast<quintptr>(element);
    if (visited->contains(key)) {
        return {};
    }
    visited->insert(key);
    ++(*visited_count);

    const QString self_text = selected_text_from_element(element, debug_lines, label);
    if (!self_text.trimmed().isEmpty()) {
        return self_text;
    }

    CFTypeRef children_value = nullptr;
    AXError children_error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute, &children_value);
    append_debug(debug_lines,
                 QString("AX %1 children error=%2 depth=%3").arg(label).arg(static_cast<int>(children_error)).arg(depth));
    if ((children_error != kAXErrorSuccess || children_value == nullptr) && children_value != nullptr) {
        CFRelease(children_value);
        children_value = nullptr;
    }
    if ((children_error != kAXErrorSuccess || children_value == nullptr) && depth > 0) {
        children_error = AXUIElementCopyAttributeValue(element, kAXVisibleChildrenAttribute, &children_value);
        append_debug(debug_lines,
                     QString("AX %1 visible_children error=%2 depth=%3").arg(label).arg(static_cast<int>(children_error)).arg(depth));
    }

    if (children_error != kAXErrorSuccess || children_value == nullptr || CFGetTypeID(children_value) != CFArrayGetTypeID()) {
        if (children_value != nullptr) {
            CFRelease(children_value);
        }
        return {};
    }

    CFArrayRef children = static_cast<CFArrayRef>(children_value);
    const CFIndex count = CFArrayGetCount(children);
    append_debug(debug_lines, QString("AX %1 child_count=%2 depth=%3").arg(label).arg(count).arg(depth));
    for (CFIndex index = 0; index < count && *visited_count <= 80; ++index) {
        const void* value = CFArrayGetValueAtIndex(children, index);
        if (value == nullptr || CFGetTypeID(value) != AXUIElementGetTypeID()) {
            continue;
        }
        AXUIElementRef child = static_cast<AXUIElementRef>(const_cast<void*>(value));
        const QString text = selected_text_from_tree(child,
                                                     debug_lines,
                                                     QString("%1.child%2").arg(label).arg(index),
                                                     depth - 1,
                                                     visited_count,
                                                     visited);
        if (!text.trimmed().isEmpty()) {
            CFRelease(children_value);
            return text;
        }
    }

    CFRelease(children_value);
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

    int visited_count = 0;
    QSet<quintptr> visited;
    QString text = selected_text_from_tree(focused_element, &debug_lines, "system.focused", 5, &visited_count, &visited);

    if (text.trimmed().isEmpty() && pid != 0) {
        AXUIElementRef app = AXUIElementCreateApplication(pid);
        if (app != nullptr) {
            text = selected_text_from_attribute_element(app, kAXFocusedUIElementAttribute, &debug_lines, "app.focused");
            if (text.trimmed().isEmpty()) {
                CFTypeRef focused_window = nullptr;
                const AXError window_error = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute, &focused_window);
                debug_lines << QString("AX app focused_window error=%1").arg(static_cast<int>(window_error));
                if (window_error == kAXErrorSuccess && focused_window != nullptr &&
                    CFGetTypeID(focused_window) == AXUIElementGetTypeID()) {
                    int window_visited_count = 0;
                    QSet<quintptr> window_visited;
                    text = selected_text_from_tree(static_cast<AXUIElementRef>(focused_window),
                                                   &debug_lines,
                                                   "app.focused_window",
                                                   6,
                                                   &window_visited_count,
                                                   &window_visited);
                }
                if (focused_window != nullptr) {
                    CFRelease(focused_window);
                }
            }
            CFRelease(app);
        }
    }

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
    const QString sentinel = QString("__shinsoku_selection_probe_%1__").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    if (!macos_preflight_post_event_access() && !macos_request_post_event_access()) {
        debug_lines << macos_auto_paste_permission_reason();
        return SelectionCaptureResult{.success = false, .selected_text = {}, .debug_info = debug_lines.join('\n')};
    }

    clipboard->setText(sentinel, QClipboard::Clipboard);
    QCoreApplication::processEvents();
    macos_activate_process(pid, nullptr);
    QThread::msleep(80);
    QCoreApplication::processEvents();

    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (source == nullptr) {
        clipboard->setText(snapshot, QClipboard::Clipboard);
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

    QString copied;
    int waited_ms = 0;
    for (int attempt = 0; attempt < 20; ++attempt) {
        QThread::msleep(50);
        waited_ms += 50;
        QCoreApplication::processEvents();
        const QString current = clipboard->text(QClipboard::Clipboard);
        if (current != sentinel && !current.trimmed().isEmpty()) {
            copied = current;
            break;
        }
    }
    clipboard->setText(snapshot, QClipboard::Clipboard);
    QCoreApplication::processEvents();

    debug_lines << QString("copy fallback waited_ms=%1").arg(waited_ms);
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
