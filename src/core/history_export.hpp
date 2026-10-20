#pragma once

#include "core/app_state.hpp"

#include <nlohmann/json.hpp>

namespace ohmytypeless {

struct HistoryExportOptions {
    bool include_meta = false;
    bool include_audio_path = false;
};

nlohmann::json public_history_entry_json(const HistoryEntry& entry,
                                         const HistoryExportOptions& options = {});

}  // namespace ohmytypeless
