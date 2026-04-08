package com.shinsoku.mobile.processing

import com.shinsoku.mobile.speechcore.LocalTranscriptCleanupPostProcessor

object NativeTranscriptCleanup {
    private var nativeLoaded = false

    init {
        nativeLoaded = runCatching {
            System.loadLibrary("shinsoku_nativecore")
            true
        }.getOrDefault(false)
    }

    fun cleanupTranscript(rawText: String): String {
        if (!nativeLoaded) {
            return LocalTranscriptCleanupPostProcessor.cleanupTranscript(rawText)
        }
        return runCatching { cleanupTranscriptNative(rawText) }
            .getOrElse { LocalTranscriptCleanupPostProcessor.cleanupTranscript(rawText) }
    }

    fun planTranscriptCommit(rawText: String, suffixModeName: String): String {
        if (!nativeLoaded) {
            return fallbackCommit(rawText, suffixModeName)
        }
        return runCatching { planTranscriptCommitNative(rawText, suffixModeName) }
            .getOrElse { fallbackCommit(rawText, suffixModeName) }
    }

    private fun fallbackCommit(rawText: String, suffixModeName: String): String =
        rawText + when (suffixModeName) {
            "None" -> ""
            "Newline" -> "\n"
            else -> " "
        }

    private external fun cleanupTranscriptNative(rawText: String): String

    private external fun planTranscriptCommitNative(rawText: String, suffixModeName: String): String
}
