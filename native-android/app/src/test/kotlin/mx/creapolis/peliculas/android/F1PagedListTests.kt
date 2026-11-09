package mx.creapolis.peliculas.android

import kotlinx.coroutines.test.runTest
import mx.creapolis.peliculas.android.core.lists.PagedListState
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.MediaListSource
import mx.creapolis.peliculas.android.core.network.TmdbMovie
import mx.creapolis.peliculas.android.core.network.TmdbPagedMovies
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** F1: infinite scroll (port de los 8 PaginationTests de iOS) + héroe/estrenos. */
class F1PagedListTests {

  private fun page(page: Int, totalPages: Int, ids: List<Int>) = TmdbPagedMovies(
    page = page,
    totalPages = totalPages,
    results = ids.map { TmdbMovie(id = it, title = "Título $it") },
  )

  private fun seedItem(id: Int) = MediaItem(id = id, title = "Seed $id")

  @Test
  fun `seed siembra la primera pagina y sigue desde la segunda`() = runTest {
    val requested = mutableListOf<Int>()
    val state = PagedListState(MediaListSource.NowPlaying, seed = listOf(seedItem(1))) { _, p ->
      requested += p
      page(p, totalPages = 3, ids = listOf(100 + p))
    }
    state.loadMore()
    assertEquals(listOf(2), requested)
    assertEquals(listOf(1, 102), state.state.value.items.map { it.id })
    assertFalse(state.state.value.done)

    state.loadMore()
    assertEquals(listOf(2, 3), requested)
    assertEquals(listOf(1, 102, 103), state.state.value.items.map { it.id })
    assertTrue("totalPages 3 alcanzado", state.state.value.done)

    state.loadMore()
    assertEquals("done corta el load-more", listOf(2, 3), requested)
  }

  @Test
  fun `deduplica titulos repetidos entre paginas`() = runTest {
    val state = PagedListState(MediaListSource.NowPlaying, seed = listOf(seedItem(1))) { _, _ ->
      page(2, totalPages = 99, ids = listOf(1, 2))
    }
    state.loadMore()
    assertEquals(listOf(1, 2), state.state.value.items.map { it.id })
    assertFalse(state.state.value.loadMoreFailed)
  }

  @Test
  fun `una pagina sin titulos nuevos pide la siguiente en la misma carga`() = runTest {
    val requested = mutableListOf<Int>()
    val state = PagedListState(MediaListSource.NowPlaying, seed = listOf(seedItem(1))) { _, p ->
      requested += p
      page(p, totalPages = 9, ids = if (p == 2) listOf(1) else listOf(100 + p))
    }
    state.loadMore()
    assertEquals(listOf(2, 3), requested)
    assertEquals(listOf(1, 103), state.state.value.items.map { it.id })
    assertFalse(state.state.value.loading)
  }

  @Test
  fun `keep filtra resultados y la fila no repite pagina`() = runTest {
    val requested = mutableListOf<Int>()
    val state = PagedListState(
      MediaListSource.Upcoming,
      seed = listOf(seedItem(1)),
      keep = { it.id % 2 == 0 },
    ) { _, p ->
      requested += p
      page(p, totalPages = 3, ids = listOf(10 * p, 10 * p + 1))
    }
    state.loadMore()
    state.loadMore()
    state.loadMore()
    assertEquals(listOf(2, 3), requested)
    assertEquals(listOf(1, 20, 30), state.state.value.items.map { it.id })
    assertTrue(state.state.value.done)
  }

  @Test
  fun `para en el tope defensivo de paginas`() = runTest {
    var calls = 0
    val state = PagedListState(MediaListSource.TopRated(MediaKind.MOVIE), maxPages = 3) { _, _ ->
      calls += 1
      page(calls, totalPages = 500, ids = listOf(calls))
    }
    repeat(5) { state.loadMore() }
    assertEquals(3, calls)
    assertTrue(state.state.value.done)
  }

  @Test
  fun `fallo de primera pagina marca failed y reintenta la misma`() = runTest {
    var calls = 0
    val state = PagedListState(MediaListSource.NowPlaying) { _, _ ->
      calls += 1
      if (calls == 1) throw RuntimeException("sin red")
      page(1, totalPages = 1, ids = listOf(7))
    }
    state.loadMore()
    assertTrue(state.state.value.failed)
    assertTrue(state.state.value.items.isEmpty())
    assertEquals(1, calls)

    state.loadMore()
    assertFalse(state.state.value.failed)
    assertEquals(listOf(7), state.state.value.items.map { it.id })
    assertTrue(state.state.value.done)
  }

  @Test
  fun `fallo de load-more conserva items y ofrece reintentar`() = runTest {
    var calls = 0
    val state = PagedListState(MediaListSource.NowPlaying, seed = listOf(seedItem(1)), maxPages = 2) { _, p ->
      calls += 1
      if (calls == 1) throw RuntimeException("sin red")
      page(p, totalPages = 9, ids = listOf(100 + p))
    }
    state.loadMore()
    assertTrue(state.state.value.loadMoreFailed)
    assertEquals(listOf(1), state.state.value.items.map { it.id })
    assertFalse("con contenido no hay error de pantalla completa", state.state.value.failed)
    assertFalse(state.state.value.done)

    state.loadMore()
    assertFalse(state.state.value.loadMoreFailed)
    assertEquals("reintenta la misma página", listOf(1, 102), state.state.value.items.map { it.id })
    assertTrue("maxPages 2 alcanzado en la segunda carga", state.state.value.done)
  }

  @Test
  fun `resultados vacios marcan done sin error`() = runTest {
    val state = PagedListState(MediaListSource.Upcoming) { _, _ -> page(1, totalPages = 40, ids = emptyList()) }
    state.loadMore()
    assertTrue(state.state.value.done)
    assertTrue(state.state.value.items.isEmpty())
    assertFalse(state.state.value.failed)
  }

  @Test
  fun `loading simultaneo no dispara dos cargas`() = runTest {
    val state = PagedListState(MediaListSource.NowPlaying) { _, p -> page(p, 10, listOf(p)) }
    state.loadMore()
    state.loadMore() // tras done=false pero page 1 de 10: segunda llamada debería avanzar
    assertEquals(listOf(1, 2), state.state.value.items.map { it.id })
  }

  // MARK: Héroe y próximos estrenos (lógica pura portada de iOS)

  private fun heroItem(id: Int, backdrop: String = "/b.jpg", kind: MediaKind = MediaKind.MOVIE) =
    MediaItem(id = id, title = "H$id", backdropPath = backdrop, kind = kind)

  @Test
  fun `heroe intercala peliculas y series y exige fondo`() {
    val day = listOf(
      heroItem(1, backdrop = ""), heroItem(2), heroItem(3), heroItem(4), heroItem(5), heroItem(6),
    )
    val shows = listOf(heroItem(11, kind = MediaKind.TV), heroItem(12, kind = MediaKind.TV))
    val heroes = mx.creapolis.peliculas.android.features.home.buildHeroes(day, shows)
    // iOS: primero intercala (película, serie) — zip(4 primeras, series) —
    // luego añade el resto de películas y FILTRA sin fondo al final.
    // zip = [1,11,2,12] + [5,6]; sin el 1 (sin fondo) ⇒ [11,2,12,5,6].
    assertEquals(listOf(11, 2, 12, 5, 6), heroes.map { it.id })
  }

  @Test
  fun `estrenos futuros filtran por fecha iso`() {
    val today = "2026-11-08"
    val movies = listOf(
      TmdbMovie(id = 1, title = "A", releaseDate = "2026-12-01"),
      TmdbMovie(id = 2, title = "B", releaseDate = "2026-11-08"),
      TmdbMovie(id = 3, title = "C", releaseDate = "2026-11-07"),
      TmdbMovie(id = 4, title = "sin fecha"),
    )
    val upcoming = mx.creapolis.peliculas.android.features.home.filterUpcoming(movies, today)
    assertEquals(listOf(1, 2), upcoming.map { it.id })
  }
}
