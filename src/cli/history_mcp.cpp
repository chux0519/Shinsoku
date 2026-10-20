#include "core/app_config.hpp"
#include "core/history_mcp_server.hpp"

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCoreApplication>

#include <nlohmann/json.hpp>

#include <filesystem>
#include <iostream>
#include <string>

namespace {

nlohmann::json parse_error_response() {
    return {
        {"jsonrpc", "2.0"},
        {"id", nullptr},
        {"error", {{"code", -32700}, {"message", "Parse error"}}},
    };
}

}  // namespace

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);
    app.setApplicationName("Shinsoku");
    app.setOrganizationName("Shinsoku");
    app.setApplicationVersion("0.1.0");

    QCommandLineParser parser;
    parser.setApplicationDescription("Serve local Shinsoku transcript history as read-only MCP tools over stdio.");
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption database_option({"d", "database"}, "History database path.", "path");
    parser.addOption(database_option);
    parser.process(app);

    std::filesystem::path database_path;
    if (parser.isSet(database_option)) {
        database_path = std::filesystem::path(parser.value(database_option).toStdString());
    } else {
        database_path = ohmytypeless::load_config().history_db_path;
    }
    ohmytypeless::HistoryMcpServer server(std::move(database_path));

    std::string line;
    while (std::getline(std::cin, line)) {
        if (line.empty()) {
            continue;
        }
        try {
            const nlohmann::json message = nlohmann::json::parse(line);
            const auto response = server.handle_message(message);
            if (response.has_value()) {
                std::cout << response->dump() << '\n' << std::flush;
            }
        } catch (const nlohmann::json::parse_error&) {
            std::cout << parse_error_response().dump() << '\n' << std::flush;
        } catch (const std::exception& exception) {
            const nlohmann::json response = {
                {"jsonrpc", "2.0"},
                {"id", nullptr},
                {"error", {{"code", -32603}, {"message", exception.what()}}},
            };
            std::cout << response.dump() << '\n' << std::flush;
        }
    }
    return 0;
}
