#include "platform/wayland/wayland_clipboard_service.hpp"

#include <QClipboard>
#include <QCoreApplication>
#include <QProcess>
#include <QStandardPaths>
#include <QStringList>

#include <chrono>
#include <thread>
#include <utility>
#include <vector>

namespace ohmytypeless {

namespace {

struct WtypeCommand {
    QString program;
    QStringList arguments;
};

QString normalize_modifier(const QString& token) {
    const QString trimmed = token.trimmed().toLower();
    if (trimmed == "ctrl" || trimmed == "control") {
        return "ctrl";
    }
    if (trimmed == "shift") {
        return "shift";
    }
    if (trimmed == "alt") {
        return "alt";
    }
    if (trimmed == "super" || trimmed == "meta") {
        return "super";
    }
    return {};
}

QString normalize_key(const QString& token) {
    const QString trimmed = token.trimmed().toLower();
    if (trimmed == "insert") {
        return "Insert";
    }
    if (trimmed == "space") {
        return "space";
    }
    if (trimmed.size() == 1) {
        return trimmed;
    }
    return token.trimmed();
}

bool build_wtype_command(const QString& key_combo, WtypeCommand* command) {
    if (command == nullptr) {
        return false;
    }

    const QString program = QStandardPaths::findExecutable("wtype");
    if (program.isEmpty()) {
        return false;
    }

    const QStringList raw_parts = key_combo.split('+', Qt::SkipEmptyParts);
    if (raw_parts.isEmpty()) {
        return false;
    }

    QStringList arguments;
    std::vector<QString> modifiers;
    modifiers.reserve(raw_parts.size() > 0 ? static_cast<std::size_t>(raw_parts.size() - 1) : 0U);
    for (int i = 0; i < raw_parts.size() - 1; ++i) {
        const QString modifier = normalize_modifier(raw_parts[i]);
        if (modifier.isEmpty()) {
            return false;
        }
        modifiers.push_back(modifier);
        arguments << "-M" << modifier;
    }

    const QString key = normalize_key(raw_parts.back());
    if (key.isEmpty()) {
        return false;
    }
    arguments << "-k" << key;
    for (auto it = modifiers.rbegin(); it != modifiers.rend(); ++it) {
        arguments << "-m" << *it;
    }

    command->program = program;
    command->arguments = arguments;
    return true;
}

}  // namespace

WaylandClipboardService::WaylandClipboardService(QClipboard* clipboard) : clipboard_(clipboard) {}

bool WaylandClipboardService::supports_auto_paste() const {
    return clipboard_ != nullptr && !QStandardPaths::findExecutable("wtype").isEmpty();
}

void WaylandClipboardService::begin_paste_session() {
    set_debug_info("begin session: Wayland clipboard backend does not need focus capture state");
}

void WaylandClipboardService::clear_paste_session() {
    set_debug_info("clear session: Wayland clipboard backend cleared transient debug state");
}

void WaylandClipboardService::copy_text(const QString& text) {
    if (clipboard_ == nullptr) {
        set_debug_info("copy failed: clipboard backend is null");
        return;
    }

    clipboard_->setText(text, QClipboard::Clipboard);
    set_debug_info(QString("copy ok: text_length=%1").arg(text.size()));
}

bool WaylandClipboardService::paste_text_to_last_target(const QString& text, const QString& paste_keys) {
    if (clipboard_ == nullptr) {
        set_debug_info("paste failed: clipboard backend is null");
        return false;
    }
    if (!has_required_tools()) {
        set_debug_info("paste failed: required Wayland helper tools are unavailable");
        return false;
    }

    clipboard_->setText(text, QClipboard::Clipboard);
    QCoreApplication::processEvents();
    std::this_thread::sleep_for(std::chrono::milliseconds(80));

    const bool sent = run_wtype_key_combo(paste_keys);
    set_debug_info(QString("paste path=wtype result=%1 text_length=%2 keys=%3")
                       .arg(sent ? "true" : "false")
                       .arg(text.size())
                       .arg(paste_keys));
    return sent;
}

QString WaylandClipboardService::last_debug_info() const {
    return last_debug_info_;
}

bool WaylandClipboardService::has_required_tools() const {
    return !QStandardPaths::findExecutable("wtype").isEmpty();
}

bool WaylandClipboardService::run_wtype_key_combo(const QString& key_combo) const {
    WtypeCommand command;
    if (!build_wtype_command(key_combo, &command)) {
        return false;
    }

    QProcess process;
    process.start(command.program, command.arguments);
    if (!process.waitForStarted(1000)) {
        return false;
    }
    process.closeWriteChannel();
    if (!process.waitForFinished(3000)) {
        process.kill();
        process.waitForFinished(1000);
        return false;
    }
    return process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0;
}

void WaylandClipboardService::set_debug_info(const QString& text) const {
    last_debug_info_ = text;
}

}  // namespace ohmytypeless
