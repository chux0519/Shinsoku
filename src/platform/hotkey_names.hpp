#pragma once

#include <QString>

namespace ohmytypeless {

QString canonical_hotkey_name(const QString& key_name);
QString display_hotkey_name(const QString& key_name);
QString evdev_hotkey_name(const QString& key_name);

}  // namespace ohmytypeless
