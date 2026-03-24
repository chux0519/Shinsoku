#pragma once

#include "core/app_config.hpp"

#include <memory>

namespace ohmytypeless {

class AsrBackend;
class StreamingAsrBackend;
class TextTransformBackend;

std::unique_ptr<AsrBackend> make_asr_backend(const AppConfig& config);
std::unique_ptr<StreamingAsrBackend> make_streaming_asr_backend(const AppConfig& config);
std::unique_ptr<TextTransformBackend> make_refine_backend(const AppConfig& config);

}  // namespace ohmytypeless
