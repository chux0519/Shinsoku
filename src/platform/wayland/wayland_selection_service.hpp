#pragma once

#include "platform/selection_service.hpp"

#include <memory>

class QClipboard;
class QMimeData;

namespace ohmytypeless {

class WaylandSelectionService final : public SelectionService {
public:
    explicit WaylandSelectionService(QClipboard* clipboard);

    QString backend_name() const override;
    bool supports_automatic_detection() const override;
    bool supports_replacement() const override;
    SelectionCaptureResult capture_selection(bool allow_clipboard_fallback = true) override;
    bool replace_selection(const QString& text, const QString& paste_keys) override;
    QString last_debug_info() const override;

private:
    struct ProcessResult {
        bool started = false;
        bool finished = false;
        bool success = false;
        int exit_code = -1;
        QString std_out;
        QString std_err;
    };

    bool has_capture_tools() const;
    bool has_replace_tools() const;
    bool run_wtype_key_combo(const QString& key_combo) const;
    ProcessResult run_process(const QString& program, const QStringList& arguments, int timeout_ms) const;
    ProcessResult read_wl_paste(bool primary_selection) const;
    bool write_wl_copy_text(const QString& text) const;
    std::unique_ptr<QMimeData> snapshot_clipboard() const;
    void restore_clipboard(std::unique_ptr<QMimeData> snapshot) const;
    void set_debug_info(const QString& text) const;

    QClipboard* clipboard_ = nullptr;
    mutable QString last_debug_info_;
};

}  // namespace ohmytypeless
