#pragma once

#include <string>

namespace shinsoku::nativecore {

enum class CommitSuffixMode {
    None,
    Space,
    Newline,
};

std::string plan_transcript_commit(const std::string& text, CommitSuffixMode suffix_mode);

}  // namespace shinsoku::nativecore
