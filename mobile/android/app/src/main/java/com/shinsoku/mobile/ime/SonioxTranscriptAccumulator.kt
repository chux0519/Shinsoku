package com.shinsoku.mobile.ime

import org.json.JSONArray
import org.json.JSONObject

class SonioxTranscriptAccumulator {
    data class Update(
        val partialText: String,
        val finalText: String,
        val finished: Boolean,
        val errorMessage: String? = null,
    )

    private val aggregateTokens = linkedMapOf<Pair<Int, Int>, TimedToken>()

    fun reset() {
        aggregateTokens.clear()
    }

    fun consume(payload: JSONObject): Update {
        val errorMessage = payload.optString("error_message").takeIf { it.isNotBlank() }
        if (payload.optInt("error_code") != 0 || errorMessage != null) {
            return Update("", "", finished = true, errorMessage = errorMessage ?: "Soniox returned an error.")
        }

        mergeTokens(payload.optJSONArray("tokens"))
        val partialText = renderText(finalsOnly = false)
        val finalText = renderText(finalsOnly = true)
        val finished = payload.optBoolean("finished") || hasFinToken(payload.optJSONArray("tokens"))
        return Update(
            partialText = partialText,
            finalText = finalText,
            finished = finished,
        )
    }

    private fun mergeTokens(tokens: JSONArray?) {
        if (tokens == null) return
        for (index in 0 until tokens.length()) {
            val token = tokens.optJSONObject(index) ?: continue
            val text = token.optString("text")
            if (text.isBlank() || text == "<fin>") continue
            val key = token.optInt("start_ms") to token.optInt("end_ms")
            val existing = aggregateTokens[key]
            aggregateTokens[key] = TimedToken(
                text = text,
                isFinal = existing?.isFinal == true || token.optBoolean("is_final"),
            )
        }
    }

    private fun renderText(finalsOnly: Boolean): String =
        aggregateTokens.values.joinToString(separator = "") { token ->
            if (finalsOnly && !token.isFinal) "" else token.text
        }

    private fun hasFinToken(tokens: JSONArray?): Boolean {
        if (tokens == null) return false
        for (index in 0 until tokens.length()) {
            val token = tokens.optJSONObject(index) ?: continue
            if (token.optString("text") == "<fin>") return true
        }
        return false
    }

    private data class TimedToken(
        val text: String,
        val isFinal: Boolean,
    )
}
