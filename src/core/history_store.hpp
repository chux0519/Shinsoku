#pragma once

#include "core/app_state.hpp"

#include <QList>

#include <filesystem>
#include <optional>

struct sqlite3;
struct sqlite3_stmt;

namespace ohmytypeless {

class HistoryStore {
public:
    explicit HistoryStore(const std::filesystem::path& db_path);
    ~HistoryStore();

    HistoryStore(const HistoryStore&) = delete;
    HistoryStore& operator=(const HistoryStore&) = delete;

    void add_entry(const QString& text,
                   const QString& summary,
                   const std::optional<std::filesystem::path>& audio_path = std::nullopt);
    QList<HistoryEntry> list_recent(std::size_t limit) const;

private:
    std::optional<HistoryEntry> entry_from_current_row(sqlite3_stmt* stmt) const;

    sqlite3* db_ = nullptr;
};

}  // namespace ohmytypeless
