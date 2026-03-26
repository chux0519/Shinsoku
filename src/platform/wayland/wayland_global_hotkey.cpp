#include "platform/wayland/wayland_global_hotkey.hpp"

#include <libevdev/libevdev.h>

#include <chrono>
#include <cerrno>
#include <cstring>
#include <filesystem>
#include <fcntl.h>
#include <memory>
#include <stdexcept>
#include <thread>
#include <utility>
#include <unistd.h>
#include <vector>

#include <QMetaObject>

namespace ohmytypeless {

namespace {

struct DeviceCloser {
    void operator()(libevdev* device) const {
        libevdev_free(device);
    }
};

struct DeviceHandle {
    int fd = -1;
    std::unique_ptr<libevdev, DeviceCloser> dev;
};

int key_code_from_name(const QString& key_name) {
    const QByteArray utf8 = key_name.trimmed().toUtf8();
    const int code = libevdev_event_code_from_name(EV_KEY, utf8.constData());
    if (code < 0) {
        throw std::runtime_error("unknown key name: " + key_name.toStdString());
    }
    return code;
}

std::vector<DeviceHandle> open_keyboard_devices(int hold_key, int chord_key) {
    std::vector<DeviceHandle> devices;
    std::vector<std::string> errors;

    for (const auto& entry : std::filesystem::directory_iterator("/dev/input")) {
        const std::string filename = entry.path().filename().string();
        if (!filename.starts_with("event")) {
            continue;
        }

        const int fd = ::open(entry.path().c_str(), O_RDONLY | O_NONBLOCK);
        if (fd < 0) {
            errors.push_back(entry.path().string() + ": open failed: " + std::strerror(errno));
            continue;
        }

        libevdev* raw = nullptr;
        if (libevdev_new_from_fd(fd, &raw) < 0) {
            errors.push_back(entry.path().string() + ": libevdev_new_from_fd failed");
            ::close(fd);
            continue;
        }

        const bool looks_like_keyboard = libevdev_has_event_type(raw, EV_KEY) != 0 &&
                                         libevdev_has_event_code(raw, EV_KEY, hold_key) != 0 &&
                                         libevdev_has_event_code(raw, EV_KEY, chord_key) != 0;
        if (!looks_like_keyboard) {
            libevdev_free(raw);
            ::close(fd);
            continue;
        }

        devices.push_back(DeviceHandle{fd, std::unique_ptr<libevdev, DeviceCloser>(raw)});
    }

    if (devices.empty()) {
        std::string message = "no readable keyboard input devices found under /dev/input";
        if (!errors.empty()) {
            message += " (";
            for (std::size_t i = 0; i < errors.size(); ++i) {
                if (i > 0) {
                    message += "; ";
                }
                message += errors[i];
            }
            message += ")";
        }
        throw std::runtime_error(message);
    }

    return devices;
}

}  // namespace

WaylandGlobalHotkey::WaylandGlobalHotkey(QObject* parent) : GlobalHotkey(parent) {}

WaylandGlobalHotkey::~WaylandGlobalHotkey() {
    unregister_hotkey();
}

bool WaylandGlobalHotkey::supports_global_hotkeys() const {
    return const_cast<WaylandGlobalHotkey*>(this)->can_access_input_devices();
}

bool WaylandGlobalHotkey::register_hotkeys(const QString& hold_key_name, const QString& chord_key_name) {
    if (!can_access_input_devices()) {
        emit registration_failed(availability_reason());
        return false;
    }

    unregister_hotkey();

    hold_key_name_ = hold_key_name;
    chord_key_name_ = chord_key_name;
    last_error_ = nullptr;

    if (running_.exchange(true)) {
        return true;
    }

    worker_ = std::thread([this]() {
        try {
            run();
        } catch (...) {
            last_error_ = std::current_exception();
            running_.store(false);
        }
    });
    std::this_thread::sleep_for(std::chrono::milliseconds(50));

    if (last_error_ != nullptr) {
        running_.store(false);
        if (worker_.joinable()) {
            worker_.join();
        }
        try {
            std::rethrow_exception(last_error_);
        } catch (const std::exception& exception) {
            emit registration_failed(QString::fromUtf8(exception.what()));
        } catch (...) {
            emit registration_failed("Wayland hotkey backend failed to start.");
        }
        return false;
    }

    return true;
}

void WaylandGlobalHotkey::unregister_hotkey() {
    if (!running_.exchange(false)) {
        if (worker_.joinable()) {
            worker_.join();
        }
        return;
    }

    if (worker_.joinable()) {
        worker_.join();
    }
}

QString WaylandGlobalHotkey::backend_name() const {
    return "wayland/libevdev";
}

QString WaylandGlobalHotkey::hold_key_name() const {
    return hold_key_name_;
}

QString WaylandGlobalHotkey::chord_key_name() const {
    return chord_key_name_;
}

QString WaylandGlobalHotkey::availability_reason() const {
    return availability_reason_;
}

bool WaylandGlobalHotkey::can_access_input_devices() {
    namespace fs = std::filesystem;
    const fs::path input_dir{"/dev/input"};
    if (!fs::exists(input_dir)) {
        availability_reason_ = "Wayland hotkeys require /dev/input, but that path is missing.";
        return false;
    }

    bool found_event_device = false;
    for (const auto& entry : fs::directory_iterator(input_dir)) {
        const std::string filename = entry.path().filename().string();
        if (!filename.starts_with("event")) {
            continue;
        }
        found_event_device = true;
        const int fd = ::open(entry.path().c_str(), O_RDONLY | O_NONBLOCK);
        if (fd >= 0) {
            ::close(fd);
            availability_reason_.clear();
            return true;
        }
    }

    availability_reason_ = found_event_device
                               ? "Wayland hotkeys need read access to /dev/input/event*. Add your user to the input group or grant equivalent permissions."
                               : "Wayland hotkeys require readable /dev/input/event* devices, but none were found.";
    return false;
}

void WaylandGlobalHotkey::run() {
    const int hold_key = key_code_from_name(hold_key_name_);
    const int chord_key = key_code_from_name(chord_key_name_);
    auto devices = open_keyboard_devices(hold_key, chord_key);

    bool hold_down = false;
    bool chord_down = false;
    bool hands_free_mode = false;
    bool ignore_next_hold_release = false;

    while (running_.load()) {
        for (auto& device : devices) {
            input_event event{};
            const int status = libevdev_next_event(device.dev.get(), LIBEVDEV_READ_FLAG_NORMAL, &event);
            if (status != LIBEVDEV_READ_STATUS_SUCCESS || event.type != EV_KEY) {
                continue;
            }

            if (event.code == hold_key) {
                if (event.value == 1) {
                    if (hands_free_mode) {
                        hands_free_mode = false;
                        ignore_next_hold_release = true;
                        QMetaObject::invokeMethod(this, [this]() { emit hands_free_disabled(); }, Qt::QueuedConnection);
                    } else if (!hold_down) {
                        QMetaObject::invokeMethod(this, [this]() { emit hold_started(); }, Qt::QueuedConnection);
                    }
                    hold_down = true;
                } else if (event.value == 0) {
                    hold_down = false;
                    if (ignore_next_hold_release) {
                        ignore_next_hold_release = false;
                        continue;
                    }
                    if (hands_free_mode) {
                        continue;
                    }
                    QMetaObject::invokeMethod(this, [this]() { emit hold_stopped(); }, Qt::QueuedConnection);
                }
            } else if (event.code == chord_key) {
                chord_down = event.value != 0;
            }

            if (hold_down && chord_down && !hands_free_mode) {
                hands_free_mode = true;
                ignore_next_hold_release = true;
                QMetaObject::invokeMethod(this, [this]() { emit hands_free_enabled(); }, Qt::QueuedConnection);
            }
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(4));
    }

    for (auto& device : devices) {
        if (device.fd >= 0) {
            ::close(device.fd);
        }
    }
}

}  // namespace ohmytypeless
