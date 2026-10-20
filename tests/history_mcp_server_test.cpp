#include "core/history_mcp_server.hpp"
#include "core/history_store.hpp"

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
    return std::filesystem::temp_directory_path() / ("shinsoku-history-mcp-test-" + std::to_string(suffix));
}

nlohmann::json request(int id, const std::string& method, nlohmann::json params = nlohmann::json::object()) {
    return {
        {"jsonrpc", "2.0"},
        {"id", id},
        {"method", method},
        {"params", std::move(params)},
    };
}

const nlohmann::json& required_result(const std::optional<nlohmann::json>& response) {
    require(response.has_value(), "request did not produce a response");
    require(response->contains("result"), "request returned a JSON-RPC error");
    return response->at("result");
}

}  // namespace

int main() {
    const std::filesystem::path directory = unique_test_directory();
    const std::filesystem::path database = directory / "history.sqlite3";

    try {
        std::filesystem::create_directories(directory);
        {
            ohmytypeless::HistoryStore store(database);
            store.add_entry("Prepare the project update",
                            directory / "private-recording.wav",
                            {{"source", {{"app_id", "com.apple.mail"}, {"app_name", "Mail"}}},
                             {"profile", {{"id", "dictation"}, {"name", "Dictation"}}},
                             {"diagnostics", {{"secret", "must-not-leak"}}}});
        }

        ohmytypeless::HistoryMcpServer legacy_server(database);
        const auto initialize = required_result(legacy_server.handle_message(
            request(1,
                    "initialize",
                    {{"protocolVersion", "2025-11-25"},
                     {"capabilities", nlohmann::json::object()},
                     {"clientInfo", {{"name", "test"}, {"version", "1"}}}})));
        require(initialize.at("protocolVersion") == "2025-11-25", "legacy initialize must negotiate the requested revision");
        require(initialize.at("capabilities").contains("tools"), "legacy initialize must advertise tools");

        const auto notification = legacy_server.handle_message(
            {{"jsonrpc", "2.0"}, {"method", "notifications/initialized"}, {"params", nlohmann::json::object()}});
        require(!notification.has_value(), "notifications must not produce JSON-RPC responses");

        const auto tools = required_result(legacy_server.handle_message(request(2, "tools/list")));
        require(tools.at("tools").size() == 2U, "the MCP server must expose exactly two read-only tools");
        for (const auto& tool : tools.at("tools")) {
            require(tool.at("annotations").at("readOnlyHint").get<bool>(), "every history tool must be marked read-only");
            require(!tool.at("annotations").at("destructiveHint").get<bool>(), "history tools must be non-destructive");
        }

        const auto search = required_result(legacy_server.handle_message(
            request(3,
                    "tools/call",
                    {{"name", "search_transcription_history"},
                     {"arguments", {{"app", "Mail"}, {"query", "project"}, {"limit", 10}}}})));
        require(!search.at("isError").get<bool>(), "valid history search must succeed");
        const auto& search_payload = search.at("structuredContent");
        require(search_payload.at("entries").size() == 1U, "history search must return the matching transcript");
        const auto& public_entry = search_payload.at("entries").front();
        require(public_entry.at("text") == "Prepare the project update", "history search returned the wrong transcript");
        require(!public_entry.contains("meta") && !public_entry.contains("audio_path"),
                "MCP results must not expose raw metadata or audio paths");
        require(public_entry.at("source").at("app_name") == "Mail", "public source context must remain available");
        require(public_entry.at("source").size() == 2U,
                "public source context must be restricted to application identity");

        const auto bad_call = required_result(legacy_server.handle_message(
            request(4,
                    "tools/call",
                    {{"name", "search_transcription_history"}, {"arguments", {{"limit", 101}}}})));
        require(bad_call.at("isError").get<bool>(), "invalid tool arguments must be returned as a tool error");

        const auto unknown_argument = required_result(legacy_server.handle_message(
            request(5,
                    "tools/call",
                    {{"name", "get_transcription_history_entry"}, {"arguments", {{"id", 1}, {"delete", true}}}})));
        require(unknown_argument.at("isError").get<bool>(), "unknown tool arguments must be rejected");

        const auto unknown_method = legacy_server.handle_message(request(6, "history/delete"));
        require(unknown_method.has_value() && unknown_method->at("error").at("code") == -32601,
                "unsupported write methods must be rejected as unknown methods");

        ohmytypeless::HistoryMcpServer modern_server(database);
        const auto discover = required_result(modern_server.handle_message(request(
            1,
            "server/discover",
            {{"_meta",
              {{"io.modelcontextprotocol/protocolVersion", "2026-07-28"},
               {"io.modelcontextprotocol/clientInfo", {{"name", "test"}, {"version", "1"}}}}}})));
        require(discover.at("resultType") == "complete", "modern discovery must use the complete result discriminator");
        require(discover.at("supportedVersions").front() == "2026-07-28", "modern discovery must advertise 2026-07-28");

        const auto modern_tools = required_result(modern_server.handle_message(request(
            2,
            "tools/list",
            {{"_meta", {{"io.modelcontextprotocol/protocolVersion", "2026-07-28"}}}})));
        require(modern_tools.at("resultType") == "complete", "modern tool listing must use the complete discriminator");
        require(modern_tools.at("cacheScope") == "private", "history tool discovery must not be publicly cached");
        require(modern_tools.at("_meta").contains("io.modelcontextprotocol/serverInfo"),
                "modern responses must carry server identity metadata");

        std::filesystem::remove_all(directory);
        std::cout << "history_mcp_server_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::filesystem::remove_all(directory);
        std::cerr << "history_mcp_server_tests: " << exception.what() << '\n';
        return 1;
    }
}
