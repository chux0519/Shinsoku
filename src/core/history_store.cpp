#include "core/history_store.hpp"

#include <sqlite3.h>

#include <algorithm>
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

std::string contains_pattern(const std::string& value) {
    std::string pattern = "%";
    pattern.reserve(value.size() + 2);
    for (const char character : value) {
        if (character == '%' || character == '_' || character == '\\') {
            pattern.push_back('\\');
        }
        pattern.push_back(character);
    }
    pattern.push_back('%');
    return pattern;
}

}  // namespace

HistoryStore::HistoryStore(const std::filesystem::path& db_path, HistoryOpenMode mode) : mode_(mode) {
    if (mode_ == HistoryOpenMode::ReadWrite && !db_path.parent_path().empty()) {
        std::filesystem::create_directories(db_path.parent_path());
    }

    const int flags = mode_ == HistoryOpenMode::ReadOnly
                          ? SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
                          : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX;
    if (sqlite3_open_v2(db_path.string().c_str(), &db_, flags, nullptr) != SQLITE_OK) {
        const std::string detail = db_ == nullptr ? std::string{} : sqlite3_errmsg(db_);
        if (db_ != nullptr) {
            sqlite3_close(db_);
            db_ = nullptr;
        }
        throw std::runtime_error(detail.empty() ? "failed to open sqlite database"
                                                : "failed to open sqlite database: " + detail);
    }

    if (mode_ == HistoryOpenMode::ReadWrite) {
        try {
            ensure_schema();
        } catch (...) {
            sqlite3_close(db_);
            db_ = nullptr;
            throw;
        }
    }
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
    if (mode_ == HistoryOpenMode::ReadOnly) {
        throw std::logic_error("history database is open read-only");
    }
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
    if (mode_ == HistoryOpenMode::ReadOnly) {
        throw std::logic_error("history database is open read-only");
    }
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
    HistoryQuery query_options;
    query_options.limit = limit;
    return query(query_options);
}

std::vector<HistoryEntry> HistoryStore::list_before_id(std::int64_t before_id, std::size_t limit) const {
    HistoryQuery query_options;
    query_options.limit = limit;
    query_options.before_id = before_id;
    return query(query_options);
}

std::vector<HistoryEntry> HistoryStore::query(const HistoryQuery& query_options) const {
    if (query_options.limit == 0) {
        return {};
    }
    std::scoped_lock lock(mutex_);

    std::string sql = "SELECT id, created_at, text, meta, audio_path FROM history";
    std::vector<std::string> conditions;
    if (query_options.before_id.has_value()) {
        conditions.emplace_back("id < ?");
    }
    if (query_options.since_date.has_value()) {
        conditions.emplace_back("created_at >= datetime(?, 'utc')");
    }
    if (query_options.source_app.has_value()) {
        conditions.emplace_back(
            "(lower(coalesce(json_extract(meta, '$.source.app_id'), '')) LIKE lower(?) ESCAPE '\\' "
            "OR lower(coalesce(json_extract(meta, '$.source.app_name'), '')) LIKE lower(?) ESCAPE '\\')");
    }
    if (query_options.text_query.has_value()) {
        conditions.emplace_back("lower(text) LIKE lower(?) ESCAPE '\\'");
    }
    if (!conditions.empty()) {
        sql += " WHERE ";
        for (std::size_t index = 0; index < conditions.size(); ++index) {
            if (index > 0) {
                sql += " AND ";
            }
            sql += conditions[index];
        }
    }
    sql += " ORDER BY id DESC LIMIT ?";

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) {
        throw std::runtime_error("failed to prepare history query");
    }

    int bind_index = 1;
    if (query_options.before_id.has_value()) {
        sqlite3_bind_int64(stmt, bind_index++, static_cast<sqlite3_int64>(*query_options.before_id));
    }
    if (query_options.since_date.has_value()) {
        const std::string since = *query_options.since_date + " 00:00:00";
        sqlite3_bind_text(stmt, bind_index++, since.c_str(), static_cast<int>(since.size()), SQLITE_TRANSIENT);
    }
    if (query_options.source_app.has_value()) {
        const std::string pattern = contains_pattern(*query_options.source_app);
        sqlite3_bind_text(stmt, bind_index++, pattern.c_str(), static_cast<int>(pattern.size()), SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, bind_index++, pattern.c_str(), static_cast<int>(pattern.size()), SQLITE_TRANSIENT);
    }
    if (query_options.text_query.has_value()) {
        const std::string pattern = contains_pattern(*query_options.text_query);
        sqlite3_bind_text(stmt, bind_index++, pattern.c_str(), static_cast<int>(pattern.size()), SQLITE_TRANSIENT);
    }
    const std::size_t bounded_limit = std::min<std::size_t>(query_options.limit, 500);
    sqlite3_bind_int64(stmt, bind_index, static_cast<sqlite3_int64>(bounded_limit));

    std::vector<HistoryEntry> entries;
    int step_result = SQLITE_ROW;
    while ((step_result = sqlite3_step(stmt)) == SQLITE_ROW) {
        if (auto entry = entry_from_current_row(stmt); entry.has_value()) {
            entries.push_back(std::move(*entry));
        }
    }
    if (step_result != SQLITE_DONE) {
        sqlite3_finalize(stmt);
        throw std::runtime_error("failed to read history query results");
    }

    sqlite3_finalize(stmt);
    return entries;
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

    if (sqlite3_exec(db_, "CREATE INDEX IF NOT EXISTS history_created_at_idx ON history(created_at)", nullptr, nullptr,
                     &error_message) != SQLITE_OK) {
        const std::string message = error_message == nullptr ? "failed to index history timestamps" : error_message;
        sqlite3_free(error_message);
        throw std::runtime_error(message);
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

std::optional<HistoryEntry> HistoryStore::entry_from_current_row(sqlite3_stmt* stmt) const {
    HistoryEntry entry;
    entry.id = static_cast<std::int64_t>(sqlite3_column_int64(stmt, 0));
    if (const auto* created_at = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1)); created_at != nullptr) {
        entry.created_at = created_at;
    }
    if (const auto* text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2)); text != nullptr) {
        entry.text = text;
    }
    entry.meta = parse_json_or_empty(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3)));
    if (sqlite3_column_type(stmt, 4) != SQLITE_NULL) {
        entry.audio_path = std::filesystem::path(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4)));
    }
    return entry;
}

}  // namespace ohmytypeless
