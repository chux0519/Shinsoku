#pragma once

#include <QtGlobal>

#include <nlohmann/json.hpp>

#include <optional>
#include <QString>

namespace ohmytypeless {

enum class SessionState {
    Idle,
    Recording,
    HandsFree,
    Transcribing,
    Error
};

struct HistoryEntry {
    qint64 id = 0;
    QString created_at;
    QString text;
    nlohmann::json meta;
    std::optional<QString> audio_path;
};

}  // namespace ohmytypeless
