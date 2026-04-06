#include "core/history_store.hpp"

#include <sqlite3.h>

#include <stdexcept>

namespace ohmytypeless {

namespace {

nlohmann::json parse_json_or_empty(const char* text) {
    if (text == nullptr) {
        return nlohmann::json::object();
    }

    const auto json = nlohmann::json::parse(text, nullptr, false);
    if (json.is_discarded()) {
        return nlohmann::json::object();
    }
    return json;
}

}  // namespace

HistoryStore::HistoryStore(const std::filesystem::path& db_path) {
    std::filesystem::create_directories(db_path.parent_path());

    if (sqlite3_open(db_path.string().c_str(), &db_) != SQLITE_OK) {
        throw std::runtime_error("failed to open sqlite database");
    }

    ensure_schema();
}

HistoryStore::~HistoryStore() {
    if (db_ != nullptr) {
        sqlite3_close(db_);
        db_ = nullptr;
    }
}

void HistoryStore::add_entry(const std::string& text,
                             const std::optional<std::filesystem::path>& audio_path,
                             const nlohmann::json& meta) {
    std::scoped_lock lock(mutex_);

    sqlite3_stmt* stmt = nullptr;
    const char* sql = "INSERT INTO history(text, meta, audio_path) VALUES (?1, json(?2), ?3)";
    if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK) {
        throw std::runtime_error("failed to prepare history insert");
    }

    const std::string meta_string = meta.dump();
    sqlite3_bind_text(stmt, 1, text.c_str(), static_cast<int>(text.size()), SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, meta_string.c_str(), static_cast<int>(meta_string.size()), SQLITE_TRANSIENT);
    if (audio_path.has_value()) {
        const std::string path_text = audio_path->lexically_normal().generic_string();
        sqlite3_bind_text(stmt, 3, path_text.c_str(), static_cast<int>(path_text.size()), SQLITE_TRANSIENT);
    } else {
        sqlite3_bind_null(stmt, 3);
    }

    if (sqlite3_step(stmt) != SQLITE_DONE) {
        sqlite3_finalize(stmt);
        throw std::runtime_error("failed to insert history entry");
    }

    sqlite3_finalize(stmt);
}

void HistoryStore::delete_entry(std::int64_t id) {
    std::scoped_lock lock(mutex_);

    sqlite3_stmt* stmt = nullptr;
    const char* sql = "DELETE FROM history WHERE id = ?1";
    if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK) {
        throw std::runtime_error("failed to prepare history delete");
    }

    sqlite3_bind_int64(stmt, 1, static_cast<sqlite3_int64>(id));
    if (sqlite3_step(stmt) != SQLITE_DONE) {
        sqlite3_finalize(stmt);
        throw std::runtime_error("failed to delete history entry");
    }

    sqlite3_finalize(stmt);
}

std::optional<HistoryEntry> HistoryStore::get_entry(std::int64_t id) const {
    std::scoped_lock lock(mutex_);

    sqlite3_stmt* stmt = nullptr;
    const char* sql = "SELECT id, created_at, text, meta, audio_path FROM history WHERE id = ?1";
    if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK) {
        throw std::runtime_error("failed to prepare history lookup");
    }

    sqlite3_bind_int64(stmt, 1, static_cast<sqlite3_int64>(id));
    std::optional<HistoryEntry> entry;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        entry = entry_from_current_row(stmt);
    }

    sqlite3_finalize(stmt);
    return entry;
}

std::vector<HistoryEntry> HistoryStore::list_recent(std::size_t limit) const {
    return list_with_query("SELECT id, created_at, text, meta, audio_path FROM history ORDER BY id DESC LIMIT ?1", 0, false,
                           limit);
}

std::vector<HistoryEntry> HistoryStore::list_before_id(std::int64_t before_id, std::size_t limit) const {
    return list_with_query(
        "SELECT id, created_at, text, meta, audio_path FROM history WHERE id < ?1 ORDER BY id DESC LIMIT ?2",
        before_id,
        true,
        limit);
}

void HistoryStore::ensure_schema() {
    const char* create_sql = R"(
        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            text TEXT NOT NULL,
            meta TEXT NOT NULL DEFAULT '{}',
            audio_path TEXT
        );
    )";

    char* error_message = nullptr;
    if (sqlite3_exec(db_, create_sql, nullptr, nullptr, &error_message) != SQLITE_OK) {
        const std::string message = error_message == nullptr ? "failed to initialize history schema" : error_message;
        sqlite3_free(error_message);
        throw std::runtime_error(message);
    }

    if (!has_column("history", "meta")) {
        if (sqlite3_exec(db_, "ALTER TABLE history ADD COLUMN meta TEXT NOT NULL DEFAULT '{}'", nullptr, nullptr, &error_message) !=
            SQLITE_OK) {
            const std::string message = error_message == nullptr ? "failed to add history meta column" : error_message;
            sqlite3_free(error_message);
            throw std::runtime_error(message);
        }
    }

    if (has_column("history", "summary")) {
        sqlite3_exec(
            db_,
            "UPDATE history SET meta = json_object('summary', summary) "
            "WHERE (meta IS NULL OR trim(meta) = '' OR trim(meta) = '{}') AND summary IS NOT NULL AND trim(summary) <> ''",
            nullptr,
            nullptr,
            nullptr);
    }
}

bool HistoryStore::has_column(const char* table_name, const char* column_name) const {
    sqlite3_stmt* stmt = nullptr;
    const std::string sql = "PRAGMA table_info(" + std::string(table_name) + ")";
    if (sqlite3_prepare_v2(db_, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) {
        throw std::runtime_error("failed to inspect history schema");
    }

    bool found = false;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        const char* current = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
        if (current != nullptr && std::string_view(current) == column_name) {
            found = true;
            break;
        }
    }

    sqlite3_finalize(stmt);
    return found;
}

std::vector<HistoryEntry> HistoryStore::list_with_query(const char* sql, std::int64_t id_arg, bool bind_id, std::size_t limit) const {
    std::scoped_lock lock(mutex_);

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK) {
        throw std::runtime_error("failed to prepare history query");
    }

    int bind_index = 1;
    if (bind_id) {
        sqlite3_bind_int64(stmt, bind_index++, static_cast<sqlite3_int64>(id_arg));
    }
    sqlite3_bind_int64(stmt, bind_index, static_cast<sqlite3_int64>(limit));

    std::vector<HistoryEntry> entries;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        if (auto entry = entry_from_current_row(stmt); entry.has_value()) {
            entries.push_back(std::move(*entry));
        }
    }

    sqlite3_finalize(stmt);
    return entries;
}

std::optional<HistoryEntry> HistoryStore::entry_from_current_row(sqlite3_stmt* stmt) const {
    HistoryEntry entry;
    entry.id = static_cast<std::int64_t>(sqlite3_column_int64(stmt, 0));
    entry.created_at = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
    entry.text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
    entry.meta = parse_json_or_empty(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3)));
    if (sqlite3_column_type(stmt, 4) != SQLITE_NULL) {
        entry.audio_path = std::filesystem::path(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4)));
    }
    return entry;
}

}  // namespace ohmytypeless
