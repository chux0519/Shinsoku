#pragma once

#include "core/app_config.hpp"

#include <filesystem>
#include <optional>
#include <vector>

namespace ohmytypeless {

class RecordingStore {
public:
    explicit RecordingStore(AudioConfig config);

    std::optional<std::filesystem::path> save_recording(const std::vector<float>& samples) const;
    void apply_rotation() const;

private:
    AudioConfig config_;
};

}  // namespace ohmytypeless
