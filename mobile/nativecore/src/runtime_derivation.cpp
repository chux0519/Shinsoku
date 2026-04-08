#include "shinsoku/nativecore/runtime_derivation.hpp"

namespace shinsoku::nativecore {

TranscriptPostProcessingMode derive_post_processing_mode(
    RecognitionProvider provider,
    const std::string& openai_api_key
) {
    if (provider == RecognitionProvider::OpenAiCompatible && !openai_api_key.empty()) {
        return TranscriptPostProcessingMode::ProviderAssisted;
    }
    return TranscriptPostProcessingMode::LocalCleanup;
}

}  // namespace shinsoku::nativecore
