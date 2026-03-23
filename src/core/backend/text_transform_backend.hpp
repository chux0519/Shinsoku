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

class TextTransformBackend {
public:
    virtual ~TextTransformBackend() = default;

    virtual std::string name() const = 0;
    virtual std::string transform(const TextTransformRequest& request,
                                  const std::atomic_bool* cancel_flag = nullptr) const = 0;
};

}  // namespace ohmytypeless
