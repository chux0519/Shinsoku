#pragma once

#include "core/app_state.hpp"

#include <filesystem>
#include <mutex>
#include <optional>
#include <vector>

struct sqlite3;
struct sqlite3_stmt;

namespace ohmytypeless {

class HistoryStore {
public:
    explicit HistoryStore(const std::filesystem::path& db_path);
    ~HistoryStore();

    HistoryStore(const HistoryStore&) = delete;
    HistoryStore& operator=(const HistoryStore&) = delete;

    void add_entry(const std::string& text,
                   const std::optional<std::filesystem::path>& audio_path = std::nullopt,
                   const nlohmann::json& meta = nlohmann::json::object());
    void delete_entry(std::int64_t id);
    std::optional<HistoryEntry> get_entry(std::int64_t id) const;
    std::vector<HistoryEntry> list_recent(std::size_t limit) const;
    std::vector<HistoryEntry> list_before_id(std::int64_t before_id, std::size_t limit) const;

private:
    void ensure_schema();
    bool has_column(const char* table_name, const char* column_name) const;
    std::vector<HistoryEntry> list_with_query(const char* sql, std::int64_t id_arg, bool bind_id, std::size_t limit) const;
    std::optional<HistoryEntry> entry_from_current_row(sqlite3_stmt* stmt) const;

    sqlite3* db_ = nullptr;
    mutable std::mutex mutex_;
};

}  // namespace ohmytypeless
