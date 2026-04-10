#include "shinsoku/nativecore/profile_presets.hpp"

#include <string>

namespace shinsoku::nativecore {

std::string builtin_profiles_json() {
    return R"json(
[
  {
    "preset_kind":"dictation",
    "id":"dictation",
    "display_name":"Dictation",
    "language_tag":"",
    "auto_commit":true,
    "commit_suffix_mode":"Space",
    "transform":{
      "enabled":false,
      "mode":"Cleanup",
      "request_format":"SystemAndUser",
      "custom_prompt":"",
      "translation_source_language":"Chinese",
      "translation_source_code":"zh",
      "translation_target_language":"English",
      "translation_target_code":"en",
      "translation_extra_instructions":""
    }
  },
  {
    "preset_kind":"chat",
    "id":"chat",
    "display_name":"Chat",
    "language_tag":"",
    "auto_commit":true,
    "commit_suffix_mode":"Newline",
    "transform":{
      "enabled":false,
      "mode":"Cleanup",
      "request_format":"SystemAndUser",
      "custom_prompt":"",
      "translation_source_language":"Chinese",
      "translation_source_code":"zh",
      "translation_target_language":"English",
      "translation_target_code":"en",
      "translation_extra_instructions":""
    }
  },
  {
    "preset_kind":"review",
    "id":"review",
    "display_name":"Review",
    "language_tag":"",
    "auto_commit":false,
    "commit_suffix_mode":"None",
    "transform":{
      "enabled":false,
      "mode":"Cleanup",
      "request_format":"SystemAndUser",
      "custom_prompt":"",
      "translation_source_language":"Chinese",
      "translation_source_code":"zh",
      "translation_target_language":"English",
      "translation_target_code":"en",
      "translation_extra_instructions":""
    }
  },
  {
    "preset_kind":"translate_zh_en",
    "id":"translate_zh_en",
    "display_name":"Zh→En",
    "language_tag":"zh-CN",
    "auto_commit":true,
    "commit_suffix_mode":"Space",
    "transform":{
      "enabled":true,
      "mode":"Translation",
      "request_format":"SystemAndUser",
      "custom_prompt":"",
      "translation_source_language":"Chinese",
      "translation_source_code":"zh",
      "translation_target_language":"English",
      "translation_target_code":"en",
      "translation_extra_instructions":""
    }
  }
]
)json";
}

}  // namespace shinsoku::nativecore
