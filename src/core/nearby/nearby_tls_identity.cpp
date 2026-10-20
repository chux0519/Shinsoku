#include "core/nearby/nearby_tls_identity.hpp"

#include <mbedtls/ctr_drbg.h>
#include <mbedtls/entropy.h>
#include <mbedtls/md.h>
#include <mbedtls/pk.h>
#include <mbedtls/rsa.h>
#include <mbedtls/x509.h>
#include <mbedtls/x509_crt.h>

#include <nlohmann/json.hpp>

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdio>
#include <ctime>
#include <fstream>
#include <optional>
#include <span>
#include <stdexcept>
#include <string_view>
#include <system_error>
#include <utility>
#include <vector>

#ifndef _WIN32
#include <sys/stat.h>
#endif

namespace ohmytypeless {

namespace {

class RandomGenerator {
public:
    RandomGenerator() {
        mbedtls_entropy_init(&entropy_);
        mbedtls_ctr_drbg_init(&generator_);
        constexpr std::string_view personalization = "shinsoku-nearby-tls-v1";
        if (mbedtls_ctr_drbg_seed(&generator_,
                                  mbedtls_entropy_func,
                                  &entropy_,
                                  reinterpret_cast<const unsigned char*>(personalization.data()),
                                  personalization.size()) != 0) {
            throw std::runtime_error("failed to initialize the Nearby TLS random generator");
        }
    }

    ~RandomGenerator() {
        mbedtls_ctr_drbg_free(&generator_);
        mbedtls_entropy_free(&entropy_);
    }

    RandomGenerator(const RandomGenerator&) = delete;
    RandomGenerator& operator=(const RandomGenerator&) = delete;

    std::vector<unsigned char> bytes(std::size_t size) {
        std::vector<unsigned char> result(size);
        if (mbedtls_ctr_drbg_random(&generator_, result.data(), result.size()) != 0) {
            throw std::runtime_error("failed to generate Nearby TLS identity material");
        }
        return result;
    }

    mbedtls_ctr_drbg_context* context() {
        return &generator_;
    }

private:
    mbedtls_entropy_context entropy_{};
    mbedtls_ctr_drbg_context generator_{};
};

class ParsedIdentity {
public:
    ParsedIdentity() {
        mbedtls_x509_crt_init(&certificate);
        mbedtls_pk_init(&private_key);
    }

    ~ParsedIdentity() {
        mbedtls_pk_free(&private_key);
        mbedtls_x509_crt_free(&certificate);
    }

    mbedtls_x509_crt certificate{};
    mbedtls_pk_context private_key{};
};

std::string hex_encode(std::span<const unsigned char> bytes) {
    static constexpr char digits[] = "0123456789abcdef";
    std::string output;
    output.reserve(bytes.size() * 2U);
    for (const unsigned char byte : bytes) {
        output.push_back(digits[(byte >> 4U) & 0x0FU]);
        output.push_back(digits[byte & 0x0FU]);
    }
    return output;
}

std::string certificate_fingerprint(const mbedtls_x509_crt& certificate) {
    const mbedtls_md_info_t* info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
    if (info == nullptr) {
        throw std::runtime_error("SHA-256 is unavailable for the Nearby certificate");
    }
    std::array<unsigned char, 32> digest{};
    if (mbedtls_md(info, certificate.raw.p, certificate.raw.len, digest.data()) != 0) {
        throw std::runtime_error("failed to fingerprint the Nearby certificate");
    }
    return hex_encode(digest);
}

void restrict_file_permissions(const std::filesystem::path& path) {
#ifndef _WIN32
    if (::chmod(path.c_str(), S_IRUSR | S_IWUSR) != 0) {
        throw std::runtime_error("failed to restrict Nearby TLS identity permissions");
    }
#else
    static_cast<void>(path);
#endif
}

std::string utc_timestamp(std::chrono::system_clock::time_point time) {
    const std::time_t value = std::chrono::system_clock::to_time_t(time);
    std::tm utc{};
#ifdef _WIN32
    if (::gmtime_s(&utc, &value) != 0) {
#else
    if (::gmtime_r(&value, &utc) == nullptr) {
#endif
        throw std::runtime_error("failed to format Nearby certificate validity");
    }
    std::array<char, 16> output{};
    if (std::strftime(output.data(), output.size(), "%Y%m%d%H%M%S", &utc) == 0U) {
        throw std::runtime_error("failed to format Nearby certificate validity");
    }
    return output.data();
}

void replace_file(const std::filesystem::path& temporary, const std::filesystem::path& destination) {
    std::error_code error;
    std::filesystem::rename(temporary, destination, error);
    if (error) {
        std::filesystem::remove(destination, error);
        error.clear();
        std::filesystem::rename(temporary, destination, error);
    }
    if (error) {
        std::filesystem::remove(temporary);
        throw std::runtime_error("failed to replace a Nearby TLS identity file");
    }
}

void write_private_file(const std::filesystem::path& path, std::string_view contents) {
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    if (!output) {
        throw std::runtime_error("failed to create a Nearby TLS identity file");
    }
    output.write(contents.data(), static_cast<std::streamsize>(contents.size()));
    output.flush();
    if (!output) {
        throw std::runtime_error("failed to write a Nearby TLS identity file");
    }
    output.close();
    restrict_file_permissions(path);
}

bool valid_metadata_string(const nlohmann::json& document, const char* key, std::size_t length) {
    return document.contains(key) && document.at(key).is_string() &&
           document.at(key).get_ref<const std::string&>().size() == length;
}

std::optional<NearbyTlsIdentity> load_existing(const std::filesystem::path& directory,
                                               RandomGenerator& random) {
    const std::filesystem::path certificate_path = directory / "certificate.pem";
    const std::filesystem::path private_key_path = directory / "private-key.pem";
    const std::filesystem::path metadata_path = directory / "identity.json";
    if (!std::filesystem::exists(certificate_path) || !std::filesystem::exists(private_key_path) ||
        !std::filesystem::exists(metadata_path)) {
        return std::nullopt;
    }

    try {
        std::ifstream metadata_input(metadata_path);
        const nlohmann::json metadata = nlohmann::json::parse(metadata_input);
        if (!metadata.is_object() || metadata.value("schema_version", 0) != 1 ||
            !valid_metadata_string(metadata, "instance_id", 32U) ||
            !valid_metadata_string(metadata, "certificate_sha256", 64U) ||
            !metadata.contains("host_name") || !metadata.at("host_name").is_string()) {
            return std::nullopt;
        }

        ParsedIdentity parsed;
        if (mbedtls_x509_crt_parse_file(&parsed.certificate, certificate_path.c_str()) != 0 ||
            mbedtls_pk_parse_keyfile(&parsed.private_key,
                                     private_key_path.c_str(),
                                     nullptr,
                                     mbedtls_ctr_drbg_random,
                                     random.context()) != 0 ||
            mbedtls_pk_check_pair(&parsed.certificate.pk,
                                  &parsed.private_key,
                                  mbedtls_ctr_drbg_random,
                                  random.context()) != 0 ||
            mbedtls_x509_time_is_future(&parsed.certificate.valid_from) != 0 ||
            mbedtls_x509_time_is_past(&parsed.certificate.valid_to) != 0) {
            return std::nullopt;
        }

        const std::string fingerprint = certificate_fingerprint(parsed.certificate);
        if (fingerprint != metadata.at("certificate_sha256").get<std::string>()) {
            return std::nullopt;
        }
        restrict_file_permissions(private_key_path);
        return NearbyTlsIdentity{
            .instance_id = metadata.at("instance_id").get<std::string>(),
            .host_name = metadata.at("host_name").get<std::string>(),
            .certificate_sha256 = fingerprint,
            .certificate_path = certificate_path,
            .private_key_path = private_key_path,
        };
    } catch (const std::exception&) {
        return std::nullopt;
    }
}

NearbyTlsIdentity create_identity(const std::filesystem::path& directory, RandomGenerator& random) {
    std::filesystem::create_directories(directory);
    const std::vector<unsigned char> instance_bytes = random.bytes(16U);
    const std::string instance_id = hex_encode(instance_bytes);
    const std::string host_name = "shinsoku-" + instance_id.substr(0, 12U) + ".local";

    mbedtls_pk_context key;
    mbedtls_pk_init(&key);
    mbedtls_x509write_cert certificate_writer;
    mbedtls_x509write_crt_init(&certificate_writer);
    try {
        if (mbedtls_pk_setup(&key, mbedtls_pk_info_from_type(MBEDTLS_PK_RSA)) != 0 ||
            mbedtls_rsa_gen_key(mbedtls_pk_rsa(key), mbedtls_ctr_drbg_random, random.context(), 2048, 65537) != 0) {
            throw std::runtime_error("failed to generate the Nearby TLS private key");
        }

        std::vector<unsigned char> serial = random.bytes(16U);
        serial.front() &= 0x7FU;
        if (std::all_of(serial.cbegin(), serial.cend(), [](unsigned char byte) { return byte == 0U; })) {
            serial.back() = 1U;
        }
        const auto now = std::chrono::system_clock::now();
        const std::string valid_from = utc_timestamp(now - std::chrono::hours(24));
        const std::string valid_to = utc_timestamp(now + std::chrono::hours(24 * 365 * 10));
        const std::string distinguished_name = "CN=" + host_name + ",O=Shinsoku Nearby";

        mbedtls_x509write_crt_set_version(&certificate_writer, MBEDTLS_X509_CRT_VERSION_3);
        mbedtls_x509write_crt_set_md_alg(&certificate_writer, MBEDTLS_MD_SHA256);
        mbedtls_x509write_crt_set_subject_key(&certificate_writer, &key);
        mbedtls_x509write_crt_set_issuer_key(&certificate_writer, &key);
        if (mbedtls_x509write_crt_set_serial_raw(&certificate_writer, serial.data(), serial.size()) != 0 ||
            mbedtls_x509write_crt_set_validity(
                &certificate_writer, valid_from.c_str(), valid_to.c_str()) != 0 ||
            mbedtls_x509write_crt_set_subject_name(&certificate_writer, distinguished_name.c_str()) != 0 ||
            mbedtls_x509write_crt_set_issuer_name(&certificate_writer, distinguished_name.c_str()) != 0 ||
            mbedtls_x509write_crt_set_basic_constraints(&certificate_writer, 0, -1) != 0 ||
            mbedtls_x509write_crt_set_key_usage(
                &certificate_writer, MBEDTLS_X509_KU_DIGITAL_SIGNATURE | MBEDTLS_X509_KU_KEY_ENCIPHERMENT) != 0) {
            throw std::runtime_error("failed to configure the Nearby TLS certificate");
        }

        std::vector<unsigned char> host_bytes(host_name.begin(), host_name.end());
        mbedtls_x509_san_list san{};
        san.node.type = MBEDTLS_X509_SAN_DNS_NAME;
        san.node.san.unstructured_name.p = host_bytes.data();
        san.node.san.unstructured_name.len = host_bytes.size();
        if (mbedtls_x509write_crt_set_subject_alternative_name(&certificate_writer, &san) != 0) {
            throw std::runtime_error("failed to add the Nearby TLS host name");
        }

        std::array<unsigned char, 8192> key_pem{};
        std::array<unsigned char, 8192> certificate_pem{};
        if (mbedtls_pk_write_key_pem(&key, key_pem.data(), key_pem.size()) != 0 ||
            mbedtls_x509write_crt_pem(&certificate_writer,
                                      certificate_pem.data(),
                                      certificate_pem.size(),
                                      mbedtls_ctr_drbg_random,
                                      random.context()) != 0) {
            throw std::runtime_error("failed to encode the Nearby TLS identity");
        }

        ParsedIdentity parsed;
        if (mbedtls_x509_crt_parse(&parsed.certificate,
                                   certificate_pem.data(),
                                   std::char_traits<char>::length(
                                       reinterpret_cast<const char*>(certificate_pem.data())) + 1U) != 0) {
            throw std::runtime_error("failed to validate the generated Nearby certificate");
        }
        const std::string fingerprint = certificate_fingerprint(parsed.certificate);

        const std::filesystem::path certificate_path = directory / "certificate.pem";
        const std::filesystem::path private_key_path = directory / "private-key.pem";
        const std::filesystem::path metadata_path = directory / "identity.json";
        const std::filesystem::path certificate_temporary = directory / "certificate.pem.tmp";
        const std::filesystem::path private_key_temporary = directory / "private-key.pem.tmp";
        const std::filesystem::path metadata_temporary = directory / "identity.json.tmp";
        write_private_file(private_key_temporary, reinterpret_cast<const char*>(key_pem.data()));
        write_private_file(certificate_temporary, reinterpret_cast<const char*>(certificate_pem.data()));
        write_private_file(metadata_temporary,
                           nlohmann::json{{"schema_version", 1},
                                          {"instance_id", instance_id},
                                          {"host_name", host_name},
                                          {"certificate_sha256", fingerprint}}
                                   .dump(2) +
                               "\n");
        replace_file(private_key_temporary, private_key_path);
        replace_file(certificate_temporary, certificate_path);
        replace_file(metadata_temporary, metadata_path);
        restrict_file_permissions(private_key_path);

        mbedtls_x509write_crt_free(&certificate_writer);
        mbedtls_pk_free(&key);
        return {
            .instance_id = instance_id,
            .host_name = host_name,
            .certificate_sha256 = fingerprint,
            .certificate_path = certificate_path,
            .private_key_path = private_key_path,
        };
    } catch (...) {
        mbedtls_x509write_crt_free(&certificate_writer);
        mbedtls_pk_free(&key);
        throw;
    }
}

}  // namespace

NearbyTlsIdentityStore::NearbyTlsIdentityStore(std::filesystem::path directory)
    : directory_(std::move(directory)) {}

NearbyTlsIdentity NearbyTlsIdentityStore::load_or_create() {
    RandomGenerator random;
    if (const auto existing = load_existing(directory_, random); existing.has_value()) {
        return *existing;
    }
    return create_identity(directory_, random);
}

}  // namespace ohmytypeless
