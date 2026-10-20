#pragma once

#include <nlohmann/json.hpp>

#include <filesystem>
#include <optional>

namespace ohmytypeless {

class HistoryMcpServer {
public:
    explicit HistoryMcpServer(std::filesystem::path database_path);

    std::optional<nlohmann::json> handle_message(const nlohmann::json& message);

private:
    enum class ProtocolEra {
        Unknown,
        Legacy2025,
        Modern2026,
    };

    nlohmann::json handle_request(const std::string& method, const nlohmann::json& params);
    nlohmann::json list_tools_result() const;
    nlohmann::json call_tool_result(const nlohmann::json& params) const;
    nlohmann::json search_history(const nlohmann::json& arguments) const;
    nlohmann::json get_history_entry(const nlohmann::json& arguments) const;
    nlohmann::json complete_result(nlohmann::json result, bool cacheable = false) const;

    std::filesystem::path database_path_;
    ProtocolEra era_ = ProtocolEra::Unknown;
};

}  // namespace ohmytypeless
