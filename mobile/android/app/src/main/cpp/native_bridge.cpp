#include <jni.h>

#include <string>

#include "shinsoku/nativecore/transcript_cleanup.hpp"
#include "shinsoku/nativecore/transcript_commit_planner.hpp"
#include "shinsoku/nativecore/runtime_derivation.hpp"

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
Java_com_shinsoku_mobile_processing_NativeVoiceRuntime_derivePostProcessingModeNative(
    JNIEnv* env,
    jobject /* thiz */,
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

    const auto mode = shinsoku::nativecore::derive_post_processing_mode(
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
