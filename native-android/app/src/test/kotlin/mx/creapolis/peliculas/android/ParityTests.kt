package mx.creapolis.peliculas.android

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKey
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.TmdbEpisodeRef
import mx.creapolis.peliculas.android.core.network.TmdbFullDetail
import mx.creapolis.peliculas.android.core.network.TmdbMovie
import mx.creapolis.peliculas.android.core.network.TmdbSeasonSummary
import mx.creapolis.peliculas.android.features.detail.ProviderLinks
import mx.creapolis.peliculas.android.features.people.actorFilmography
import mx.creapolis.peliculas.android.features.upnext.UpNextCalculator
import mx.creapolis.peliculas.android.features.upnext.UpNextStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files
import java.time.LocalDate

/** Paridad con iOS: bugs corregidos y lógica nueva de la app Android. */
class ParityTests {

  private val dune = MediaItem(id = 438631, title = "Dune", posterPath = "/dune.jpg", year = "2021", kind = MediaKind.MOVIE)
  private val blankDune = MediaItem(id = 438631, title = "", kind = MediaKind.MOVIE)

  // MARK: Biblioteca

  @Test
  fun `guardar desde una ficha sin datos conserva el título y el póster conocidos`() {
    val store = LibraryStore()
    store.remember(dune)
    store.toggle(blankDune, LibraryStore.Kind.WATCHLIST)
    val saved = store.state.value.items(LibraryStore.Kind.WATCHLIST).single()
    assertEquals("Dune", saved.title)
    assertEquals("/dune.jpg", saved.posterPath)
  }

  @Test
  fun `visto recientemente pone lo último primero, sin duplicados y con tope de 15`() {
    val store = LibraryStore()
    (1..20).forEach { store.touchRecent(MediaItem(id = it, title = "T$it")) }
    store.touchRecent(MediaItem(id = 5, title = "T5"))
    val recent = store.state.value.recentItems
    assertEquals(15, recent.size)
    assertEquals(5, recent.first().id)
    assertEquals(recent.size, recent.map { it.key }.toSet().size)
  }

  @Test
  fun `marcar un episodio ya visto no encola otra op`() {
    val store = LibraryStore()
    store.setEpisode(1399, 1, 1, watched = true)
    val pending = store.pendingChanges
    store.setEpisode(1399, 1, 1, watched = true)
    assertEquals(pending, store.pendingChanges)
  }

  @Test
  fun `marcar temporada vacía no hace nada`() {
    val store = LibraryStore()
    store.toggleSeason(1399, 1, emptyList())
    assertEquals(0, store.state.value.watchedEpisodeCount)
    assertEquals(0, store.pendingChanges)
  }

  @Test
  fun `una lista nueva va al final aunque se haya quitado algo antes`() {
    val store = LibraryStore()
    val list = store.createList("Clásicos")
    val a = MediaItem(id = 1, title = "A")
    val b = MediaItem(id = 2, title = "B")
    val c = MediaItem(id = 3, title = "C")
    store.toggleInList(a, list)
    store.toggleInList(b, list)
    store.toggleInList(a, list) // quitar A
    store.toggleInList(c, list)
    assertEquals(listOf("B", "C"), store.state.value.itemsOfList(list).map { it.title })
  }

  @Test
  fun `calificadas cuenta también títulos con solo reseña (como iOS)`() {
    val store = LibraryStore()
    store.setReview(dune, "Arena por todas partes.")
    assertEquals(1, store.state.value.ratedCount)
    assertEquals(listOf("Dune"), store.state.value.ratedItems.map { it.title })
  }

  @Test
  fun `el guardado es atómico y se vuelve a leer igual`() {
    val dir = Files.createTempDirectory("lib").toFile()
    val a = LibraryStore(dir)
    a.toggle(dune, LibraryStore.Kind.FAVORITE)
    a.touchRecent(dune)
    a.saveNow()
    assertFalse("no quedan temporales", File(dir, "library.v2.json.tmp").exists())
    val b = LibraryStore(dir)
    assertTrue(b.state.value.contains(dune.key, LibraryStore.Kind.FAVORITE))
    assertEquals("Dune", b.state.value.recentItems.single().title)
  }

  // MARK: Actor

  @Test
  fun `filmografía sin duplicados, con póster y lo mejor valorado primero`() {
    val cast = listOf(
      TmdbMovie(id = 1399, name = "Juego de tronos", posterPath = "/got.jpg", voteAverage = 8.4, mediaType = "tv"),
      TmdbMovie(id = 1399, name = "Juego de tronos", posterPath = "/got.jpg", voteAverage = 8.4, mediaType = "tv"),
      TmdbMovie(id = 1399, title = "Otra con el mismo id", posterPath = "/x.jpg", voteAverage = 9.0, mediaType = "movie"),
      TmdbMovie(id = 7, title = "Sin póster", voteAverage = 9.9, mediaType = "movie"),
    )
    val films = actorFilmography(cast)
    assertEquals(2, films.size)
    assertEquals(MediaKey(MediaKind.MOVIE, 1399), films.first().key)
    assertEquals(MediaKey(MediaKind.TV, 1399), films.last().key)
  }

  // MARK: Dónde verla

  @Test
  fun `proveedores abren su búsqueda web (App Link a su app), como iOS`() {
    assertEquals(
      "https://www.netflix.com/search?q=La%20casa%20de%20papel",
      ProviderLinks.webUrl(8, "Netflix", "La casa de papel", "MX"),
    )
    assertEquals("https://play.max.com/search?q=Dune", ProviderLinks.webUrl(1899, "Max", "Dune", "MX"))
    assertTrue(ProviderLinks.webUrl(119, "Amazon Prime Video", "Dune", "MX").startsWith("https://www.primevideo.com/"))
    assertEquals("https://www.justwatch.com/mx/search?q=Dune", ProviderLinks.webUrl(999, "Cinépolis Klic", "Dune", "MX"))
  }

  // MARK: Siguiente

  @Test
  fun `días hasta el estreno`() {
    val today = LocalDate.of(2026, 11, 8)
    assertEquals(0, UpNextCalculator.daysUntil(today, today))
    assertEquals(1, UpNextCalculator.daysUntil(today.plusDays(1), today))
    assertEquals(6, UpNextCalculator.daysUntil(today.plusDays(6), today))
  }

  @OptIn(ExperimentalCoroutinesApi::class)
  @Test
  fun `siguiente pide cada serie una vez y recalcula con caché al marcar`() = runTest(UnconfinedTestDispatcher()) {
    val library = LibraryStore()
    library.set(MediaItem(id = 1, title = "Serie", kind = MediaKind.TV), LibraryStore.Kind.WATCHLIST, on = true)
    var fetches = 0
    val store = UpNextStore(library, scope = backgroundScope, fetchSeason = { _, _ -> emptyList() }, fetchShow = { id ->
      fetches++
      TmdbFullDetail(
        id = id,
        name = "Serie",
        seasons = listOf(TmdbSeasonSummary(seasonNumber = 1, episodeCount = 3)),
        lastEpisodeToAir = TmdbEpisodeRef(seasonNumber = 1, episodeNumber = 3),
      )
    })
    store.loadNow()
    assertEquals(1, store.state.value.entries.single().next.episode)
    library.setEpisode(1, 1, 1, watched = true)
    store.loadNow()
    assertEquals(2, store.state.value.entries.single().next.episode)
    assertEquals("la serie se pidió una sola vez", 1, fetches)
  }
}
