package com.kurogami.template

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpHandler
import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.nio.charset.StandardCharsets
import java.util.concurrent.CountDownLatch

class App(private val greeting: String = "Hello world") {
    fun createServer(port: Int = 8080): HttpServer {
        val server = HttpServer.create(InetSocketAddress("0.0.0.0", port), 0)
        server.createContext("/hello", textHandler(greeting))
        server.createContext("/health", textHandler("OK"))
        return server
    }

    private fun textHandler(body: String): HttpHandler = HttpHandler { exchange ->
        exchange.use {
            if (it.requestMethod != "GET") {
                it.sendResponseHeaders(405, -1)
                return@HttpHandler
            }

            val payload = body.toByteArray(StandardCharsets.UTF_8)
            it.responseHeaders.add("Content-Type", "text/plain; charset=utf-8")
            it.sendResponseHeaders(200, payload.size.toLong())
            it.responseBody.use { output ->
                output.write(payload)
            }
        }
    }
}

fun main() {
    val port = System.getenv("PORT")?.toIntOrNull() ?: 8080
    val server = App().createServer(port)
    val shutdownLatch = CountDownLatch(1)

    Runtime.getRuntime().addShutdownHook(Thread {
        server.stop(0)
        shutdownLatch.countDown()
    })

    server.start()
    println("Server listening on 0.0.0.0:$port")
    shutdownLatch.await()
}
