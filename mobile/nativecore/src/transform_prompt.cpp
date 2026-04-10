#include "shinsoku/nativecore/transform_prompt.hpp"

#include <string>

namespace shinsoku::nativecore {

namespace {

std::string trim(std::string value) {
    const auto begin = value.find_first_not_of(" \t\r\n");
    if (begin == std::string::npos) {
        return {};
    }
    const auto end = value.find_last_not_of(" \t\r\n");
    return value.substr(begin, end - begin + 1U);
}

std::string format_language_label(
    const std::string& language,
    const std::string& code,
    const std::string& fallback
) {
    const std::string trimmed_language = trim(language);
    const std::string trimmed_code = trim(code);
    if (trimmed_language.empty() && trimmed_code.empty()) {
        return fallback;
    }
    if (trimmed_language.empty()) {
        return trimmed_code;
    }
    if (trimmed_code.empty()) {
        return trimmed_language;
    }
    return trimmed_language + " (" + trimmed_code + ")";
}

TransformPromptPlan cleanup_plan(const std::string& cleaned_input) {
    return {
        .system_prompt =
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
            "Output only the corrected text.",
        .user_content = cleaned_input,
        .request_format = TransformRequestFormat::SystemAndUser,
    };
}

TransformPromptPlan translation_plan(
    const std::string& cleaned_input,
    const TransformPromptConfig& config
) {
    const std::string source_language = trim(config.translation_source_language);
    const std::string target_language = trim(config.translation_target_language);
    const std::string source_label = format_language_label(
        source_language,
        config.translation_source_code,
        "source"
    );
    const std::string target_label = format_language_label(
        target_language,
        config.translation_target_code,
        "target"
    );
    const std::string source_noun = source_language.empty() ? source_label : source_language;
    const std::string target_noun = target_language.empty() ? target_label : target_language;

    std::string prompt;
    prompt += "You are a professional ";
    prompt += source_label;
    prompt += " to ";
    prompt += target_label;
    prompt += " translator. Your goal is to accurately convey the meaning and nuances of the original ";
    prompt += source_noun;
    prompt += " text while adhering to ";
    prompt += target_noun;
    prompt += " grammar, vocabulary, and cultural sensitivities.\n";
    prompt += "Produce only the ";
    prompt += target_noun;
    prompt += " translation, without any additional explanations or commentary. Please translate the following ";
    prompt += source_noun;
    prompt += " text into ";
    prompt += target_noun;
    prompt += ":";

    const std::string extra = trim(config.translation_extra_instructions);
    if (!extra.empty()) {
        prompt += "\n";
        prompt += extra;
    }

    return {
        .system_prompt = std::move(prompt),
        .user_content = cleaned_input,
        .request_format = config.request_format,
    };
}

TransformPromptPlan custom_prompt_plan(
    const std::string& cleaned_input,
    const TransformPromptConfig& config
) {
    std::string system_prompt = trim(config.custom_prompt);
    if (system_prompt.empty()) {
        system_prompt =
            "You are a text transformation assistant. "
            "Follow the user's requested transformation and return only the final text.";
    }

    return {
        .system_prompt = std::move(system_prompt),
        .user_content = cleaned_input,
        .request_format = config.request_format,
    };
}

}  // namespace

TransformPromptPlan build_transform_prompt(
    const std::string& raw_transcript,
    const TransformPromptConfig& config
) {
    const std::string cleaned_input = trim(raw_transcript);
    if (!config.enabled) {
        return cleanup_plan(cleaned_input);
    }

    switch (config.mode) {
        case TransformPromptMode::Translation:
            return translation_plan(cleaned_input, config);
        case TransformPromptMode::CustomPrompt:
            return custom_prompt_plan(cleaned_input, config);
        case TransformPromptMode::Cleanup:
        default:
            return cleanup_plan(cleaned_input);
    }
}

}  // namespace shinsoku::nativecore
