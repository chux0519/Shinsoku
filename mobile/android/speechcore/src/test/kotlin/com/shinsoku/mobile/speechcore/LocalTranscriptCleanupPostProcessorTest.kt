package com.shinsoku.mobile.speechcore

import kotlin.test.Test
import kotlin.test.assertEquals

class LocalTranscriptCleanupPostProcessorTest {
    @Test
    fun `cleanup normalizes whitespace and punctuation`() {
        val processor = LocalTranscriptCleanupPostProcessor()

        assertEquals(
            "hello, world",
            LocalTranscriptCleanupPostProcessor.cleanupTranscript("  hello  ,   world  "),
        )
    }

    @Test
    fun `cleanup keeps space between chinese and latin text`() {
        val processor = LocalTranscriptCleanupPostProcessor()

        assertEquals(
            "中文 OpenAI 测试",
            LocalTranscriptCleanupPostProcessor.cleanupTranscript("中文OpenAI   测试"),
        )
    }
}
