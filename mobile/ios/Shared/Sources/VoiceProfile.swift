import Foundation

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

    static let defaults: [VoiceProfile] = [
        VoiceProfile(id: "dictation", title: "Dictation", mode: .dictation, languageTag: nil),
        VoiceProfile(id: "chat", title: "Chat", mode: .chat, languageTag: nil),
        VoiceProfile(id: "review", title: "Review", mode: .review, languageTag: nil),
        VoiceProfile(id: "zh-en", title: "Chinese to English", mode: .translateChineseToEnglish, languageTag: "zh-CN"),
    ]
}
