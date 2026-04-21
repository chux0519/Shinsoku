#include "platform/macos/macos_global_hotkey.hpp"

#include "platform/hotkey_names.hpp"
#include "platform/macos/macos_input_utils.hpp"

#include <QDeadlineTimer>

#include <Carbon/Carbon.h>

#include <array>

namespace ohmytypeless {

namespace {

struct KeyMapping {
    const char* canonical_name;
    CGKeyCode keycode;
    bool is_modifier;
    CGEventFlags modifier_mask;
};

constexpr std::array<KeyMapping, 31> kKeyMappings{{
    {"left_ctrl", static_cast<CGKeyCode>(59), true, kCGEventFlagMaskControl},
    {"right_ctrl", static_cast<CGKeyCode>(62), true, kCGEventFlagMaskControl},
    {"left_shift", static_cast<CGKeyCode>(56), true, kCGEventFlagMaskShift},
    {"right_shift", static_cast<CGKeyCode>(60), true, kCGEventFlagMaskShift},
    {"left_alt", static_cast<CGKeyCode>(58), true, kCGEventFlagMaskAlternate},
    {"right_alt", static_cast<CGKeyCode>(61), true, kCGEventFlagMaskAlternate},
    {"left_meta", static_cast<CGKeyCode>(55), true, kCGEventFlagMaskCommand},
    {"right_meta", static_cast<CGKeyCode>(54), true, kCGEventFlagMaskCommand},
    {"space", static_cast<CGKeyCode>(49), false, 0},
    {"tab", static_cast<CGKeyCode>(48), false, 0},
    {"return", static_cast<CGKeyCode>(36), false, 0},
    {"escape", static_cast<CGKeyCode>(53), false, 0},
    {"delete", static_cast<CGKeyCode>(51), false, 0},
    {"forward_delete", static_cast<CGKeyCode>(117), false, 0},
    {"up", static_cast<CGKeyCode>(126), false, 0},
    {"down", static_cast<CGKeyCode>(125), false, 0},
    {"left", static_cast<CGKeyCode>(123), false, 0},
    {"right", static_cast<CGKeyCode>(124), false, 0},
    {"a", static_cast<CGKeyCode>(0), false, 0},
    {"b", static_cast<CGKeyCode>(11), false, 0},
    {"c", static_cast<CGKeyCode>(8), false, 0},
    {"d", static_cast<CGKeyCode>(2), false, 0},
    {"e", static_cast<CGKeyCode>(14), false, 0},
    {"f", static_cast<CGKeyCode>(3), false, 0},
    {"g", static_cast<CGKeyCode>(5), false, 0},
    {"q", static_cast<CGKeyCode>(12), false, 0},
    {"r", static_cast<CGKeyCode>(15), false, 0},
    {"s", static_cast<CGKeyCode>(1), false, 0},
    {"v", static_cast<CGKeyCode>(9), false, 0},
    {"w", static_cast<CGKeyCode>(13), false, 0},
    {"z", static_cast<CGKeyCode>(6), false, 0},
}};

const KeyMapping* key_mapping_for_name(const QString& key_name) {
    const QString canonical = canonical_hotkey_name(key_name);
    for (const KeyMapping& mapping : kKeyMappings) {
        if (canonical == QLatin1String(mapping.canonical_name)) {
            return &mapping;
        }
    }
    return nullptr;
}

const KeyMapping* key_mapping_for_keycode(CGKeyCode keycode) {
    for (const KeyMapping& mapping : kKeyMappings) {
        if (mapping.keycode == keycode) {
            return &mapping;
        }
    }
    return nullptr;
}

bool modifier_is_pressed(CGKeyCode keycode, CGEventFlags flags) {
    switch (keycode) {
    case 59:
    case 62:
        return (flags & kCGEventFlagMaskControl) != 0;
    case 56:
    case 60:
        return (flags & kCGEventFlagMaskShift) != 0;
    case 58:
    case 61:
        return (flags & kCGEventFlagMaskAlternate) != 0;
    case 55:
    case 54:
        return (flags & kCGEventFlagMaskCommand) != 0;
    default:
        return false;
    }
}

bool event_matches_spec(CGEventType type, CGEventRef event, const MacOSGlobalHotkey::KeySpec& spec, bool* pressed_out) {
    if (pressed_out != nullptr) {
        *pressed_out = false;
    }
    if (event == nullptr) {
        return false;
    }

    const CGKeyCode keycode = static_cast<CGKeyCode>(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode));
    if (keycode != spec.keycode) {
        return false;
    }

    if (spec.is_modifier) {
        if (type != kCGEventFlagsChanged) {
            return false;
        }
        const bool pressed = modifier_is_pressed(keycode, CGEventGetFlags(event));
        if (pressed_out != nullptr) {
            *pressed_out = pressed;
        }
        return true;
    }

    if (type == kCGEventKeyDown || type == kCGEventKeyUp) {
        if (pressed_out != nullptr) {
            *pressed_out = type == kCGEventKeyDown;
        }
        return true;
    }

    return false;
}

struct CaptureContext {
    CFMachPortRef tap = nullptr;
    CFRunLoopSourceRef source = nullptr;
    QString captured_key_name;
};

CGEventRef capture_event_callback(CGEventTapProxy, CGEventType type, CGEventRef event, void* user_info) {
    auto* context = static_cast<CaptureContext*>(user_info);
    if (context == nullptr) {
        return event;
    }

    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (context->tap != nullptr) {
            CGEventTapEnable(context->tap, true);
        }
        return event;
    }

    if (type != kCGEventKeyDown && type != kCGEventFlagsChanged) {
        return event;
    }

    const CGKeyCode keycode = static_cast<CGKeyCode>(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode));
    const KeyMapping* mapping = key_mapping_for_keycode(keycode);
    if (mapping == nullptr) {
        return event;
    }
    if (mapping->is_modifier && !modifier_is_pressed(keycode, CGEventGetFlags(event))) {
        return event;
    }

    context->captured_key_name = QLatin1String(mapping->canonical_name);
    return nullptr;
}

}  // namespace

MacOSGlobalHotkey::MacOSGlobalHotkey(QObject* parent) : GlobalHotkey(parent) {}

MacOSGlobalHotkey::~MacOSGlobalHotkey() {
    unregister_hotkey();
}

bool MacOSGlobalHotkey::supports_global_hotkeys() const {
    return macos_preflight_listen_event_access();
}

bool MacOSGlobalHotkey::supports_key_capture() const {
    return macos_preflight_listen_event_access();
}

QString MacOSGlobalHotkey::capture_next_key(int timeout_ms, QString* error_message) {
    if (!macos_preflight_listen_event_access() && !macos_request_listen_event_access()) {
        if (error_message != nullptr) {
            *error_message = macos_global_hotkey_permission_reason();
        }
        return {};
    }

    CaptureContext context;
    const CGEventMask mask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged);
    context.tap = CGEventTapCreate(kCGSessionEventTap,
                                   kCGHeadInsertEventTap,
                                   kCGEventTapOptionDefault,
                                   mask,
                                   &capture_event_callback,
                                   &context);
    if (context.tap == nullptr) {
        if (error_message != nullptr) {
            *error_message = "Failed to create a macOS event tap for key capture.";
        }
        return {};
    }

    context.source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, context.tap, 0);
    if (context.source == nullptr) {
        CFRelease(context.tap);
        if (error_message != nullptr) {
            *error_message = "Failed to create a macOS run-loop source for key capture.";
        }
        return {};
    }

    CFRunLoopRef run_loop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(run_loop, context.source, kCFRunLoopCommonModes);
    CGEventTapEnable(context.tap, true);

    const QDeadlineTimer deadline(timeout_ms);
    while (!deadline.hasExpired() && context.captured_key_name.isEmpty()) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, true);
    }

    CFRunLoopRemoveSource(run_loop, context.source, kCFRunLoopCommonModes);
    CFRelease(context.source);
    CFRelease(context.tap);

    if (!context.captured_key_name.isEmpty()) {
        return context.captured_key_name;
    }

    if (error_message != nullptr) {
        *error_message = "Timed out waiting for a key press.";
    }
    return {};
}

bool MacOSGlobalHotkey::register_hotkeys(const QString& hold_key_name, const QString& chord_key_name) {
    unregister_hotkey();

    if (!macos_preflight_listen_event_access() && !macos_request_listen_event_access()) {
        emit registration_failed(macos_global_hotkey_permission_reason());
        return false;
    }

    QString error_message;
    if (!parse_key_name(hold_key_name, &hold_spec_, &error_message)) {
        emit registration_failed(error_message);
        return false;
    }
    if (!parse_key_name(chord_key_name, &chord_spec_, &error_message)) {
        emit registration_failed(error_message);
        return false;
    }

    hold_key_name_ = hold_spec_.canonical_name;
    chord_key_name_ = chord_spec_.canonical_name;

    if (!ensure_event_tap()) {
        emit registration_failed("Failed to install the macOS global hotkey event tap.");
        reset_runtime_state();
        return false;
    }

    reset_runtime_state();
    return true;
}

void MacOSGlobalHotkey::unregister_hotkey() {
    release_event_tap();
    hold_key_name_.clear();
    chord_key_name_.clear();
    reset_runtime_state();
}

QString MacOSGlobalHotkey::backend_name() const {
    return "macos/EventTap";
}

QString MacOSGlobalHotkey::hold_key_name() const {
    return hold_key_name_;
}

QString MacOSGlobalHotkey::chord_key_name() const {
    return chord_key_name_;
}

CGEventRef MacOSGlobalHotkey::event_tap_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* user_info) {
    Q_UNUSED(proxy);
    auto* self = static_cast<MacOSGlobalHotkey*>(user_info);
    if (self == nullptr) {
        return event;
    }
    return self->handle_event(type, event);
}

CGEventRef MacOSGlobalHotkey::handle_event(CGEventType type, CGEventRef event) {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (event_tap_ != nullptr) {
            CGEventTapEnable(event_tap_, true);
        }
        return event;
    }

    bool consume = false;
    bool pressed = false;
    if (event_matches_spec(type, event, hold_spec_, &pressed)) {
        consume = true;
        if (pressed) {
            if (hands_free_mode_) {
                hands_free_mode_ = false;
                ignore_next_hold_release_ = true;
                emit hands_free_disabled();
            } else if (!hold_down_) {
                emit hold_started();
            }
            hold_down_ = true;
        } else {
            hold_down_ = false;
            if (ignore_next_hold_release_) {
                ignore_next_hold_release_ = false;
                return nullptr;
            }
            if (hands_free_mode_) {
                return nullptr;
            }
            emit hold_stopped();
        }
    } else if (event_matches_spec(type, event, chord_spec_, &pressed)) {
        if (hold_down_ || hands_free_mode_) {
            consume = true;
        }
        chord_down_ = pressed;
    }

    if (hold_down_ && chord_down_ && !hands_free_mode_) {
        hands_free_mode_ = true;
        ignore_next_hold_release_ = true;
        emit hands_free_enabled();
        consume = true;
    }

    return consume ? nullptr : event;
}

bool MacOSGlobalHotkey::ensure_event_tap() {
    const CGEventMask mask =
        CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventFlagsChanged);
    event_tap_ = CGEventTapCreate(kCGSessionEventTap,
                                  kCGHeadInsertEventTap,
                                  kCGEventTapOptionDefault,
                                  mask,
                                  &MacOSGlobalHotkey::event_tap_callback,
                                  this);
    if (event_tap_ == nullptr) {
        return false;
    }

    run_loop_source_ = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, event_tap_, 0);
    if (run_loop_source_ == nullptr) {
        CFRelease(event_tap_);
        event_tap_ = nullptr;
        return false;
    }

    CFRunLoopAddSource(CFRunLoopGetMain(), run_loop_source_, kCFRunLoopCommonModes);
    CGEventTapEnable(event_tap_, true);
    return true;
}

void MacOSGlobalHotkey::release_event_tap() {
    if (run_loop_source_ != nullptr) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), run_loop_source_, kCFRunLoopCommonModes);
        CFRelease(run_loop_source_);
        run_loop_source_ = nullptr;
    }
    if (event_tap_ != nullptr) {
        CFRelease(event_tap_);
        event_tap_ = nullptr;
    }
}

void MacOSGlobalHotkey::reset_runtime_state() {
    hold_down_ = false;
    chord_down_ = false;
    hands_free_mode_ = false;
    ignore_next_hold_release_ = false;
}

bool MacOSGlobalHotkey::parse_key_name(const QString& key_name, KeySpec* out_spec, QString* error_message) const {
    const KeyMapping* mapping = key_mapping_for_name(key_name);
    if (mapping == nullptr) {
        if (error_message != nullptr) {
            *error_message = QString("Unsupported macOS hotkey: %1").arg(key_name);
        }
        return false;
    }

    if (out_spec != nullptr) {
        out_spec->canonical_name = QLatin1String(mapping->canonical_name);
        out_spec->keycode = mapping->keycode;
        out_spec->is_modifier = mapping->is_modifier;
        out_spec->modifier_mask = mapping->modifier_mask;
    }
    return true;
}

}  // namespace ohmytypeless
