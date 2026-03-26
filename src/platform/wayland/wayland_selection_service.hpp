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
    bool replace_selection(const QString& text) override;
    QString last_debug_info() const override;

private:
    bool has_required_tools() const;
    bool run_wtype_key_combo(const QString& key_combo) const;
    std::unique_ptr<QMimeData> snapshot_clipboard() const;
    void restore_clipboard(std::unique_ptr<QMimeData> snapshot) const;
    void set_debug_info(const QString& text) const;

    QClipboard* clipboard_ = nullptr;
    mutable QString last_debug_info_;
};

}  // namespace ohmytypeless
