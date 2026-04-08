package com.shinsoku.mobile.ime

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BailianTranscriptAccumulatorTest {
    @Test
    fun accumulates_sentences_and_marks_finished() {
        val accumulator = BailianTranscriptAccumulator()

        val started = accumulator.consume(
            JSONObject()
                .put("header", JSONObject().put("event", "task-started")),
        )
        assertTrue(started is BailianTranscriptAccumulator.Event.TaskStarted)

        val partial = accumulator.consume(
            JSONObject()
                .put("header", JSONObject().put("event", "result-generated"))
                .put(
                    "payload",
                    JSONObject().put(
                        "output",
                        JSONObject().put(
                            "sentence",
                            JSONObject()
                                .put("sentence_id", 1)
                                .put("text", "hello ")
                                .put("sentence_end", true),
                        ),
                    ),
                ),
        )
        assertEquals(
            "hello ",
            (partial as BailianTranscriptAccumulator.Event.Partial).text,
        )

        accumulator.consume(
            JSONObject()
                .put("header", JSONObject().put("event", "result-generated"))
                .put(
                    "payload",
                    JSONObject().put(
                        "output",
                        JSONObject().put(
                            "sentence",
                            JSONObject()
                                .put("sentence_id", 2)
                                .put("text", "world")
                                .put("sentence_end", true),
                        ),
                    ),
                ),
        )

        val finished = accumulator.consume(
            JSONObject()
                .put("header", JSONObject().put("event", "task-finished")),
        )
        assertEquals(
            "hello world",
            (finished as BailianTranscriptAccumulator.Event.Finished).text,
        )
    }
}
