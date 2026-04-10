#include "shinsoku/nativecore/profile_presets.hpp"

#include <sstream>
#include <string>
#include <vector>

namespace shinsoku::nativecore {

namespace {

const std::vector<BuiltinProfileSpec>& specs() {
    static const std::vector<BuiltinProfileSpec> value = {
        {
            .preset_kind = "dictation",
            .id = "dictation",
            .display_name = "Dictation",
            .summary = "Speak and insert directly.",
            .behavior_summary = "Auto-insert on · Append space",
            .language_tag = "",
            .auto_commit = true,
            .commit_suffix_mode = "Space",
            .transform = {},
        },
        {
            .preset_kind = "chat",
            .id = "chat",
            .display_name = "Chat",
            .summary = "Speak and commit with a trailing newline.",
            .behavior_summary = "Auto-insert on · Append newline",
            .language_tag = "",
            .auto_commit = true,
            .commit_suffix_mode = "Newline",
            .transform = {},
        },
        {
            .preset_kind = "review",
            .id = "review",
            .display_name = "Review",
            .summary = "Hold results before inserting.",
            .behavior_summary = "Review before insert · No suffix",
            .language_tag = "",
            .auto_commit = false,
            .commit_suffix_mode = "None",
            .transform = {},
        },
        {
            .preset_kind = "translate_zh_en",
            .id = "translate_zh_en",
            .display_name = "Zh→En",
            .summary = "Transcribe first, then transform to English.",
            .behavior_summary = "Auto-insert on · Append space",
            .language_tag = "zh-CN",
            .auto_commit = true,
            .commit_suffix_mode = "Space",
            .transform = {
                .enabled = true,
                .mode = TransformPromptMode::Translation,
                .request_format = TransformRequestFormat::SystemAndUser,
                .translation_source_language = "Chinese",
                .translation_source_code = "zh",
                .translation_target_language = "English",
                .translation_target_code = "en",
            },
        },
    };
    return value;
}

std::string escape_json(const std::string& value) {
    std::string output;
    output.reserve(value.size());
    for (const char ch : value) {
        switch (ch) {
            case '\\':
                output += "\\\\";
                break;
            case '"':
                output += "\\\"";
                break;
            case '\n':
                output += "\\n";
                break;
            default:
                output.push_back(ch);
                break;
        }
    }
    return output;
}

bool same_transform_config(const TransformPromptConfig& lhs, const TransformPromptConfig& rhs) {
    return lhs.enabled == rhs.enabled &&
        lhs.mode == rhs.mode &&
        lhs.request_format == rhs.request_format &&
        lhs.custom_prompt == rhs.custom_prompt &&
        lhs.translation_source_language == rhs.translation_source_language &&
        lhs.translation_source_code == rhs.translation_source_code &&
        lhs.translation_target_language == rhs.translation_target_language &&
        lhs.translation_target_code == rhs.translation_target_code &&
        lhs.translation_extra_instructions == rhs.translation_extra_instructions;
}

}  // namespace

const std::vector<BuiltinProfileSpec>& builtin_profiles() {
    return specs();
}

std::string builtin_profiles_json() {
    std::ostringstream json;
    json << "[";
    bool first_profile = true;
    for (const auto& profile : builtin_profiles()) {
        if (!first_profile) {
            json << ",";
        }
        first_profile = false;
        json
            << "{"
            << "\"preset_kind\":\"" << escape_json(profile.preset_kind) << "\","
            << "\"id\":\"" << escape_json(profile.id) << "\","
            << "\"display_name\":\"" << escape_json(profile.display_name) << "\","
            << "\"summary\":\"" << escape_json(profile.summary) << "\","
            << "\"behavior_summary\":\"" << escape_json(profile.behavior_summary) << "\","
            << "\"language_tag\":\"" << escape_json(profile.language_tag) << "\","
            << "\"auto_commit\":" << (profile.auto_commit ? "true" : "false") << ","
            << "\"commit_suffix_mode\":\"" << escape_json(profile.commit_suffix_mode) << "\","
            << "\"transform\":{"
            << "\"enabled\":" << (profile.transform.enabled ? "true" : "false") << ","
            << "\"mode\":\"" << (
                profile.transform.mode == TransformPromptMode::Translation
                    ? "Translation"
                    : profile.transform.mode == TransformPromptMode::CustomPrompt
                        ? "CustomPrompt"
                        : "Cleanup"
            ) << "\","
            << "\"request_format\":\"" << (
                profile.transform.request_format == TransformRequestFormat::SingleUserMessage
                    ? "SingleUserMessage"
                    : "SystemAndUser"
            ) << "\","
            << "\"custom_prompt\":\"" << escape_json(profile.transform.custom_prompt) << "\","
            << "\"translation_source_language\":\"" << escape_json(profile.transform.translation_source_language) << "\","
            << "\"translation_source_code\":\"" << escape_json(profile.transform.translation_source_code) << "\","
            << "\"translation_target_language\":\"" << escape_json(profile.transform.translation_target_language) << "\","
            << "\"translation_target_code\":\"" << escape_json(profile.transform.translation_target_code) << "\","
            << "\"translation_extra_instructions\":\"" << escape_json(profile.transform.translation_extra_instructions) << "\""
            << "}"
            << "}";
    }
    json << "]";
    return json.str();
}

std::string identify_builtin_profile_id(
    bool auto_commit,
    const std::string& commit_suffix_mode,
    const std::string& language_tag,
    const TransformPromptConfig& transform
) {
    for (const auto& profile : builtin_profiles()) {
        if (profile.auto_commit == auto_commit &&
            profile.commit_suffix_mode == commit_suffix_mode &&
            profile.language_tag == language_tag &&
            same_transform_config(profile.transform, transform)) {
            return profile.id;
        }
    }
    return {};
}

std::string describe_profile_behavior(
    bool auto_commit,
    const std::string& commit_suffix_mode
) {
    const std::string commit_description = auto_commit
        ? "Auto-insert on"
        : "Review before insert";
    std::string suffix_description = "Append space";
    if (commit_suffix_mode == "None") {
        suffix_description = "No suffix";
    } else if (commit_suffix_mode == "Newline") {
        suffix_description = "Append newline";
    }
    return commit_description + " · " + suffix_description;
}

}  // namespace shinsoku::nativecore
