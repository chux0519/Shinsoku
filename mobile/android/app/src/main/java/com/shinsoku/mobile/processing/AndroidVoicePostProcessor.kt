package com.shinsoku.mobile.processing

import android.content.Context
import android.util.Log
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
import java.net.URI
import java.util.concurrent.TimeUnit
import java.util.concurrent.Executors

class AndroidVoicePostProcessor(
    context: Context,
) : VoiceTranscriptPostProcessor {
    companion object {
        private const val POST_PROCESSING_TIMEOUT_SECONDS = 45L
        private const val POST_PROCESSING_MAX_TOKENS = 256
    }

    private val runtimeConfigStore = AndroidVoiceRuntimeConfigStore(context)
    private val executor = Executors.newSingleThreadExecutor()
    private val client = OkHttpClient.Builder()
        .dns(com.shinsoku.mobile.ime.ShinsokuDns)
        .callTimeout(POST_PROCESSING_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(POST_PROCESSING_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
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
            PostProcessingDiagnostics.report("post_process=skipped mode=${runtimeConfig.postProcessingConfig.mode.name}")
            callback.onSuccess(cleaned)
            return
        }
        val promptPlan = VoiceTransformPromptBuilder.build(cleaned, profile)
        val endpoint = providerConfig.openAiPostProcessing.baseUrl.trimEnd('/') + "/chat/completions"
        val model = providerConfig.openAiPostProcessing.model.ifBlank { "gpt-5.4-nano" }

        executor.execute {
            runCatching {
                refineWithOpenAi(
                    promptPlan = promptPlan,
                    baseUrl = providerConfig.openAiPostProcessing.baseUrl,
                    apiKey = providerConfig.openAiPostProcessing.apiKey,
                    model = providerConfig.openAiPostProcessing.model,
                )
            }.onSuccess { refined ->
                PostProcessingDiagnostics.report(
                    "post_process=provider_assisted status=success endpoint=$endpoint model=$model format=${promptPlan.requestFormat.name}",
                )
                callback.onSuccess(refined.ifBlank { cleaned })
            }.onFailure { error ->
                Log.w(
                    "ShinsokuPostProcess",
                    "Provider-assisted post-processing failed, falling back to local cleanup",
                    error,
                )
                val reason = (error.message ?: error.javaClass.simpleName).replace('\n', ' ')
                val reasonShort = fallbackReason(error) ?: "unknown"
                PostProcessingDiagnostics.report(
                    "post_process=provider_assisted status=fallback endpoint=$endpoint model=$model reason_short=$reasonShort reason=$reason",
                )
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

        val endpoint = baseUrl.trimEnd('/') + "/chat/completions"
        val requestBody = JSONObject()
            .put("model", model.ifBlank { "gpt-5.4-nano" })
            .put("messages", messages)
            .put("stream", false)
            .put("max_tokens", POST_PROCESSING_MAX_TOKENS)
            .put("temperature", 0.2)
        if (isDashScopeCompatibleEndpoint(endpoint)) {
            requestBody.put("enable_thinking", false)
        }

        Log.d(
            "ShinsokuPostProcess",
            "Requesting provider-assisted transform. endpoint=$endpoint model=$model format=${promptPlan.requestFormat} dashscope=${isDashScopeCompatibleEndpoint(endpoint)}",
        )
        val request = Request.Builder()
            .url(endpoint)
            .addHeader("Authorization", "Bearer $apiKey")
            .post(requestBody.toString().toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                Log.e(
                    "ShinsokuPostProcess",
                    "Post-processing HTTP failure. code=${response.code} body=$body",
                )
                val compactBody = body.replace('\n', ' ').take(300)
                throw IOException(
                    "http=${response.code} body=${compactBody.ifBlank { "OpenAI post-processing failed with ${response.code}." }}",
                )
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

    private fun isDashScopeCompatibleEndpoint(endpoint: String): Boolean {
        val uri = runCatching { URI(endpoint) }.getOrNull() ?: return false
        val host = uri.host?.lowercase().orEmpty()
        return host == "dashscope.aliyuncs.com" ||
            host == "dashscope-intl.aliyuncs.com" ||
            host == "dashscope-us.aliyuncs.com"
    }

    private fun fallbackReason(error: Throwable): String? {
        val message = error.message.orEmpty()
        if (message.contains("model_not_found", ignoreCase = true)) {
            return "model_not_found"
        }
        if (message.contains("http=429", ignoreCase = true) ||
            message.contains("\"code\":\"1302\"", ignoreCase = true)
        ) {
            return "rate_limited(429)"
        }
        if (message.contains("http=", ignoreCase = true)) {
            val code = Regex("""http=(\d{3})""").find(message)?.groupValues?.getOrNull(1)
            if (!code.isNullOrBlank()) {
                return "http_$code"
            }
        }
        if (message.contains("timeout", ignoreCase = true)) {
            return "timeout"
        }
        return null
    }
}
