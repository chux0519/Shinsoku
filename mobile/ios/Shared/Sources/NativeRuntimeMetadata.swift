import Foundation

struct NativeRuntimeMetadata {
    let providerLabel: String
    let postProcessingLabel: String
    let compactPostProcessingLabel: String

    static func describe(
        providerName: String,
        postProcessingMode: String
    ) -> NativeRuntimeMetadata {
        if let values = NativeProfileBridge.describeProviderMetadata(
            withProviderName: providerName,
            postProcessingMode: postProcessingMode
        ), values.count >= 3 {
            return NativeRuntimeMetadata(
                providerLabel: values[0],
                postProcessingLabel: values[1],
                compactPostProcessingLabel: values[2]
            )
        }
        return NativeRuntimeMetadata(
            providerLabel: fallbackProviderLabel(providerName),
            postProcessingLabel: fallbackPostProcessingLabel(postProcessingMode),
            compactPostProcessingLabel: fallbackPostProcessingLabel(postProcessingMode)
        )
    }

    private static func fallbackProviderLabel(_ providerName: String) -> String {
        switch providerName {
        case "OpenAiCompatible":
            return "OpenAI-Compatible"
        case "Soniox":
            return "Soniox"
        case "Bailian":
            return "Bailian"
        default:
            return "Android System"
        }
    }

    private static func fallbackPostProcessingLabel(_ mode: String) -> String {
        switch mode {
        case "Disabled":
            return "Disabled"
        case "ProviderAssisted":
            return "Provider-assisted"
        default:
            return "Local cleanup"
        }
    }
}
