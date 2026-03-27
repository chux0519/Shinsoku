#include "core/app_config.hpp"
#include "platform/hotkey_names.hpp"

#include <QDir>
#include <QStandardPaths>

#include <algorithm>
#include <cctype>
#include <fstream>
#include <set>
#include <stdexcept>
#include <unordered_map>

namespace ohmytypeless {

namespace {

using SectionMap = std::unordered_map<std::string, std::unordered_map<std::string, std::string>>;

std::filesystem::path path_from_qstring(const QString& path) {
    return std::filesystem::path(QDir::fromNativeSeparators(path).toStdWString());
}

QString path_to_qstring(const std::filesystem::path& path) {
    return QDir::cleanPath(QString::fromStdWString(path.generic_wstring()));
}

std::string path_to_portable_string(const std::filesystem::path& path) {
    return path_to_qstring(path).toStdString();
}

std::filesystem::path app_data_root() {
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (path.isEmpty()) {
        path = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    }
    if (path.isEmpty()) {
        return std::filesystem::temp_directory_path() / "shinsoku";
    }
    return path_from_qstring(path);
}

std::filesystem::path config_root() {
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    if (path.isEmpty()) {
        path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    }
    if (path.isEmpty()) {
        return std::filesystem::temp_directory_path() / "shinsoku";
    }
    return path_from_qstring(path);
}

std::string trim(std::string value) {
    const auto begin = value.find_first_not_of(" \t\r\n");
    if (begin == std::string::npos) {
        return {};
    }
    const auto end = value.find_last_not_of(" \t\r\n");
    return value.substr(begin, end - begin + 1U);
}

std::string strip_comments(std::string line) {
    bool in_quotes = false;
    bool escaped = false;
    for (std::size_t i = 0; i < line.size(); ++i) {
        const char ch = line[i];
        if (escaped) {
            escaped = false;
            continue;
        }
        if (ch == '\\') {
            escaped = true;
            continue;
        }
        if (ch == '"') {
            in_quotes = !in_quotes;
            continue;
        }
        if (ch == '#' && !in_quotes) {
            return line.substr(0, i);
        }
    }
    return line;
}

std::string unquote(std::string value) {
    value = trim(std::move(value));
    if (value.size() < 2U || value.front() != '"' || value.back() != '"') {
        return value;
    }

    value = value.substr(1, value.size() - 2U);
    std::string out;
    out.reserve(value.size());
    bool escaped = false;
    for (const char ch : value) {
        if (!escaped) {
            if (ch == '\\') {
                escaped = true;
            } else {
                out += ch;
            }
            continue;
        }

        switch (ch) {
        case 'n':
            out += '\n';
            break;
        case 'r':
            out += '\r';
            break;
        case 't':
            out += '\t';
            break;
        case '\\':
            out += '\\';
            break;
        case '"':
            out += '"';
            break;
        default:
            out += ch;
            break;
        }
        escaped = false;
    }
    return out;
}

std::string escape_toml_string(const std::string& value) {
    std::string escaped;
    escaped.reserve(value.size());
    for (const char ch : value) {
        switch (ch) {
        case '\\':
            escaped += "\\\\";
            break;
        case '"':
            escaped += "\\\"";
            break;
        case '\n':
            escaped += "\\n";
            break;
        case '\r':
            escaped += "\\r";
            break;
        case '\t':
            escaped += "\\t";
            break;
        default:
            escaped += ch;
            break;
        }
    }
    return escaped;
}

bool parse_bool(const std::string& value, bool fallback) {
    const std::string normalized = trim(value);
    if (normalized == "true") {
        return true;
    }
    if (normalized == "false") {
        return false;
    }
    return fallback;
}

std::string normalize_proxy_type(std::string value) {
    value = trim(std::move(value));
    for (char& ch : value) {
        ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
    }
    if (value == "http" || value == "socks5") {
        return value;
    }
    return "http";
}

std::string normalize_capture_mode(std::string value) {
    value = trim(std::move(value));
    for (char& ch : value) {
        ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
    }
    if (value == "microphone" || value == "system") {
        return value;
    }
    return "microphone";
}

std::size_t parse_size(const std::string& value, std::size_t fallback) {
    try {
        return static_cast<std::size_t>(std::stoull(trim(value)));
    } catch (...) {
        return fallback;
    }
}

int parse_int(const std::string& value, int fallback) {
    try {
        return std::stoi(trim(value));
    } catch (...) {
        return fallback;
    }
}

std::string normalize_prompt_mode(std::string value) {
    value = trim(std::move(value));
    for (char& ch : value) {
        ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
    }
    if (value == "inherit_global" || value == "custom") {
        return value;
    }
    return "inherit_global";
}

ProfileConfig make_default_profile(const AppConfig& config) {
    ProfileConfig profile;
    profile.id = "default";
    profile.name = "Default Dictation";
    profile.capture.input_source = config.audio.capture_mode;
    profile.capture.input_device_id = config.audio.input_device_id;
    profile.capture.prefer_streaming = config.pipeline.streaming.enabled;
    profile.capture.preferred_streaming_provider = config.pipeline.streaming.provider;
    profile.capture.language_hint = config.pipeline.streaming.language;
    profile.transform.enabled = config.pipeline.refine.enabled;
    profile.transform.prompt_mode = "inherit_global";
    profile.output.copy_to_clipboard = config.output.copy_to_clipboard;
    profile.output.paste_to_focused_window = config.output.paste_to_focused_window;
    profile.output.paste_keys = config.output.paste_keys;
    profile.notes = "Migrated from the original single-profile configuration.";
    return profile;
}

ProfileConfig make_chinese_to_english_profile() {
    ProfileConfig profile;
    profile.id = "zh-to-en";
    profile.name = "Chinese To English Conversation";
    profile.capture.input_source = "microphone";
    profile.capture.prefer_streaming = true;
    profile.capture.preferred_streaming_provider = "soniox";
    profile.transform.enabled = true;
    profile.transform.prompt_mode = "custom";
    profile.transform.custom_prompt =
        "You are a bilingual conversation assistant.\n\n"
        "Convert the user's spoken Chinese into natural, concise, native-sounding English.\n"
        "Preserve the intended meaning.\n"
        "Do not explain what you changed.\n"
        "Return only the final English text.";
    profile.output.copy_to_clipboard = true;
    profile.output.paste_to_focused_window = true;
    profile.output.paste_keys = "ctrl+v";
    profile.notes = "Speak Chinese and output polished English directly.";
    return profile;
}

ProfileConfig make_live_caption_profile() {
    ProfileConfig profile;
    profile.id = "live-caption";
    profile.name = "Live Caption";
    profile.capture.input_source = "system";
    profile.capture.prefer_streaming = true;
    profile.capture.preferred_streaming_provider = "bailian";
    profile.transform.enabled = false;
    profile.output.copy_to_clipboard = false;
    profile.output.paste_to_focused_window = false;
    profile.output.paste_keys = "ctrl+v";
    profile.notes = "Designed for system-audio live caption workflows. Results stay in the live caption window instead of auto-paste.";
    return profile;
}

void ensure_profiles(AppConfig& config) {
    if (config.profiles.items.empty()) {
        config.profiles.items.push_back(make_default_profile(config));
        config.profiles.items.push_back(make_chinese_to_english_profile());
        config.profiles.items.push_back(make_live_caption_profile());
    }
    if (config.profiles.active_profile_id.empty()) {
        config.profiles.active_profile_id = config.profiles.items.front().id;
    }

    std::set<std::string> seen_ids;
    std::string fallback_active_id;
    for (auto& profile : config.profiles.items) {
        if (profile.id.empty() || seen_ids.contains(profile.id)) {
            profile.id = "profile_" + std::to_string(seen_ids.size() + 1U);
        }
        seen_ids.insert(profile.id);
        if (profile.name.empty()) {
            profile.name = profile.id;
        }
        if (profile.id == "live-caption") {
            profile.capture.input_source = "system";
        }
        if (profile.capture.input_source.empty()) {
            profile.capture.input_source = profile.id == "live-caption" ? "system" : "microphone";
        }
        if (profile.capture.preferred_streaming_provider.empty()) {
            profile.capture.preferred_streaming_provider = "none";
        }
        profile.transform.prompt_mode = normalize_prompt_mode(profile.transform.prompt_mode);
        if (profile.output.paste_keys.empty()) {
            profile.output.paste_keys = "ctrl+shift+v";
        }
        if (fallback_active_id.empty()) {
            fallback_active_id = profile.id;
        }
    }

    const bool active_exists = std::any_of(config.profiles.items.begin(),
                                           config.profiles.items.end(),
                                           [&](const ProfileConfig& profile) {
                                               return profile.id == config.profiles.active_profile_id;
                                           });
    if (!active_exists) {
        config.profiles.active_profile_id = fallback_active_id;
    }
}

float parse_float(const std::string& value, float fallback) {
    try {
        return std::stof(trim(value));
    } catch (...) {
        return fallback;
    }
}

SectionMap parse_toml_like_file(const std::filesystem::path& path) {
    SectionMap sections;
    std::ifstream input(path);
    if (!input.is_open()) {
        return sections;
    }

    std::string current_section;
    std::string line;
    while (std::getline(input, line)) {
        line = trim(strip_comments(std::move(line)));
        if (line.empty()) {
            continue;
        }
        if (line.front() == '[' && line.back() == ']') {
            current_section = trim(line.substr(1, line.size() - 2U));
            continue;
        }

        const auto equals_pos = line.find('=');
        if (equals_pos == std::string::npos) {
            continue;
        }
        sections[current_section][trim(line.substr(0, equals_pos))] = trim(line.substr(equals_pos + 1U));
    }

    return sections;
}

std::optional<std::string> get_value(const SectionMap& sections, const std::string& section, const std::string& key) {
    const auto section_it = sections.find(section);
    if (section_it == sections.end()) {
        return std::nullopt;
    }
    const auto value_it = section_it->second.find(key);
    if (value_it == section_it->second.end()) {
        return std::nullopt;
    }
    return value_it->second;
}

}  // namespace

AppConfig load_config() {
    AppConfig config;
    const AppConfig defaults;
    config.config_path = config_root() / "config.toml";
    config.history_db_path = app_data_root() / "history.sqlite3";
    config.audio.recordings_dir = app_data_root() / "recordings";
    config.audio.rotation.max_files = 50U;

    std::filesystem::create_directories(config.config_path.parent_path());
    std::filesystem::create_directories(config.history_db_path.parent_path());
    std::filesystem::create_directories(config.audio.recordings_dir);

    const SectionMap sections = parse_toml_like_file(config.config_path);

    if (const auto value = get_value(sections, "hotkey", "hold_key")) {
        config.hotkey.hold_key = canonical_hotkey_name(QString::fromStdString(unquote(*value))).toStdString();
    }
    if (const auto value = get_value(sections, "hotkey", "hands_free_chord_key")) {
        config.hotkey.hands_free_chord_key = canonical_hotkey_name(QString::fromStdString(unquote(*value))).toStdString();
    }
    if (const auto value = get_value(sections, "hotkey", "selection_command_trigger")) {
        config.hotkey.selection_command_trigger = unquote(*value);
    }
    if (const auto value = get_value(sections, "pipeline.asr", "provider")) {
        config.pipeline.asr.provider = unquote(*value);
    }
    if (const auto value = get_value(sections, "pipeline.asr", "base_url")) {
        config.pipeline.asr.base_url = unquote(*value);
    }
    if (const auto value = get_value(sections, "pipeline.asr", "api_key")) {
        config.pipeline.asr.api_key = unquote(*value);
    }
    if (const auto value = get_value(sections, "pipeline.asr", "model")) {
        config.pipeline.asr.model = unquote(*value);
    }
    if (const auto value = get_value(sections, "pipeline.refine", "enabled")) {
        config.pipeline.refine.enabled = parse_bool(*value, config.pipeline.refine.enabled);
    }
    if (const auto value = get_value(sections, "pipeline.refine", "provider")) {
        config.pipeline.refine.endpoint.provider = unquote(*value);
    }
    if (const auto value = get_value(sections, "pipeline.refine", "base_url")) {
        config.pipeline.refine.endpoint.base_url = unquote(*value);
    }
    if (const auto value = get_value(sections, "pipeline.refine", "api_key")) {
        config.pipeline.refine.endpoint.api_key = unquote(*value);
    }
    if (const auto value = get_value(sections, "pipeline.refine", "model")) {
        config.pipeline.refine.endpoint.model = unquote(*value);
    }
    if (const auto value = get_value(sections, "pipeline.refine", "system_prompt")) {
        config.pipeline.refine.system_prompt = unquote(*value);
    }
    if (const auto value = get_value(sections, "pipeline.streaming", "enabled")) {
        config.pipeline.streaming.enabled = parse_bool(*value, config.pipeline.streaming.enabled);
    }
    if (const auto value = get_value(sections, "pipeline.streaming", "provider")) {
        config.pipeline.streaming.provider = unquote(*value);
    }
    if (const auto value = get_value(sections, "pipeline.streaming", "language")) {
        config.pipeline.streaming.language = unquote(*value);
    }
    if (const auto value = get_value(sections, "audio", "input_device_id")) {
        config.audio.input_device_id = unquote(*value);
    }
    if (const auto value = get_value(sections, "audio", "capture_mode")) {
        config.audio.capture_mode = normalize_capture_mode(unquote(*value));
    }
    if (const auto value = get_value(sections, "audio", "save_recordings")) {
        config.audio.save_recordings = parse_bool(*value, config.audio.save_recordings);
    }
    if (const auto value = get_value(sections, "audio", "recordings_dir")) {
        config.audio.recordings_dir = path_from_qstring(QString::fromStdString(unquote(*value)));
    }
    if (const auto value = get_value(sections, "audio.rotation", "mode")) {
        config.audio.rotation.mode = unquote(*value);
    }
    if (const auto value = get_value(sections, "audio.rotation", "max_files")) {
        config.audio.rotation.max_files = parse_size(*value, 50U);
    }
    if (const auto value = get_value(sections, "output", "copy_to_clipboard")) {
        config.output.copy_to_clipboard = parse_bool(*value, config.output.copy_to_clipboard);
    }
    if (const auto value = get_value(sections, "output", "paste_to_focused_window")) {
        config.output.paste_to_focused_window = parse_bool(*value, config.output.paste_to_focused_window);
    }
    if (const auto value = get_value(sections, "output", "paste_keys")) {
        config.output.paste_keys = unquote(*value);
    }
    if (const auto value = get_value(sections, "profiles", "active_profile_id")) {
        config.profiles.active_profile_id = unquote(*value);
    }
    if (const auto value = get_value(sections, "network.proxy", "enabled")) {
        config.network.proxy.enabled = parse_bool(*value, config.network.proxy.enabled);
    }
    if (const auto value = get_value(sections, "network.proxy", "type")) {
        config.network.proxy.type = normalize_proxy_type(unquote(*value));
    }
    if (const auto value = get_value(sections, "network.proxy", "host")) {
        config.network.proxy.host = unquote(*value);
    }
    if (const auto value = get_value(sections, "network.proxy", "port")) {
        config.network.proxy.port = parse_int(*value, config.network.proxy.port);
    }
    if (const auto value = get_value(sections, "network.proxy", "username")) {
        config.network.proxy.username = unquote(*value);
    }
    if (const auto value = get_value(sections, "network.proxy", "password")) {
        config.network.proxy.password = unquote(*value);
    }
    if (const auto value = get_value(sections, "providers.soniox", "url")) {
        config.providers.soniox.url = unquote(*value);
    }
    if (const auto value = get_value(sections, "providers.soniox", "api_key")) {
        config.providers.soniox.api_key = unquote(*value);
    }
    if (const auto value = get_value(sections, "providers.soniox", "model")) {
        config.providers.soniox.model = unquote(*value);
    }
    if (const auto value = get_value(sections, "providers.bailian", "region")) {
        config.providers.bailian.region = unquote(*value);
    }
    if (const auto value = get_value(sections, "providers.bailian", "url")) {
        config.providers.bailian.url = unquote(*value);
    }
    if (const auto value = get_value(sections, "providers.bailian", "api_key")) {
        config.providers.bailian.api_key = unquote(*value);
    }
    if (const auto value = get_value(sections, "providers.bailian", "model")) {
        config.providers.bailian.model = unquote(*value);
    }
    if (const auto value = get_value(sections, "vad", "enabled")) {
        config.vad.enabled = parse_bool(*value, config.vad.enabled);
    }
    if (const auto value = get_value(sections, "vad", "threshold")) {
        config.vad.threshold = parse_float(*value, config.vad.threshold);
    }
    if (const auto value = get_value(sections, "vad", "min_speech_duration_ms")) {
        config.vad.min_speech_duration_ms = static_cast<std::uint32_t>(parse_int(*value, static_cast<int>(config.vad.min_speech_duration_ms)));
    }
    if (const auto value = get_value(sections, "observability", "record_metadata")) {
        config.observability.record_metadata = parse_bool(*value, config.observability.record_metadata);
    }
    if (const auto value = get_value(sections, "observability", "record_timing")) {
        config.observability.record_timing = parse_bool(*value, config.observability.record_timing);
    }
    if (const auto value = get_value(sections, "hud", "enabled")) {
        config.hud.enabled = parse_bool(*value, config.hud.enabled);
    }
    if (const auto value = get_value(sections, "hud", "bottom_margin")) {
        config.hud.bottom_margin = parse_int(*value, config.hud.bottom_margin);
    }

    std::set<std::string> profile_ids;
    for (const auto& [section_name, _] : sections) {
        if (!section_name.starts_with("profile.")) {
            continue;
        }
        const std::string remainder = section_name.substr(std::string("profile.").size());
        const auto dot_pos = remainder.find('.');
        const std::string profile_id = dot_pos == std::string::npos ? remainder : remainder.substr(0, dot_pos);
        if (!profile_id.empty()) {
            profile_ids.insert(profile_id);
        }
    }

    for (const std::string& profile_id : profile_ids) {
        ProfileConfig profile;
        profile.id = profile_id;

        const std::string base_section = "profile." + profile_id;
        if (const auto value = get_value(sections, base_section, "name")) {
            profile.name = unquote(*value);
        }
        if (const auto value = get_value(sections, base_section, "notes")) {
            profile.notes = unquote(*value);
        }

        if (const auto value = get_value(sections, base_section + ".capture", "prefer_streaming")) {
            profile.capture.prefer_streaming = parse_bool(*value, profile.capture.prefer_streaming);
        }
        if (const auto value = get_value(sections, base_section + ".capture", "input_source")) {
            profile.capture.input_source = normalize_capture_mode(unquote(*value));
        }
        if (const auto value = get_value(sections, base_section + ".capture", "input_device_id")) {
            profile.capture.input_device_id = unquote(*value);
        }
        if (const auto value = get_value(sections, base_section + ".capture", "preferred_streaming_provider")) {
            profile.capture.preferred_streaming_provider = unquote(*value);
        }
        if (const auto value = get_value(sections, base_section + ".capture", "language_hint")) {
            profile.capture.language_hint = unquote(*value);
        }

        if (const auto value = get_value(sections, base_section + ".transform", "enabled")) {
            profile.transform.enabled = parse_bool(*value, profile.transform.enabled);
        }
        if (const auto value = get_value(sections, base_section + ".transform", "prompt_mode")) {
            profile.transform.prompt_mode = normalize_prompt_mode(unquote(*value));
        }
        if (const auto value = get_value(sections, base_section + ".transform", "custom_prompt")) {
            profile.transform.custom_prompt = unquote(*value);
        }

        if (const auto value = get_value(sections, base_section + ".output", "copy_to_clipboard")) {
            profile.output.copy_to_clipboard = parse_bool(*value, profile.output.copy_to_clipboard);
        }
        if (const auto value = get_value(sections, base_section + ".output", "paste_to_focused_window")) {
            profile.output.paste_to_focused_window = parse_bool(*value, profile.output.paste_to_focused_window);
        }
        if (const auto value = get_value(sections, base_section + ".output", "paste_keys")) {
            profile.output.paste_keys = unquote(*value);
        }

        config.profiles.items.push_back(std::move(profile));
    }

    if (config.hotkey.hold_key.empty()) {
        config.hotkey.hold_key = defaults.hotkey.hold_key;
    }
    if (config.hotkey.hands_free_chord_key.empty()) {
        config.hotkey.hands_free_chord_key = defaults.hotkey.hands_free_chord_key;
    }
    if (config.hotkey.selection_command_trigger.empty()) {
        config.hotkey.selection_command_trigger = defaults.hotkey.selection_command_trigger;
    }
    if (config.pipeline.asr.provider.empty()) {
        config.pipeline.asr.provider = defaults.pipeline.asr.provider;
    }
    if (config.pipeline.asr.base_url.empty()) {
        config.pipeline.asr.base_url = defaults.pipeline.asr.base_url;
    }
    if (config.pipeline.asr.model.empty()) {
        config.pipeline.asr.model = defaults.pipeline.asr.model;
    }
    if (config.pipeline.refine.endpoint.provider.empty()) {
        config.pipeline.refine.endpoint.provider = defaults.pipeline.refine.endpoint.provider;
    }
    if (config.pipeline.streaming.provider.empty()) {
        config.pipeline.streaming.provider = defaults.pipeline.streaming.provider;
    }
    if (config.pipeline.refine.endpoint.model.empty()) {
        config.pipeline.refine.endpoint.model = defaults.pipeline.refine.endpoint.model;
    }
    if (config.pipeline.refine.system_prompt.empty()) {
        config.pipeline.refine.system_prompt = defaults.pipeline.refine.system_prompt;
    }
    if (config.providers.soniox.url.empty()) {
        config.providers.soniox.url = defaults.providers.soniox.url;
    }
    if (config.providers.soniox.model.empty()) {
        config.providers.soniox.model = defaults.providers.soniox.model;
    }
    if (config.providers.bailian.region.empty()) {
        config.providers.bailian.region = defaults.providers.bailian.region;
    }
    if (config.providers.bailian.url.empty()) {
        config.providers.bailian.url = defaults.providers.bailian.url;
    }
    if (config.providers.bailian.model.empty()) {
        config.providers.bailian.model = defaults.providers.bailian.model;
    }
    if (config.output.paste_keys.empty()) {
        config.output.paste_keys = defaults.output.paste_keys;
    }
    if (config.audio.capture_mode.empty()) {
        config.audio.capture_mode = defaults.audio.capture_mode;
    }
    config.audio.capture_mode = normalize_capture_mode(config.audio.capture_mode);
    if (config.network.proxy.type.empty()) {
        config.network.proxy.type = defaults.network.proxy.type;
    }
    config.network.proxy.type = normalize_proxy_type(config.network.proxy.type);
    if (config.network.proxy.port <= 0) {
        config.network.proxy.port = defaults.network.proxy.port;
    }

    ensure_profiles(config);

    std::filesystem::create_directories(config.audio.recordings_dir);
    return config;
}

void save_config(const AppConfig& config) {
    std::filesystem::create_directories(config.config_path.parent_path());

    std::ofstream output(config.config_path);
    if (!output.is_open()) {
        throw std::runtime_error("failed to open config file for writing");
    }

    output << "[hotkey]\n";
    output << "hold_key = \"" << escape_toml_string(canonical_hotkey_name(QString::fromStdString(config.hotkey.hold_key)).toStdString()) << "\"\n";
    output << "hands_free_chord_key = \"" << escape_toml_string(canonical_hotkey_name(QString::fromStdString(config.hotkey.hands_free_chord_key)).toStdString()) << "\"\n";
    output << "selection_command_trigger = \"" << escape_toml_string(config.hotkey.selection_command_trigger) << "\"\n\n";

    output << "[pipeline.asr]\n";
    output << "provider = \"" << escape_toml_string(config.pipeline.asr.provider) << "\"\n";
    output << "base_url = \"" << escape_toml_string(config.pipeline.asr.base_url) << "\"\n";
    output << "api_key = \"" << escape_toml_string(config.pipeline.asr.api_key) << "\"\n";
    output << "model = \"" << escape_toml_string(config.pipeline.asr.model) << "\"\n\n";

    output << "[pipeline.refine]\n";
    output << "enabled = " << (config.pipeline.refine.enabled ? "true" : "false") << "\n";
    output << "provider = \"" << escape_toml_string(config.pipeline.refine.endpoint.provider) << "\"\n";
    output << "base_url = \"" << escape_toml_string(config.pipeline.refine.endpoint.base_url) << "\"\n";
    output << "api_key = \"" << escape_toml_string(config.pipeline.refine.endpoint.api_key) << "\"\n";
    output << "model = \"" << escape_toml_string(config.pipeline.refine.endpoint.model) << "\"\n";
    output << "system_prompt = \"" << escape_toml_string(config.pipeline.refine.system_prompt) << "\"\n\n";

    output << "[pipeline.streaming]\n";
    output << "enabled = " << (config.pipeline.streaming.enabled ? "true" : "false") << "\n";
    output << "provider = \"" << escape_toml_string(config.pipeline.streaming.provider) << "\"\n";
    output << "language = \"" << escape_toml_string(config.pipeline.streaming.language) << "\"\n\n";

    output << "[audio]\n";
    output << "capture_mode = \"" << escape_toml_string(normalize_capture_mode(config.audio.capture_mode)) << "\"\n";
    output << "input_device_id = \"" << escape_toml_string(config.audio.input_device_id) << "\"\n";
    output << "save_recordings = " << (config.audio.save_recordings ? "true" : "false") << "\n";
    output << "recordings_dir = \"" << escape_toml_string(path_to_portable_string(config.audio.recordings_dir)) << "\"\n\n";

    output << "[audio.rotation]\n";
    output << "mode = \"" << escape_toml_string(config.audio.rotation.mode) << "\"\n";
    if (config.audio.rotation.max_files.has_value()) {
        output << "max_files = " << *config.audio.rotation.max_files << "\n";
    }
    output << "\n";

    output << "[output]\n";
    output << "copy_to_clipboard = " << (config.output.copy_to_clipboard ? "true" : "false") << "\n";
    output << "paste_to_focused_window = " << (config.output.paste_to_focused_window ? "true" : "false") << "\n";
    output << "paste_keys = \"" << escape_toml_string(config.output.paste_keys) << "\"\n\n";

    output << "[profiles]\n";
    output << "active_profile_id = \"" << escape_toml_string(config.profiles.active_profile_id) << "\"\n\n";

    for (const auto& profile : config.profiles.items) {
        output << "[profile." << profile.id << "]\n";
        output << "name = \"" << escape_toml_string(profile.name) << "\"\n";
        output << "notes = \"" << escape_toml_string(profile.notes) << "\"\n\n";

        output << "[profile." << profile.id << ".capture]\n";
        output << "input_source = \"" << escape_toml_string(normalize_capture_mode(profile.capture.input_source)) << "\"\n";
        output << "input_device_id = \"" << escape_toml_string(profile.capture.input_device_id) << "\"\n";
        output << "prefer_streaming = " << (profile.capture.prefer_streaming ? "true" : "false") << "\n";
        output << "preferred_streaming_provider = \""
               << escape_toml_string(profile.capture.preferred_streaming_provider) << "\"\n";
        output << "language_hint = \"" << escape_toml_string(profile.capture.language_hint) << "\"\n\n";

        output << "[profile." << profile.id << ".transform]\n";
        output << "enabled = " << (profile.transform.enabled ? "true" : "false") << "\n";
        output << "prompt_mode = \"" << escape_toml_string(normalize_prompt_mode(profile.transform.prompt_mode)) << "\"\n";
        output << "custom_prompt = \"" << escape_toml_string(profile.transform.custom_prompt) << "\"\n\n";

        output << "[profile." << profile.id << ".output]\n";
        output << "copy_to_clipboard = " << (profile.output.copy_to_clipboard ? "true" : "false") << "\n";
        output << "paste_to_focused_window = " << (profile.output.paste_to_focused_window ? "true" : "false") << "\n";
        output << "paste_keys = \"" << escape_toml_string(profile.output.paste_keys) << "\"\n\n";
    }

    output << "[network.proxy]\n";
    output << "enabled = " << (config.network.proxy.enabled ? "true" : "false") << "\n";
    output << "type = \"" << escape_toml_string(normalize_proxy_type(config.network.proxy.type)) << "\"\n";
    output << "host = \"" << escape_toml_string(config.network.proxy.host) << "\"\n";
    output << "port = " << config.network.proxy.port << "\n";
    output << "username = \"" << escape_toml_string(config.network.proxy.username) << "\"\n";
    output << "password = \"" << escape_toml_string(config.network.proxy.password) << "\"\n\n";

    output << "[providers.soniox]\n";
    output << "url = \"" << escape_toml_string(config.providers.soniox.url) << "\"\n";
    output << "api_key = \"" << escape_toml_string(config.providers.soniox.api_key) << "\"\n";
    output << "model = \"" << escape_toml_string(config.providers.soniox.model) << "\"\n\n";

    output << "[providers.bailian]\n";
    output << "region = \"" << escape_toml_string(config.providers.bailian.region) << "\"\n";
    output << "url = \"" << escape_toml_string(config.providers.bailian.url) << "\"\n";
    output << "api_key = \"" << escape_toml_string(config.providers.bailian.api_key) << "\"\n";
    output << "model = \"" << escape_toml_string(config.providers.bailian.model) << "\"\n\n";

    output << "[vad]\n";
    output << "enabled = " << (config.vad.enabled ? "true" : "false") << "\n";
    output << "threshold = " << config.vad.threshold << "\n";
    output << "min_speech_duration_ms = " << config.vad.min_speech_duration_ms << "\n\n";

    output << "[observability]\n";
    output << "record_metadata = " << (config.observability.record_metadata ? "true" : "false") << "\n";
    output << "record_timing = " << (config.observability.record_timing ? "true" : "false") << "\n\n";

    output << "[hud]\n";
    output << "enabled = " << (config.hud.enabled ? "true" : "false") << "\n";
    output << "bottom_margin = " << config.hud.bottom_margin << "\n";
}

}  // namespace ohmytypeless
