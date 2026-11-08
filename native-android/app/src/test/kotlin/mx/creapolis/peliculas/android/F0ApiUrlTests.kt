package mx.creapolis.peliculas.android

import mx.creapolis.peliculas.android.core.network.ApiClient
import mx.creapolis.peliculas.android.core.network.ApiError
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** F0: construcción de URLs del backend (port de la lógica de `APIClient.url`). */
class F0ApiUrlTests {

  @Test
  fun `url une base y path con query ordenada`() {
    val url = ApiClient.buildUrl(
      "https://api-peliculas.creapolis.dev", "/v1/tmdb/trending/movie/week",
      mapOf("page" to "2", "language" to "es-MX"),
    )
    assertEquals(
      "https://api-peliculas.creapolis.dev/v1/tmdb/trending/movie/week?language=es-MX&page=2",
      url.toString(),
    )
  }

  @Test
  fun `base con barra final no duplica`() {
    val url = ApiClient.buildUrl("https://api-peliculas.creapolis.dev/", "/healthz")
    assertEquals("https://api-peliculas.creapolis.dev/healthz", url.toString())
  }

  @Test
  fun `query con espacios y caracteres especiales se codifica`() {
    val url = ApiClient.buildUrl(
      "http://10.0.2.2:8787", "/v1/tmdb/search/movie",
      mapOf("query" to "el señor de los anillos"),
    )
    assertTrue(url.toString().contains("query=el%20se%C3%B1or"))
  }

  @Test
  fun `base inválida lanza ApiError`() {
    var thrown: ApiError? = null
    try {
      ApiClient.buildUrl("no-es-un-url", "/x")
    } catch (e: ApiError) {
      thrown = e
    }
    assertEquals("bad_base_url", thrown?.code)
  }
}
