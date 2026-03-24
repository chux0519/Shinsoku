#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>

namespace ohmytypeless {

inline constexpr std::uint32_t kFixedSampleRate = 16000;
inline constexpr std::uint32_t kFixedChannelCount = 1;

struct HotkeyConfig {
    std::string hold_key = "KEY_RIGHTALT";
    std::string hands_free_chord_key = "KEY_SPACE";
    std::string selection_command_trigger = "double_press_hold";
};

struct EndpointConfig {
    std::string provider = "openai";
    std::string base_url = "https://api.openai.com/v1";
    std::string api_key;
    std::string model = "gpt-4o-mini-transcribe";
};

struct RefineStageConfig {
    bool enabled = false;
    EndpointConfig endpoint{
        .provider = "openai",
        .base_url = "",
        .api_key = "",
        .model = "gpt-5.4-nano",
    };
    std::string system_prompt =
        "You are a transcription post-processor.\n\n"
        "Strict rules:\n"
        "- Do not translate any text.\n"
        "- Do not change the language of any word or sentence.\n"
        "- Do not paraphrase, rewrite, summarize, or beautify the user's wording.\n"
        "- Do not add or remove information.\n"
        "- Preserve the original wording and meaning as much as possible.\n\n"
        "Allowed changes only:\n"
        "- Fix obvious transcription typos.\n"
        "- Fix punctuation.\n"
        "- Fix spacing.\n"
        "- Add proper spaces between Chinese and English when appropriate.\n"
        "- Add line breaks or sentence breaks only when they improve readability without changing wording.\n\n"
        "Output only the corrected text.";
};

struct StreamingStageConfig {
    bool enabled = false;
    std::string provider = "none";
    std::string language;
};

struct SonioxConfig {
    std::string url = "wss://stt-rt.soniox.com/transcribe-websocket";
    std::string api_key;
    std::string model = "stt-rt-preview";
};

struct BailianConfig {
    std::string region = "cn-beijing";
    std::string url = "wss://dashscope.aliyuncs.com/api-ws/v1/inference/";
    std::string api_key;
    std::string model = "fun-asr-realtime";
};

struct ProvidersConfig {
    SonioxConfig soniox;
    BailianConfig bailian;
};

struct PipelineConfig {
    EndpointConfig asr;
    RefineStageConfig refine;
    StreamingStageConfig streaming;
};

struct RotationConfig {
    std::string mode = "disabled";
    std::optional<std::size_t> max_files;
};

struct AudioConfig {
    std::string input_device_id;
    std::uint32_t sample_rate = kFixedSampleRate;
    std::uint32_t channels = kFixedChannelCount;
    bool save_recordings = false;
    std::filesystem::path recordings_dir;
    RotationConfig rotation;
};

struct OutputConfig {
    bool copy_to_clipboard = true;
    bool paste_to_focused_window = false;
    std::string paste_keys = "ctrl+shift+v";
};

struct NetworkProxyConfig {
    bool enabled = false;
    std::string type = "http";
    std::string host;
    int port = 8080;
    std::string username;
    std::string password;
};

struct NetworkConfig {
    NetworkProxyConfig proxy;
};

struct VadConfig {
    bool enabled = true;
    float threshold = 0.5f;
    std::uint32_t min_speech_duration_ms = 100;
};

struct ObservabilityConfig {
    bool record_metadata = true;
    bool record_timing = true;
};

struct HudConfig {
    bool enabled = true;
    int bottom_margin = 104;
};

struct AppConfig {
    HotkeyConfig hotkey;
    PipelineConfig pipeline;
    AudioConfig audio;
    OutputConfig output;
    NetworkConfig network;
    ProvidersConfig providers;
    VadConfig vad;
    ObservabilityConfig observability;
    HudConfig hud;
    std::filesystem::path history_db_path;
    std::filesystem::path config_path;
};

AppConfig load_config();
void save_config(const AppConfig& config);

}  // namespace ohmytypeless
