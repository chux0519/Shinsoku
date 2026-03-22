#pragma once

#include "platform/global_hotkey.hpp"

#include <QAbstractNativeEventFilter>

namespace ohmytypeless {

class WindowsGlobalHotkey final : public GlobalHotkey, public QAbstractNativeEventFilter {
    Q_OBJECT
public:
    explicit WindowsGlobalHotkey(QObject* parent = nullptr);
    ~WindowsGlobalHotkey() override;

    bool register_hotkey(const QString& sequence) override;
    void unregister_hotkey() override;
    QString backend_name() const override;

    bool nativeEventFilter(const QByteArray& event_type, void* message, qintptr* result) override;

private:
    bool parse_sequence(const QString& sequence, unsigned int& modifiers, unsigned int& vk, QString& error) const;

    int hotkey_id_ = 1;
    bool registered_ = false;
};

}  // namespace ohmytypeless
