import Foundation

enum VoiceTransformMode: String, Hashable {
    case cleanup = "cleanup"
    case translation = "translation"
    case customPrompt = "custom_prompt"
}

enum VoiceRefineRequestFormat: String, Hashable {
    case systemAndUser = "system_and_user"
    case singleUserMessage = "single_user_message"
}

struct VoiceTransformConfig: Equatable, Hashable {
    let enabled: Bool
    let mode: VoiceTransformMode
    let requestFormat: VoiceRefineRequestFormat
    let customPrompt: String
    let translationSourceLanguage: String
    let translationSourceCode: String
    let translationTargetLanguage: String
    let translationTargetCode: String
    let translationExtraInstructions: String

    init(
        enabled: Bool = false,
        mode: VoiceTransformMode = .cleanup,
        requestFormat: VoiceRefineRequestFormat = .systemAndUser,
        customPrompt: String = "",
        translationSourceLanguage: String = "Chinese",
        translationSourceCode: String = "zh",
        translationTargetLanguage: String = "English",
        translationTargetCode: String = "en",
        translationExtraInstructions: String = ""
    ) {
        self.enabled = enabled
        self.mode = mode
        self.requestFormat = requestFormat
        self.customPrompt = customPrompt
        self.translationSourceLanguage = translationSourceLanguage
        self.translationSourceCode = translationSourceCode
        self.translationTargetLanguage = translationTargetLanguage
        self.translationTargetCode = translationTargetCode
        self.translationExtraInstructions = translationExtraInstructions
    }
}

enum VoiceCommitMode: String, CaseIterable, Identifiable, Hashable {
    case dictation
    case chat
    case review
    case translateChineseToEnglish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dictation:
            return "Dictation"
        case .chat:
            return "Chat"
        case .review:
            return "Review"
        case .translateChineseToEnglish:
            return "Zh→En"
        }
    }

    var summary: String {
        switch self {
        case .dictation:
            return "Speak and insert directly."
        case .chat:
            return "Speak and commit with a trailing newline."
        case .review:
            return "Hold results before inserting."
        case .translateChineseToEnglish:
            return "Transcribe first, then transform to English."
        }
    }

    var commitSuffix: String {
        switch self {
        case .dictation, .translateChineseToEnglish:
            return " "
        case .chat:
            return "\n"
        case .review:
            return ""
        }
    }
}

struct VoiceProfile: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let mode: VoiceCommitMode
    let languageTag: String?
    let transform: VoiceTransformConfig

    var transformSummary: String {
        guard transform.enabled else {
            return "Transform disabled."
        }
        switch transform.mode {
        case .cleanup:
            return "Cleanup prompt with \(transform.requestFormat == .singleUserMessage ? "single prompt" : "system + user") format."
        case .translation:
            return "Translate \(transform.translationSourceLanguage) to \(transform.translationTargetLanguage)."
        case .customPrompt:
            return "Custom prompt with \(transform.requestFormat == .singleUserMessage ? "single prompt" : "system + user") format."
        }
    }

    static let defaults: [VoiceProfile] = NativeVoiceProfiles.loadBuiltIns() ?? [
        VoiceProfile(id: "dictation", title: "Dictation", mode: .dictation, languageTag: nil, transform: VoiceTransformConfig()),
        VoiceProfile(id: "chat", title: "Chat", mode: .chat, languageTag: nil, transform: VoiceTransformConfig()),
        VoiceProfile(id: "review", title: "Review", mode: .review, languageTag: nil, transform: VoiceTransformConfig()),
        VoiceProfile(
            id: "translate_zh_en",
            title: "Zh→En",
            mode: .translateChineseToEnglish,
            languageTag: "zh-CN",
            transform: VoiceTransformConfig(
                enabled: true,
                mode: .translation,
                requestFormat: .systemAndUser,
                translationSourceLanguage: "Chinese",
                translationSourceCode: "zh",
                translationTargetLanguage: "English",
                translationTargetCode: "en"
            )
        ),
    ]
}
