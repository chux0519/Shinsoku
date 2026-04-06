#pragma once

#include <nlohmann/json.hpp>

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>

namespace ohmytypeless {

enum class SessionState {
    Idle,
    Recording,
    HandsFree,
    Transcribing,
    Error
};

struct HistoryEntry {
    std::int64_t id = 0;
    std::string created_at;
    std::string text;
    nlohmann::json meta;
    std::optional<std::filesystem::path> audio_path;
};

}  // namespace ohmytypeless
