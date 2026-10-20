#include "core/nearby/nearby_tls_identity.hpp"

#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>

#ifndef _WIN32
#include <sys/stat.h>
#endif

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

std::filesystem::path unique_test_directory() {
    const auto suffix = std::chrono::steady_clock::now().time_since_epoch().count();
    return std::filesystem::temp_directory_path() / ("shinsoku-nearby-tls-test-" + std::to_string(suffix));
}

}  // namespace

int main() {
    const std::filesystem::path directory = unique_test_directory();
    try {
        ohmytypeless::NearbyTlsIdentityStore store(directory);
        const ohmytypeless::NearbyTlsIdentity created = store.load_or_create();
        require(created.instance_id.size() == 32U && created.certificate_sha256.size() == 64U &&
                    created.host_name.starts_with("shinsoku-") && created.host_name.ends_with(".local"),
                "a Nearby TLS identity must expose stable instance, host, and fingerprint values");
        require(std::filesystem::exists(created.certificate_path) &&
                    std::filesystem::exists(created.private_key_path),
                "a Nearby TLS identity must persist its certificate and private key");
#ifndef _WIN32
        struct stat key_status {};
        require(::stat(created.private_key_path.c_str(), &key_status) == 0 && (key_status.st_mode & 0777) == 0600,
                "the Nearby TLS private key must be owner-only");
#endif

        const ohmytypeless::NearbyTlsIdentity reloaded = store.load_or_create();
        require(reloaded.instance_id == created.instance_id &&
                    reloaded.certificate_sha256 == created.certificate_sha256,
                "a valid Nearby TLS identity must remain stable across launches");

        {
            std::ofstream corrupt(directory / "identity.json", std::ios::trunc);
            corrupt << "{not-json";
        }
        const ohmytypeless::NearbyTlsIdentity rotated = store.load_or_create();
        require(rotated.instance_id != created.instance_id &&
                    rotated.certificate_sha256 != created.certificate_sha256,
                "a corrupted identity must be replaced instead of being trusted");

        std::filesystem::remove_all(directory);
        std::cout << "nearby_tls_identity_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::filesystem::remove_all(directory);
        std::cerr << "nearby_tls_identity_tests: " << exception.what() << '\n';
        return 1;
    }
}
