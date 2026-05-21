package com.kurogami.template

import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class AppTest {
    @Test
    fun helloEndpointReturnsHelloWorld() {
        val server = App().createServer(0)
        server.start()

        try {
            val response = HttpClient.newHttpClient().send(
                HttpRequest.newBuilder(URI("http://127.0.0.1:${server.address.port}/hello"))
                    .GET()
                    .build(),
                HttpResponse.BodyHandlers.ofString(),
            )

            assertEquals(200, response.statusCode())
            assertEquals("Hello world", response.body())
        } finally {
            server.stop(0)
        }
    }

    @Test
    fun healthEndpointReturnsOk() {
        val server = App().createServer(0)
        server.start()

        try {
            val response = HttpClient.newHttpClient().send(
                HttpRequest.newBuilder(URI("http://127.0.0.1:${server.address.port}/health"))
                    .GET()
                    .build(),
                HttpResponse.BodyHandlers.ofString(),
            )

            assertEquals(200, response.statusCode())
            assertEquals("OK", response.body())
        } finally {
            server.stop(0)
        }
    }
}
