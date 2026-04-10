#pragma once

#include <string>
#include <vector>

#include "shinsoku/nativecore/transform_prompt.hpp"

namespace shinsoku::nativecore {

struct BuiltinProfileSpec {
    std::string preset_kind;
    std::string id;
    std::string display_name;
    std::string summary;
    std::string behavior_summary;
    std::string language_tag;
    bool auto_commit = true;
    std::string commit_suffix_mode;
    TransformPromptConfig transform;
};

const std::vector<BuiltinProfileSpec>& builtin_profiles();
std::string builtin_profiles_json();
std::string identify_builtin_profile_id(
    bool auto_commit,
    const std::string& commit_suffix_mode,
    const std::string& language_tag,
    const TransformPromptConfig& transform
);
std::string describe_profile_behavior(
    bool auto_commit,
    const std::string& commit_suffix_mode
);

}  // namespace shinsoku::nativecore
