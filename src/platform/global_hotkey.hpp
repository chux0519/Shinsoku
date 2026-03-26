#pragma once

#include <QObject>
#include <QString>

namespace ohmytypeless {

class GlobalHotkey : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    ~GlobalHotkey() override = default;

    virtual bool supports_global_hotkeys() const = 0;
    virtual bool register_hotkeys(const QString& hold_key_name, const QString& chord_key_name) = 0;
    virtual void unregister_hotkey() = 0;
    virtual QString backend_name() const = 0;
    virtual QString hold_key_name() const = 0;
    virtual QString chord_key_name() const = 0;

signals:
    void hold_started();
    void hold_stopped();
    void hands_free_enabled();
    void hands_free_disabled();
    void registration_failed(const QString& reason);
};

}  // namespace ohmytypeless
