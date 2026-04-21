#include "core/text_refiner.hpp"

#include "core/curl_support.hpp"

#include <curl/curl.h>
#include <nlohmann/json.hpp>

#include <memory>
#include <stdexcept>
#include <chrono>

namespace ohmytypeless {

namespace {

size_t append_response(char* ptr, size_t size, size_t nmemb, void* userdata) {
    auto* out = static_cast<std::string*>(userdata);
    out->append(ptr, size * nmemb);
    return size * nmemb;
}

std::string trim(std::string value) {
    const auto begin = value.find_first_not_of(" \t\r\n");
    if (begin == std::string::npos) {
        return {};
    }
    const auto end = value.find_last_not_of(" \t\r\n");
    return value.substr(begin, end - begin + 1U);
}

bool uses_single_user_message_format(const RefineStageConfig& config) {
    return config.request_format == "single_user_message";
}

std::string stringify_optional(const std::optional<std::string>& value) {
    return value.has_value() ? value.value() : std::string{};
}

std::string format_language_label(const std::string& language, const std::string& code) {
    const std::string trimmed_language = trim(language);
    const std::string trimmed_code = trim(code);
    if (trimmed_language.empty() && trimmed_code.empty()) {
        return "source";
    }
    if (trimmed_language.empty()) {
        return trimmed_code;
    }
    if (trimmed_code.empty()) {
        return trimmed_language;
    }
    return trimmed_language + " (" + trimmed_code + ")";
}

std::string selection_command_system_prompt() {
    return "You are a text transformation assistant.\n\n"
           "You will receive:\n"
           "1. a spoken instruction\n"
           "2. an input text selection\n\n"
           "Apply the instruction to the input text exactly as requested.\n"
           "You may translate, rewrite, shorten, expand, or restyle the text when the instruction asks for it.\n"
           "Return only the final transformed text.\n"
           "Do not explain what you did.\n"
           "Do not quote the instruction.\n"
           "Do not add commentary or markdown fences.";
}

}  // namespace

TextRefiner::TextRefiner(AppConfig config)
    : fallback_api_(std::move(config.pipeline.asr)),
      config_(std::move(config.pipeline.refine)),
      transport_options_(make_curl_transport_options(config)) {}

std::string TextRefiner::name() const {
    return config_.endpoint.provider.empty() ? "text_refine" : config_.endpoint.provider;
}

std::optional<TextTransformDiagnostics> TextRefiner::last_diagnostics() const {
    return last_diagnostics_;
}

std::string TextRefiner::transform(const TextTransformRequest& request, const std::atomic_bool* cancel_flag) const {
    if (request.input_text.empty()) {
        return {};
    }
    if (request.instruction.empty() || request.instruction == "refine") {
        return refine(request.input_text, cancel_flag);
    }

    const std::string prompt = build_user_prompt(request);
    return request_completion(prompt, selection_command_system_prompt(), true, cancel_flag);
}

std::string TextRefiner::refine(const std::string& text, const std::atomic_bool* cancel_flag) const {
    return request_completion(text, build_refine_system_prompt(), false, cancel_flag);
}

std::string TextRefiner::build_refine_system_prompt() const {
    if (config_.prompt_mode != "structured_translation") {
        return config_.system_prompt;
    }

    const std::string source_language = trim(config_.translation_source_language);
    const std::string target_language = trim(config_.translation_target_language);
    const std::string source_label =
        format_language_label(source_language, config_.translation_source_code);
    const std::string target_label =
        format_language_label(target_language, config_.translation_target_code);
    const std::string source_noun = source_language.empty() ? source_label : source_language;
    const std::string target_noun = target_language.empty() ? target_label : target_language;

    std::string prompt;
    prompt += "You are a professional ";
    prompt += source_label;
    prompt += " to ";
    prompt += target_label;
    prompt += " translator. Your goal is to accurately convey the meaning and nuances of the original ";
    prompt += source_noun;
    prompt += " text while adhering to ";
    prompt += target_noun;
    prompt += " grammar, vocabulary, and cultural sensitivities.\n";
    prompt += "Produce only the ";
    prompt += target_noun;
    prompt += " translation, without any additional explanations or commentary. Please translate the following ";
    prompt += source_noun;
    prompt += " text into ";
    prompt += target_noun;
    prompt += ":";

    const std::string extra_instructions = trim(config_.translation_extra_instructions);
    if (!extra_instructions.empty()) {
        prompt += "\n";
        prompt += extra_instructions;
    }
    return prompt;
}

std::string TextRefiner::request_completion(const std::string& user_content,
                                            const std::string& system_prompt,
                                            bool bypass_enabled_gate,
                                            const std::atomic_bool* cancel_flag) const {
    if (user_content.empty()) {
        return {};
    }
    if (!bypass_enabled_gate && !config_.enabled) {
        return user_content;
    }

    const std::string& base_url =
        config_.endpoint.base_url.empty() ? fallback_api_.base_url : config_.endpoint.base_url;
    const std::string& api_key =
        config_.endpoint.api_key.empty() ? fallback_api_.api_key : config_.endpoint.api_key;
    const std::string& model = config_.endpoint.model;
    if (base_url.empty() || model.empty()) {
        throw std::runtime_error("refine configuration is incomplete");
    }
    if (api_key.empty()) {
        throw std::runtime_error("refine API key is empty");
    }

    ensure_curl_global_init();

    std::unique_ptr<CURL, decltype(&curl_easy_cleanup)> curl(curl_easy_init(), &curl_easy_cleanup);
    if (!curl) {
        throw std::runtime_error("failed to initialize curl");
    }

    nlohmann::json body = {
        {"model", model},
    };
    if (uses_single_user_message_format(config_)) {
        std::string combined_prompt = trim(system_prompt);
        if (!combined_prompt.empty()) {
            combined_prompt += "\n\n";
        }
        combined_prompt += user_content;
        body["messages"] = {{{"role", "user"}, {"content", combined_prompt}}};
    } else {
        body["messages"] = {
            {{"role", "system"}, {"content", system_prompt}},
            {{"role", "user"}, {"content", user_content}},
        };
    }

    std::string response_body;
    const std::string body_string = body.dump();
    const std::string url = base_url + "/chat/completions";

    TextTransformDiagnostics diagnostics;
    diagnostics.provider = config_.endpoint.provider;
    diagnostics.base_url = base_url;
    diagnostics.url = url;
    diagnostics.model = model;
    diagnostics.request_format = config_.request_format;
    diagnostics.request_bytes = body_string.size();
    diagnostics.user_content_chars = user_content.size();
    diagnostics.system_prompt_chars = system_prompt.size();

    curl_easy_setopt(curl.get(), CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl.get(), CURLOPT_WRITEFUNCTION, &append_response);
    curl_easy_setopt(curl.get(), CURLOPT_WRITEDATA, &response_body);
    curl_easy_setopt(curl.get(), CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl.get(), CURLOPT_TIMEOUT, 180L);
    curl_easy_setopt(curl.get(), CURLOPT_POST, 1L);
    curl_easy_setopt(curl.get(), CURLOPT_POSTFIELDS, body_string.c_str());
    curl_easy_setopt(curl.get(), CURLOPT_POSTFIELDSIZE, static_cast<long>(body_string.size()));
    curl_easy_setopt(curl.get(), CURLOPT_NOPROGRESS, 0L);
    apply_curl_transport_options(curl.get(), transport_options_);

    CurlCancelContext cancel_context{cancel_flag};
    curl_easy_setopt(curl.get(), CURLOPT_XFERINFOFUNCTION, &curl_cancel_callback);
    curl_easy_setopt(curl.get(), CURLOPT_XFERINFODATA, &cancel_context);

    struct curl_slist* headers = nullptr;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    const std::string auth_header = "Authorization: Bearer " + api_key;
    headers = curl_slist_append(headers, auth_header.c_str());
    curl_easy_setopt(curl.get(), CURLOPT_HTTPHEADER, headers);

    const auto request_started_at = std::chrono::steady_clock::now();
    const CURLcode result = curl_easy_perform(curl.get());
    diagnostics.wall_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                              std::chrono::steady_clock::now() - request_started_at)
                              .count();
    long http_status = 0;
    curl_easy_getinfo(curl.get(), CURLINFO_RESPONSE_CODE, &http_status);
    diagnostics.http_status = http_status;
    diagnostics.response_bytes = response_body.size();

    double seconds = 0.0;
    if (curl_easy_getinfo(curl.get(), CURLINFO_TOTAL_TIME, &seconds) == CURLE_OK) {
        diagnostics.curl_total_ms = seconds * 1000.0;
    }
    if (curl_easy_getinfo(curl.get(), CURLINFO_NAMELOOKUP_TIME, &seconds) == CURLE_OK) {
        diagnostics.curl_name_lookup_ms = seconds * 1000.0;
    }
    if (curl_easy_getinfo(curl.get(), CURLINFO_CONNECT_TIME, &seconds) == CURLE_OK) {
        diagnostics.curl_connect_ms = seconds * 1000.0;
    }
    if (curl_easy_getinfo(curl.get(), CURLINFO_APPCONNECT_TIME, &seconds) == CURLE_OK) {
        diagnostics.curl_tls_handshake_ms = seconds * 1000.0;
    }
    if (curl_easy_getinfo(curl.get(), CURLINFO_PRETRANSFER_TIME, &seconds) == CURLE_OK) {
        diagnostics.curl_pretransfer_ms = seconds * 1000.0;
    }
    if (curl_easy_getinfo(curl.get(), CURLINFO_STARTTRANSFER_TIME, &seconds) == CURLE_OK) {
        diagnostics.curl_starttransfer_ms = seconds * 1000.0;
    }
    last_diagnostics_ = diagnostics;
    curl_slist_free_all(headers);

    if (result != CURLE_OK) {
        if (result == CURLE_ABORTED_BY_CALLBACK && cancel_flag != nullptr && cancel_flag->load()) {
            throw std::runtime_error("request cancelled");
        }
        throw std::runtime_error(curl_easy_strerror(result));
    }

    const auto json = nlohmann::json::parse(response_body, nullptr, false);
    if (http_status < 200 || http_status >= 300) {
        if (!json.is_discarded() && json.contains("error")) {
            const auto& error = json["error"];
            if (error.is_object() && error.contains("message") && error["message"].is_string()) {
                throw std::runtime_error(error["message"].get<std::string>());
            }
        }
        throw std::runtime_error(trim(response_body));
    }
    if (json.is_discarded()) {
        throw std::runtime_error("text transform response returned invalid JSON");
    }
    if (json.contains("error")) {
        const auto& error = json["error"];
        if (error.is_object() && error.contains("message") && error["message"].is_string()) {
            throw std::runtime_error(error["message"].get<std::string>());
        }
    }
    if (!json.contains("choices") || !json["choices"].is_array() || json["choices"].empty()) {
        throw std::runtime_error("text transform response missing choices");
    }

    const auto& choice = json["choices"][0];
    if (!choice.contains("message") || !choice["message"].contains("content")) {
        throw std::runtime_error("text transform response missing message content");
    }

    std::string output = choice["message"]["content"].get<std::string>();
    if (last_diagnostics_.has_value()) {
        last_diagnostics_->output_chars = output.size();
    }
    return output;
}

std::string TextRefiner::build_user_prompt(const TextTransformRequest& request) const {
    std::string prompt;
    prompt += "Apply the spoken instruction to the provided text.\n";
    prompt += "Return only the transformed text, with no explanation.\n\n";
    prompt += "Instruction:\n";
    prompt += request.instruction;
    prompt += "\n\nInput text:\n";
    prompt += request.input_text;

    const std::string context = stringify_optional(request.context);
    if (!context.empty()) {
        prompt += "\n\nContext:\n";
        prompt += context;
    }
    return prompt;
}

}  // namespace ohmytypeless
