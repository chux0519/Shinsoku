package com.shinsoku.mobile.ime

import java.net.URI

data class EndpointDebug(
    val endpoint: String,
    val scheme: String?,
    val host: String?,
)

object RecognitionEndpointDebug {
    fun from(endpoint: String): EndpointDebug {
        val normalized = endpoint.trim()
        val parsed = runCatching { URI(normalized) }.getOrNull()
        return EndpointDebug(
            endpoint = normalized,
            scheme = parsed?.scheme,
            host = parsed?.host,
        )
    }

    fun describe(endpoint: String): String {
        val debug = from(endpoint)
        return buildString {
            append("Endpoint: ")
            append(if (debug.endpoint.isBlank()) "(empty)" else debug.endpoint)
            if (!debug.host.isNullOrBlank()) {
                append(" • Host: ")
                append(debug.host)
            }
            if (!debug.scheme.isNullOrBlank()) {
                append(" • Scheme: ")
                append(debug.scheme)
            }
        }
    }

    fun formatFailure(providerName: String, endpoint: String, throwable: Throwable): String {
        val detail = describe(endpoint)
        val exceptionName = throwable::class.java.simpleName.ifBlank { "Exception" }
        val message = throwable.message?.trim().orEmpty().ifBlank { "Unknown error." }
        return "$providerName request failed ($exceptionName): $message\n$detail"
    }
}
