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

    private external fun cleanupTranscriptNative(rawText: String): String
}
