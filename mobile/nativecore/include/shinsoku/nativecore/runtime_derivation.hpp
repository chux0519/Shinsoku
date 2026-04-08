#pragma once

#include <string>

namespace shinsoku::nativecore {

enum class RecognitionProvider {
    AndroidSystem,
    OpenAiCompatible,
    Soniox,
    Bailian,
};

enum class TranscriptPostProcessingMode {
    Disabled,
    LocalCleanup,
    ProviderAssisted,
};

TranscriptPostProcessingMode derive_post_processing_mode(
    RecognitionProvider provider,
    const std::string& openai_api_key
);

}  // namespace shinsoku::nativecore
