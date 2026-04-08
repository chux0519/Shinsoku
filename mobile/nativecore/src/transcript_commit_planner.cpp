#include "shinsoku/nativecore/transcript_commit_planner.hpp"

namespace shinsoku::nativecore {

std::string plan_transcript_commit(const std::string& text, CommitSuffixMode suffix_mode) {
    switch (suffix_mode) {
        case CommitSuffixMode::None:
            return text;
        case CommitSuffixMode::Space:
            return text + " ";
        case CommitSuffixMode::Newline:
            return text + "\n";
    }
    return text;
}

}  // namespace shinsoku::nativecore
