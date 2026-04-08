package com.shinsoku.mobile.ime

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SonioxTranscriptAccumulatorTest {
    @Test
    fun accumulates_partial_and_final_tokens() {
        val accumulator = SonioxTranscriptAccumulator()

        val partial = accumulator.consume(
            JSONObject()
                .put(
                    "tokens",
                    JSONArray()
                        .put(
                            JSONObject()
                                .put("start_ms", 0)
                                .put("end_ms", 100)
                                .put("text", "hello ")
                                .put("is_final", true),
                        )
                        .put(
                            JSONObject()
                                .put("start_ms", 100)
                                .put("end_ms", 200)
                                .put("text", "wor")
                                .put("is_final", false),
                        ),
                ),
        )

        assertEquals("hello wor", partial.partialText)
        assertEquals("hello ", partial.finalText)
        assertFalse(partial.finished)

        val finished = accumulator.consume(
            JSONObject()
                .put("finished", true)
                .put(
                    "tokens",
                    JSONArray()
                        .put(
                            JSONObject()
                                .put("start_ms", 100)
                                .put("end_ms", 200)
                                .put("text", "world")
                                .put("is_final", true),
                        )
                        .put(JSONObject().put("text", "<fin>")),
                ),
        )

        assertEquals("hello world", finished.partialText)
        assertEquals("hello world", finished.finalText)
        assertTrue(finished.finished)
    }
}
