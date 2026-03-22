#include "ui/history_window.hpp"

#include <QListWidget>
#include <QVBoxLayout>

namespace ohmytypeless {

HistoryWindow::HistoryWindow(QWidget* parent) : QWidget(parent) {
    setWindowTitle("History");
    resize(640, 420);

    auto* layout = new QVBoxLayout(this);
    list_ = new QListWidget(this);
    layout->addWidget(list_);
}

void HistoryWindow::set_entries(const QList<HistoryEntry>& entries) {
    list_->clear();
    for (const HistoryEntry& entry : entries) {
        auto* item = new QListWidgetItem(QString("[%1] %2").arg(entry.created_at, entry.text), list_);
        if (!entry.summary.isEmpty()) {
            item->setToolTip(entry.summary);
        }
        if (entry.audio_path.has_value()) {
            item->setStatusTip(*entry.audio_path);
        }
    }
}

}  // namespace ohmytypeless
