package com.shinsoku.mobile.ime

import org.json.JSONObject
import java.util.SortedMap
import java.util.TreeMap

class BailianTranscriptAccumulator {
    sealed interface Event {
        data object TaskStarted : Event
        data class Partial(val text: String) : Event
        data class Finished(val text: String) : Event
        data class Failed(val message: String) : Event
        data object Ignored : Event
    }

    private val sentences: SortedMap<Int, SentenceState> = TreeMap()

    fun reset() {
        sentences.clear()
    }

    fun consume(payload: JSONObject): Event {
        val header = payload.optJSONObject("header") ?: JSONObject()
        return when (header.optString("event")) {
            "task-failed" -> Event.Failed(
                header.optString("error_message").ifBlank { "Bailian returned task-failed." },
            )

            "task-started" -> Event.TaskStarted

            "result-generated" -> {
                val sentence = payload.optJSONObject("payload")
                    ?.optJSONObject("output")
                    ?.optJSONObject("sentence")
                    ?: return Event.Ignored
                val sentenceId = sentence.optInt("sentence_id")
                val text = sentence.optString("text")
                if (sentenceId <= 0 || text.isBlank()) {
                    return Event.Ignored
                }
                sentences[sentenceId] = SentenceState(
                    text = text,
                    isFinal = sentence.optBoolean("sentence_end"),
                )
                Event.Partial(renderText(finalsOnly = false))
            }

            "task-finished" -> Event.Finished(
                renderText(finalsOnly = true).ifBlank { renderText(finalsOnly = false) },
            )

            else -> Event.Ignored
        }
    }

    private fun renderText(finalsOnly: Boolean): String =
        sentences.values.joinToString(separator = "") { sentence ->
            if (finalsOnly && !sentence.isFinal) "" else sentence.text
        }

    private data class SentenceState(
        val text: String,
        val isFinal: Boolean,
    )
}
