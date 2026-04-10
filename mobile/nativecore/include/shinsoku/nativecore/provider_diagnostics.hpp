#pragma once

#include "shinsoku/nativecore/runtime_derivation.hpp"

#include <string>

namespace shinsoku::nativecore {

struct ProviderRuntimeStatus {
    bool ready = false;
    std::string summary;
    std::string detail;
};

ProviderRuntimeStatus describe_provider_runtime(
    RecognitionProvider provider,
    const std::string& openai_base_url,
    const std::string& openai_api_key,
    const std::string& openai_transcription_model,
    const std::string& soniox_url,
    const std::string& soniox_api_key,
    const std::string& soniox_model,
    const std::string& bailian_region,
    const std::string& bailian_url,
    const std::string& bailian_api_key,
    const std::string& bailian_model
);

}  // namespace shinsoku::nativecore
