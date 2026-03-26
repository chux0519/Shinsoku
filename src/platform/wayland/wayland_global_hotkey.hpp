#pragma once

#include "platform/global_hotkey.hpp"

#include <atomic>
#include <exception>
#include <string>
#include <thread>

namespace ohmytypeless {

class WaylandGlobalHotkey final : public GlobalHotkey {
    Q_OBJECT
public:
    explicit WaylandGlobalHotkey(QObject* parent = nullptr);
    ~WaylandGlobalHotkey() override;

    bool supports_global_hotkeys() const override;
    bool register_hotkeys(const QString& hold_key_name, const QString& chord_key_name) override;
    void unregister_hotkey() override;
    QString backend_name() const override;
    QString hold_key_name() const override;
    QString chord_key_name() const override;

    QString availability_reason() const;

private:
    void run();
    bool can_access_input_devices();

    QString hold_key_name_;
    QString chord_key_name_;
    QString availability_reason_;
    std::atomic<bool> running_ = false;
    std::thread worker_;
    std::exception_ptr last_error_;
};

}  // namespace ohmytypeless
