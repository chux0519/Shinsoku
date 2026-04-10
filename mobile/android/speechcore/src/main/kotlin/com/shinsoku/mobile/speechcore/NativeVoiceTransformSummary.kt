package com.shinsoku.mobile.speechcore

object NativeVoiceTransformSummary {
    init {
        runCatching { System.loadLibrary("shinsoku_nativecore") }
    }

    fun build(transform: VoiceTransformConfig): String? =
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
        }.getOrNull()?.ifBlank { null }

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
