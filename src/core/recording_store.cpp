#include "core/recording_store.hpp"

#include "core/wav_encoder.hpp"

#include <algorithm>
#include <chrono>
#include <fstream>
#include <stdexcept>

namespace ohmytypeless {

RecordingStore::RecordingStore(AudioConfig config) : config_(std::move(config)) {
    std::filesystem::create_directories(config_.recordings_dir);
}

std::optional<std::filesystem::path> RecordingStore::save_recording(const std::vector<float>& samples) const {
    if (!config_.save_recordings || samples.empty()) {
        return std::nullopt;
    }

    const auto now = std::chrono::system_clock::now();
    const auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count();
    const auto path = config_.recordings_dir / ("recording-" + std::to_string(timestamp) + ".wav");
    const auto wav = encode_wav_pcm16(samples, config_.sample_rate);

    std::ofstream output(path, std::ios::binary);
    if (!output.is_open()) {
        throw std::runtime_error("failed to open recording output file");
    }

    output.write(reinterpret_cast<const char*>(wav.data()), static_cast<std::streamsize>(wav.size()));
    output.close();

    apply_rotation();
    return path;
}

void RecordingStore::apply_rotation() const {
    if (config_.rotation.mode != "max_files" || !config_.rotation.max_files.has_value()) {
        return;
    }

    std::vector<std::filesystem::directory_entry> entries;
    for (const auto& entry : std::filesystem::directory_iterator(config_.recordings_dir)) {
        if (entry.is_regular_file() && entry.path().extension() == ".wav") {
            entries.push_back(entry);
        }
    }

    std::sort(entries.begin(), entries.end(), [](const auto& left, const auto& right) {
        return left.path().filename().string() < right.path().filename().string();
    });

    while (entries.size() > *config_.rotation.max_files) {
        std::filesystem::remove(entries.front().path());
        entries.erase(entries.begin());
    }
}

}  // namespace ohmytypeless
