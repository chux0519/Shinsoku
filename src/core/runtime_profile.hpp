#pragma once

#include "core/app_config.hpp"

#include <nlohmann/json.hpp>

#include <string>
#include <utility>
#include <vector>

namespace ohmytypeless {

const ProfileConfig* find_profile_by_id(const ProfilesConfig& profiles, const std::string& profile_id);
const ProfileConfig* active_profile(const AppConfig& config);

std::vector<std::pair<std::string, std::string>> profile_items(const AppConfig& config);
std::string active_profile_display_name(const AppConfig& config);
bool active_profile_uses_system_audio(const AppConfig& config);

AppConfig derive_runtime_config(const AppConfig& config);
nlohmann::json capture_context_meta(const AppConfig& config);

}  // namespace ohmytypeless
