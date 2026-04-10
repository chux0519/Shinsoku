#include <jni.h>

#include <string>

#include "shinsoku/nativecore/transcript_cleanup.hpp"
#include "shinsoku/nativecore/transcript_commit_planner.hpp"
#include "shinsoku/nativecore/runtime_derivation.hpp"
#include "shinsoku/nativecore/profile_presets.hpp"
#include "shinsoku/nativecore/transform_prompt.hpp"

namespace {

jstring to_java_string(JNIEnv* env, const std::string& value) {
    return env->NewStringUTF(value.c_str());
}

std::string from_java_string(JNIEnv* env, jstring value) {
    if (value == nullptr) {
        return {};
    }

    const char* chars = env->GetStringUTFChars(value, nullptr);
    if (chars == nullptr) {
        return {};
    }

    const std::string text(chars);
    env->ReleaseStringUTFChars(value, chars);
    return text;
}

}  // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_shinsoku_mobile_processing_NativeTranscriptCleanup_cleanupTranscriptNative(
    JNIEnv* env,
    jobject /* thiz */,
    jstring text
) {
    return to_java_string(env, shinsoku::nativecore::cleanup_transcript(from_java_string(env, text)));
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_shinsoku_mobile_processing_NativeTranscriptCleanup_planTranscriptCommitNative(
    JNIEnv* env,
    jobject /* thiz */,
    jstring text,
    jstring suffix_mode
) {
    const std::string suffix_mode_name = from_java_string(env, suffix_mode);
    shinsoku::nativecore::CommitSuffixMode mode = shinsoku::nativecore::CommitSuffixMode::Space;
    if (suffix_mode_name == "None") {
        mode = shinsoku::nativecore::CommitSuffixMode::None;
    } else if (suffix_mode_name == "Newline") {
        mode = shinsoku::nativecore::CommitSuffixMode::Newline;
    }

    return to_java_string(
        env,
        shinsoku::nativecore::plan_transcript_commit(from_java_string(env, text), mode)
    );
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_shinsoku_mobile_processing_NativeVoiceRuntime_resolvePostProcessingModeNative(
    JNIEnv* env,
    jobject /* thiz */,
    jstring requested_mode_name,
    jstring active_provider_name,
    jstring openai_api_key
) {
    const std::string provider_name = from_java_string(env, active_provider_name);
    shinsoku::nativecore::RecognitionProvider provider = shinsoku::nativecore::RecognitionProvider::AndroidSystem;
    if (provider_name == "OpenAiCompatible") {
        provider = shinsoku::nativecore::RecognitionProvider::OpenAiCompatible;
    } else if (provider_name == "Soniox") {
        provider = shinsoku::nativecore::RecognitionProvider::Soniox;
    } else if (provider_name == "Bailian") {
        provider = shinsoku::nativecore::RecognitionProvider::Bailian;
    }

    const std::string requested_mode_name_value = from_java_string(env, requested_mode_name);
    shinsoku::nativecore::TranscriptPostProcessingMode requested_mode =
        shinsoku::nativecore::TranscriptPostProcessingMode::LocalCleanup;
    if (requested_mode_name_value == "Disabled") {
        requested_mode = shinsoku::nativecore::TranscriptPostProcessingMode::Disabled;
    } else if (requested_mode_name_value == "ProviderAssisted") {
        requested_mode = shinsoku::nativecore::TranscriptPostProcessingMode::ProviderAssisted;
    }

    const auto mode = shinsoku::nativecore::resolve_post_processing_mode(
        requested_mode,
        provider,
        from_java_string(env, openai_api_key)
    );

    switch (mode) {
        case shinsoku::nativecore::TranscriptPostProcessingMode::Disabled:
            return to_java_string(env, "Disabled");
        case shinsoku::nativecore::TranscriptPostProcessingMode::ProviderAssisted:
            return to_java_string(env, "ProviderAssisted");
        case shinsoku::nativecore::TranscriptPostProcessingMode::LocalCleanup:
        default:
            return to_java_string(env, "LocalCleanup");
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_shinsoku_mobile_speechcore_NativeVoiceProfiles_builtinProfilesJsonNative(
    JNIEnv* env,
    jobject /* thiz */
) {
    return to_java_string(env, shinsoku::nativecore::builtin_profiles_json());
}

extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_shinsoku_mobile_speechcore_NativeVoiceTransformPromptBuilder_buildPromptPlanNative(
    JNIEnv* env,
    jobject /* thiz */,
    jstring raw_transcript,
    jboolean enabled,
    jstring mode_name,
    jstring request_format_name,
    jstring custom_prompt,
    jstring translation_source_language,
    jstring translation_source_code,
    jstring translation_target_language,
    jstring translation_target_code,
    jstring translation_extra_instructions
) {
    using shinsoku::nativecore::TransformPromptConfig;
    using shinsoku::nativecore::TransformPromptMode;
    using shinsoku::nativecore::TransformRequestFormat;

    TransformPromptConfig config;
    config.enabled = enabled == JNI_TRUE;

    const std::string mode = from_java_string(env, mode_name);
    if (mode == "Translation") {
        config.mode = TransformPromptMode::Translation;
    } else if (mode == "CustomPrompt") {
        config.mode = TransformPromptMode::CustomPrompt;
    } else {
        config.mode = TransformPromptMode::Cleanup;
    }

    const std::string request_format = from_java_string(env, request_format_name);
    config.request_format = request_format == "SingleUserMessage"
        ? TransformRequestFormat::SingleUserMessage
        : TransformRequestFormat::SystemAndUser;
    config.custom_prompt = from_java_string(env, custom_prompt);
    config.translation_source_language = from_java_string(env, translation_source_language);
    config.translation_source_code = from_java_string(env, translation_source_code);
    config.translation_target_language = from_java_string(env, translation_target_language);
    config.translation_target_code = from_java_string(env, translation_target_code);
    config.translation_extra_instructions = from_java_string(env, translation_extra_instructions);

    const auto plan = shinsoku::nativecore::build_transform_prompt(
        from_java_string(env, raw_transcript),
        config
    );

    jclass string_class = env->FindClass("java/lang/String");
    jobjectArray output = env->NewObjectArray(3, string_class, nullptr);
    env->SetObjectArrayElement(output, 0, to_java_string(env, plan.system_prompt));
    env->SetObjectArrayElement(output, 1, to_java_string(env, plan.user_content));
    env->SetObjectArrayElement(
        output,
        2,
        to_java_string(
            env,
            plan.request_format == TransformRequestFormat::SingleUserMessage
                ? "SingleUserMessage"
                : "SystemAndUser"
        )
    );
    return output;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_shinsoku_mobile_speechcore_NativeVoiceTransformSummary_buildSummaryNative(
    JNIEnv* env,
    jobject /* thiz */,
    jboolean enabled,
    jstring mode_name,
    jstring request_format_name,
    jstring custom_prompt,
    jstring translation_source_language,
    jstring translation_source_code,
    jstring translation_target_language,
    jstring translation_target_code,
    jstring translation_extra_instructions
) {
    using shinsoku::nativecore::TransformPromptConfig;
    using shinsoku::nativecore::TransformPromptMode;
    using shinsoku::nativecore::TransformRequestFormat;

    TransformPromptConfig config;
    config.enabled = enabled == JNI_TRUE;

    const std::string mode = from_java_string(env, mode_name);
    if (mode == "Translation") {
        config.mode = TransformPromptMode::Translation;
    } else if (mode == "CustomPrompt") {
        config.mode = TransformPromptMode::CustomPrompt;
    } else {
        config.mode = TransformPromptMode::Cleanup;
    }

    const std::string request_format = from_java_string(env, request_format_name);
    config.request_format = request_format == "SingleUserMessage"
        ? TransformRequestFormat::SingleUserMessage
        : TransformRequestFormat::SystemAndUser;
    config.custom_prompt = from_java_string(env, custom_prompt);
    config.translation_source_language = from_java_string(env, translation_source_language);
    config.translation_source_code = from_java_string(env, translation_source_code);
    config.translation_target_language = from_java_string(env, translation_target_language);
    config.translation_target_code = from_java_string(env, translation_target_code);
    config.translation_extra_instructions = from_java_string(env, translation_extra_instructions);

    return to_java_string(env, shinsoku::nativecore::describe_transform_config(config));
}
