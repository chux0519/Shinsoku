#import "NativeProfileBridge.h"

#include "shinsoku/nativecore/c_api.h"
#include "shinsoku/nativecore/provider_metadata.hpp"
#include "shinsoku/nativecore/profile_presets.hpp"
#include "shinsoku/nativecore/transform_prompt.hpp"
#include "shinsoku/nativecore/runtime_derivation.hpp"

@implementation NativeProfileBridge

+ (nullable NSString *)builtinProfilesJSON {
    const char *raw = shinsoku_mobile_builtin_profiles_json();
    if (raw == nullptr) {
        return nil;
    }

    NSString *value = [NSString stringWithUTF8String:raw];
    shinsoku_mobile_free_string(raw);
    return value;
}

+ (nullable NSString *)identifyBuiltInProfileIDWithAutoCommit:(BOOL)autoCommit
                                             commitSuffixMode:(NSString *)commitSuffixMode
                                                  languageTag:(NSString *)languageTag
                                                      enabled:(BOOL)enabled
                                                         mode:(NSString *)mode
                                                requestFormat:(NSString *)requestFormat
                                                 customPrompt:(NSString *)customPrompt
                                    translationSourceLanguage:(NSString *)translationSourceLanguage
                                        translationSourceCode:(NSString *)translationSourceCode
                                    translationTargetLanguage:(NSString *)translationTargetLanguage
                                        translationTargetCode:(NSString *)translationTargetCode
                               translationExtraInstructions:(NSString *)translationExtraInstructions {
    using namespace shinsoku::nativecore;

    TransformPromptConfig config;
    config.enabled = enabled;
    if ([mode isEqualToString:@"translation"]) {
        config.mode = TransformPromptMode::Translation;
    } else if ([mode isEqualToString:@"custom_prompt"]) {
        config.mode = TransformPromptMode::CustomPrompt;
    } else {
        config.mode = TransformPromptMode::Cleanup;
    }

    config.request_format = [requestFormat isEqualToString:@"single_user_message"]
        ? TransformRequestFormat::SingleUserMessage
        : TransformRequestFormat::SystemAndUser;
    config.custom_prompt = customPrompt.UTF8String ?: "";
    config.translation_source_language = translationSourceLanguage.UTF8String ?: "";
    config.translation_source_code = translationSourceCode.UTF8String ?: "";
    config.translation_target_language = translationTargetLanguage.UTF8String ?: "";
    config.translation_target_code = translationTargetCode.UTF8String ?: "";
    config.translation_extra_instructions = translationExtraInstructions.UTF8String ?: "";

    const auto profileID = identify_builtin_profile_id(
        autoCommit,
        commitSuffixMode.UTF8String ?: "",
        languageTag.UTF8String ?: "",
        config
    );
    return profileID.empty() ? nil : [NSString stringWithUTF8String:profileID.c_str()];
}

+ (nullable NSString *)describeProfileBehaviorWithAutoCommit:(BOOL)autoCommit
                                           commitSuffixMode:(NSString *)commitSuffixMode {
    const auto summary = shinsoku::nativecore::describe_profile_behavior(
        autoCommit,
        commitSuffixMode.UTF8String ?: ""
    );
    return [NSString stringWithUTF8String:summary.c_str()] ?: nil;
}

+ (nullable NSArray<NSString *> *)describeProviderMetadataWithProviderName:(NSString *)providerName
                                                       postProcessingMode:(NSString *)postProcessingMode {
    using namespace shinsoku::nativecore;

    RecognitionProvider provider = RecognitionProvider::AndroidSystem;
    if ([providerName isEqualToString:@"OpenAiCompatible"]) {
        provider = RecognitionProvider::OpenAiCompatible;
    } else if ([providerName isEqualToString:@"Soniox"]) {
        provider = RecognitionProvider::Soniox;
    } else if ([providerName isEqualToString:@"Bailian"]) {
        provider = RecognitionProvider::Bailian;
    }

    TranscriptPostProcessingMode mode = TranscriptPostProcessingMode::LocalCleanup;
    if ([postProcessingMode isEqualToString:@"Disabled"]) {
        mode = TranscriptPostProcessingMode::Disabled;
    } else if ([postProcessingMode isEqualToString:@"ProviderAssisted"]) {
        mode = TranscriptPostProcessingMode::ProviderAssisted;
    }

    NSString *providerLabel =
        [NSString stringWithUTF8String:describe_provider_name(provider).c_str()] ?: @"";
    NSString *postProcessingLabel =
        [NSString stringWithUTF8String:describe_post_processing_mode(mode, false).c_str()] ?: @"";
    NSString *compactPostProcessingLabel =
        [NSString stringWithUTF8String:describe_post_processing_mode(mode, true).c_str()] ?: @"";
    return @[providerLabel, postProcessingLabel, compactPostProcessingLabel];
}

+ (nullable NSArray<NSString *> *)buildTransformPromptForTranscript:(NSString *)rawTranscript
                                                           enabled:(BOOL)enabled
                                                              mode:(NSString *)mode
                                                     requestFormat:(NSString *)requestFormat
                                                      customPrompt:(NSString *)customPrompt
                                         translationSourceLanguage:(NSString *)translationSourceLanguage
                                             translationSourceCode:(NSString *)translationSourceCode
                                         translationTargetLanguage:(NSString *)translationTargetLanguage
                                             translationTargetCode:(NSString *)translationTargetCode
                                   translationExtraInstructions:(NSString *)translationExtraInstructions {
    using namespace shinsoku::nativecore;

    TransformPromptConfig config;
    config.enabled = enabled;
    if ([mode isEqualToString:@"translation"]) {
        config.mode = TransformPromptMode::Translation;
    } else if ([mode isEqualToString:@"custom_prompt"]) {
        config.mode = TransformPromptMode::CustomPrompt;
    } else {
        config.mode = TransformPromptMode::Cleanup;
    }

    config.request_format = [requestFormat isEqualToString:@"single_user_message"]
        ? TransformRequestFormat::SingleUserMessage
        : TransformRequestFormat::SystemAndUser;
    config.custom_prompt = customPrompt.UTF8String ?: "";
    config.translation_source_language = translationSourceLanguage.UTF8String ?: "";
    config.translation_source_code = translationSourceCode.UTF8String ?: "";
    config.translation_target_language = translationTargetLanguage.UTF8String ?: "";
    config.translation_target_code = translationTargetCode.UTF8String ?: "";
    config.translation_extra_instructions = translationExtraInstructions.UTF8String ?: "";

    const auto plan = build_transform_prompt(rawTranscript.UTF8String ?: "", config);
    NSString *systemPrompt = [NSString stringWithUTF8String:plan.system_prompt.c_str()] ?: @"";
    NSString *userContent = [NSString stringWithUTF8String:plan.user_content.c_str()] ?: @"";
    NSString *format = plan.request_format == TransformRequestFormat::SingleUserMessage
        ? @"single_user_message"
        : @"system_and_user";
    return @[systemPrompt, userContent, format];
}

+ (nullable NSString *)describeTransformEnabled:(BOOL)enabled
                                           mode:(NSString *)mode
                                  requestFormat:(NSString *)requestFormat
                                   customPrompt:(NSString *)customPrompt
                      translationSourceLanguage:(NSString *)translationSourceLanguage
                          translationSourceCode:(NSString *)translationSourceCode
                      translationTargetLanguage:(NSString *)translationTargetLanguage
                          translationTargetCode:(NSString *)translationTargetCode
                translationExtraInstructions:(NSString *)translationExtraInstructions {
    using namespace shinsoku::nativecore;

    TransformPromptConfig config;
    config.enabled = enabled;
    if ([mode isEqualToString:@"translation"]) {
        config.mode = TransformPromptMode::Translation;
    } else if ([mode isEqualToString:@"custom_prompt"]) {
        config.mode = TransformPromptMode::CustomPrompt;
    } else {
        config.mode = TransformPromptMode::Cleanup;
    }

    config.request_format = [requestFormat isEqualToString:@"single_user_message"]
        ? TransformRequestFormat::SingleUserMessage
        : TransformRequestFormat::SystemAndUser;
    config.custom_prompt = customPrompt.UTF8String ?: "";
    config.translation_source_language = translationSourceLanguage.UTF8String ?: "";
    config.translation_source_code = translationSourceCode.UTF8String ?: "";
    config.translation_target_language = translationTargetLanguage.UTF8String ?: "";
    config.translation_target_code = translationTargetCode.UTF8String ?: "";
    config.translation_extra_instructions = translationExtraInstructions.UTF8String ?: "";

    const auto summary = describe_transform_config(config);
    return [NSString stringWithUTF8String:summary.c_str()] ?: nil;
}

@end
