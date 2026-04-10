import Foundation

struct TransformPromptPreview {
    let systemPrompt: String
    let userContent: String
    let requestFormat: VoiceRefineRequestFormat

    var displayPreview: String {
        switch requestFormat {
        case .singleUserMessage:
            let prompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if prompt.isEmpty {
                return userContent
            }
            return "\(prompt)\n\n\(userContent)"
        case .systemAndUser:
            return systemPrompt
        }
    }
}

enum NativeTransformPromptBuilder {
    static func build(rawTranscript: String, transform: VoiceTransformConfig) -> TransformPromptPreview? {
        guard let values = NativeProfileBridge.buildTransformPrompt(
            forTranscript: rawTranscript,
            enabled: transform.enabled,
            mode: transform.mode.rawValue,
            requestFormat: transform.requestFormat.rawValue,
            customPrompt: transform.customPrompt,
            translationSourceLanguage: transform.translationSourceLanguage,
            translationSourceCode: transform.translationSourceCode,
            translationTargetLanguage: transform.translationTargetLanguage,
            translationTargetCode: transform.translationTargetCode,
            translationExtraInstructions: transform.translationExtraInstructions
        ), values.count >= 3 else {
            return nil
        }

        return TransformPromptPreview(
            systemPrompt: values[0],
            userContent: values[1],
            requestFormat: VoiceRefineRequestFormat(rawValue: values[2]) ?? .systemAndUser
        )
    }
}
