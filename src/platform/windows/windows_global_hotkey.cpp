#include "platform/windows/windows_global_hotkey.hpp"
#include "platform/hotkey_names.hpp"

#include <QDeadlineTimer>
#include <QString>

namespace ohmytypeless {

namespace {

struct CaptureState {
    HHOOK hook = nullptr;
    DWORD thread_id = 0;
    QString captured_key_name;
};

CaptureState* active_capture_state = nullptr;

QString canonical_key_name_from_event(const KBDLLHOOKSTRUCT& key_info) {
    switch (key_info.vkCode) {
    case VK_SPACE:
        return "space";
    case VK_LMENU:
        return "left_alt";
    case VK_RMENU:
        return "right_alt";
    case VK_LCONTROL:
        return "left_ctrl";
    case VK_RCONTROL:
        return "right_ctrl";
    case VK_LSHIFT:
        return "left_shift";
    case VK_RSHIFT:
        return "right_shift";
    case VK_LWIN:
        return "left_meta";
    case VK_RWIN:
        return "right_meta";
    case VK_APPS:
        return "menu";
    case VK_MENU:
        return (key_info.flags & LLKHF_EXTENDED) != 0 ? "right_alt" : "left_alt";
    case VK_CONTROL:
        return (key_info.flags & LLKHF_EXTENDED) != 0 ? "right_ctrl" : "left_ctrl";
    case VK_SHIFT: {
        const UINT mapped = ::MapVirtualKeyW(key_info.scanCode, MAPVK_VSC_TO_VK_EX);
        if (mapped == VK_RSHIFT) {
            return "right_shift";
        }
        return "left_shift";
    }
    default:
        break;
    }

    return {};
}

LRESULT CALLBACK capture_keyboard_proc(int code, WPARAM w_param, LPARAM l_param) {
    if (code < 0 || l_param == 0) {
        return ::CallNextHookEx(nullptr, code, w_param, l_param);
    }

    if (active_capture_state == nullptr) {
        return ::CallNextHookEx(nullptr, code, w_param, l_param);
    }

    if (w_param != WM_KEYDOWN && w_param != WM_SYSKEYDOWN) {
        return ::CallNextHookEx(nullptr, code, w_param, l_param);
    }

    const auto* key_info = reinterpret_cast<const KBDLLHOOKSTRUCT*>(l_param);
    if ((key_info->flags & LLKHF_INJECTED) != 0) {
        return ::CallNextHookEx(nullptr, code, w_param, l_param);
    }

    const QString key_name = canonical_key_name_from_event(*key_info);
    if (key_name.isEmpty()) {
        return ::CallNextHookEx(nullptr, code, w_param, l_param);
    }

    active_capture_state->captured_key_name = canonical_hotkey_name(key_name);
    if (active_capture_state->thread_id != 0) {
        ::PostThreadMessageW(active_capture_state->thread_id, WM_APP + 1, 0, 0);
    }
    return 1;
}

}  // namespace

WindowsGlobalHotkey* WindowsGlobalHotkey::active_instance_ = nullptr;

WindowsGlobalHotkey::WindowsGlobalHotkey(QObject* parent) : GlobalHotkey(parent) {}

WindowsGlobalHotkey::~WindowsGlobalHotkey() {
    unregister_hotkey();
}

bool WindowsGlobalHotkey::supports_global_hotkeys() const {
    return true;
}

bool WindowsGlobalHotkey::supports_key_capture() const {
    return true;
}

QString WindowsGlobalHotkey::capture_next_key(int timeout_ms, QString* error_message) {
    MSG ignored{};
    ::PeekMessageW(&ignored, nullptr, WM_USER, WM_USER, PM_NOREMOVE);

    CaptureState capture_state;
    capture_state.thread_id = ::GetCurrentThreadId();
    active_capture_state = &capture_state;

    capture_state.hook = ::SetWindowsHookExW(WH_KEYBOARD_LL, &capture_keyboard_proc, ::GetModuleHandleW(nullptr), 0);
    if (capture_state.hook == nullptr) {
        active_capture_state = nullptr;
        if (error_message != nullptr) {
            *error_message = "SetWindowsHookEx failed for key capture.";
        }
        return {};
    }

    const QDeadlineTimer deadline(timeout_ms);
    MSG msg{};
    while (!deadline.hasExpired()) {
        while (::PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_APP + 1 && !capture_state.captured_key_name.isEmpty()) {
                ::UnhookWindowsHookEx(capture_state.hook);
                active_capture_state = nullptr;
                return capture_state.captured_key_name;
            }
            ::TranslateMessage(&msg);
            ::DispatchMessageW(&msg);
        }
        ::MsgWaitForMultipleObjects(0, nullptr, FALSE, 25, QS_ALLINPUT);
    }

    ::UnhookWindowsHookEx(capture_state.hook);
    active_capture_state = nullptr;
    if (error_message != nullptr) {
        *error_message = "Timed out waiting for a key press.";
    }
    return {};
}

bool WindowsGlobalHotkey::register_hotkeys(const QString& hold_key_name, const QString& chord_key_name) {
    unregister_hotkey();
    hold_key_name_ = hold_key_name;
    chord_key_name_ = chord_key_name;

    QString error;
    if (!parse_key_name(hold_key_name, hold_vk_, error)) {
        emit registration_failed(error);
        return false;
    }
    if (!parse_key_name(chord_key_name, chord_vk_, error)) {
        emit registration_failed(error);
        return false;
    }

    active_instance_ = this;
    hook_ = ::SetWindowsHookExW(WH_KEYBOARD_LL, &WindowsGlobalHotkey::keyboard_proc, ::GetModuleHandleW(nullptr), 0);
    if (hook_ == nullptr) {
        active_instance_ = nullptr;
        emit registration_failed("SetWindowsHookEx failed");
        return false;
    }

    reset_runtime_state();
    return true;
}

void WindowsGlobalHotkey::unregister_hotkey() {
    const DWORD hold_vk = hold_vk_;
    const DWORD chord_vk = chord_vk_;
    const bool hold_down = hold_down_;
    const bool chord_down = chord_down_;
    if (hook_ != nullptr) {
        ::UnhookWindowsHookEx(hook_);
        hook_ = nullptr;
    }
    if (active_instance_ == this) {
        active_instance_ = nullptr;
    }
    if (hold_down && hold_vk != 0) {
        send_key_up(hold_vk);
    }
    if (chord_down && chord_vk != 0) {
        send_key_up(chord_vk);
    }
    reset_runtime_state();
}

QString WindowsGlobalHotkey::backend_name() const {
    return "windows/LowLevelKeyboardHook";
}

QString WindowsGlobalHotkey::hold_key_name() const {
    return hold_key_name_;
}

QString WindowsGlobalHotkey::chord_key_name() const {
    return chord_key_name_;
}

LRESULT CALLBACK WindowsGlobalHotkey::keyboard_proc(int code, WPARAM w_param, LPARAM l_param) {
    if (code < 0 || l_param == 0) {
        return ::CallNextHookEx(nullptr, code, w_param, l_param);
    }

    if (active_instance_ != nullptr) {
        const auto* key_info = reinterpret_cast<const KBDLLHOOKSTRUCT*>(l_param);
        if ((key_info->flags & LLKHF_INJECTED) == 0 && active_instance_->handle_keyboard_event(w_param, *key_info)) {
            return 1;
        }
    }

    return ::CallNextHookEx(nullptr, code, w_param, l_param);
}

bool WindowsGlobalHotkey::handle_keyboard_event(WPARAM w_param, const KBDLLHOOKSTRUCT& key_info) {
    const bool key_down = w_param == WM_KEYDOWN || w_param == WM_SYSKEYDOWN;
    const bool key_up = w_param == WM_KEYUP || w_param == WM_SYSKEYUP;
    if (!key_down && !key_up) {
        return false;
    }

    bool consume = false;
    if (key_info.vkCode == hold_vk_) {
        consume = true;
        if (key_down) {
            if (hands_free_mode_) {
                hands_free_mode_ = false;
                ignore_next_hold_release_ = true;
                emit hands_free_disabled();
            } else if (!hold_down_) {
                emit hold_started();
            }
            hold_down_ = true;
        } else if (key_up) {
            hold_down_ = false;
            if (ignore_next_hold_release_) {
                ignore_next_hold_release_ = false;
                return true;
            }
            if (hands_free_mode_) {
                return true;
            }
            emit hold_stopped();
        }
    } else if (key_info.vkCode == chord_vk_) {
        if (hold_down_ || hands_free_mode_) {
            consume = true;
        }
        chord_down_ = key_down;
    }

    if (hold_down_ && chord_down_ && !hands_free_mode_) {
        hands_free_mode_ = true;
        ignore_next_hold_release_ = true;
        emit hands_free_enabled();
        consume = true;
    }

    return consume;
}

bool WindowsGlobalHotkey::parse_key_name(const QString& key_name, DWORD& vk, QString& error) const {
    const QString normalized = canonical_hotkey_name(key_name);
    if (normalized == "right_alt") {
        vk = VK_RMENU;
        return true;
    }
    if (normalized == "left_alt") {
        vk = VK_LMENU;
        return true;
    }
    if (normalized == "space") {
        vk = VK_SPACE;
        return true;
    }
    if (normalized == "right_ctrl") {
        vk = VK_RCONTROL;
        return true;
    }
    if (normalized == "left_ctrl") {
        vk = VK_LCONTROL;
        return true;
    }
    if (normalized == "right_shift") {
        vk = VK_RSHIFT;
        return true;
    }
    if (normalized == "left_shift") {
        vk = VK_LSHIFT;
        return true;
    }
    if (normalized == "left_meta" || normalized == "right_meta") {
        vk = VK_LWIN;
        return true;
    }
    if (normalized == "menu") {
        vk = VK_APPS;
        return true;
    }

    error = QString("unsupported key name: %1").arg(key_name);
    return false;
}

void WindowsGlobalHotkey::reset_runtime_state() {
    hold_down_ = false;
    chord_down_ = false;
    hands_free_mode_ = false;
    ignore_next_hold_release_ = false;
}

void WindowsGlobalHotkey::send_key_up(DWORD vk) {
    if ((::GetAsyncKeyState(static_cast<int>(vk)) & 0x8000) == 0) {
        return;
    }
    INPUT input{};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = static_cast<WORD>(vk);
    input.ki.dwFlags = KEYEVENTF_KEYUP;
    ::SendInput(1, &input, sizeof(INPUT));
}

}  // namespace ohmytypeless
