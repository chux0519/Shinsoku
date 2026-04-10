package com.shinsoku.mobile.speechcore

object NativeVoiceTransformPromptBuilder {
    init {
        runCatching { System.loadLibrary("shinsoku_nativecore") }
    }

    fun build(rawTranscript: String, profile: VoiceInputProfile): VoiceTransformPromptPlan? {
        val transform = profile.transform
        val values = runCatching {
            buildPromptPlanNative(
                rawTranscript = rawTranscript,
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
        }.getOrNull() ?: return null

        if (values.size < 3) {
            return null
        }

        return VoiceTransformPromptPlan(
            systemPrompt = values[0],
            userContent = values[1],
            requestFormat = runCatching { VoiceRefineRequestFormat.valueOf(values[2]) }
                .getOrDefault(VoiceRefineRequestFormat.SystemAndUser),
        )
    }

    private external fun buildPromptPlanNative(
        rawTranscript: String,
        enabled: Boolean,
        modeName: String,
        requestFormatName: String,
        customPrompt: String,
        translationSourceLanguage: String,
        translationSourceCode: String,
        translationTargetLanguage: String,
        translationTargetCode: String,
        translationExtraInstructions: String,
    ): Array<String>
}
