#include "platform/wayland/wayland_selection_service.hpp"

#include <QClipboard>
#include <QCoreApplication>
#include <QMimeData>
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

bool run_command(const WtypeCommand& command) {
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

}  // namespace

WaylandSelectionService::WaylandSelectionService(QClipboard* clipboard) : clipboard_(clipboard) {}

QString WaylandSelectionService::backend_name() const {
    return "wayland/clipboard-fallback";
}

bool WaylandSelectionService::supports_automatic_detection() const {
    return clipboard_ != nullptr && has_required_tools();
}

bool WaylandSelectionService::supports_replacement() const {
    return clipboard_ != nullptr && has_required_tools();
}

SelectionCaptureResult WaylandSelectionService::capture_selection(bool allow_clipboard_fallback) {
    if (clipboard_ == nullptr) {
        set_debug_info("capture failed: clipboard backend is null");
        return SelectionCaptureResult{false, {}, last_debug_info_};
    }
    if (!allow_clipboard_fallback) {
        set_debug_info("capture failed: clipboard fallback disabled");
        return SelectionCaptureResult{false, {}, last_debug_info_};
    }
    if (!has_required_tools()) {
        set_debug_info("capture failed: required Wayland helper tools are unavailable");
        return SelectionCaptureResult{false, {}, last_debug_info_};
    }

    auto snapshot = snapshot_clipboard();
    const QString placeholder = "__ohmytypeless_selection_probe__";
    clipboard_->setText(placeholder, QClipboard::Clipboard);
    QCoreApplication::processEvents();
    std::this_thread::sleep_for(std::chrono::milliseconds(50));

    const bool copy_sent = run_wtype_key_combo("ctrl+c");
    std::this_thread::sleep_for(std::chrono::milliseconds(120));
    QCoreApplication::processEvents();

    const QString copied_text = clipboard_->text(QClipboard::Clipboard);
    restore_clipboard(std::move(snapshot));

    const bool success = copy_sent && copied_text != placeholder && !copied_text.trimmed().isEmpty();
    set_debug_info(QString("capture path=clipboard_copy_fallback copy_sent=%1 copied_text_length=%2 success=%3")
                       .arg(copy_sent ? "true" : "false")
                       .arg(copied_text.size())
                       .arg(success ? "true" : "false"));
    return SelectionCaptureResult{success, success ? copied_text : QString(), last_debug_info_};
}

bool WaylandSelectionService::replace_selection(const QString& text) {
    if (clipboard_ == nullptr) {
        set_debug_info("replace failed: clipboard backend is null");
        return false;
    }
    if (!has_required_tools()) {
        set_debug_info("replace failed: required Wayland helper tools are unavailable");
        return false;
    }

    auto snapshot = snapshot_clipboard();
    clipboard_->setText(text, QClipboard::Clipboard);
    QCoreApplication::processEvents();
    std::this_thread::sleep_for(std::chrono::milliseconds(80));

    const bool sent = run_wtype_key_combo("ctrl+v");
    std::this_thread::sleep_for(std::chrono::milliseconds(120));
    restore_clipboard(std::move(snapshot));

    set_debug_info(QString("replace path=clipboard_ctrl_v text_length=%1 result=%2 paste_keys=ctrl+v")
                       .arg(text.size())
                       .arg(sent ? "true" : "false"));
    return sent;
}

QString WaylandSelectionService::last_debug_info() const {
    return last_debug_info_;
}

bool WaylandSelectionService::has_required_tools() const {
    return !QStandardPaths::findExecutable("wl-copy").isEmpty() && !QStandardPaths::findExecutable("wtype").isEmpty();
}

bool WaylandSelectionService::run_wtype_key_combo(const QString& key_combo) const {
    WtypeCommand command;
    return build_wtype_command(key_combo, &command) && run_command(command);
}

std::unique_ptr<QMimeData> WaylandSelectionService::snapshot_clipboard() const {
    auto snapshot = std::make_unique<QMimeData>();
    if (clipboard_ == nullptr) {
        return snapshot;
    }

    const QMimeData* source = clipboard_->mimeData(QClipboard::Clipboard);
    if (source == nullptr) {
        return snapshot;
    }

    const QStringList formats = source->formats();
    for (const QString& format : formats) {
        snapshot->setData(format, source->data(format));
    }
    return snapshot;
}

void WaylandSelectionService::restore_clipboard(std::unique_ptr<QMimeData> snapshot) const {
    if (clipboard_ == nullptr || snapshot == nullptr) {
        return;
    }
    clipboard_->setMimeData(snapshot.release(), QClipboard::Clipboard);
    QCoreApplication::processEvents();
}

void WaylandSelectionService::set_debug_info(const QString& text) const {
    last_debug_info_ = text;
}

}  // namespace ohmytypeless
