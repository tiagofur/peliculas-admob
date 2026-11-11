package mx.creapolis.peliculas.android

import mx.creapolis.peliculas.android.core.network.TmdbMovie
import mx.creapolis.peliculas.android.features.widget.TrendItems
import mx.creapolis.peliculas.android.ui.navigation.DeepLinkRouter
import mx.creapolis.peliculas.android.ui.navigation.DeepLinkTarget
import mx.creapolis.peliculas.android.core.model.MediaKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Widget de Tendencias: qué títulos enseña y a dónde lleva cada uno. */
class WidgetTests {

  private fun movie(id: Int, title: String?, poster: String? = "/p$id.jpg") =
    TmdbMovie(id = id, title = title, posterPath = poster, voteAverage = 8.24, releaseDate = "2026-03-01")

  @Test
  fun `toma los tres primeros en el orden de TMDB`() {
    val items = TrendItems.from((1..6).map { movie(it, "Peli $it") })
    assertEquals(listOf(1, 2, 3), items.map { it.id })
  }

  @Test
  fun `salta resultados sin titulo o sin id y rellena con los siguientes`() {
    val items = TrendItems.from(listOf(movie(1, "A"), movie(2, " "), movie(0, "X"), movie(3, null), movie(4, "D"), movie(5, "E")))
    assertEquals(listOf(1, 4, 5), items.map { it.id })
  }

  @Test
  fun `sin resultados no inventa nada`() {
    assertTrue(TrendItems.from(emptyList()).isEmpty())
  }

  @Test
  fun `poster vacio cuenta como sin poster`() {
    val item = TrendItems.from(listOf(movie(1, "A", poster = ""))).single()
    assertNull(item.posterUrl("w185"))
    assertEquals("https://image.tmdb.org/t/p/w185/p2.jpg", TrendItems.from(listOf(movie(2, "B"))).single().posterUrl("w185"))
  }

  @Test
  fun `meta muestra anio y nota y omite lo que falte`() {
    assertEquals("2026 · ★ 8.2", TrendItems.from(listOf(movie(1, "A"))).single().meta)
    val bare = TrendItems.from(listOf(TmdbMovie(id = 1, title = "A"))).single()
    assertEquals("", bare.meta)
  }

  @Test
  fun `los enlaces del widget los entiende el router de la app`() {
    val item = TrendItems.from(listOf(movie(550, "Fight Club"))).single()
    assertEquals(DeepLinkTarget.Detail(MediaKind.MOVIE, 550), DeepLinkRouter.parse(item.link))
    assertEquals(DeepLinkTarget.Home, DeepLinkRouter.parse(TrendItems.FALLBACK_LINK))
  }
}
