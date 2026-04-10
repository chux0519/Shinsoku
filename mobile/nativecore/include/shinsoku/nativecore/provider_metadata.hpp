#pragma once

#include <string>

#include "shinsoku/nativecore/runtime_derivation.hpp"

namespace shinsoku::nativecore {

std::string describe_provider_name(RecognitionProvider provider);
std::string describe_post_processing_mode(
    TranscriptPostProcessingMode mode,
    bool compact
);

}  // namespace shinsoku::nativecore
