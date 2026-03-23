#pragma once

#include "platform/selection_service.hpp"

class QClipboard;

namespace ohmytypeless {

class QtSelectionService final : public SelectionService {
public:
    explicit QtSelectionService(QClipboard* clipboard);

    QString backend_name() const override;
    SelectionCaptureResult capture_selection() override;
    bool replace_selection(const QString& text) override;
    QString last_debug_info() const override;

private:
    QClipboard* clipboard_ = nullptr;
};

}  // namespace ohmytypeless
