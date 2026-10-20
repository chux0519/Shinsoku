#include "core/history_mcp_server.hpp"

#include "core/history_export.hpp"
#include "core/history_store.hpp"

#include <QDate>
#include <QString>

#include <algorithm>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <string>

namespace ohmytypeless {

namespace {

constexpr auto kLegacyProtocolVersion = "2025-11-25";
constexpr auto kModernProtocolVersion = "2026-07-28";
constexpr auto kServerName = "shinsoku-history";
constexpr auto kServerVersion = "0.1.0";

nlohmann::json server_info() {
    return {
        {"name", kServerName},
        {"version", kServerVersion},
        {"description", "Read-only access to local Shinsoku transcription history."},
    };
}

nlohmann::json error_response(const nlohmann::json& id, int code, const std::string& message) {
    return {
        {"jsonrpc", "2.0"},
        {"id", id},
        {"error", {{"code", code}, {"message", message}}},
    };
}

std::int64_t positive_integer(const nlohmann::json& object, const char* key, std::int64_t fallback) {
    const auto it = object.find(key);
    if (it == object.end()) {
        if (fallback <= 0) {
            throw std::invalid_argument(std::string(key) + " is required");
        }
        return fallback;
    }
    if (!it->is_number_integer() && !it->is_number_unsigned()) {
        throw std::invalid_argument(std::string(key) + " must be a positive integer");
    }
    if (it->is_number_unsigned()) {
        const auto value = it->get<std::uint64_t>();
        if (value == 0 || value > static_cast<std::uint64_t>(std::numeric_limits<std::int64_t>::max())) {
            throw std::invalid_argument(std::string(key) + " must be a positive integer");
        }
        return static_cast<std::int64_t>(value);
    }
    const auto value = it->get<std::int64_t>();
    if (value <= 0) {
        throw std::invalid_argument(std::string(key) + " must be a positive integer");
    }
    return value;
}

void reject_unknown_arguments(const nlohmann::json& arguments, std::initializer_list<const char*> allowed) {
    for (auto it = arguments.begin(); it != arguments.end(); ++it) {
        const bool known = std::any_of(allowed.begin(), allowed.end(), [&](const char* name) {
            return it.key() == name;
        });
        if (!known) {
            throw std::invalid_argument("unknown argument: " + it.key());
        }
    }
}

std::optional<std::string> optional_trimmed_string(const nlohmann::json& object,
                                                   const char* key,
                                                   std::size_t max_length) {
    const auto it = object.find(key);
    if (it == object.end()) {
        return std::nullopt;
    }
    if (!it->is_string()) {
        throw std::invalid_argument(std::string(key) + " must be a string");
    }
    const QString value = QString::fromStdString(it->get<std::string>()).trimmed();
    if (value.size() > static_cast<qsizetype>(max_length)) {
        throw std::invalid_argument(std::string(key) + " is too long");
    }
    if (value.isEmpty()) {
        return std::nullopt;
    }
    return value.toStdString();
}

nlohmann::json tool_result(nlohmann::json payload) {
    return {
        {"content", nlohmann::json::array({{{"type", "text"}, {"text", payload.dump()}}})},
        {"structuredContent", std::move(payload)},
        {"isError", false},
    };
}

nlohmann::json tool_error(const std::string& message) {
    return {
        {"content", nlohmann::json::array({{{"type", "text"}, {"text", message}}})},
        {"isError", true},
    };
}

nlohmann::json search_tool_definition() {
    return {
        {"name", "search_transcription_history"},
        {"title", "Search transcription history"},
        {"description", "Search the user's local Shinsoku transcripts by date, source application, or text. Returns newest entries first and never returns raw diagnostic metadata or audio paths."},
        {"inputSchema",
         {{"type", "object"},
          {"properties",
           {{"limit", {{"type", "integer"}, {"minimum", 1}, {"maximum", 100}, {"default", 20}}},
            {"before_id", {{"type", "integer"}, {"minimum", 1}}},
            {"since", {{"type", "string"}, {"format", "date"}, {"description", "Local date in YYYY-MM-DD format."}}},
            {"app", {{"type", "string"}, {"description", "Source application ID or display name."}}},
            {"query", {{"type", "string"}, {"description", "Text contained in the transcript."}}}}},
          {"additionalProperties", false}}},
        {"outputSchema",
         {{"type", "object"},
          {"properties",
           {{"schema_version", {{"type", "integer"}, {"const", 1}}},
            {"entries", {{"type", "array"}, {"items", {{"type", "object"}}}}},
            {"next_before_id", {{"type", nlohmann::json::array({"integer", "null"})}}}}},
          {"required", nlohmann::json::array({"schema_version", "entries", "next_before_id"})}}},
        {"annotations",
         {{"readOnlyHint", true},
          {"destructiveHint", false},
          {"idempotentHint", true},
          {"openWorldHint", false}}},
    };
}

nlohmann::json get_tool_definition() {
    return {
        {"name", "get_transcription_history_entry"},
        {"title", "Get transcription history entry"},
        {"description", "Read one local Shinsoku transcript by entry ID. The result excludes raw diagnostic metadata and audio paths."},
        {"inputSchema",
         {{"type", "object"},
          {"properties", {{"id", {{"type", "integer"}, {"minimum", 1}}}}},
          {"required", nlohmann::json::array({"id"})},
          {"additionalProperties", false}}},
        {"outputSchema",
         {{"type", "object"},
          {"properties",
           {{"schema_version", {{"type", "integer"}, {"const", 1}}},
            {"entry", {{"type", "object"}}}}},
          {"required", nlohmann::json::array({"schema_version", "entry"})}}},
        {"annotations",
         {{"readOnlyHint", true},
          {"destructiveHint", false},
          {"idempotentHint", true},
          {"openWorldHint", false}}},
    };
}

}  // namespace

HistoryMcpServer::HistoryMcpServer(std::filesystem::path database_path)
    : database_path_(std::move(database_path)) {}

std::optional<nlohmann::json> HistoryMcpServer::handle_message(const nlohmann::json& message) {
    if (!message.is_object() || !message.contains("jsonrpc") || !message["jsonrpc"].is_string() ||
        message["jsonrpc"].get<std::string>() != "2.0" ||
        !message.contains("method") || !message["method"].is_string()) {
        const nlohmann::json id = message.is_object() && message.contains("id") ? message["id"] : nlohmann::json(nullptr);
        return error_response(id, -32600, "Invalid Request");
    }

    const bool has_id = message.contains("id");
    if (!has_id) {
        return std::nullopt;
    }
    if ((!message["id"].is_string() && !message["id"].is_number_integer() && !message["id"].is_number_unsigned()) ||
        message["id"].is_null()) {
        return error_response(nullptr, -32600, "Invalid Request ID");
    }

    const std::string method = message["method"].get<std::string>();
    const nlohmann::json params = message.contains("params") ? message["params"] : nlohmann::json::object();
    if (!params.is_object()) {
        return error_response(message["id"], -32602, "Invalid params");
    }

    if (method == "server/discover") {
        era_ = ProtocolEra::Modern2026;
    } else if (method == "initialize") {
        era_ = ProtocolEra::Legacy2025;
    } else if (era_ == ProtocolEra::Unknown) {
        const auto meta = params.find("_meta");
        if (meta != params.end() && meta->is_object() &&
            meta->value("io.modelcontextprotocol/protocolVersion", std::string()) == kModernProtocolVersion) {
            era_ = ProtocolEra::Modern2026;
        } else {
            era_ = ProtocolEra::Legacy2025;
        }
    }

    if (method != "server/discover" && method != "initialize" && method != "ping" &&
        method != "tools/list" && method != "tools/call") {
        return error_response(message["id"], -32601, "Method not found: " + method);
    }

    try {
        return nlohmann::json{
            {"jsonrpc", "2.0"},
            {"id", message["id"]},
            {"result", handle_request(method, params)},
        };
    } catch (const std::invalid_argument& exception) {
        return error_response(message["id"], -32602, exception.what());
    } catch (const std::out_of_range& exception) {
        return error_response(message["id"], -32602, exception.what());
    } catch (const std::exception& exception) {
        return error_response(message["id"], -32603, exception.what());
    }
}

nlohmann::json HistoryMcpServer::handle_request(const std::string& method, const nlohmann::json& params) {
    if (method == "server/discover") {
        nlohmann::json result = {
            {"resultType", "complete"},
            {"supportedVersions", nlohmann::json::array({kModernProtocolVersion})},
            {"capabilities", {{"tools", nlohmann::json::object()}}},
            {"instructions", "Read-only local transcription history. Search narrowly and cite entry IDs and timestamps."},
            {"ttlMs", 0},
            {"cacheScope", "private"},
        };
        result["_meta"]["io.modelcontextprotocol/serverInfo"] = server_info();
        return result;
    }
    if (method == "initialize") {
        std::string protocol_version = kLegacyProtocolVersion;
        if (params.contains("protocolVersion") && params["protocolVersion"].is_string()) {
            const std::string requested = params["protocolVersion"].get<std::string>();
            if (requested == "2024-11-05" || requested == "2025-03-26" || requested == "2025-06-18" ||
                requested == kLegacyProtocolVersion) {
                protocol_version = requested;
            }
        }
        return {
            {"protocolVersion", protocol_version},
            {"capabilities", {{"tools", nlohmann::json::object()}}},
            {"serverInfo", server_info()},
            {"instructions", "Read-only local transcription history. Search narrowly and cite entry IDs and timestamps."},
        };
    }
    if (method == "ping") {
        return complete_result(nlohmann::json::object());
    }
    if (method == "tools/list") {
        return complete_result(list_tools_result(), true);
    }
    if (method == "tools/call") {
        return complete_result(call_tool_result(params));
    }
    throw std::invalid_argument("Method not found: " + method);
}

nlohmann::json HistoryMcpServer::list_tools_result() const {
    return {
        {"tools", nlohmann::json::array({search_tool_definition(), get_tool_definition()})},
    };
}

nlohmann::json HistoryMcpServer::call_tool_result(const nlohmann::json& params) const {
    if (!params.contains("name") || !params["name"].is_string()) {
        throw std::invalid_argument("tools/call requires a tool name");
    }
    const std::string name = params["name"].get<std::string>();
    const nlohmann::json arguments = params.contains("arguments") ? params["arguments"] : nlohmann::json::object();
    if (!arguments.is_object()) {
        return tool_error("Tool arguments must be an object.");
    }

    try {
        if (name == "search_transcription_history") {
            return tool_result(search_history(arguments));
        }
        if (name == "get_transcription_history_entry") {
            return tool_result(get_history_entry(arguments));
        }
    } catch (const std::exception& exception) {
        return tool_error(exception.what());
    }
    throw std::invalid_argument("Unknown tool: " + name);
}

nlohmann::json HistoryMcpServer::search_history(const nlohmann::json& arguments) const {
    reject_unknown_arguments(arguments, {"limit", "before_id", "since", "app", "query"});
    HistoryQuery query;
    const std::int64_t limit = positive_integer(arguments, "limit", 20);
    if (limit > 100) {
        throw std::invalid_argument("limit must not exceed 100");
    }
    query.limit = static_cast<std::size_t>(limit);

    if (arguments.contains("before_id")) {
        query.before_id = positive_integer(arguments, "before_id", 0);
    }
    if (const auto since = optional_trimmed_string(arguments, "since", 10); since.has_value()) {
        if (!QDate::fromString(QString::fromStdString(*since), Qt::ISODate).isValid() || since->size() != 10U) {
            throw std::invalid_argument("since must use YYYY-MM-DD");
        }
        query.since_date = *since;
    }
    query.source_app = optional_trimmed_string(arguments, "app", 512);
    query.text_query = optional_trimmed_string(arguments, "query", 4096);

    HistoryStore store(database_path_, HistoryOpenMode::ReadOnly);
    const auto entries = store.query(query);
    nlohmann::json entry_list = nlohmann::json::array();
    for (const auto& entry : entries) {
        entry_list.push_back(public_history_entry_json(entry));
    }
    return {
        {"schema_version", 1},
        {"entries", std::move(entry_list)},
        {"next_before_id", entries.size() == query.limit && !entries.empty() ? nlohmann::json(entries.back().id)
                                                                             : nlohmann::json(nullptr)},
    };
}

nlohmann::json HistoryMcpServer::get_history_entry(const nlohmann::json& arguments) const {
    reject_unknown_arguments(arguments, {"id"});
    const std::int64_t id = positive_integer(arguments, "id", 0);
    HistoryStore store(database_path_, HistoryOpenMode::ReadOnly);
    const auto entry = store.get_entry(id);
    if (!entry.has_value()) {
        throw std::runtime_error("history entry not found");
    }
    return {
        {"schema_version", 1},
        {"entry", public_history_entry_json(*entry)},
    };
}

nlohmann::json HistoryMcpServer::complete_result(nlohmann::json result, bool cacheable) const {
    if (era_ == ProtocolEra::Modern2026) {
        result["resultType"] = "complete";
        result["_meta"]["io.modelcontextprotocol/serverInfo"] = server_info();
        if (cacheable) {
            result["ttlMs"] = 0;
            result["cacheScope"] = "private";
        }
    }
    return result;
}

}  // namespace ohmytypeless
