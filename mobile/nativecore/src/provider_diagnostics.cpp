#include "shinsoku/nativecore/provider_diagnostics.hpp"

#include <algorithm>
#include <cctype>
#include <set>
#include <sstream>
#include <string>

namespace shinsoku::nativecore {

namespace {

std::string trim(std::string value) {
    const auto begin = value.find_first_not_of(" \t\r\n");
    if (begin == std::string::npos) {
        return {};
    }
    const auto end = value.find_last_not_of(" \t\r\n");
    return value.substr(begin, end - begin + 1U);
}

std::string lowercase(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch) {
        return static_cast<char>(std::tolower(ch));
    });
    return value;
}

std::string extract_scheme(const std::string& endpoint) {
    const auto pos = endpoint.find(':');
    if (pos == std::string::npos) {
        return {};
    }
    return lowercase(endpoint.substr(0, pos));
}

std::string extract_host(const std::string& endpoint) {
    const auto scheme_pos = endpoint.find("://");
    const auto start = scheme_pos == std::string::npos ? 0U : scheme_pos + 3U;
    if (start >= endpoint.size()) {
        return {};
    }
    const auto end = endpoint.find_first_of("/?#", start);
    const std::string authority = endpoint.substr(start, end == std::string::npos ? std::string::npos : end - start);
    if (authority.empty()) {
        return {};
    }
    const auto at = authority.rfind('@');
    const std::string host_port = at == std::string::npos ? authority : authority.substr(at + 1U);
    if (host_port.empty()) {
        return {};
    }
    if (host_port.front() == '[') {
        const auto close = host_port.find(']');
        return close == std::string::npos ? host_port : host_port.substr(1U, close - 1U);
    }
    const auto colon = host_port.find(':');
    return colon == std::string::npos ? host_port : host_port.substr(0U, colon);
}

std::string endpoint_debug(const std::string& endpoint) {
    const std::string normalized = trim(endpoint);
    if (normalized.empty()) {
        return "Endpoint: missing";
    }
    std::ostringstream output;
    output << "Endpoint: " << normalized;
    const std::string scheme = extract_scheme(normalized);
    const std::string host = extract_host(normalized);
    if (!host.empty()) {
        output << " • Host: " << host;
    }
    if (!scheme.empty()) {
        output << " • Scheme: " << scheme;
    }
    return output.str();
}

ProviderRuntimeStatus build_remote_status(
    const std::string& provider_name,
    const std::string& endpoint,
    const std::string& api_key,
    const std::string& model,
    const std::set<std::string>& allowed_schemes,
    const std::string& extra_issue = {}
) {
    std::vector<std::string> issues;
    if (trim(api_key).empty()) {
        issues.emplace_back("API key is missing.");
    }
    if (trim(model).empty()) {
        issues.emplace_back("Model is missing.");
    }

    const std::string normalized_endpoint = trim(endpoint);
    if (normalized_endpoint.empty()) {
        issues.emplace_back("Endpoint is missing.");
    } else {
        const std::string scheme = extract_scheme(normalized_endpoint);
        if (allowed_schemes.find(scheme) == allowed_schemes.end()) {
            std::ostringstream schemes;
            bool first = true;
            for (const auto& item : allowed_schemes) {
                if (!first) {
                    schemes << "/";
                }
                schemes << item;
                first = false;
            }
            issues.emplace_back("Endpoint must use " + schemes.str() + ".");
        }
    }

    if (!extra_issue.empty()) {
        issues.push_back(extra_issue);
    }

    if (issues.empty()) {
        return {
            .ready = true,
            .summary = "credentials ready",
            .detail = provider_name + " is configured for live recognition.\n" + endpoint_debug(normalized_endpoint),
        };
    }

    std::ostringstream detail;
    detail << provider_name << " is not ready:";
    for (const auto& issue : issues) {
        detail << " " << issue;
    }
    detail << "\n" << endpoint_debug(normalized_endpoint);
    return {
        .ready = false,
        .summary = "configuration incomplete",
        .detail = detail.str(),
    };
}

}  // namespace

ProviderRuntimeStatus describe_provider_runtime(
    RecognitionProvider provider,
    const std::string& openai_base_url,
    const std::string& openai_api_key,
    const std::string& openai_transcription_model,
    const std::string& soniox_url,
    const std::string& soniox_api_key,
    const std::string& soniox_model,
    const std::string& bailian_region,
    const std::string& bailian_url,
    const std::string& bailian_api_key,
    const std::string& bailian_model
) {
    switch (provider) {
        case RecognitionProvider::AndroidSystem:
            return {
                .ready = true,
                .summary = "on-device ready",
                .detail = "Uses Android system speech recognition. No remote credentials required.",
            };
        case RecognitionProvider::OpenAiCompatible:
            return build_remote_status(
                "OpenAI-compatible",
                openai_base_url,
                openai_api_key,
                openai_transcription_model,
                {"http", "https"}
            );
        case RecognitionProvider::Soniox:
            return build_remote_status(
                "Soniox",
                soniox_url,
                soniox_api_key,
                soniox_model,
                {"ws", "wss"}
            );
        case RecognitionProvider::Bailian:
            return build_remote_status(
                "Bailian",
                bailian_url,
                bailian_api_key,
                bailian_model,
                {"ws", "wss"},
                trim(bailian_region).empty() ? "Region is missing." : ""
            );
    }

    return {};
}

}  // namespace shinsoku::nativecore
