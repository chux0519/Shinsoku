#pragma once

#include <string>

namespace ohmytypeless {

enum class CaptureMode {
    Dictation,
    SelectionCommand,
};

struct TextTask {
    CaptureMode mode = CaptureMode::Dictation;
    std::string selected_text;
    std::string spoken_instruction;
    std::string result_text;
};

}  // namespace ohmytypeless
