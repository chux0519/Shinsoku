#include "shinsoku/nativecore/runtime_derivation.hpp"

namespace shinsoku::nativecore {

TranscriptPostProcessingMode default_post_processing_mode(
    RecognitionProvider /* provider */,
    const std::string& openai_api_key
) {
    if (!openai_api_key.empty()) {
        return TranscriptPostProcessingMode::ProviderAssisted;
    }
    return TranscriptPostProcessingMode::LocalCleanup;
}

TranscriptPostProcessingMode resolve_post_processing_mode(
    TranscriptPostProcessingMode requested_mode,
    RecognitionProvider provider,
    const std::string& openai_api_key
) {
    if (requested_mode == TranscriptPostProcessingMode::Disabled) {
        return TranscriptPostProcessingMode::Disabled;
    }
    if (requested_mode == TranscriptPostProcessingMode::ProviderAssisted &&
        openai_api_key.empty()) {
        return TranscriptPostProcessingMode::LocalCleanup;
    }
    if (requested_mode == TranscriptPostProcessingMode::LocalCleanup) {
        return TranscriptPostProcessingMode::LocalCleanup;
    }
    return default_post_processing_mode(provider, openai_api_key);
}

}  // namespace shinsoku::nativecore
