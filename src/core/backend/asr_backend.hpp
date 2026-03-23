#pragma once

#include <atomic>
#include <string>
#include <vector>

namespace ohmytypeless {

class AsrBackend {
public:
    virtual ~AsrBackend() = default;

    virtual std::string name() const = 0;
    virtual bool supports_streaming() const = 0;
    virtual std::string transcribe(const std::vector<float>& samples,
                                   const std::atomic_bool* cancel_flag = nullptr) const = 0;
};

}  // namespace ohmytypeless
