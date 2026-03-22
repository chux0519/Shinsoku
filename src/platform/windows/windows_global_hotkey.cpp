#include "platform/windows/windows_global_hotkey.hpp"

#include <QApplication>
#include <QStringList>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace ohmytypeless {

WindowsGlobalHotkey::WindowsGlobalHotkey(QObject* parent) : GlobalHotkey(parent) {
    qApp->installNativeEventFilter(this);
}

WindowsGlobalHotkey::~WindowsGlobalHotkey() {
    unregister_hotkey();
    qApp->removeNativeEventFilter(this);
}

bool WindowsGlobalHotkey::register_hotkey(const QString& sequence) {
    unregister_hotkey();

    unsigned int modifiers = 0;
    unsigned int vk = 0;
    QString error;
    if (!parse_sequence(sequence, modifiers, vk, error)) {
        emit registration_failed(error);
        return false;
    }

    if (!::RegisterHotKey(nullptr, hotkey_id_, modifiers, vk)) {
        emit registration_failed(QString("RegisterHotKey failed for %1").arg(sequence));
        return false;
    }

    registered_ = true;
    return true;
}

void WindowsGlobalHotkey::unregister_hotkey() {
    if (!registered_) {
        return;
    }

    ::UnregisterHotKey(nullptr, hotkey_id_);
    registered_ = false;
}

QString WindowsGlobalHotkey::backend_name() const {
    return "windows/RegisterHotKey";
}

bool WindowsGlobalHotkey::nativeEventFilter(const QByteArray& event_type, void* message, qintptr* result) {
    Q_UNUSED(result);

    if (event_type != "windows_generic_MSG" && event_type != "windows_dispatcher_MSG") {
        return false;
    }

    auto* msg = static_cast<MSG*>(message);
    if (msg->message == WM_HOTKEY && static_cast<int>(msg->wParam) == hotkey_id_) {
        emit activated();
        return true;
    }

    return false;
}

bool WindowsGlobalHotkey::parse_sequence(const QString& sequence,
                                         unsigned int& modifiers,
                                         unsigned int& vk,
                                         QString& error) const {
    const QStringList parts = sequence.toLower().split('+', Qt::SkipEmptyParts);
    if (parts.isEmpty()) {
        error = "hotkey sequence is empty";
        return false;
    }

    modifiers = 0;
    vk = 0;

    for (const QString& raw_part : parts) {
        const QString part = raw_part.trimmed();
        if (part == "ctrl" || part == "control") {
            modifiers |= MOD_CONTROL;
        } else if (part == "alt") {
            modifiers |= MOD_ALT;
        } else if (part == "shift") {
            modifiers |= MOD_SHIFT;
        } else if (part == "win" || part == "meta") {
            modifiers |= MOD_WIN;
        } else if (part.length() == 1) {
            const QChar ch = part.front().toUpper();
            if (ch.isLetterOrNumber()) {
                vk = static_cast<unsigned int>(ch.unicode());
            } else {
                error = QString("unsupported key token: %1").arg(part);
                return false;
            }
        } else if (part == "space") {
            vk = VK_SPACE;
        } else if (part == "f1") {
            vk = VK_F1;
        } else if (part == "f2") {
            vk = VK_F2;
        } else if (part == "f3") {
            vk = VK_F3;
        } else if (part == "f4") {
            vk = VK_F4;
        } else if (part == "f5") {
            vk = VK_F5;
        } else if (part == "f6") {
            vk = VK_F6;
        } else if (part == "f7") {
            vk = VK_F7;
        } else if (part == "f8") {
            vk = VK_F8;
        } else if (part == "f9") {
            vk = VK_F9;
        } else if (part == "f10") {
            vk = VK_F10;
        } else if (part == "f11") {
            vk = VK_F11;
        } else if (part == "f12") {
            vk = VK_F12;
        } else {
            error = QString("unsupported key token: %1").arg(part);
            return false;
        }
    }

    if (vk == 0) {
        error = "missing non-modifier key";
        return false;
    }

    return true;
}

}  // namespace ohmytypeless
