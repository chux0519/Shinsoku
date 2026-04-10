#pragma once

#include <string>

namespace shinsoku::nativecore {

enum class TransformPromptMode {
    Cleanup,
    Translation,
    CustomPrompt,
};

enum class TransformRequestFormat {
    SystemAndUser,
    SingleUserMessage,
};

struct TransformPromptConfig {
    bool enabled = false;
    TransformPromptMode mode = TransformPromptMode::Cleanup;
    TransformRequestFormat request_format = TransformRequestFormat::SystemAndUser;
    std::string custom_prompt;
    std::string translation_source_language = "Chinese";
    std::string translation_source_code = "zh";
    std::string translation_target_language = "English";
    std::string translation_target_code = "en";
    std::string translation_extra_instructions;
};

struct TransformPromptPlan {
    std::string system_prompt;
    std::string user_content;
    TransformRequestFormat request_format = TransformRequestFormat::SystemAndUser;
};

TransformPromptPlan build_transform_prompt(
    const std::string& raw_transcript,
    const TransformPromptConfig& config
);

std::string describe_transform_config(const TransformPromptConfig& config);

}  // namespace shinsoku::nativecore
