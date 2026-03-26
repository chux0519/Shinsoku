#include "platform/hotkey_names.hpp"

namespace ohmytypeless {

namespace {

QString normalize_for_lookup(const QString& key_name) {
    QString normalized = key_name.trimmed();
    normalized.replace('-', '_');
    normalized.replace(' ', '_');
    return normalized.toLower();
}

}  // namespace

QString canonical_hotkey_name(const QString& key_name) {
    const QString normalized = normalize_for_lookup(key_name);

    if (normalized == "key_rightalt" || normalized == "right_alt") return "right_alt";
    if (normalized == "key_leftalt" || normalized == "left_alt") return "left_alt";
    if (normalized == "key_space" || normalized == "space") return "space";
    if (normalized == "key_rightctrl" || normalized == "right_ctrl") return "right_ctrl";
    if (normalized == "key_leftctrl" || normalized == "left_ctrl") return "left_ctrl";
    if (normalized == "key_rightshift" || normalized == "right_shift") return "right_shift";
    if (normalized == "key_leftshift" || normalized == "left_shift") return "left_shift";
    if (normalized == "key_menu" || normalized == "menu") return "menu";
    if (normalized == "key_compose" || normalized == "compose") return "compose";
    if (normalized == "key_rightmeta" || normalized == "right_meta") return "right_meta";
    if (normalized == "key_leftmeta" || normalized == "left_meta") return "left_meta";

    if (normalized.startsWith("key_")) {
        return normalized.toUpper();
    }

    return normalized;
}

QString display_hotkey_name(const QString& key_name) {
    const QString canonical = canonical_hotkey_name(key_name);

    if (canonical == "right_alt") return "Right Alt";
    if (canonical == "left_alt") return "Left Alt";
    if (canonical == "space") return "Space";
    if (canonical == "right_ctrl") return "Right Ctrl";
    if (canonical == "left_ctrl") return "Left Ctrl";
    if (canonical == "right_shift") return "Right Shift";
    if (canonical == "left_shift") return "Left Shift";
    if (canonical == "menu") return "Menu";
    if (canonical == "compose") return "Compose";
    if (canonical == "right_meta") return "Right Meta";
    if (canonical == "left_meta") return "Left Meta";

    QString label = canonical;
    if (label.startsWith("KEY_")) {
        label.remove(0, 4);
    }
    label = label.toLower().replace('_', ' ');
    if (!label.isEmpty()) {
        label[0] = label[0].toUpper();
    }
    return label;
}

QString evdev_hotkey_name(const QString& key_name) {
    const QString canonical = canonical_hotkey_name(key_name);

    if (canonical == "right_alt") return "KEY_RIGHTALT";
    if (canonical == "left_alt") return "KEY_LEFTALT";
    if (canonical == "space") return "KEY_SPACE";
    if (canonical == "right_ctrl") return "KEY_RIGHTCTRL";
    if (canonical == "left_ctrl") return "KEY_LEFTCTRL";
    if (canonical == "right_shift") return "KEY_RIGHTSHIFT";
    if (canonical == "left_shift") return "KEY_LEFTSHIFT";
    if (canonical == "menu") return "KEY_MENU";
    if (canonical == "compose") return "KEY_COMPOSE";
    if (canonical == "right_meta") return "KEY_RIGHTMETA";
    if (canonical == "left_meta") return "KEY_LEFTMETA";

    return canonical;
}

}  // namespace ohmytypeless
