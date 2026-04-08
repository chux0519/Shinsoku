#include "shinsoku/nativecore/transcript_cleanup.hpp"

#include <regex>
#include <stdexcept>
#include <string>

namespace shinsoku::nativecore {

namespace {

std::u32string utf8_to_u32(const std::string& input) {
    std::u32string output;
    output.reserve(input.size());

    for (std::size_t index = 0; index < input.size();) {
        const unsigned char lead = static_cast<unsigned char>(input[index]);
        char32_t codepoint = 0;
        std::size_t width = 0;

        if (lead <= 0x7F) {
            codepoint = lead;
            width = 1;
        } else if ((lead >> 5) == 0x6 && index + 1 < input.size()) {
            codepoint = ((lead & 0x1F) << 6) |
                (static_cast<unsigned char>(input[index + 1]) & 0x3F);
            width = 2;
        } else if ((lead >> 4) == 0xE && index + 2 < input.size()) {
            codepoint = ((lead & 0x0F) << 12) |
                ((static_cast<unsigned char>(input[index + 1]) & 0x3F) << 6) |
                (static_cast<unsigned char>(input[index + 2]) & 0x3F);
            width = 3;
        } else if ((lead >> 3) == 0x1E && index + 3 < input.size()) {
            codepoint = ((lead & 0x07) << 18) |
                ((static_cast<unsigned char>(input[index + 1]) & 0x3F) << 12) |
                ((static_cast<unsigned char>(input[index + 2]) & 0x3F) << 6) |
                (static_cast<unsigned char>(input[index + 3]) & 0x3F);
            width = 4;
        } else {
            throw std::runtime_error("Invalid UTF-8 input");
        }

        output.push_back(codepoint);
        index += width;
    }

    return output;
}

std::string u32_to_utf8(const std::u32string& input) {
    std::string output;
    output.reserve(input.size() * 4);

    for (const char32_t codepoint : input) {
        if (codepoint <= 0x7F) {
            output.push_back(static_cast<char>(codepoint));
        } else if (codepoint <= 0x7FF) {
            output.push_back(static_cast<char>(0xC0 | (codepoint >> 6)));
            output.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
        } else if (codepoint <= 0xFFFF) {
            output.push_back(static_cast<char>(0xE0 | (codepoint >> 12)));
            output.push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F)));
            output.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
        } else {
            output.push_back(static_cast<char>(0xF0 | (codepoint >> 18)));
            output.push_back(static_cast<char>(0x80 | ((codepoint >> 12) & 0x3F)));
            output.push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F)));
            output.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
        }
    }

    return output;
}

bool is_han(char32_t codepoint) {
    return (codepoint >= 0x4E00 && codepoint <= 0x9FFF) ||
        (codepoint >= 0x3400 && codepoint <= 0x4DBF) ||
        (codepoint >= 0x20000 && codepoint <= 0x2A6DF) ||
        (codepoint >= 0x2A700 && codepoint <= 0x2B73F) ||
        (codepoint >= 0x2B740 && codepoint <= 0x2B81F) ||
        (codepoint >= 0x2B820 && codepoint <= 0x2CEAF) ||
        (codepoint >= 0xF900 && codepoint <= 0xFAFF);
}

bool is_ascii_alnum(char32_t codepoint) {
    return (codepoint >= U'0' && codepoint <= U'9') ||
        (codepoint >= U'A' && codepoint <= U'Z') ||
        (codepoint >= U'a' && codepoint <= U'z');
}

bool is_ascii_punctuation(char32_t codepoint) {
    switch (codepoint) {
        case U',':
        case U'.':
        case U';':
        case U':':
        case U'!':
        case U'?':
            return true;
        default:
            return false;
    }
}

std::string normalize_whitespace(const std::string& input) {
    std::string normalized = input;
    normalized = std::regex_replace(normalized, std::regex("[\\t\\r ]+"), " ");
    normalized = std::regex_replace(normalized, std::regex(" *\\n+ *"), "\n");
    normalized = std::regex_replace(normalized, std::regex("^\\s+|\\s+$"), "");
    normalized = std::regex_replace(normalized, std::regex("\\s+([,.;:!?])"), "$1");
    return normalized;
}

}  // namespace

std::string cleanup_transcript(const std::string& input) {
    const std::string normalized_utf8 = normalize_whitespace(input);
    if (normalized_utf8.empty()) {
        return normalized_utf8;
    }

    const std::u32string normalized = utf8_to_u32(normalized_utf8);
    std::u32string output;
    output.reserve(normalized.size() + 8);

    for (std::size_t index = 0; index < normalized.size(); ++index) {
        const char32_t current = normalized[index];
        if (current == U' ' && !output.empty()) {
            const char32_t previous = output.back();
            const char32_t next = index + 1 < normalized.size() ? normalized[index + 1] : U'\0';

            if (is_ascii_punctuation(next)) {
                continue;
            }

            if ((is_han(previous) && is_ascii_alnum(next)) ||
                (is_ascii_alnum(previous) && is_han(next))) {
                output.push_back(U' ');
                continue;
            }

            if (previous == U' ' || next == U' ' || next == U'\0' || previous == U'\n' || next == U'\n') {
                continue;
            }

            output.push_back(U' ');
            continue;
        }

        if (!output.empty()) {
            const char32_t previous = output.back();
            if ((is_han(previous) && is_ascii_alnum(current)) ||
                (is_ascii_alnum(previous) && is_han(current))) {
                if (previous != U' ' && current != U' ') {
                    output.push_back(U' ');
                }
            }
        }

        output.push_back(current);
    }

    return u32_to_utf8(output);
}

}  // namespace shinsoku::nativecore
