#pragma once

#include "core/app_state.hpp"

#include <QList>
#include <QWidget>

class QListWidget;
class QListWidgetItem;
class QPushButton;

namespace ohmytypeless {

class HistoryWindow final : public QWidget {
    Q_OBJECT
public:
    explicit HistoryWindow(QWidget* parent = nullptr);

    void set_entries(const QList<HistoryEntry>& entries);
    void append_entries(const QList<HistoryEntry>& entries);
    void set_load_older_visible(bool visible);

signals:
    void copy_entry_requested(qint64 id);
    void show_details_requested(qint64 id);
    void delete_entry_requested(qint64 id, bool delete_audio);
    void load_older_requested();

private:
    void append_entry(const HistoryEntry& entry);

    QListWidget* list_ = nullptr;
    QPushButton* load_older_button_ = nullptr;
};

}  // namespace ohmytypeless
