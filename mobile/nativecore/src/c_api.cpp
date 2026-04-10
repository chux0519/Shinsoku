#include "shinsoku/nativecore/c_api.h"

#include "shinsoku/nativecore/profile_presets.hpp"

#include <cstdlib>
#include <cstring>

const char* shinsoku_mobile_builtin_profiles_json() {
    const std::string json = shinsoku::nativecore::builtin_profiles_json();
    char* output = static_cast<char*>(std::malloc(json.size() + 1));
    if (output == nullptr) {
        return nullptr;
    }
    std::memcpy(output, json.c_str(), json.size() + 1);
    return output;
}

void shinsoku_mobile_free_string(const char* value) {
    std::free(const_cast<char*>(value));
}
