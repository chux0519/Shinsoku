#include "core/backend/backend_factory.hpp"

#include "core/asr_client.hpp"
#include "core/backend/asr_backend.hpp"
#include "core/backend/text_transform_backend.hpp"
#include "core/text_refiner.hpp"

namespace ohmytypeless {

std::unique_ptr<AsrBackend> make_asr_backend(const AppConfig& config) {
    return std::make_unique<AsrClient>(config);
}

std::unique_ptr<TextTransformBackend> make_refine_backend(const AppConfig& config) {
    return std::make_unique<TextRefiner>(config);
}

}  // namespace ohmytypeless
