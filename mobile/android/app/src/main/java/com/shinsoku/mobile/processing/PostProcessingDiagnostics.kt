package com.shinsoku.mobile.processing

import java.util.concurrent.atomic.AtomicReference

object PostProcessingDiagnostics {
    private val latest = AtomicReference<String?>(null)

    fun report(detail: String) {
        latest.set(detail)
    }

    fun consume(): String? = latest.getAndSet(null)
}
