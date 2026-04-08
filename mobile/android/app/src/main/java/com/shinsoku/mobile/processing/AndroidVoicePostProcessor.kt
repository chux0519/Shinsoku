package com.shinsoku.mobile.processing

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast
import com.shinsoku.mobile.R
import com.shinsoku.mobile.settings.AndroidVoiceRuntimeConfigStore
import com.shinsoku.mobile.speechcore.TranscriptPostProcessingMode
import com.shinsoku.mobile.speechcore.VoiceInputProfile
import com.shinsoku.mobile.speechcore.VoiceRefineRequestFormat
import com.shinsoku.mobile.speechcore.VoiceTranscriptPostProcessor
import com.shinsoku.mobile.speechcore.VoiceTranscriptPostProcessorCallback
import com.shinsoku.mobile.speechcore.VoiceTransformPromptBuilder
import okhttp3.Dns
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit
import java.util.concurrent.Executors

class AndroidVoicePostProcessor(
    context: Context,
) : VoiceTranscriptPostProcessor {
    companion object {
        private const val POST_PROCESSING_TIMEOUT_SECONDS = 20L
    }

    private val appContext = context.applicationContext
    private val runtimeConfigStore = AndroidVoiceRuntimeConfigStore(context)
    private val executor = Executors.newSingleThreadExecutor()
    private val client = OkHttpClient.Builder()
        .dns(com.shinsoku.mobile.ime.ShinsokuDns)
        .callTimeout(POST_PROCESSING_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .build()

    override fun process(
        rawText: String,
        profile: VoiceInputProfile,
        callback: VoiceTranscriptPostProcessorCallback,
    ) {
        val cleaned = NativeTranscriptCleanup.cleanupTranscript(rawText)
        if (cleaned.isEmpty()) {
            callback.onSuccess("")
            return
        }

        val runtimeConfig = runtimeConfigStore.loadRuntimeConfig()
        val providerConfig = runtimeConfig.providerConfig
        if (runtimeConfig.postProcessingConfig.mode != TranscriptPostProcessingMode.ProviderAssisted) {
            callback.onSuccess(cleaned)
            return
        }
        val promptPlan = VoiceTransformPromptBuilder.build(cleaned, profile)

        executor.execute {
            runCatching {
                refineWithOpenAi(
                    promptPlan = promptPlan,
                    baseUrl = providerConfig.openAi.baseUrl,
                    apiKey = providerConfig.openAi.apiKey,
                    model = providerConfig.openAi.postProcessingModel,
                )
            }.onSuccess { refined ->
                callback.onSuccess(refined.ifBlank { cleaned })
            }.onFailure { error ->
                Log.w(
                    "ShinsokuPostProcess",
                    "Provider-assisted post-processing failed, falling back to local cleanup",
                    error,
                )
                showFallbackHint(error)
                callback.onSuccess(cleaned)
            }
        }
    }

    private fun refineWithOpenAi(
        promptPlan: com.shinsoku.mobile.speechcore.VoiceTransformPromptPlan,
        baseUrl: String,
        apiKey: String,
        model: String,
    ): String {
        val messages = JSONArray()
        when (promptPlan.requestFormat) {
            VoiceRefineRequestFormat.SystemAndUser -> {
                messages.put(
                    JSONObject()
                        .put("role", "system")
                        .put("content", promptPlan.systemPrompt),
                )
                messages.put(
                    JSONObject()
                        .put("role", "user")
                        .put("content", promptPlan.userContent),
                )
            }

            VoiceRefineRequestFormat.SingleUserMessage -> {
                val mergedPrompt = buildString {
                    append(promptPlan.systemPrompt.trim())
                    append("\n\n")
                    append(promptPlan.userContent)
                }
                messages.put(
                    JSONObject()
                        .put("role", "user")
                        .put("content", mergedPrompt),
                )
            }
        }

        val requestBody = JSONObject()
            .put("model", model.ifBlank { "gpt-5.4-nano" })
            .put("messages", messages)
            .put("stream", false)
            .toString()

        val endpoint = baseUrl.trimEnd('/') + "/chat/completions"
        Log.d(
            "ShinsokuPostProcess",
            "Requesting provider-assisted transform. endpoint=$endpoint model=$model format=${promptPlan.requestFormat}",
        )
        val request = Request.Builder()
            .url(endpoint)
            .addHeader("Authorization", "Bearer $apiKey")
            .post(requestBody.toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                Log.e(
                    "ShinsokuPostProcess",
                    "Post-processing HTTP failure. code=${response.code} body=$body",
                )
                throw IOException(body.ifBlank { "OpenAI post-processing failed with ${response.code}." })
            }
            Log.d(
                "ShinsokuPostProcess",
                "Post-processing success. code=${response.code} body=$body",
            )
            val json = JSONObject(body)
            return json.optJSONArray("choices")
                ?.optJSONObject(0)
                ?.optJSONObject("message")
                ?.optString("content")
                ?.trim()
                .orEmpty()
        }
    }

    private fun showFallbackHint(error: Throwable) {
        val messageRes = if ((error.message ?: "").contains("timeout", ignoreCase = true)) {
            R.string.post_processing_timeout_fallback
        } else {
            R.string.post_processing_failure_fallback
        }
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(appContext, appContext.getString(messageRes), Toast.LENGTH_SHORT).show()
        }
    }
}
