import Foundation

private struct NativeBuiltinProfile: Decodable {
    struct TransformConfig: Decodable {
        let enabled: Bool
        let mode: String
    }

    let presetKind: String
    let id: String
    let displayName: String
    let languageTag: String
    let autoCommit: Bool
    let commitSuffixMode: String
    let transform: TransformConfig

    enum CodingKeys: String, CodingKey {
        case presetKind = "preset_kind"
        case id
        case displayName = "display_name"
        case languageTag = "language_tag"
        case autoCommit = "auto_commit"
        case commitSuffixMode = "commit_suffix_mode"
        case transform
    }
}

enum NativeVoiceProfiles {
    static func loadBuiltIns() -> [VoiceProfile]? {
        guard let raw = NativeProfileBridge.builtinProfilesJSON(),
              let data = raw.data(using: .utf8) else {
            return nil
        }

        let decoded = try? JSONDecoder().decode([NativeBuiltinProfile].self, from: data)
        return decoded?.compactMap(makeProfile)
    }

    private static func makeProfile(from native: NativeBuiltinProfile) -> VoiceProfile? {
        let mode: VoiceCommitMode
        switch native.presetKind {
        case "dictation":
            mode = .dictation
        case "chat":
            mode = .chat
        case "review":
            mode = .review
        case "translate_zh_en":
            mode = .translateChineseToEnglish
        default:
            return nil
        }

        return VoiceProfile(
            id: native.id,
            title: native.displayName,
            mode: mode,
            languageTag: native.languageTag.isEmpty ? nil : native.languageTag
        )
    }
}
