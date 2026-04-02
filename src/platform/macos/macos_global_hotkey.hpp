#pragma once

#include "platform/global_hotkey.hpp"

#include <ApplicationServices/ApplicationServices.h>

namespace ohmytypeless {

class MacOSGlobalHotkey final : public GlobalHotkey {
    Q_OBJECT
public:
    struct KeySpec {
        QString canonical_name;
        CGKeyCode keycode = 0;
        bool is_modifier = false;
        CGEventFlags modifier_mask = 0;
    };

    explicit MacOSGlobalHotkey(QObject* parent = nullptr);
    ~MacOSGlobalHotkey() override;

    bool supports_global_hotkeys() const override;
    bool supports_key_capture() const override;
    QString capture_next_key(int timeout_ms, QString* error_message) override;
    bool register_hotkeys(const QString& hold_key_name, const QString& chord_key_name) override;
    void unregister_hotkey() override;
    QString backend_name() const override;
    QString hold_key_name() const override;
    QString chord_key_name() const override;

private:
    static CGEventRef event_tap_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* user_info);
    CGEventRef handle_event(CGEventType type, CGEventRef event);
    bool ensure_event_tap();
    void release_event_tap();
    void reset_runtime_state();
    bool parse_key_name(const QString& key_name, KeySpec* out_spec, QString* error_message) const;

    CFMachPortRef event_tap_ = nullptr;
    CFRunLoopSourceRef run_loop_source_ = nullptr;
    KeySpec hold_spec_;
    KeySpec chord_spec_;
    QString hold_key_name_;
    QString chord_key_name_;
    bool hold_down_ = false;
    bool chord_down_ = false;
    bool hands_free_mode_ = false;
    bool ignore_next_hold_release_ = false;
};

}  // namespace ohmytypeless
