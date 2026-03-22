#pragma once

#include "core/app_config.hpp"

#include <atomic>
#include <string>

namespace ohmytypeless {

class TextRefiner {
public:
    explicit TextRefiner(AppConfig config);

    std::string refine(const std::string& text, const std::atomic_bool* cancel_flag = nullptr) const;

private:
    EndpointConfig fallback_api_;
    RefineStageConfig config_;
};

}  // namespace ohmytypeless
