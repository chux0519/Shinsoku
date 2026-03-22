#pragma once

#include <cstdint>
#include <vector>

namespace ohmytypeless {

std::vector<std::uint8_t> encode_wav_pcm16(const std::vector<float>& samples, std::uint32_t sample_rate);

}  // namespace ohmytypeless
