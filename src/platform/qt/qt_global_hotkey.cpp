#include "platform/qt/qt_global_hotkey.hpp"

namespace ohmytypeless {

QtGlobalHotkey::QtGlobalHotkey(QObject* parent) : GlobalHotkey(parent) {}

bool QtGlobalHotkey::supports_global_hotkeys() const {
    return false;
}

QString QtGlobalHotkey::hold_key_name() const {
    return {};
}

QString QtGlobalHotkey::chord_key_name() const {
    return {};
}

bool QtGlobalHotkey::register_hotkeys(const QString& hold_key_name, const QString& chord_key_name) {
    Q_UNUSED(hold_key_name);
    Q_UNUSED(chord_key_name);
    emit registration_failed("Global hotkeys are not implemented on this platform yet.");
    return false;
}

void QtGlobalHotkey::unregister_hotkey() {}

QString QtGlobalHotkey::backend_name() const {
    return "qt/unsupported";
}

}  // namespace ohmytypeless
