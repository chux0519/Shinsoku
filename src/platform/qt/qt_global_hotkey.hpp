#pragma once

#include "platform/global_hotkey.hpp"

namespace ohmytypeless {

class QtGlobalHotkey final : public GlobalHotkey {
    Q_OBJECT
public:
    explicit QtGlobalHotkey(QObject* parent = nullptr);

    bool supports_global_hotkeys() const override;
    bool register_hotkeys(const QString& hold_key_name, const QString& chord_key_name) override;
    void unregister_hotkey() override;
    QString backend_name() const override;
    QString hold_key_name() const override;
    QString chord_key_name() const override;
};

}  // namespace ohmytypeless
