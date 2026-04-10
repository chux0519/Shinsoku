import Foundation

enum NativeTransformSummary {
    static func describe(transform: VoiceTransformConfig) -> String {
        if let nativeSummary = NativeProfileBridge.describeTransformEnabled(
            transform.enabled,
            mode: transform.mode.rawValue,
            requestFormat: transform.requestFormat.rawValue,
            customPrompt: transform.customPrompt,
            translationSourceLanguage: transform.translationSourceLanguage,
            translationSourceCode: transform.translationSourceCode,
            translationTargetLanguage: transform.translationTargetLanguage,
            translationTargetCode: transform.translationTargetCode,
            translationExtraInstructions: transform.translationExtraInstructions
        )?.trimmingCharacters(in: .whitespacesAndNewlines), !nativeSummary.isEmpty {
            return nativeSummary
        }
        return fallbackSummary(transform)
    }

    private static func fallbackSummary(_ transform: VoiceTransformConfig) -> String {
        if !transform.enabled {
            return "Transform disabled. Shinsoku keeps only the configured post-processing mode."
        }
        switch transform.mode {
        case .cleanup:
            return "Transform mode cleanup. Provider-assisted mode will only correct transcript quality without changing language."
        case .translation:
            return "Transform mode translation from \(transform.translationSourceLanguage) to \(transform.translationTargetLanguage)."
        case .customPrompt:
            return "Transform mode custom prompt. Provider-assisted mode will use your custom prompt text."
        }
    }
}
