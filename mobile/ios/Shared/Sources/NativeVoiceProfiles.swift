import Foundation

private struct NativeBuiltinProfile: Decodable {
    struct TransformConfig: Decodable {
        let enabled: Bool
        let mode: String
        let requestFormat: String
        let customPrompt: String
        let translationSourceLanguage: String
        let translationSourceCode: String
        let translationTargetLanguage: String
        let translationTargetCode: String
        let translationExtraInstructions: String

        enum CodingKeys: String, CodingKey {
            case enabled
            case mode
            case requestFormat = "request_format"
            case customPrompt = "custom_prompt"
            case translationSourceLanguage = "translation_source_language"
            case translationSourceCode = "translation_source_code"
            case translationTargetLanguage = "translation_target_language"
            case translationTargetCode = "translation_target_code"
            case translationExtraInstructions = "translation_extra_instructions"
        }
    }

    let presetKind: String
    let id: String
    let displayName: String
    let summary: String
    let behaviorSummary: String
    let languageTag: String
    let autoCommit: Bool
    let commitSuffixMode: String
    let transform: TransformConfig

    enum CodingKeys: String, CodingKey {
        case presetKind = "preset_kind"
        case id
        case displayName = "display_name"
        case summary
        case behaviorSummary = "behavior_summary"
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

    static func identifyBuiltIn(_ profile: VoiceProfile) -> String? {
        NativeProfileBridge.identifyBuiltInProfileID(
            withAutoCommit: profile.autoCommit,
            commitSuffixMode: profile.commitSuffixMode.rawValue,
            languageTag: profile.languageTag ?? "",
            enabled: profile.transform.enabled,
            mode: profile.transform.mode.rawValue,
            requestFormat: profile.transform.requestFormat.rawValue,
            customPrompt: profile.transform.customPrompt,
            translationSourceLanguage: profile.transform.translationSourceLanguage,
            translationSourceCode: profile.transform.translationSourceCode,
            translationTargetLanguage: profile.transform.translationTargetLanguage,
            translationTargetCode: profile.transform.translationTargetCode,
            translationExtraInstructions: profile.transform.translationExtraInstructions
        )
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
            summary: native.summary,
            mode: mode,
            languageTag: native.languageTag.isEmpty ? nil : native.languageTag,
            autoCommit: native.autoCommit,
            commitSuffixMode: VoiceCommitSuffixMode(rawValue: native.commitSuffixMode) ?? .space,
            nativeBehaviorSummary: native.behaviorSummary,
            transform: VoiceTransformConfig(
                enabled: native.transform.enabled,
                mode: VoiceTransformMode(rawValue: native.transform.mode.lowercased()) ?? .cleanup,
                requestFormat: VoiceRefineRequestFormat(rawValue: native.transform.requestFormat.lowercased()) ?? .systemAndUser,
                customPrompt: native.transform.customPrompt,
                translationSourceLanguage: native.transform.translationSourceLanguage,
                translationSourceCode: native.transform.translationSourceCode,
                translationTargetLanguage: native.transform.translationTargetLanguage,
                translationTargetCode: native.transform.translationTargetCode,
                translationExtraInstructions: native.transform.translationExtraInstructions
            )
        )
    }
}
