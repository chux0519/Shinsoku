#pragma once

#include "core/app_state.hpp"

#include <QWidget>

class QLabel;
class QListWidget;
class QPlainTextEdit;

namespace ohmytypeless {

class MeetingTranscriptionWindow final : public QWidget {
    Q_OBJECT
public:
    explicit MeetingTranscriptionWindow(QWidget* parent = nullptr);

    void set_profile_name(const QString& profile_name);
    void set_session_state(SessionState state);
    void set_live_text(const QString& text);
    void append_transcript_segment(const QString& timestamp, const QString& text);
    void clear_live_text();

private:
    QLabel* profile_label_ = nullptr;
    QLabel* state_label_ = nullptr;
    QPlainTextEdit* live_view_ = nullptr;
    QListWidget* transcript_list_ = nullptr;
};

}  // namespace ohmytypeless
