package com.shinsoku.mobile.speechcore

class LocalTranscriptCleanupPostProcessor : VoiceTranscriptPostProcessor {
    override fun process(
        rawText: String,
        profile: VoiceInputProfile,
        callback: VoiceTranscriptPostProcessorCallback,
    ) {
        callback.onSuccess(cleanupTranscript(rawText))
    }

    companion object {
        fun cleanupTranscript(rawText: String): String {
            val trimmed = rawText.trim()
            if (trimmed.isEmpty()) {
                return ""
            }

            val normalizedWhitespace = trimmed
                .replace(Regex("[\\t\\r ]+"), " ")
                .replace(Regex(" *\\n+ *"), "\n")

            return normalizedWhitespace
                .replace(Regex("\\s+([,.;:!?])"), "$1")
                .replace(Regex("([\\p{IsHan}])([A-Za-z0-9])"), "$1 $2")
                .replace(Regex("([A-Za-z0-9])([\\p{IsHan}])"), "$1 $2")
                .replace(Regex("([\\p{IsHan}])\\s+([A-Za-z0-9])"), "$1 $2")
                .replace(Regex("([A-Za-z0-9])\\s+([\\p{IsHan}])"), "$1 $2")
                .trim()
        }
    }
}
