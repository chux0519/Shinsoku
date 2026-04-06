#include "core/runtime_profile.hpp"

#include <algorithm>

namespace ohmytypeless {

const ProfileConfig* find_profile_by_id(const ProfilesConfig& profiles, const std::string& profile_id) {
    const auto it = std::find_if(profiles.items.begin(), profiles.items.end(), [&](const ProfileConfig& profile) {
        return profile.id == profile_id;
    });
    return it != profiles.items.end() ? &(*it) : nullptr;
}

const ProfileConfig* active_profile(const AppConfig& config) {
    return find_profile_by_id(config.profiles, config.profiles.active_profile_id);
}

std::vector<std::pair<std::string, std::string>> profile_items(const AppConfig& config) {
    std::vector<std::pair<std::string, std::string>> items;
    items.reserve(config.profiles.items.size());
    for (const auto& profile : config.profiles.items) {
        items.emplace_back(profile.id, profile.name);
    }
    return items;
}

std::string active_profile_display_name(const AppConfig& config) {
    if (const auto* profile = active_profile(config); profile != nullptr) {
        return profile->name;
    }
    return {};
}

bool active_profile_uses_system_audio(const AppConfig& config) {
    if (const auto* profile = active_profile(config); profile != nullptr) {
        return profile->capture.input_source == "system";
    }
    return false;
}

AppConfig derive_runtime_config(const AppConfig& config) {
    AppConfig runtime_config = config;
    if (runtime_config.profiles.items.empty()) {
        return runtime_config;
    }

    const ProfileConfig* profile = active_profile(runtime_config);
    if (profile == nullptr) {
        profile = &runtime_config.profiles.items.front();
        runtime_config.profiles.active_profile_id = profile->id;
    }

    runtime_config.audio.capture_mode = profile->capture.input_source.empty() ? "microphone" : profile->capture.input_source;
    if (runtime_config.audio.capture_mode == "system") {
        runtime_config.audio.input_device_id.clear();
    } else if (!profile->capture.input_device_id.empty()) {
        runtime_config.audio.input_device_id = profile->capture.input_device_id;
    } else {
        runtime_config.audio.input_device_id.clear();
    }

    runtime_config.pipeline.streaming.enabled = profile->capture.prefer_streaming;
    runtime_config.pipeline.streaming.provider = profile->capture.preferred_streaming_provider.empty()
                                                     ? std::string("none")
                                                     : profile->capture.preferred_streaming_provider;
    runtime_config.pipeline.streaming.language = profile->capture.language_hint;

    runtime_config.pipeline.refine.enabled = profile->transform.enabled;
    runtime_config.pipeline.refine.request_format =
        profile->transform.request_format.empty() ? AppConfig{}.pipeline.refine.request_format : profile->transform.request_format;
    runtime_config.pipeline.refine.translation_source_language = profile->transform.translation_source_language;
    runtime_config.pipeline.refine.translation_source_code = profile->transform.translation_source_code;
    runtime_config.pipeline.refine.translation_target_language = profile->transform.translation_target_language;
    runtime_config.pipeline.refine.translation_target_code = profile->transform.translation_target_code;
    runtime_config.pipeline.refine.translation_extra_instructions = profile->transform.translation_extra_instructions;

    if (!profile->transform.enabled) {
        runtime_config.pipeline.refine.prompt_mode = "generic";
        runtime_config.pipeline.refine.system_prompt = AppConfig{}.pipeline.refine.system_prompt;
    } else if (profile->transform.mode == "translation") {
        runtime_config.pipeline.refine.prompt_mode = "structured_translation";
        runtime_config.pipeline.refine.system_prompt.clear();
    } else if (profile->transform.mode == "custom_prompt") {
        runtime_config.pipeline.refine.prompt_mode = "generic";
        runtime_config.pipeline.refine.system_prompt =
            profile->transform.custom_prompt.empty() ? AppConfig{}.pipeline.refine.system_prompt : profile->transform.custom_prompt;
    } else {
        runtime_config.pipeline.refine.prompt_mode = "generic";
        runtime_config.pipeline.refine.system_prompt = AppConfig{}.pipeline.refine.system_prompt;
    }

    runtime_config.output.copy_to_clipboard = profile->output.copy_to_clipboard;
    runtime_config.output.paste_to_focused_window = profile->output.paste_to_focused_window;
    if (!profile->output.paste_keys.empty()) {
        runtime_config.output.paste_keys = profile->output.paste_keys;
    }

    return runtime_config;
}

nlohmann::json capture_context_meta(const AppConfig& config) {
    nlohmann::json input = {
        {"capture_mode", config.audio.capture_mode},
        {"sample_rate", config.audio.sample_rate},
        {"channels", config.audio.channels},
    };
    if (config.audio.capture_mode == "microphone") {
        input["device_id"] = config.audio.input_device_id;
    } else {
        input["device"] = "default_system_output";
    }

    return {
        {"input", std::move(input)},
        {"profile", {{"id", config.profiles.active_profile_id}}},
    };
}

}  // namespace ohmytypeless
