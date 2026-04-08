package com.shinsoku.mobile.ime

import okhttp3.Dns
import java.net.UnknownHostException

data class DnsPreflightResult(
    val ok: Boolean,
    val detail: String,
)

object NetworkPreflight {
    fun resolveEndpoint(endpoint: String): DnsPreflightResult {
        val debug = RecognitionEndpointDebug.from(endpoint)
        val host = debug.host
        if (host.isNullOrBlank()) {
            return DnsPreflightResult(
                ok = false,
                detail = "Endpoint host could not be parsed.\n${RecognitionEndpointDebug.describe(endpoint)}",
            )
        }

        return runCatching {
            val addresses = ShinsokuDns.lookup(host)
            val ipSummary = addresses.joinToString(", ") { it.hostAddress.orEmpty() }
            DnsPreflightResult(
                ok = true,
                detail = buildString {
                    append("DNS resolved successfully.\n")
                    append(RecognitionEndpointDebug.describe(endpoint))
                    if (ipSummary.isNotBlank()) {
                        append("\nIPs: ")
                        append(ipSummary)
                    }
                },
            )
        }.getOrElse { error ->
            val message = when (error) {
                is UnknownHostException -> error.message?.trim().orEmpty().ifBlank { "Unknown host." }
                else -> error.message?.trim().orEmpty().ifBlank { "Unknown DNS error." }
            }
            DnsPreflightResult(
                ok = false,
                detail = "DNS preflight failed (${error::class.java.simpleName}): $message\n${RecognitionEndpointDebug.describe(endpoint)}",
            )
        }
    }
}
