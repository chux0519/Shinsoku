#pragma once

#include <QString>

namespace ohmytypeless {

enum class CaptureMode {
    Dictation,
    SelectionCommand,
};

struct TextTask {
    CaptureMode mode = CaptureMode::Dictation;
    QString selected_text;
    QString spoken_instruction;
    QString result_text;
};

}  // namespace ohmytypeless
