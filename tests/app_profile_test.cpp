#include "core/app_config.hpp"
#include "core/runtime_profile.hpp"

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
    return std::filesystem::temp_directory_path() / ("shinsoku-app-profile-test-" + std::to_string(suffix));
}

ohmytypeless::AppConfig make_config() {
    ohmytypeless::AppConfig config;
    config.profiles.items.clear();

    ohmytypeless::ProfileConfig dictation;
    dictation.id = "dictation";
    dictation.name = "Dictation";
    config.profiles.items.push_back(dictation);

    ohmytypeless::ProfileConfig translation;
    translation.id = "translate";
    translation.name = "Chinese To English";
    translation.transform.enabled = true;
    translation.transform.mode = "translation";
    config.profiles.items.push_back(translation);

    config.profiles.active_profile_id = "dictation";
    config.profiles.auto_select_by_app = true;
    config.profiles.app_rules = {
        {
            .app_id = "com.tinyspeck.slackmacgap",
            .app_name = "Slack",
            .profile_id = "translate",
        },
    };
    return config;
}

}  // namespace

int main() {
    const std::filesystem::path directory = unique_test_directory();

    try {
        using ohmytypeless::AppProfileMatchStatus;

        require(ohmytypeless::canonical_app_id("  COM.Apple.Mail\n") == "com.apple.mail",
                "application IDs must be trimmed and case-normalized");

        auto config = make_config();
        require(ohmytypeless::resolve_app_profile(config, {}).status == AppProfileMatchStatus::AppUnavailable,
                "empty application context must remain explicit");
        require(ohmytypeless::resolve_app_profile(config, "com.apple.mail").status == AppProfileMatchStatus::NoMatch,
                "an unknown application must preserve the manual profile");

        const auto matched = ohmytypeless::resolve_app_profile(config, "COM.TINYSPECK.SLACKMACGAP");
        require(matched.status == AppProfileMatchStatus::Matched && matched.profile != nullptr &&
                    matched.profile->id == "translate",
                "an exact application ID must resolve to its configured profile");

        config.profiles.auto_select_by_app = false;
        require(ohmytypeless::resolve_app_profile(config, "com.tinyspeck.slackmacgap").status ==
                    AppProfileMatchStatus::Disabled,
                "the global switch must disable automatic selection");

        config = make_config();
        config.profiles.app_rules.push_back(config.profiles.app_rules.front());
        require(ohmytypeless::resolve_app_profile(config, "com.tinyspeck.slackmacgap").status ==
                    AppProfileMatchStatus::Conflict,
                "duplicate enabled rules must report a conflict instead of guessing");

        config = make_config();
        config.profiles.app_rules.front().profile_id = "deleted-profile";
        require(ohmytypeless::resolve_app_profile(config, "com.tinyspeck.slackmacgap").status ==
                    AppProfileMatchStatus::MissingProfile,
                "a rule targeting a deleted profile must fall back safely");

        config = make_config();
        config.profiles.app_rules.front().enabled = false;
        require(ohmytypeless::resolve_app_profile(config, "com.tinyspeck.slackmacgap").status ==
                    AppProfileMatchStatus::NoMatch,
                "disabled rules must not participate in matching");

        std::filesystem::create_directories(directory);
        const ohmytypeless::AppConfigPaths paths{
            .config_path = directory / "config.toml",
            .history_db_path = directory / "history.sqlite3",
            .recordings_dir = directory / "recordings",
        };
        config = make_config();
        config.profiles.app_rules.front().app_id = " COM.TinySpeck.SlackMacGap ";
        config.network.nearby.enabled = true;
        config.network.nearby.port = 40123;
        config.device_adapter.enabled = true;
        config.device_adapter.executable_path = directory / "fixture-adapter";
        ohmytypeless::save_config(config, paths.config_path);
        const auto loaded = ohmytypeless::load_config(paths);
        require(loaded.profiles.auto_select_by_app, "the global rule switch must survive a configuration round trip");
        require(loaded.profiles.app_rules.size() == 1U, "application rules must survive a configuration round trip");
        require(loaded.profiles.app_rules.front().app_id == "com.tinyspeck.slackmacgap" &&
                    loaded.profiles.app_rules.front().app_name == "Slack" &&
                    loaded.profiles.app_rules.front().profile_id == "translate",
                "application rule fields must be normalized and preserved");
        require(loaded.network.nearby.enabled && loaded.network.nearby.port == 40123,
                "Nearby microphone settings must survive a configuration round trip");
        require(loaded.device_adapter.enabled &&
                    loaded.device_adapter.executable_path == directory / "fixture-adapter",
                "device adapter approval settings must survive a configuration round trip");

        std::filesystem::remove_all(directory);
        std::cout << "app_profile_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::filesystem::remove_all(directory);
        std::cerr << "app_profile_tests: " << exception.what() << '\n';
        return 1;
    }
}
