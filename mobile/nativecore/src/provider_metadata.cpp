#include "shinsoku/nativecore/provider_metadata.hpp"

namespace shinsoku::nativecore {

std::string describe_provider_name(RecognitionProvider provider) {
    switch (provider) {
        case RecognitionProvider::AndroidSystem:
            return "Android System";
        case RecognitionProvider::OpenAiCompatible:
            return "OpenAI-Compatible";
        case RecognitionProvider::Soniox:
            return "Soniox";
        case RecognitionProvider::Bailian:
            return "Bailian";
    }
    return "Android System";
}

std::string describe_post_processing_mode(
    TranscriptPostProcessingMode mode,
    bool compact
) {
    switch (mode) {
        case TranscriptPostProcessingMode::Disabled:
            return "Disabled";
        case TranscriptPostProcessingMode::ProviderAssisted:
            return compact ? "Provider-assisted" : "Provider-assisted";
        case TranscriptPostProcessingMode::LocalCleanup:
        default:
            return compact ? "Local cleanup" : "Local cleanup";
    }
}

}  // namespace shinsoku::nativecore
