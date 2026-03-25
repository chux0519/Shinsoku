#include "ui/meeting_transcription_window.hpp"

#include <QApplication>
#include <QClipboard>
#include <QFrame>
#include <QHBoxLayout>
#include <QLabel>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QTextCursor>
#include <QVBoxLayout>

namespace ohmytypeless {

namespace {

QString state_text(SessionState state) {
    switch (state) {
    case SessionState::Idle:
        return "Idle";
    case SessionState::Recording:
        return "Recording";
    case SessionState::HandsFree:
        return "Recording";
    case SessionState::Transcribing:
        return "Processing";
    case SessionState::Error:
        return "Error";
    }
    return "Idle";
}

}  // namespace

MeetingTranscriptionWindow::MeetingTranscriptionWindow(QWidget* parent) : QWidget(parent) {
    setWindowTitle("Meeting Transcription");
    resize(920, 760);
    setMinimumSize(760, 620);

    auto* layout = new QVBoxLayout(this);
    layout->setContentsMargins(22, 20, 22, 20);
    layout->setSpacing(16);

    auto* header = new QFrame(this);
    header->setObjectName("historyHeader");
    auto* header_layout = new QVBoxLayout(header);
    header_layout->setContentsMargins(24, 22, 24, 22);
    header_layout->setSpacing(8);

    auto* eyebrow = new QLabel("Meeting Transcript", header);
    eyebrow->setObjectName("historyEyebrow");
    auto* title = new QLabel("Watch live transcription in a dedicated workspace.", header);
    title->setObjectName("historyTitle");
    title->setWordWrap(true);
    auto* body = new QLabel(
        "This window is intended for meeting and system-audio workflows. Live text stays here in a single lightweight transcript view.",
        header);
    body->setObjectName("historyBody");
    body->setWordWrap(true);
    header_layout->addWidget(eyebrow);
    header_layout->addWidget(title);
    header_layout->addWidget(body);
    layout->addWidget(header);

    auto* status_card = new QFrame(this);
    status_card->setObjectName("statusCard");
    auto* status_layout = new QVBoxLayout(status_card);
    status_layout->setContentsMargins(20, 18, 20, 18);
    status_layout->setSpacing(8);
    profile_label_ = new QLabel("Profile: Meeting Transcription", status_card);
    profile_label_->setObjectName("summaryLabel");
    state_label_ = new QLabel("State: Idle", status_card);
    state_label_->setObjectName("statusText");
    status_layout->addWidget(profile_label_);
    status_layout->addWidget(state_label_);
    layout->addWidget(status_card);

    auto* live_card = new QFrame(this);
    live_card->setObjectName("summaryCard");
    auto* live_layout = new QVBoxLayout(live_card);
    live_layout->setContentsMargins(20, 18, 20, 18);
    live_layout->setSpacing(10);
    auto* live_label = new QLabel("Live Transcript", live_card);
    live_label->setObjectName("summaryLabel");
    live_view_ = new QPlainTextEdit(live_card);
    live_view_->setReadOnly(true);
    live_view_->setPlaceholderText("Live streaming partial text will appear here.");
    live_view_->setMinimumHeight(0);
    live_layout->addWidget(live_label);
    live_layout->addWidget(live_view_, 1);
    layout->addWidget(live_card, 1);

    auto* actions = new QWidget(this);
    actions->setObjectName("inlineFieldRow");
    actions->setSizePolicy(QSizePolicy::Preferred, QSizePolicy::Fixed);
    auto* actions_layout = new QHBoxLayout(actions);
    actions_layout->setContentsMargins(0, 4, 0, 0);
    actions_layout->setSpacing(10);
    actions_layout->addStretch();
    auto* copy_button = new QPushButton("Copy", actions);
    auto* clear_button = new QPushButton("Clear", actions);
    auto* close_button = new QPushButton("Close", actions);
    actions_layout->addWidget(copy_button);
    actions_layout->addWidget(clear_button);
    actions_layout->addWidget(close_button);
    layout->addWidget(actions);

    connect(copy_button, &QPushButton::clicked, this, [this]() {
        const QString text = live_view_->toPlainText().trimmed();
        if (!text.isEmpty()) {
            QApplication::clipboard()->setText(text);
        }
    });
    connect(clear_button, &QPushButton::clicked, this, [this]() {
        committed_text_.clear();
        live_preview_text_.clear();
        refresh_view();
    });
    connect(close_button, &QPushButton::clicked, this, &QWidget::hide);
}

void MeetingTranscriptionWindow::set_profile_name(const QString& profile_name) {
    profile_label_->setText(QString("Profile: %1").arg(profile_name));
}

void MeetingTranscriptionWindow::set_session_state(SessionState state) {
    state_label_->setText(QString("State: %1").arg(state_text(state)));
}

void MeetingTranscriptionWindow::set_live_text(const QString& text) {
    live_preview_text_ = text.trimmed();
    refresh_view();
}

void MeetingTranscriptionWindow::append_transcript_segment(const QString& timestamp, const QString& text) {
    Q_UNUSED(timestamp);
    if (text.trimmed().isEmpty()) {
        return;
    }
    if (!committed_text_.isEmpty()) {
        committed_text_.append("\n\n");
    }
    committed_text_.append(text.trimmed());
    live_preview_text_.clear();
    refresh_view();
}

void MeetingTranscriptionWindow::clear_live_text() {
    live_preview_text_.clear();
    refresh_view();
}

void MeetingTranscriptionWindow::refresh_view() {
    QString combined = committed_text_;
    if (!live_preview_text_.isEmpty()) {
        if (!combined.isEmpty()) {
            combined.append("\n\n");
        }
        combined.append(live_preview_text_);
    }
    live_view_->setPlainText(combined);
    QTextCursor cursor = live_view_->textCursor();
    cursor.movePosition(QTextCursor::End);
    live_view_->setTextCursor(cursor);
}

}  // namespace ohmytypeless
