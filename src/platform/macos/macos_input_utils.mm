#include "platform/macos/macos_input_utils.hpp"

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

#include <QStringList>

namespace ohmytypeless {

namespace {

QString qstring_from_nsstring(NSString* value) {
    if (value == nil) {
        return {};
    }
    return QString::fromUtf8(value.UTF8String);
}

bool request_accessibility_access(bool prompt) {
    NSDictionary* options = @{(__bridge NSString*)kAXTrustedCheckOptionPrompt : @(prompt)};
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

CGKeyCode paste_keycode_for_string(const QString& paste_keys, CGEventFlags* flags, QString* translated) {
    CGEventFlags event_flags = kCGEventFlagMaskCommand;
    QString applied = paste_keys.trimmed().toLower();
    CGKeyCode keycode = static_cast<CGKeyCode>(9);  // v

    if (applied == "ctrl+shift+v" || applied == "cmd+shift+v") {
        event_flags |= kCGEventFlagMaskShift;
        applied = "cmd+shift+v";
    } else if (applied == "ctrl+v" || applied == "cmd+v") {
        applied = "cmd+v";
    } else if (applied == "shift+insert") {
        applied = "cmd+v";
    } else {
        return static_cast<CGKeyCode>(UINT16_MAX);
    }

    if (flags != nullptr) {
        *flags = event_flags;
    }
    if (translated != nullptr) {
        *translated = applied;
    }
    return keycode;
}

void append_debug(QString* debug_info, const QString& line) {
    if (debug_info == nullptr) {
        return;
    }
    if (!debug_info->isEmpty()) {
        *debug_info += '\n';
    }
    *debug_info += line;
}

bool send_key_event(CGEventSourceRef source, CGEventTapLocation tap, CGKeyCode keycode, CGEventFlags flags, bool key_down) {
    CGEventRef event = CGEventCreateKeyboardEvent(source, keycode, key_down);
    if (event == nullptr) {
        return false;
    }
    CGEventSetFlags(event, flags);
    CGEventPost(tap, event);
    CFRelease(event);
    return true;
}

}  // namespace

bool macos_preflight_listen_event_access() {
    if (@available(macOS 10.15, *)) {
        return CGPreflightListenEventAccess();
    }
    return true;
}

bool macos_request_listen_event_access() {
    if (@available(macOS 10.15, *)) {
        return CGRequestListenEventAccess();
    }
    return true;
}

bool macos_preflight_post_event_access() {
    if (@available(macOS 10.15, *)) {
        return CGPreflightPostEventAccess();
    }
    return true;
}

bool macos_request_post_event_access() {
    if (@available(macOS 10.15, *)) {
        return CGRequestPostEventAccess();
    }
    return true;
}

bool macos_preflight_accessibility_access() {
    return request_accessibility_access(false);
}

bool macos_request_accessibility_access() {
    return request_accessibility_access(true);
}

QString macos_global_hotkey_permission_reason() {
    return "macOS global hotkeys need Input Monitoring permission. Grant it in System Settings > Privacy & Security > Input Monitoring, then restart the app.";
}

QString macos_auto_paste_permission_reason() {
    return "macOS auto paste needs permission to post input events. Grant the app Accessibility permission in System Settings > Privacy & Security, then restart the app.";
}

QString macos_accessibility_permission_reason() {
    return "macOS focused-text workflows need Accessibility permission. Grant it in System Settings > Privacy & Security > Accessibility, then restart the app.";
}

pid_t macos_frontmost_process_id() {
    NSRunningApplication* app = [[NSWorkspace sharedWorkspace] frontmostApplication];
    return app != nil ? static_cast<pid_t>(app.processIdentifier) : 0;
}

bool macos_is_current_process(pid_t pid) {
    return pid != 0 && pid == [[NSRunningApplication currentApplication] processIdentifier];
}

bool macos_capture_frontmost_external_process(pid_t* pid, QString* debug_info) {
    if (pid != nullptr) {
        *pid = 0;
    }

    NSRunningApplication* app = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (app == nil) {
        append_debug(debug_info, "frontmost application unavailable");
        return false;
    }

    const pid_t process_id = static_cast<pid_t>(app.processIdentifier);
    if (macos_is_current_process(process_id)) {
        append_debug(debug_info, "frontmost application is Shinsoku; no external target captured");
        return false;
    }

    if (pid != nullptr) {
        *pid = process_id;
    }
    NSString* bundle_id = app.bundleIdentifier != nil ? app.bundleIdentifier : @"(unknown)";
    append_debug(debug_info,
                 QString("captured frontmost app pid=%1 bundle=%2")
                     .arg(process_id)
                     .arg(qstring_from_nsstring(bundle_id)));
    return true;
}

bool macos_activate_process(pid_t pid, QString* debug_info) {
    if (pid == 0) {
        append_debug(debug_info, "activate failed: target pid is 0");
        return false;
    }

    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    if (app == nil) {
        append_debug(debug_info, QString("activate failed: target pid %1 no longer exists").arg(pid));
        return false;
    }

    const BOOL activated = [app activateWithOptions:0];
    NSString* bundle_id = app.bundleIdentifier != nil ? app.bundleIdentifier : @"(unknown)";
    append_debug(debug_info,
                 QString("activate target pid=%1 result=%2 bundle=%3")
                     .arg(pid)
                     .arg(activated ? "true" : "false")
                     .arg(qstring_from_nsstring(bundle_id)));
    return activated == YES;
}

bool macos_send_paste_shortcut(pid_t pid, const QString& paste_keys, QString* debug_info) {
    QString translated;
    CGEventFlags flags = 0;
    const CGKeyCode keycode = paste_keycode_for_string(paste_keys, &flags, &translated);
    if (keycode == static_cast<CGKeyCode>(UINT16_MAX)) {
        append_debug(debug_info, QString("paste failed: unsupported paste_keys=%1").arg(paste_keys));
        return false;
    }

    if (!macos_preflight_post_event_access() && !macos_request_post_event_access()) {
        append_debug(debug_info, macos_auto_paste_permission_reason());
        return false;
    }

    macos_activate_process(pid, debug_info);
    [NSThread sleepForTimeInterval:0.06];

    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (source == nullptr) {
        append_debug(debug_info, "paste failed: could not create CGEventSource");
        return false;
    }

    const bool down_ok = send_key_event(source, kCGAnnotatedSessionEventTap, keycode, flags, true);
    const bool up_ok = send_key_event(source, kCGAnnotatedSessionEventTap, keycode, flags, false);
    CFRelease(source);

    append_debug(debug_info,
                 QString("posted paste shortcut pid=%1 requested=%2 translated=%3")
                     .arg(pid)
                     .arg(paste_keys, translated));
    return down_ok && up_ok;
}

}  // namespace ohmytypeless
