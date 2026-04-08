package com.shinsoku.mobile.ime

import com.shinsoku.mobile.speechcore.BailianProviderConfig
import com.shinsoku.mobile.speechcore.OpenAiProviderConfig
import com.shinsoku.mobile.speechcore.SonioxProviderConfig
import com.shinsoku.mobile.speechcore.VoiceProviderConfig
import com.shinsoku.mobile.speechcore.VoiceRecognitionProvider
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecognitionProviderDiagnosticsTest {
    @Test
    fun openai_requires_api_key_and_model() {
        val status = RecognitionProviderDiagnostics.status(
            VoiceProviderConfig(
                activeRecognitionProvider = VoiceRecognitionProvider.OpenAiCompatible,
                openAi = OpenAiProviderConfig(baseUrl = "https://api.openai.com/v1", apiKey = "", model = ""),
            ),
        )

        assertFalse(status.ready)
        assertTrue(status.detail.contains("API key is missing"))
        assertTrue(status.detail.contains("Model is missing"))
    }

    @Test
    fun soniox_accepts_websocket_url() {
        val status = RecognitionProviderDiagnostics.status(
            VoiceProviderConfig(
                activeRecognitionProvider = VoiceRecognitionProvider.Soniox,
                soniox = SonioxProviderConfig(
                    url = "wss://stt-rt.soniox.com/transcribe-websocket",
                    apiKey = "test-key",
                    model = "stt-rt-preview",
                ),
            ),
        )

        assertTrue(status.ready)
    }

    @Test
    fun bailian_requires_region() {
        val status = RecognitionProviderDiagnostics.status(
            VoiceProviderConfig(
                activeRecognitionProvider = VoiceRecognitionProvider.Bailian,
                bailian = BailianProviderConfig(
                    region = "",
                    url = "wss://dashscope.aliyuncs.com/api-ws/v1/inference/",
                    apiKey = "test-key",
                    model = "fun-asr-realtime",
                ),
            ),
        )

        assertFalse(status.ready)
        assertTrue(status.detail.contains("Region is missing"))
    }
}
