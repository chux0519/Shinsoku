#include "ui/history_details_dialog.hpp"

#include <QDialogButtonBox>
#include <QFrame>
#include <QLabel>
#include <QPlainTextEdit>
#include <QVBoxLayout>

namespace ohmytypeless {

HistoryDetailsDialog::HistoryDetailsDialog(QWidget* parent) : QDialog(parent) {
    setWindowTitle("History Details");
    resize(760, 560);
    setMinimumSize(680, 480);

    auto* layout = new QVBoxLayout(this);
    layout->setContentsMargins(22, 20, 22, 20);
    layout->setSpacing(16);

    auto* summary_card = new QFrame(this);
    summary_card->setObjectName("summaryCard");
    auto* summary_layout = new QVBoxLayout(summary_card);
    summary_layout->setContentsMargins(20, 18, 20, 18);

    summary_label_ = new QLabel(summary_card);
    summary_label_->setObjectName("summaryLabel");
    summary_label_->setWordWrap(true);
    summary_layout->addWidget(summary_label_);
    layout->addWidget(summary_card);

    details_view_ = new QPlainTextEdit(this);
    details_view_->setReadOnly(true);
    layout->addWidget(details_view_);

    auto* buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    layout->addWidget(buttons);
}

void HistoryDetailsDialog::set_entry(const QString& summary, const QString& details) {
    summary_label_->setText(summary);
    details_view_->setPlainText(details);
}

}  // namespace ohmytypeless
