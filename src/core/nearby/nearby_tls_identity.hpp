#pragma once

#include <filesystem>
#include <string>

namespace ohmytypeless {

struct NearbyTlsIdentity {
    std::string instance_id;
    std::string host_name;
    std::string certificate_sha256;
    std::filesystem::path certificate_path;
    std::filesystem::path private_key_path;
};

class NearbyTlsIdentityStore {
public:
    explicit NearbyTlsIdentityStore(std::filesystem::path directory);

    NearbyTlsIdentity load_or_create();

private:
    std::filesystem::path directory_;
};

}  // namespace ohmytypeless
