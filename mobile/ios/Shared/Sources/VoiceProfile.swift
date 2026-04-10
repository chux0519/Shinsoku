import Foundation

enum VoiceCommitSuffixMode: String, Hashable {
    case none = "None"
    case space = "Space"
    case newline = "Newline"

    var suffix: String {
        switch self {
        case .none:
            return ""
        case .space:
            return " "
        case .newline:
            return "\n"
        }
    }

    var title: String {
        switch self {
        case .none:
            return "No suffix"
        case .space:
            return "Append space"
        case .newline:
            return "Append newline"
        }
    }
}

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

}

struct VoiceProfile: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let summary: String
    let mode: VoiceCommitMode
    let languageTag: String?
    let autoCommit: Bool
    let commitSuffixMode: VoiceCommitSuffixMode
    let nativeBehaviorSummary: String
    let transform: VoiceTransformConfig

    var commitSuffix: String { commitSuffixMode.suffix }

    var behaviorSummary: String {
        if !nativeBehaviorSummary.isEmpty {
            return nativeBehaviorSummary
        }
        let commitDescription = autoCommit ? "Auto-insert on" : "Review before insert"
        return "\(commitDescription) · \(commitSuffixMode.title)"
    }

    var transformSummary: String {
        NativeTransformSummary.describe(transform: transform)
    }

    static let defaults: [VoiceProfile] = NativeVoiceProfiles.loadBuiltIns() ?? [
        VoiceProfile(
            id: "dictation",
            title: "Dictation",
            summary: "Speak and insert directly.",
            mode: .dictation,
            languageTag: nil,
            autoCommit: true,
            commitSuffixMode: .space,
            nativeBehaviorSummary: "Auto-insert on · Append space",
            transform: VoiceTransformConfig()
        ),
        VoiceProfile(
            id: "chat",
            title: "Chat",
            summary: "Speak and commit with a trailing newline.",
            mode: .chat,
            languageTag: nil,
            autoCommit: true,
            commitSuffixMode: .newline,
            nativeBehaviorSummary: "Auto-insert on · Append newline",
            transform: VoiceTransformConfig()
        ),
        VoiceProfile(
            id: "review",
            title: "Review",
            summary: "Hold results before inserting.",
            mode: .review,
            languageTag: nil,
            autoCommit: false,
            commitSuffixMode: .none,
            nativeBehaviorSummary: "Review before insert · No suffix",
            transform: VoiceTransformConfig()
        ),
        VoiceProfile(
            id: "translate_zh_en",
            title: "Zh→En",
            summary: "Transcribe first, then transform to English.",
            mode: .translateChineseToEnglish,
            languageTag: "zh-CN",
            autoCommit: true,
            commitSuffixMode: .space,
            nativeBehaviorSummary: "Auto-insert on · Append space",
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
