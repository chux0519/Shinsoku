#pragma once

#include "core/app_config.hpp"
#include "core/backend/text_transform_backend.hpp"
#include "core/curl_support.hpp"

#include <atomic>
#include <string>

namespace ohmytypeless {

class TextRefiner final : public TextTransformBackend {
public:
    explicit TextRefiner(AppConfig config);

    std::string name() const override;
    std::string transform(const TextTransformRequest& request,
                          const std::atomic_bool* cancel_flag = nullptr) const override;
    std::optional<TextTransformDiagnostics> last_diagnostics() const override;
    std::string refine(const std::string& text, const std::atomic_bool* cancel_flag = nullptr) const;

private:
    std::string build_refine_system_prompt() const;
    std::string build_user_prompt(const TextTransformRequest& request) const;
    std::string request_completion(const std::string& user_content,
                                   const std::string& system_prompt,
                                   bool bypass_enabled_gate,
                                   const std::atomic_bool* cancel_flag) const;

    EndpointConfig fallback_api_;
    RefineStageConfig config_;
    CurlTransportOptions transport_options_;
    mutable std::optional<TextTransformDiagnostics> last_diagnostics_;
};

}  // namespace ohmytypeless
