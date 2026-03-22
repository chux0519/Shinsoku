#include "core/wav_encoder.hpp"

#include <algorithm>
#include <bit>
#include <cstdint>
#include <type_traits>

namespace ohmytypeless {

namespace {

template <typename T>
void append_le(std::vector<std::uint8_t>& out, T value) {
    static_assert(std::is_integral_v<T>, "append_le only supports integral types");

    if constexpr (std::endian::native == std::endian::little) {
        const auto* begin = reinterpret_cast<const std::uint8_t*>(&value);
        out.insert(out.end(), begin, begin + sizeof(T));
    } else {
        for (std::size_t i = 0; i < sizeof(T); ++i) {
            out.push_back(static_cast<std::uint8_t>((value >> (i * 8U)) & 0xFF));
        }
    }
}

}  // namespace

std::vector<std::uint8_t> encode_wav_pcm16(const std::vector<float>& samples, std::uint32_t sample_rate) {
    constexpr std::uint16_t channels = 1;
    constexpr std::uint16_t bits_per_sample = 16;
    constexpr std::uint32_t bytes_per_sample = bits_per_sample / 8U;

    const auto data_size = static_cast<std::uint32_t>(samples.size() * bytes_per_sample);
    const auto riff_size = static_cast<std::uint32_t>(36U + data_size);

    std::vector<std::uint8_t> wav;
    wav.reserve(44U + data_size);

    wav.insert(wav.end(), {'R', 'I', 'F', 'F'});
    append_le(wav, riff_size);
    wav.insert(wav.end(), {'W', 'A', 'V', 'E'});
    wav.insert(wav.end(), {'f', 'm', 't', ' '});
    append_le<std::uint32_t>(wav, 16);
    append_le<std::uint16_t>(wav, 1);
    append_le<std::uint16_t>(wav, channels);
    append_le(wav, sample_rate);
    append_le<std::uint32_t>(wav, sample_rate * channels * bytes_per_sample);
    append_le<std::uint16_t>(wav, channels * bits_per_sample / 8U);
    append_le<std::uint16_t>(wav, bits_per_sample);
    wav.insert(wav.end(), {'d', 'a', 't', 'a'});
    append_le(wav, data_size);

    for (float sample : samples) {
        const float clamped = std::clamp(sample, -1.0f, 1.0f);
        const auto pcm = static_cast<std::int16_t>(clamped * 32767.0f);
        append_le(wav, pcm);
    }

    return wav;
}

}  // namespace ohmytypeless
