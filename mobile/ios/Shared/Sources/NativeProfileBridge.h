#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NativeProfileBridge : NSObject

+ (nullable NSString *)builtinProfilesJSON;
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
                                    translationExtraInstructions:(NSString *)translationExtraInstructions;
+ (nullable NSString *)describeProfileBehaviorWithAutoCommit:(BOOL)autoCommit
                                           commitSuffixMode:(NSString *)commitSuffixMode;
+ (nullable NSArray<NSString *> *)describeProviderMetadataWithProviderName:(NSString *)providerName
                                                       postProcessingMode:(NSString *)postProcessingMode;
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
+ (nullable NSString *)describeTransformEnabled:(BOOL)enabled
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
