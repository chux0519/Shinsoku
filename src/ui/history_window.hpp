#pragma once

#include "core/app_state.hpp"

#include <QWidget>

class QListWidget;

namespace ohmytypeless {

class HistoryWindow final : public QWidget {
    Q_OBJECT
public:
    explicit HistoryWindow(QWidget* parent = nullptr);

    void set_entries(const QList<HistoryEntry>& entries);

private:
    QListWidget* list_ = nullptr;
};

}  // namespace ohmytypeless
