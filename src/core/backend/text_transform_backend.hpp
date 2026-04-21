#pragma once

#include <atomic>
#include <optional>
#include <string>

namespace ohmytypeless {

struct TextTransformRequest {
    std::string input_text;
    std::string instruction;
    std::optional<std::string> context;
};

struct TextTransformDiagnostics {
    std::string provider;
    std::string base_url;
    std::string url;
    std::string model;
    std::string request_format;
    long http_status = 0;
    long long wall_ms = 0;
    double curl_total_ms = 0.0;
    double curl_name_lookup_ms = 0.0;
    double curl_connect_ms = 0.0;
    double curl_tls_handshake_ms = 0.0;
    double curl_pretransfer_ms = 0.0;
    double curl_starttransfer_ms = 0.0;
    std::size_t request_bytes = 0;
    std::size_t response_bytes = 0;
    std::size_t user_content_chars = 0;
    std::size_t system_prompt_chars = 0;
    std::size_t output_chars = 0;
};

class TextTransformBackend {
public:
    virtual ~TextTransformBackend() = default;

    virtual std::string name() const = 0;
    virtual std::string transform(const TextTransformRequest& request,
                                  const std::atomic_bool* cancel_flag = nullptr) const = 0;
    virtual std::optional<TextTransformDiagnostics> last_diagnostics() const {
        return std::nullopt;
    }
};

}  // namespace ohmytypeless
