#pragma once

#include <QObject>
#include <QString>

namespace ohmytypeless {

class GlobalHotkey : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    ~GlobalHotkey() override = default;

    virtual bool register_hotkey(const QString& sequence) = 0;
    virtual void unregister_hotkey() = 0;
    virtual QString backend_name() const = 0;

signals:
    void activated();
    void registration_failed(const QString& reason);
};

}  // namespace ohmytypeless
