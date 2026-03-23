#include "ui/history_window.hpp"

#include <QFrame>
#include <QFont>
#include <QLabel>
#include <QListWidget>
#include <QMenu>
#include <QPushButton>
#include <QVBoxLayout>

namespace ohmytypeless {

namespace {

QString build_summary(const HistoryEntry& entry) {
    if (!entry.meta.is_object()) {
        return {};
    }
    const auto summary_it = entry.meta.find("summary");
    if (summary_it != entry.meta.end() && summary_it->is_string()) {
        return QString::fromStdString(summary_it->get<std::string>());
    }

    const auto diagnostics_it = entry.meta.find("diagnostics");
    if (diagnostics_it == entry.meta.end() || !diagnostics_it->is_object()) {
        return {};
    }

    const auto& diagnostics = *diagnostics_it;
    QString summary;
    if (const auto it = diagnostics.find("asr"); it != diagnostics.end() && it->is_object()) {
        const auto model_it = it->find("model");
        if (model_it != it->end() && model_it->is_string()) {
            summary = QString::fromStdString(model_it->get<std::string>());
        }
    }
    if (const auto it = diagnostics.find("refine"); it != diagnostics.end() && it->is_object()) {
        const auto model_it = it->find("model");
        if (model_it != it->end() && model_it->is_string()) {
            const QString model = QString::fromStdString(model_it->get<std::string>());
            summary = summary.isEmpty() ? model : summary + " -> " + model;
        }
    }
    if (const auto it = diagnostics.find("timing"); it != diagnostics.end() && it->is_object()) {
        const auto total_it = it->find("total");
        if (total_it != it->end() && total_it->is_number_integer()) {
            const QString timing = QString("total=%1ms").arg(total_it->get<long long>());
            summary = summary.isEmpty() ? timing : summary + " • " + timing;
        }
    }
    return summary;
}

QString build_preview(const HistoryEntry& entry) {
    QString preview = entry.text.simplified();
    if (preview.size() > 180) {
        preview = preview.left(177) + "...";
    }
    return preview;
}

QWidget* build_item_widget(const HistoryEntry& entry, QWidget* parent) {
    auto* container = new QFrame(parent);
    container->setObjectName("entryCard");
    auto* layout = new QVBoxLayout(container);
    layout->setContentsMargins(16, 14, 16, 14);
    layout->setSpacing(6);

    auto* header = new QLabel(QString("[%1]").arg(entry.created_at), container);
    header->setObjectName("entryHeader");
    QFont header_font = header->font();
    header_font.setBold(true);
    header->setFont(header_font);
    header->setWordWrap(true);
    layout->addWidget(header);

    const QString summary = build_summary(entry);
    if (!summary.isEmpty()) {
        auto* summary_label = new QLabel(summary, container);
        summary_label->setObjectName("entrySummary");
        summary_label->setWordWrap(true);
        layout->addWidget(summary_label);
    }

    auto* preview = new QLabel(build_preview(entry), container);
    preview->setObjectName("entryPreview");
    preview->setWordWrap(true);
    layout->addWidget(preview);

    return container;
}

}  // namespace

HistoryWindow::HistoryWindow(QWidget* parent) : QWidget(parent) {
    setWindowTitle("History");
    resize(860, 680);
    setMinimumSize(760, 580);

    auto* layout = new QVBoxLayout(this);
    layout->setContentsMargins(22, 20, 22, 20);
    layout->setSpacing(16);

    auto* header = new QFrame(this);
    header->setObjectName("historyHeader");
    auto* header_layout = new QVBoxLayout(header);
    header_layout->setContentsMargins(24, 22, 24, 22);
    header_layout->setSpacing(8);
    auto* eyebrow = new QLabel("Session Archive", header);
    eyebrow->setObjectName("historyEyebrow");
    auto* title = new QLabel("Inspect transcripts, diagnostics, and recordings.", header);
    title->setObjectName("historyTitle");
    title->setWordWrap(true);
    auto* body = new QLabel("Single click copies the text. Double click or use the context menu for structured details and cleanup actions.", header);
    body->setObjectName("historyBody");
    body->setWordWrap(true);
    header_layout->addWidget(eyebrow);
    header_layout->addWidget(title);
    header_layout->addWidget(body);
    layout->addWidget(header);

    list_ = new QListWidget(this);
    list_->setContextMenuPolicy(Qt::CustomContextMenu);
    list_->setSpacing(10);
    layout->addWidget(list_);

    load_older_button_ = new QPushButton("Load Older", this);
    layout->addWidget(load_older_button_);

    connect(load_older_button_, &QPushButton::clicked, this, &HistoryWindow::load_older_requested);
    connect(list_, &QListWidget::itemClicked, this, [this](QListWidgetItem* item) {
        emit copy_entry_requested(item->data(Qt::UserRole).toLongLong());
    });
    connect(list_, &QListWidget::itemDoubleClicked, this, [this](QListWidgetItem* item) {
        emit show_details_requested(item->data(Qt::UserRole).toLongLong());
    });
    connect(list_, &QListWidget::customContextMenuRequested, this, [this](const QPoint& pos) {
        auto* item = list_->itemAt(pos);
        if (item == nullptr) {
            return;
        }

        const qint64 id = item->data(Qt::UserRole).toLongLong();
        const bool has_audio = item->data(Qt::UserRole + 1).toBool();
        QMenu menu(this);
        auto* copy_action = menu.addAction("Copy");
        auto* details_action = menu.addAction("Details");
        auto* delete_action = menu.addAction("Delete");
        QAction* selected = menu.exec(list_->viewport()->mapToGlobal(pos));
        if (selected == copy_action) {
            emit copy_entry_requested(id);
        } else if (selected == details_action) {
            emit show_details_requested(id);
        } else if (selected == delete_action) {
            emit delete_entry_requested(id, has_audio);
        }
    });
}

void HistoryWindow::set_entries(const QList<HistoryEntry>& entries) {
    list_->clear();
    append_entries(entries);
}

void HistoryWindow::append_entries(const QList<HistoryEntry>& entries) {
    for (const auto& entry : entries) {
        append_entry(entry);
    }
}

void HistoryWindow::set_load_older_visible(bool visible) {
    load_older_button_->setVisible(visible);
}

void HistoryWindow::append_entry(const HistoryEntry& entry) {
    auto* item = new QListWidgetItem();
    item->setData(Qt::UserRole, entry.id);
    item->setData(Qt::UserRole + 1, entry.audio_path.has_value());
    item->setToolTip(build_summary(entry));

    QWidget* widget = build_item_widget(entry, list_);
    item->setSizeHint(widget->sizeHint());
    list_->addItem(item);
    list_->setItemWidget(item, widget);
}

}  // namespace ohmytypeless
