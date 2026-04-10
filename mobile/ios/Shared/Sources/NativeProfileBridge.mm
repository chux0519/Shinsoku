#import "NativeProfileBridge.h"

#include "shinsoku/nativecore/c_api.h"
#include "shinsoku/nativecore/transform_prompt.hpp"

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

@end
