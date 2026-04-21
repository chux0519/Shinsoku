#include "platform/windows/windows_clipboard_service.hpp"

#include <QClipboard>
#include <QCoreApplication>
#include <QStringList>

#include <chrono>
#include <iterator>
#include <thread>

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace ohmytypeless {

namespace {

struct WindowTarget {
    HWND window = nullptr;
    HWND focus = nullptr;
    DWORD thread_id = 0;
};

bool is_valid_window(HWND hwnd) {
    return hwnd != nullptr && ::IsWindow(hwnd) != FALSE;
}

bool is_current_process_window(HWND hwnd) {
    if (!is_valid_window(hwnd)) {
        return false;
    }

    DWORD process_id = 0;
    ::GetWindowThreadProcessId(hwnd, &process_id);
    return process_id == ::GetCurrentProcessId();
}

QString format_hwnd(HWND hwnd) {
    return is_valid_window(hwnd) ? QString("0x%1").arg(reinterpret_cast<quintptr>(hwnd), 0, 16) : "null";
}

QString window_class_name(HWND hwnd) {
    if (!is_valid_window(hwnd)) {
        return "n/a";
    }

    wchar_t buffer[256] = {};
    const int length = ::GetClassNameW(hwnd, buffer, static_cast<int>(std::size(buffer)));
    return length > 0 ? QString::fromWCharArray(buffer, length) : "unknown";
}

QString window_title(HWND hwnd) {
    if (!is_valid_window(hwnd)) {
        return "n/a";
    }

    wchar_t buffer[512] = {};
    const int length = ::GetWindowTextW(hwnd, buffer, static_cast<int>(std::size(buffer)));
    if (length <= 0) {
        return "(empty)";
    }
    return QString::fromWCharArray(buffer, length);
}

void send_key_event(WORD vk, DWORD flags) {
    INPUT input{};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = vk;
    input.ki.dwFlags = flags;
    ::SendInput(1, &input, sizeof(INPUT));
}

bool send_paste_shortcut(const QString& paste_keys) {
    struct KeyCombo {
        bool ctrl = false;
        bool shift = false;
        WORD key = 0;
    };

    KeyCombo combo;
    if (paste_keys == "ctrl+v") {
        combo.ctrl = true;
        combo.key = 'V';
    } else if (paste_keys == "shift+insert") {
        combo.shift = true;
        combo.key = VK_INSERT;
    } else if (paste_keys == "ctrl+shift+v") {
        combo.ctrl = true;
        combo.shift = true;
        combo.key = 'V';
    } else {
        return false;
    }

    if (combo.ctrl) {
        send_key_event(VK_CONTROL, 0);
    }
    if (combo.shift) {
        send_key_event(VK_SHIFT, 0);
    }
    send_key_event(combo.key, 0);
    send_key_event(combo.key, KEYEVENTF_KEYUP);
    if (combo.shift) {
        send_key_event(VK_SHIFT, KEYEVENTF_KEYUP);
    }
    if (combo.ctrl) {
        send_key_event(VK_CONTROL, KEYEVENTF_KEYUP);
    }
    return true;
}

WindowTarget capture_foreground_target() {
    WindowTarget target;
    target.window = ::GetForegroundWindow();
    if (!is_valid_window(target.window)) {
        return target;
    }

    target.thread_id = ::GetWindowThreadProcessId(target.window, nullptr);
    GUITHREADINFO info{};
    info.cbSize = sizeof(info);
    if (target.thread_id != 0 && ::GetGUIThreadInfo(target.thread_id, &info) != FALSE) {
        if (is_valid_window(info.hwndFocus)) {
            target.focus = info.hwndFocus;
        } else if (is_valid_window(info.hwndActive)) {
            target.focus = info.hwndActive;
        }
        if (is_valid_window(info.hwndActive)) {
            target.window = ::GetAncestor(info.hwndActive, GA_ROOT);
        }
    }

    if (!is_valid_window(target.focus)) {
        target.focus = target.window;
    }
    if (!is_valid_window(target.window)) {
        target.window = target.focus;
    }
    return target;
}

bool activate_target_window(HWND hwnd, HWND focus) {
    if (!is_valid_window(hwnd)) {
        return false;
    }

    if (::IsIconic(hwnd)) {
        ::ShowWindow(hwnd, SW_RESTORE);
    }

    const DWORD current_thread = ::GetCurrentThreadId();
    const DWORD target_thread = ::GetWindowThreadProcessId(hwnd, nullptr);
    const HWND foreground = ::GetForegroundWindow();
    const DWORD foreground_thread = foreground != nullptr ? ::GetWindowThreadProcessId(foreground, nullptr) : 0;
    const bool attached_to_target = target_thread != 0 && target_thread != current_thread &&
                                    ::AttachThreadInput(current_thread, target_thread, TRUE) != FALSE;
    const bool attached_to_foreground = foreground_thread != 0 && foreground_thread != current_thread &&
                                        foreground_thread != target_thread &&
                                        ::AttachThreadInput(current_thread, foreground_thread, TRUE) != FALSE;

    ::ShowWindow(hwnd, SW_SHOW);
    ::BringWindowToTop(hwnd);
    ::SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    ::SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    ::SetForegroundWindow(hwnd);
    ::SetActiveWindow(hwnd);
    if (is_valid_window(focus)) {
        ::SetFocus(focus);
    }

    if (attached_to_foreground) {
        ::AttachThreadInput(current_thread, foreground_thread, FALSE);
    }
    if (attached_to_target) {
        ::AttachThreadInput(current_thread, target_thread, FALSE);
    }

    const HWND activated = ::GetForegroundWindow();
    return activated == hwnd || ::GetAncestor(activated, GA_ROOTOWNER) == hwnd;
}

}  // namespace

WindowsClipboardService::WindowsClipboardService(QClipboard* clipboard) : clipboard_(clipboard) {}

bool WindowsClipboardService::supports_auto_paste() const {
    return true;
}

void WindowsClipboardService::begin_paste_session() {
    const WindowTarget target = capture_foreground_target();
    if (is_current_process_window(target.window)) {
        target_window_ = 0;
        target_focus_ = 0;
        target_thread_id_ = 0;
        set_debug_info("begin session: foreground belongs to this process; no external target captured");
        return;
    }
    target_window_ = reinterpret_cast<quintptr>(target.window);
    target_focus_ = reinterpret_cast<quintptr>(target.focus);
    target_thread_id_ = target.thread_id;

    QStringList lines;
    lines << "begin session: captured external target"
          << QString("window=%1 class=%2 title=%3")
                 .arg(format_hwnd(target.window), window_class_name(target.window), window_title(target.window))
          << QString("focus=%1 class=%2 title=%3")
                 .arg(format_hwnd(target.focus), window_class_name(target.focus), window_title(target.focus))
          << QString("thread_id=%1").arg(target.thread_id);
    set_debug_info(lines.join('\n'));
}

void WindowsClipboardService::clear_paste_session() {
    target_window_ = 0;
    target_focus_ = 0;
    target_thread_id_ = 0;
}

void WindowsClipboardService::copy_text(const QString& text) {
    if (clipboard_ == nullptr) {
        return;
    }
    clipboard_->setText(text, QClipboard::Clipboard);
}

bool WindowsClipboardService::paste_text_to_last_target(const QString& text, const QString& paste_keys) {
    if (clipboard_ == nullptr) {
        set_debug_info("paste failed: clipboard backend is null");
        return false;
    }

    QStringList lines;
    lines << QString("paste request: text_length=%1 paste_keys=%2").arg(text.size()).arg(paste_keys);
    clipboard_->setText(text, QClipboard::Clipboard);
    QCoreApplication::processEvents();
    std::this_thread::sleep_for(std::chrono::milliseconds(50));

    WindowTarget active_target = capture_foreground_target();
    lines << QString("foreground before restore: window=%1 class=%2 title=%3")
                 .arg(format_hwnd(active_target.window),
                      window_class_name(active_target.window),
                      window_title(active_target.window))
          << QString("focus before restore: window=%1 class=%2 title=%3")
                 .arg(format_hwnd(active_target.focus),
                      window_class_name(active_target.focus),
                      window_title(active_target.focus));
    WindowTarget target;
    if (is_valid_window(active_target.window) && !is_current_process_window(active_target.window)) {
        target = active_target;
        lines << "target selection: using current external foreground target";
    } else {
        target.window = reinterpret_cast<HWND>(target_window_);
        target.focus = reinterpret_cast<HWND>(target_focus_);
        target.thread_id = target_thread_id_;
        lines << "target selection: foreground is this process; falling back to captured target";
    }

    if (is_valid_window(target.window) && target.window != active_target.window) {
        const bool activated = activate_target_window(target.window, target.focus);
        lines << QString("activate target: attempted=yes result=%1").arg(activated ? "true" : "false");
    } else {
        lines << "activate target: attempted=no";
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(80));

    active_target = capture_foreground_target();
    lines << QString("foreground after restore: window=%1 class=%2 title=%3")
                 .arg(format_hwnd(active_target.window),
                      window_class_name(active_target.window),
                      window_title(active_target.window))
          << QString("focus after restore: window=%1 class=%2 title=%3")
                 .arg(format_hwnd(active_target.focus),
                      window_class_name(active_target.focus),
                      window_title(active_target.focus));
    HWND paste_hwnd = nullptr;
    if (is_valid_window(active_target.focus) && !is_current_process_window(active_target.focus)) {
        paste_hwnd = active_target.focus;
        lines << "paste target: using current focus window";
    } else if (is_valid_window(target.focus) && !is_current_process_window(target.focus)) {
        paste_hwnd = target.focus;
        lines << "paste target: using captured focus window";
    } else {
        lines << "paste target: none";
    }

    const bool sent_shortcut = send_paste_shortcut(paste_keys);
    lines << QString("paste path: SendInput result=%1").arg(sent_shortcut ? "true" : "false");
    set_debug_info(lines.join('\n'));
    return sent_shortcut;
}

QString WindowsClipboardService::last_debug_info() const {
    return last_debug_info_;
}

void WindowsClipboardService::set_debug_info(const QString& text) {
    last_debug_info_ = text;
    ::OutputDebugStringW(reinterpret_cast<LPCWSTR>(text.utf16()));
    ::OutputDebugStringW(L"\n");
}

}  // namespace ohmytypeless
