#pragma once

#include "platform/global_hotkey.hpp"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace ohmytypeless {

class WindowsGlobalHotkey final : public GlobalHotkey {
    Q_OBJECT
public:
    explicit WindowsGlobalHotkey(QObject* parent = nullptr);
    ~WindowsGlobalHotkey() override;

    bool register_hotkeys(const QString& hold_key_name, const QString& chord_key_name) override;
    void unregister_hotkey() override;
    QString backend_name() const override;

private:
    static LRESULT CALLBACK keyboard_proc(int code, WPARAM w_param, LPARAM l_param);
    bool handle_keyboard_event(WPARAM w_param, const KBDLLHOOKSTRUCT& key_info);
    bool parse_key_name(const QString& key_name, DWORD& vk, QString& error) const;
    void reset_runtime_state();

    static WindowsGlobalHotkey* active_instance_;

    HHOOK hook_ = nullptr;
    DWORD hold_vk_ = 0;
    DWORD chord_vk_ = 0;
    bool hold_down_ = false;
    bool chord_down_ = false;
    bool hands_free_mode_ = false;
    bool ignore_next_hold_release_ = false;
};

}  // namespace ohmytypeless
