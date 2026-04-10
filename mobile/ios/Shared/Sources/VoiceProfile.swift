import Foundation

enum VoiceCommitMode: String, CaseIterable, Identifiable {
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

struct VoiceProfile: Identifiable, Equatable {
    let id: String
    let title: String
    let mode: VoiceCommitMode

    static let defaults: [VoiceProfile] = [
        VoiceProfile(id: "dictation", title: "Dictation", mode: .dictation),
        VoiceProfile(id: "chat", title: "Chat", mode: .chat),
        VoiceProfile(id: "review", title: "Review", mode: .review),
        VoiceProfile(id: "zh-en", title: "Chinese to English", mode: .translateChineseToEnglish),
    ]
}
