import Foundation

enum NativeTransformSummary {
    static func describe(transform: VoiceTransformConfig) -> String? {
        NativeProfileBridge.describeTransformEnabled(
            transform.enabled,
            mode: transform.mode.rawValue,
            requestFormat: transform.requestFormat.rawValue,
            customPrompt: transform.customPrompt,
            translationSourceLanguage: transform.translationSourceLanguage,
            translationSourceCode: transform.translationSourceCode,
            translationTargetLanguage: transform.translationTargetLanguage,
            translationTargetCode: transform.translationTargetCode,
            translationExtraInstructions: transform.translationExtraInstructions
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
