#include "core/app_config.hpp"
#include "core/history_export.hpp"
#include "core/history_store.hpp"

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCoreApplication>
#include <QDate>

#include <nlohmann/json.hpp>

#include <filesystem>
#include <iostream>
#include <stdexcept>

namespace {

long long parse_positive_integer(const QString& value, const char* label) {
    bool ok = false;
    const qlonglong parsed = value.toLongLong(&ok);
    if (!ok || parsed <= 0) {
        throw std::invalid_argument(std::string(label) + " must be a positive integer");
    }
    return parsed;
}

}  // namespace

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);
    app.setApplicationName("Shinsoku");
    app.setOrganizationName("Shinsoku");
    app.setApplicationVersion("0.1.0");

    QCommandLineParser parser;
    parser.setApplicationDescription("Read Shinsoku transcript history as JSON without modifying it.");
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument("command", "Command to run: list or get.");
    parser.addPositionalArgument("id", "History entry ID for the get command.", "[id]");

    const QCommandLineOption database_option({"d", "database"}, "History database path.", "path");
    const QCommandLineOption limit_option({"l", "limit"}, "Maximum entries to return (1-500).", "count", "50");
    const QCommandLineOption before_option("before-id", "Only return entries older than this ID.", "id");
    const QCommandLineOption since_option("since", "Only return entries on or after YYYY-MM-DD.", "date");
    const QCommandLineOption app_option("app", "Filter by source application ID or name.", "text");
    const QCommandLineOption query_option({"q", "query"}, "Filter transcript text.", "text");
    const QCommandLineOption pretty_option("pretty", "Pretty-print JSON output.");
    const QCommandLineOption include_meta_option("include-meta", "Include diagnostic and provider metadata.");
    const QCommandLineOption include_audio_option("include-audio-path", "Include local recording paths.");
    parser.addOptions({database_option,
                       limit_option,
                       before_option,
                       since_option,
                       app_option,
                       query_option,
                       pretty_option,
                       include_meta_option,
                       include_audio_option});
    parser.process(app);

    try {
        const QStringList positional = parser.positionalArguments();
        if (positional.isEmpty()) {
            throw std::invalid_argument("missing command; use list or get");
        }

        std::filesystem::path database_path;
        if (parser.isSet(database_option)) {
            database_path = std::filesystem::path(parser.value(database_option).toStdString());
        } else {
            database_path = ohmytypeless::load_config().history_db_path;
        }
        ohmytypeless::HistoryStore store(database_path, ohmytypeless::HistoryOpenMode::ReadOnly);

        const bool include_meta = parser.isSet(include_meta_option);
        const bool include_audio = parser.isSet(include_audio_option);
        const ohmytypeless::HistoryExportOptions export_options{
            .include_meta = include_meta,
            .include_audio_path = include_audio,
        };
        nlohmann::json output;
        const QString command = positional.front().trimmed().toLower();
        if (command == "get") {
            if (positional.size() != 2) {
                throw std::invalid_argument("get requires exactly one history entry ID");
            }
            const auto id = parse_positive_integer(positional[1], "id");
            const auto entry = store.get_entry(id);
            if (!entry.has_value()) {
                throw std::runtime_error("history entry not found");
            }
            output = {
                {"schema_version", 1},
                {"entry", ohmytypeless::public_history_entry_json(*entry, export_options)},
            };
        } else if (command == "list") {
            if (positional.size() != 1) {
                throw std::invalid_argument("list does not accept positional arguments");
            }
            ohmytypeless::HistoryQuery query;
            query.limit = static_cast<std::size_t>(parse_positive_integer(parser.value(limit_option), "limit"));
            if (query.limit > 500) {
                throw std::invalid_argument("limit must not exceed 500");
            }
            if (parser.isSet(before_option)) {
                query.before_id = parse_positive_integer(parser.value(before_option), "before-id");
            }
            if (parser.isSet(since_option)) {
                const QString since = parser.value(since_option).trimmed();
                if (!QDate::fromString(since, Qt::ISODate).isValid()) {
                    throw std::invalid_argument("since must use YYYY-MM-DD");
                }
                query.since_date = since.toStdString();
            }
            if (parser.isSet(app_option) && !parser.value(app_option).trimmed().isEmpty()) {
                query.source_app = parser.value(app_option).trimmed().toStdString();
            }
            if (parser.isSet(query_option) && !parser.value(query_option).trimmed().isEmpty()) {
                query.text_query = parser.value(query_option).trimmed().toStdString();
            }

            const auto entries = store.query(query);
            nlohmann::json entry_list = nlohmann::json::array();
            for (const auto& entry : entries) {
                entry_list.push_back(ohmytypeless::public_history_entry_json(entry, export_options));
            }
            output = {
                {"schema_version", 1},
                {"entries", std::move(entry_list)},
                {"next_before_id", entries.size() == query.limit && !entries.empty() ? nlohmann::json(entries.back().id)
                                                                                     : nlohmann::json(nullptr)},
            };
        } else {
            throw std::invalid_argument("unknown command; use list or get");
        }

        std::cout << output.dump(parser.isSet(pretty_option) ? 2 : -1) << '\n';
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << "shinsoku-history: " << exception.what() << '\n';
        return 2;
    }
}
