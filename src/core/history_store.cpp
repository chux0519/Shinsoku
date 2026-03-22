#include "core/history_store.hpp"

#include <sqlite3.h>

#include <QByteArray>

#include <stdexcept>

namespace ohmytypeless {

HistoryStore::HistoryStore(const std::filesystem::path& db_path) {
    std::filesystem::create_directories(db_path.parent_path());

    if (sqlite3_open(db_path.string().c_str(), &db_) != SQLITE_OK) {
        throw std::runtime_error("failed to open sqlite database");
    }

    const char* sql = R"(
        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            text TEXT NOT NULL,
            summary TEXT NOT NULL DEFAULT '',
            audio_path TEXT
        );
    )";

    char* error_message = nullptr;
    if (sqlite3_exec(db_, sql, nullptr, nullptr, &error_message) != SQLITE_OK) {
        const std::string message = error_message == nullptr ? "failed to initialize history schema" : error_message;
        sqlite3_free(error_message);
        throw std::runtime_error(message);
    }
}

HistoryStore::~HistoryStore() {
    if (db_ != nullptr) {
        sqlite3_close(db_);
        db_ = nullptr;
    }
}

void HistoryStore::add_entry(const QString& text,
                             const QString& summary,
                             const std::optional<std::filesystem::path>& audio_path) {
    sqlite3_stmt* stmt = nullptr;
    const char* sql = "INSERT INTO history(text, summary, audio_path) VALUES (?1, ?2, ?3)";
    if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK) {
        throw std::runtime_error("failed to prepare history insert");
    }

    const QByteArray text_utf8 = text.toUtf8();
    const QByteArray summary_utf8 = summary.toUtf8();
    sqlite3_bind_text(stmt, 1, text_utf8.constData(), text_utf8.size(), SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, summary_utf8.constData(), summary_utf8.size(), SQLITE_TRANSIENT);
    if (audio_path.has_value()) {
        const std::string path_text = audio_path->string();
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

QList<HistoryEntry> HistoryStore::list_recent(std::size_t limit) const {
    sqlite3_stmt* stmt = nullptr;
    const char* sql = "SELECT id, created_at, text, summary, audio_path FROM history ORDER BY id DESC LIMIT ?1";
    if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK) {
        throw std::runtime_error("failed to prepare history query");
    }

    sqlite3_bind_int64(stmt, 1, static_cast<sqlite3_int64>(limit));

    QList<HistoryEntry> entries;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        if (auto entry = entry_from_current_row(stmt); entry.has_value()) {
            entries.push_back(*entry);
        }
    }

    sqlite3_finalize(stmt);
    return entries;
}

std::optional<HistoryEntry> HistoryStore::entry_from_current_row(sqlite3_stmt* stmt) const {
    HistoryEntry entry;
    entry.id = static_cast<qint64>(sqlite3_column_int64(stmt, 0));
    entry.created_at = QString::fromUtf8(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1)));
    entry.text = QString::fromUtf8(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2)));
    entry.summary = QString::fromUtf8(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3)));
    if (sqlite3_column_type(stmt, 4) != SQLITE_NULL) {
        entry.audio_path = QString::fromUtf8(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4)));
    }
    return entry;
}

}  // namespace ohmytypeless
