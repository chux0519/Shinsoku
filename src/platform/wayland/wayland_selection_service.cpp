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
    return clipboard_ != nullptr && has_capture_tools();
}

bool WaylandSelectionService::supports_replacement() const {
    return clipboard_ != nullptr && has_replace_tools();
}

SelectionCaptureResult WaylandSelectionService::capture_selection(bool allow_clipboard_fallback) {
    if (clipboard_ == nullptr) {
        set_debug_info("capture failed: clipboard backend is null");
        return SelectionCaptureResult{false, {}, last_debug_info_};
    }
    if (!has_capture_tools()) {
        set_debug_info("capture failed: required Wayland helper tools are unavailable");
        return SelectionCaptureResult{false, {}, last_debug_info_};
    }

    const ProcessResult primary_selection = read_wl_paste(true);
    const QString primary_text = primary_selection.std_out.trimmed();
    const bool primary_success = primary_selection.success && !primary_text.isEmpty();
    if (!has_replace_tools()) {
        if (primary_success) {
            set_debug_info(QString("capture path=primary_selection success=true clipboard_probe=unavailable text_length=%1")
                               .arg(primary_text.size()));
            return SelectionCaptureResult{true, primary_text, last_debug_info_};
        }
        set_debug_info(QString("capture path=primary_selection success=false clipboard_probe=unavailable primary_exit=%1 stderr=%2")
                           .arg(primary_selection.exit_code)
                           .arg(primary_selection.std_err.trimmed()));
        return SelectionCaptureResult{false, {}, last_debug_info_};
    }

    auto snapshot = snapshot_clipboard();
    const QString placeholder = "__shinsoku_selection_probe__";
    const bool probe_written = write_wl_copy_text(placeholder);
    QCoreApplication::processEvents();
    std::this_thread::sleep_for(std::chrono::milliseconds(60));

    const bool copy_sent = probe_written && run_wtype_key_combo("ctrl+c");
    std::this_thread::sleep_for(std::chrono::milliseconds(140));
    QCoreApplication::processEvents();

    const ProcessResult clipboard_read = read_wl_paste(false);
    const QString copied_text = clipboard_read.success ? clipboard_read.std_out : clipboard_->text(QClipboard::Clipboard);
    restore_clipboard(std::move(snapshot));

    const QString clipboard_text = copied_text.trimmed();
    const bool clipboard_success = copy_sent && clipboard_read.success && copied_text != placeholder && !clipboard_text.isEmpty();

    if (clipboard_success) {
        if (primary_success && primary_text != clipboard_text) {
            set_debug_info(QString("capture path=clipboard_copy_preferred primary_mismatch=true primary_length=%1 copied_length=%2")
                               .arg(primary_text.size())
                               .arg(clipboard_text.size()));
        } else {
            set_debug_info(QString("capture path=%1 primary_ok=%2 probe_written=%3 copy_sent=%4 clipboard_read=%5 clipboard_exit=%6 copied_text_length=%7")
                               .arg(primary_success ? "clipboard_copy_confirmed" : "clipboard_copy_fallback")
                               .arg(primary_success ? "true" : "false")
                               .arg(probe_written ? "true" : "false")
                               .arg(copy_sent ? "true" : "false")
                               .arg(clipboard_read.success ? "true" : "false")
                               .arg(clipboard_read.exit_code)
                               .arg(copied_text.size()));
        }
        return SelectionCaptureResult{true, clipboard_text, last_debug_info_};
    }

    if (primary_success && allow_clipboard_fallback) {
        set_debug_info(QString("capture path=primary_selection clipboard_probe_success=false probe_written=%1 copy_sent=%2 clipboard_read=%3 clipboard_exit=%4 text_length=%5")
                           .arg(probe_written ? "true" : "false")
                           .arg(copy_sent ? "true" : "false")
                           .arg(clipboard_read.success ? "true" : "false")
                           .arg(clipboard_read.exit_code)
                           .arg(primary_text.size()));
        return SelectionCaptureResult{true, primary_text, last_debug_info_};
    }

    set_debug_info(QString("capture failed primary_ok=%1 probe_written=%2 copy_sent=%3 clipboard_read=%4 clipboard_exit=%5 fallback=%6")
                       .arg(primary_success ? "true" : "false")
                       .arg(probe_written ? "true" : "false")
                       .arg(copy_sent ? "true" : "false")
                       .arg(clipboard_read.success ? "true" : "false")
                       .arg(clipboard_read.exit_code)
                       .arg(allow_clipboard_fallback ? "true" : "false"));
    return SelectionCaptureResult{false, {}, last_debug_info_};
}

bool WaylandSelectionService::replace_selection(const QString& text, const QString& paste_keys) {
    if (clipboard_ == nullptr) {
        set_debug_info("replace failed: clipboard backend is null");
        return false;
    }
    if (!has_replace_tools()) {
        set_debug_info("replace failed: required Wayland helper tools are unavailable");
        return false;
    }

    auto snapshot = snapshot_clipboard();
    const bool copied = write_wl_copy_text(text);
    if (!copied) {
        clipboard_->setText(text, QClipboard::Clipboard);
    }
    QCoreApplication::processEvents();
    std::this_thread::sleep_for(std::chrono::milliseconds(80));

    const QString effective_paste_keys = paste_keys.trimmed().isEmpty() ? QStringLiteral("ctrl+v") : paste_keys;
    const bool sent = run_wtype_key_combo(effective_paste_keys);
    std::this_thread::sleep_for(std::chrono::milliseconds(120));
    restore_clipboard(std::move(snapshot));

    set_debug_info(QString("replace path=%1 text_length=%2 result=%3 paste_keys=%4")
                       .arg(copied ? "wl-copy+wtype" : "qt-clipboard+wtype")
                       .arg(text.size())
                       .arg(sent ? "true" : "false")
                       .arg(effective_paste_keys));
    return sent;
}

QString WaylandSelectionService::last_debug_info() const {
    return last_debug_info_;
}

bool WaylandSelectionService::has_capture_tools() const {
    return !QStandardPaths::findExecutable("wl-paste").isEmpty();
}

bool WaylandSelectionService::has_replace_tools() const {
    return !QStandardPaths::findExecutable("wl-copy").isEmpty() && !QStandardPaths::findExecutable("wtype").isEmpty();
}

bool WaylandSelectionService::run_wtype_key_combo(const QString& key_combo) const {
    WtypeCommand command;
    return build_wtype_command(key_combo, &command) && run_command(command);
}

WaylandSelectionService::ProcessResult WaylandSelectionService::run_process(const QString& program,
                                                                           const QStringList& arguments,
                                                                           int timeout_ms) const {
    ProcessResult result;
    if (program.isEmpty()) {
        return result;
    }

    QProcess process;
    process.start(program, arguments);
    result.started = process.waitForStarted(1000);
    if (!result.started) {
        result.std_err = process.errorString();
        return result;
    }
    process.closeWriteChannel();
    result.finished = process.waitForFinished(timeout_ms);
    if (!result.finished) {
        process.kill();
        process.waitForFinished(1000);
        result.std_err = "timeout";
        return result;
    }

    result.exit_code = process.exitCode();
    result.std_out = QString::fromUtf8(process.readAllStandardOutput());
    result.std_err = QString::fromUtf8(process.readAllStandardError());
    result.success = process.exitStatus() == QProcess::NormalExit && result.exit_code == 0;
    return result;
}

WaylandSelectionService::ProcessResult WaylandSelectionService::read_wl_paste(bool primary_selection) const {
    const QString program = QStandardPaths::findExecutable("wl-paste");
    QStringList arguments{"--no-newline"};
    if (primary_selection) {
        arguments << "--primary";
    }
    return run_process(program, arguments, 1500);
}

bool WaylandSelectionService::write_wl_copy_text(const QString& text) const {
    const QString program = QStandardPaths::findExecutable("wl-copy");
    if (program.isEmpty()) {
        return false;
    }

    QProcess process;
    process.start(program, {});
    if (!process.waitForStarted(1000)) {
        return false;
    }
    process.write(text.toUtf8());
    process.closeWriteChannel();
    if (!process.waitForFinished(1500)) {
        process.kill();
        process.waitForFinished(1000);
        return false;
    }
    return process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0;
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
