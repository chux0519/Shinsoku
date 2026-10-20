#include "core/history_store.hpp"
#include "platform/input_target_context.hpp"

#include <chrono>
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

std::filesystem::path unique_test_directory() {
    const auto suffix = std::chrono::steady_clock::now().time_since_epoch().count();
    return std::filesystem::temp_directory_path() / ("shinsoku-history-test-" + std::to_string(suffix));
}

}  // namespace

int main() {
    const std::filesystem::path directory = unique_test_directory();
    const std::filesystem::path database = directory / "history.sqlite3";

    try {
        const auto password_context = ohmytypeless::classify_input_target(
            "com.example.browser", "Browser", "AXTextField", true, true, {});
        require(password_context.privacy == ohmytypeless::InputTargetPrivacy::Sensitive,
                "secure fields must be classified as sensitive");

        const auto token_context = ohmytypeless::classify_input_target(
            "com.example.editor", "Editor", "AXTextField", true, false, {"API key"});
        require(token_context.privacy == ohmytypeless::InputTargetPrivacy::Sensitive &&
                    token_context.privacy_reason == "credential_field",
                "credential hints must be classified as sensitive");

        const auto search_context = ohmytypeless::classify_input_target(
            "com.example.browser", "Browser", "AXSearchField", true, false, {});
        require(search_context.privacy == ohmytypeless::InputTargetPrivacy::Sensitive &&
                    search_context.privacy_reason == "search_or_address_field",
                "search fields must be excluded from history");

        const auto normal_context = ohmytypeless::classify_input_target(
            "com.example.editor", "Editor", "AXTextArea", true, false, {"Document body"});
        require(normal_context.privacy == ohmytypeless::InputTargetPrivacy::Normal,
                "inspected non-sensitive fields should be classified as normal");

        const auto unknown_context = ohmytypeless::classify_input_target(
            "org.example.app", "Example", {}, false, false, {});
        require(unknown_context.privacy == ohmytypeless::InputTargetPrivacy::Unknown,
                "missing field inspection must remain explicit");

        {
            ohmytypeless::HistoryStore store(database);
            store.add_entry("Draft an email",
                            std::nullopt,
                            {{"source", {{"app_id", "com.apple.mail"}, {"app_name", "Mail"}}},
                             {"profile", {{"id", "dictation"}}}});
            store.add_entry("Translate this message",
                            std::nullopt,
                            {{"source", {{"app_id", "com.tinyspeck.slackmacgap"}, {"app_name", "Slack"}}},
                             {"profile", {{"id", "translate"}}}});
            store.add_entry("Legacy entry", std::nullopt, nlohmann::json::object());

            require(store.list_recent(2).size() == 2, "list_recent should apply its limit");
            require(store.list_before_id(3, 10).size() == 2, "list_before_id should page by ID");
        }

        {
            ohmytypeless::HistoryStore reader(database, ohmytypeless::HistoryOpenMode::ReadOnly);

            ohmytypeless::HistoryQuery app_query;
            app_query.source_app = "MAIL";
            const auto mail_entries = reader.query(app_query);
            require(mail_entries.size() == 1, "source application filtering should be case-insensitive");
            require(mail_entries.front().text == "Draft an email", "source application filtering returned the wrong row");

            ohmytypeless::HistoryQuery text_query;
            text_query.text_query = "translate";
            const auto translated_entries = reader.query(text_query);
            require(translated_entries.size() == 1, "text filtering should find matching transcripts");

            ohmytypeless::HistoryQuery wildcard_query;
            wildcard_query.text_query = "%";
            require(reader.query(wildcard_query).empty(), "text filtering should treat SQL wildcard characters literally");

            ohmytypeless::HistoryQuery future_query;
            future_query.since_date = "9999-01-01";
            require(reader.query(future_query).empty(), "since filtering should exclude older rows");

            bool write_rejected = false;
            try {
                reader.add_entry("must fail");
            } catch (const std::logic_error&) {
                write_rejected = true;
            }
            require(write_rejected, "read-only history handles must reject writes");
        }

        const std::filesystem::path missing_database = directory / "missing.sqlite3";
        bool missing_rejected = false;
        try {
            ohmytypeless::HistoryStore missing(missing_database, ohmytypeless::HistoryOpenMode::ReadOnly);
        } catch (const std::runtime_error&) {
            missing_rejected = true;
        }
        require(missing_rejected, "read-only mode should reject a missing database");
        require(!std::filesystem::exists(missing_database), "read-only mode must not create a database");

        std::filesystem::remove_all(directory);
        std::cout << "history_store_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::filesystem::remove_all(directory);
        std::cerr << "history_store_tests: " << exception.what() << '\n';
        return 1;
    }
}
