#include "core/asr_client.hpp"

#include "core/curl_support.hpp"
#include "core/wav_encoder.hpp"

#include <curl/curl.h>
#include <nlohmann/json.hpp>

#include <memory>
#include <stdexcept>

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

}  // namespace

AsrClient::AsrClient(AppConfig config)
    : config_(std::move(config.pipeline.asr)),
      transport_options_(make_curl_transport_options(config)),
      sample_rate_(config.audio.sample_rate) {}

std::string AsrClient::transcribe(const std::vector<float>& samples, const std::atomic_bool* cancel_flag) const {
    if (samples.empty()) {
        return {};
    }
    if (config_.base_url.empty()) {
        throw std::runtime_error("ASR base URL is empty");
    }
    if (config_.model.empty()) {
        throw std::runtime_error("ASR model is empty");
    }
    if (config_.api_key.empty()) {
        throw std::runtime_error("ASR API key is empty");
    }

    ensure_curl_global_init();

    std::unique_ptr<CURL, decltype(&curl_easy_cleanup)> curl(curl_easy_init(), &curl_easy_cleanup);
    if (!curl) {
        throw std::runtime_error("failed to initialize curl");
    }

    const auto wav = encode_wav_pcm16(samples, sample_rate_);
    std::string response_body;

    curl_easy_setopt(curl.get(), CURLOPT_URL, (config_.base_url + "/audio/transcriptions").c_str());
    curl_easy_setopt(curl.get(), CURLOPT_WRITEFUNCTION, &append_response);
    curl_easy_setopt(curl.get(), CURLOPT_WRITEDATA, &response_body);
    curl_easy_setopt(curl.get(), CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl.get(), CURLOPT_TIMEOUT, 180L);
    curl_easy_setopt(curl.get(), CURLOPT_NOPROGRESS, 0L);
    apply_curl_transport_options(curl.get(), transport_options_);

    CurlCancelContext cancel_context{cancel_flag};
    curl_easy_setopt(curl.get(), CURLOPT_XFERINFOFUNCTION, &curl_cancel_callback);
    curl_easy_setopt(curl.get(), CURLOPT_XFERINFODATA, &cancel_context);

    struct curl_slist* headers = nullptr;
    const std::string auth_header = "Authorization: Bearer " + config_.api_key;
    headers = curl_slist_append(headers, auth_header.c_str());
    curl_easy_setopt(curl.get(), CURLOPT_HTTPHEADER, headers);

    std::unique_ptr<curl_mime, decltype(&curl_mime_free)> mime(curl_mime_init(curl.get()), &curl_mime_free);
    if (!mime) {
        curl_slist_free_all(headers);
        throw std::runtime_error("failed to create mime body");
    }

    curl_mimepart* part = curl_mime_addpart(mime.get());
    curl_mime_name(part, "model");
    curl_mime_data(part, config_.model.c_str(), CURL_ZERO_TERMINATED);

    part = curl_mime_addpart(mime.get());
    curl_mime_name(part, "response_format");
    curl_mime_data(part, "text", CURL_ZERO_TERMINATED);

    part = curl_mime_addpart(mime.get());
    curl_mime_name(part, "file");
    curl_mime_filename(part, "recording.wav");
    curl_mime_type(part, "audio/wav");
    curl_mime_data(part, reinterpret_cast<const char*>(wav.data()), wav.size());

    curl_easy_setopt(curl.get(), CURLOPT_MIMEPOST, mime.get());

    const CURLcode result = curl_easy_perform(curl.get());
    long http_status = 0;
    curl_easy_getinfo(curl.get(), CURLINFO_RESPONSE_CODE, &http_status);
    curl_slist_free_all(headers);

    if (result != CURLE_OK) {
        if (result == CURLE_ABORTED_BY_CALLBACK && cancel_flag != nullptr && cancel_flag->load()) {
            throw std::runtime_error("request cancelled");
        }
        throw std::runtime_error(curl_easy_strerror(result));
    }

    const std::string trimmed = trim(response_body);
    const auto json = nlohmann::json::parse(trimmed, nullptr, false);

    if (http_status < 200 || http_status >= 300) {
        if (!json.is_discarded() && json.contains("error")) {
            const auto& error = json["error"];
            if (error.is_object() && error.contains("message") && error["message"].is_string()) {
                throw std::runtime_error(error["message"].get<std::string>());
            }
        }
        throw std::runtime_error(trimmed.empty() ? ("ASR request failed with HTTP " + std::to_string(http_status)) : trimmed);
    }

    if (json.is_string()) {
        return trim(json.get<std::string>());
    }
    if (!json.is_discarded() && json.contains("text") && json["text"].is_string()) {
        return trim(json.at("text").get<std::string>());
    }

    return trimmed;
}

}  // namespace ohmytypeless
