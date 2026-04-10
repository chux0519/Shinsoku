#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NativeProfileBridge : NSObject

+ (nullable NSString *)builtinProfilesJSON;
+ (nullable NSArray<NSString *> *)buildTransformPromptForTranscript:(NSString *)rawTranscript
                                                           enabled:(BOOL)enabled
                                                              mode:(NSString *)mode
                                                     requestFormat:(NSString *)requestFormat
                                                      customPrompt:(NSString *)customPrompt
                                         translationSourceLanguage:(NSString *)translationSourceLanguage
                                             translationSourceCode:(NSString *)translationSourceCode
                                         translationTargetLanguage:(NSString *)translationTargetLanguage
                                             translationTargetCode:(NSString *)translationTargetCode
                                   translationExtraInstructions:(NSString *)translationExtraInstructions;

@end

NS_ASSUME_NONNULL_END
