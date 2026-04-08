package com.shinsoku.mobile.speechcore

data class VoiceTransformPromptPlan(
    val systemPrompt: String,
    val userContent: String,
    val requestFormat: VoiceRefineRequestFormat,
)

object VoiceTransformPromptBuilder {
    fun build(rawTranscript: String, profile: VoiceInputProfile): VoiceTransformPromptPlan {
        val cleanedInput = rawTranscript.trim()
        val transform = profile.transform
        if (!transform.enabled) {
            return cleanupPlan(cleanedInput)
        }
        return when (transform.mode) {
            VoiceTransformMode.Cleanup -> cleanupPlan(cleanedInput)
            VoiceTransformMode.Translation -> translationPlan(cleanedInput, transform)
            VoiceTransformMode.CustomPrompt -> customPromptPlan(cleanedInput, transform)
        }
    }

    private fun cleanupPlan(cleanedInput: String): VoiceTransformPromptPlan = VoiceTransformPromptPlan(
        systemPrompt =
            "You are a transcription post-processor.\n\n" +
                "Strict rules:\n" +
                "- Do not translate any text.\n" +
                "- Do not change the language of any word or sentence.\n" +
                "- Do not paraphrase, rewrite, summarize, or beautify the user's wording.\n" +
                "- Do not add or remove information.\n" +
                "- Preserve the original wording and meaning as much as possible.\n\n" +
                "Allowed changes only:\n" +
                "- Fix obvious transcription typos.\n" +
                "- Fix punctuation.\n" +
                "- Fix spacing.\n" +
                "- Add proper spaces between Chinese and English when appropriate.\n" +
                "- Add line breaks or sentence breaks only when they improve readability without changing wording.\n\n" +
                "Output only the corrected text.",
        userContent = cleanedInput,
        requestFormat = VoiceRefineRequestFormat.SystemAndUser,
    )

    private fun translationPlan(
        cleanedInput: String,
        transform: VoiceTransformConfig,
    ): VoiceTransformPromptPlan {
        val sourceLabel = formatLanguageLabel(
            transform.translationSourceLanguage,
            transform.translationSourceCode,
            fallback = "source",
        )
        val targetLabel = formatLanguageLabel(
            transform.translationTargetLanguage,
            transform.translationTargetCode,
            fallback = "target",
        )
        val sourceNoun = transform.translationSourceLanguage.trim().ifEmpty { sourceLabel }
        val targetNoun = transform.translationTargetLanguage.trim().ifEmpty { targetLabel }
        val prompt = buildString {
            append("You are a professional ")
            append(sourceLabel)
            append(" to ")
            append(targetLabel)
            append(" translator. Your goal is to accurately convey the meaning and nuances of the original ")
            append(sourceNoun)
            append(" text while adhering to ")
            append(targetNoun)
            append(" grammar, vocabulary, and cultural sensitivities.\n")
            append("Produce only the ")
            append(targetNoun)
            append(" translation, without any additional explanations or commentary. Please translate the following ")
            append(sourceNoun)
            append(" text into ")
            append(targetNoun)
            append(":")
            val extra = transform.translationExtraInstructions.trim()
            if (extra.isNotEmpty()) {
                append("\n")
                append(extra)
            }
        }
        return VoiceTransformPromptPlan(
            systemPrompt = prompt,
            userContent = cleanedInput,
            requestFormat = transform.requestFormat,
        )
    }

    private fun customPromptPlan(
        cleanedInput: String,
        transform: VoiceTransformConfig,
    ): VoiceTransformPromptPlan {
        val systemPrompt = transform.customPrompt.trim().ifEmpty {
            "You are a text transformation assistant. Follow the user's requested transformation and return only the final text."
        }
        return VoiceTransformPromptPlan(
            systemPrompt = systemPrompt,
            userContent = cleanedInput,
            requestFormat = transform.requestFormat,
        )
    }

    private fun formatLanguageLabel(language: String, code: String, fallback: String): String {
        val trimmedLanguage = language.trim()
        val trimmedCode = code.trim()
        return when {
            trimmedLanguage.isEmpty() && trimmedCode.isEmpty() -> fallback
            trimmedLanguage.isEmpty() -> trimmedCode
            trimmedCode.isEmpty() -> trimmedLanguage
            else -> "$trimmedLanguage ($trimmedCode)"
        }
    }
}
