package com.shinsoku.mobile.speechcore

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class VoiceTransformPromptBuilderTest {
    @Test
    fun `cleanup mode keeps system plus user format`() {
        val plan = VoiceTransformPromptBuilder.build(
            rawTranscript = "  hello world  ",
            profile = VoiceInputProfiles.dictation,
        )

        assertEquals(VoiceRefineRequestFormat.SystemAndUser, plan.requestFormat)
        assertEquals("hello world", plan.userContent)
        assertTrue(plan.systemPrompt.contains("Do not translate"))
    }

    @Test
    fun `translation mode builds structured translation prompt`() {
        val plan = VoiceTransformPromptBuilder.build(
            rawTranscript = "你好世界",
            profile = VoiceInputProfiles.translateChineseToEnglish,
        )

        assertEquals(VoiceRefineRequestFormat.SystemAndUser, plan.requestFormat)
        assertEquals("你好世界", plan.userContent)
        assertTrue(plan.systemPrompt.contains("Chinese (zh)"))
        assertTrue(plan.systemPrompt.contains("English (en)"))
        assertTrue(plan.systemPrompt.contains("translator"))
    }

    @Test
    fun `custom prompt mode respects single user format`() {
        val profile = VoiceInputProfile(
            transform = VoiceTransformConfig(
                enabled = true,
                mode = VoiceTransformMode.CustomPrompt,
                requestFormat = VoiceRefineRequestFormat.SingleUserMessage,
                customPrompt = "Rewrite the transcript as a concise standup update.",
            ),
        )

        val plan = VoiceTransformPromptBuilder.build("status update raw", profile)

        assertEquals(VoiceRefineRequestFormat.SingleUserMessage, plan.requestFormat)
        assertEquals("status update raw", plan.userContent)
        assertEquals("Rewrite the transcript as a concise standup update.", plan.systemPrompt)
    }
}
