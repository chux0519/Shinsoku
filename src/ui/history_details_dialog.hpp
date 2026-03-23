#pragma once

#include <QDialog>

class QLabel;
class QPlainTextEdit;

namespace ohmytypeless {

class HistoryDetailsDialog final : public QDialog {
    Q_OBJECT
public:
    explicit HistoryDetailsDialog(QWidget* parent = nullptr);

    void set_entry(const QString& summary, const QString& details);

private:
    QLabel* summary_label_ = nullptr;
    QPlainTextEdit* details_view_ = nullptr;
};

}  // namespace ohmytypeless
