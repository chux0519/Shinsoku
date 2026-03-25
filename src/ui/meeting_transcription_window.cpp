#include "ui/meeting_transcription_window.hpp"

#include <QFrame>
#include <QLabel>
#include <QListWidget>
#include <QPlainTextEdit>
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
    resize(920, 720);
    setMinimumSize(780, 600);

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
        "This window is intended for meeting and system-audio workflows. Live text stays here while final segments are appended below.",
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
    live_view_->setMinimumHeight(140);
    live_layout->addWidget(live_label);
    live_layout->addWidget(live_view_);
    layout->addWidget(live_card);

    auto* transcript_card = new QFrame(this);
    transcript_card->setObjectName("summaryCard");
    auto* transcript_layout = new QVBoxLayout(transcript_card);
    transcript_layout->setContentsMargins(20, 18, 20, 18);
    transcript_layout->setSpacing(10);
    auto* transcript_label = new QLabel("Transcript Segments", transcript_card);
    transcript_label->setObjectName("summaryLabel");
    transcript_list_ = new QListWidget(transcript_card);
    transcript_layout->addWidget(transcript_label);
    transcript_layout->addWidget(transcript_list_);
    layout->addWidget(transcript_card, 1);
}

void MeetingTranscriptionWindow::set_profile_name(const QString& profile_name) {
    profile_label_->setText(QString("Profile: %1").arg(profile_name));
}

void MeetingTranscriptionWindow::set_session_state(SessionState state) {
    state_label_->setText(QString("State: %1").arg(state_text(state)));
}

void MeetingTranscriptionWindow::set_live_text(const QString& text) {
    live_view_->setPlainText(text);
}

void MeetingTranscriptionWindow::append_transcript_segment(const QString& timestamp, const QString& text) {
    if (text.trimmed().isEmpty()) {
        return;
    }
    transcript_list_->addItem(QString("[%1] %2").arg(timestamp, text));
    transcript_list_->scrollToBottom();
}

void MeetingTranscriptionWindow::clear_live_text() {
    live_view_->clear();
}

}  // namespace ohmytypeless
