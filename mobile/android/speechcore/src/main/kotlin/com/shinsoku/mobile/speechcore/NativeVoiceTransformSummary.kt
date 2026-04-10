package com.shinsoku.mobile.speechcore

object NativeVoiceTransformSummary {
    init {
        runCatching { System.loadLibrary("shinsoku_nativecore") }
    }

    fun build(transform: VoiceTransformConfig): String =
        runCatching {
            buildSummaryNative(
                enabled = transform.enabled,
                modeName = transform.mode.name,
                requestFormatName = transform.requestFormat.name,
                customPrompt = transform.customPrompt,
                translationSourceLanguage = transform.translationSourceLanguage,
                translationSourceCode = transform.translationSourceCode,
                translationTargetLanguage = transform.translationTargetLanguage,
                translationTargetCode = transform.translationTargetCode,
                translationExtraInstructions = transform.translationExtraInstructions,
            )
        }.getOrNull()?.ifBlank { null } ?: fallbackSummary(transform)

    private fun fallbackSummary(transform: VoiceTransformConfig): String =
        when {
            !transform.enabled -> "Transform disabled. Shinsoku keeps only the configured post-processing mode."
            transform.mode == VoiceTransformMode.Cleanup ->
                "Transform mode cleanup. Provider-assisted mode will only correct transcript quality without changing language."
            transform.mode == VoiceTransformMode.Translation ->
                "Transform mode translation from ${transform.translationSourceLanguage} to ${transform.translationTargetLanguage}."
            else ->
                "Transform mode custom prompt. Provider-assisted mode will use your custom prompt text."
        }

    private external fun buildSummaryNative(
        enabled: Boolean,
        modeName: String,
        requestFormatName: String,
        customPrompt: String,
        translationSourceLanguage: String,
        translationSourceCode: String,
        translationTargetLanguage: String,
        translationTargetCode: String,
        translationExtraInstructions: String,
    ): String
}
