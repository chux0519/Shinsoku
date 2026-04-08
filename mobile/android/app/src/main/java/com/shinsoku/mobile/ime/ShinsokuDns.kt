package com.shinsoku.mobile.ime

import okhttp3.Dns
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.dnsoverhttps.DnsOverHttps
import java.net.InetAddress
import java.net.UnknownHostException

object ShinsokuDns : Dns {
    private val system = Dns.SYSTEM

    private val aliDns = buildDohDns(
        url = "https://dns.alidns.com/dns-query",
        bootstrapHosts = listOf("223.5.5.5", "223.6.6.6"),
    )

    private val googleDns = buildDohDns(
        url = "https://dns.google/dns-query",
        bootstrapHosts = listOf("8.8.8.8", "8.8.4.4"),
    )

    override fun lookup(hostname: String): List<InetAddress> {
        val failures = mutableListOf<Throwable>()
        for (resolver in listOf(system, aliDns, googleDns)) {
            try {
                val addresses = resolver.lookup(hostname)
                if (addresses.isNotEmpty()) {
                    return addresses
                }
            } catch (error: Throwable) {
                failures += error
            }
        }

        val message = buildString {
            append("Unable to resolve host \"")
            append(hostname)
            append("\"")
            if (failures.isNotEmpty()) {
                append(": ")
                append(
                    failures.joinToString(" | ") {
                        val type = it::class.java.simpleName.ifBlank { "Error" }
                        val detail = it.message?.trim().orEmpty().ifBlank { "unknown failure" }
                        "$type: $detail"
                    },
                )
            }
        }
        throw UnknownHostException(message)
    }

    private fun buildDohDns(
        url: String,
        bootstrapHosts: List<String>,
    ): DnsOverHttps {
        val client = OkHttpClient.Builder().dns(system).build()
        val bootstrap = bootstrapHosts.mapNotNull {
            runCatching { InetAddress.getByName(it) }.getOrNull()
        }
        return DnsOverHttps.Builder()
            .client(client)
            .url(url.toHttpUrl())
            .bootstrapDnsHosts(bootstrap)
            .resolvePrivateAddresses(true)
            .build()
    }
}
