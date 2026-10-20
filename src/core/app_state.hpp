#pragma once

#include <nlohmann/json.hpp>

#include <cstddef>
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

struct HistoryQuery {
    std::size_t limit = 50;
    std::optional<std::int64_t> before_id;
    std::optional<std::string> since_date;
    std::optional<std::string> source_app;
    std::optional<std::string> text_query;
};

}  // namespace ohmytypeless
