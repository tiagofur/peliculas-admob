package mx.creapolis.peliculas.android

import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKey
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.TmdbCredits
import mx.creapolis.peliculas.android.core.network.TmdbFullDetail
import mx.creapolis.peliculas.android.core.network.TmdbPerson
import mx.creapolis.peliculas.android.core.network.TmdbProvider
import mx.creapolis.peliculas.android.core.network.TmdbVideo
import mx.creapolis.peliculas.android.core.network.TmdbWatchCountry
import mx.creapolis.peliculas.android.core.network.TmdbWatchResponse
import mx.creapolis.peliculas.android.core.network.bestTrailer
import mx.creapolis.peliculas.android.core.network.creditHeadline
import mx.creapolis.peliculas.android.core.network.providersFrom
import mx.creapolis.peliculas.android.features.home.buildHeroes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** F3: funciones puras del detalle y biblioteca local (ports de los tests iOS). */
class F3DetailTests {

  // MARK: bestTrailer

  @Test
  fun bestTrailerPrefersOfficialTrailer() {
    val videos = listOf(
      TmdbVideo(key = "teaser", site = "YouTube", type = "Teaser", official = true),
      TmdbVideo(key = "fan", site = "YouTube", type = "Trailer", official = false),
      TmdbVideo(key = "vimeo", site = "Vimeo", type = "Trailer", official = true),
      TmdbVideo(key = "oficial", site = "YouTube", type = "Trailer", official = true),
    )
    assertEquals("oficial", bestTrailer(videos))
    assertNull(bestTrailer(emptyList()))
  }

  // MARK: Providers

  @Test
  fun providersFromRegionFallbackUSAndDedupe() {
    val response = TmdbWatchResponse(
      results = mapOf(
        "MX" to TmdbWatchCountry(
          link = "https://example.com/mx",
          flatrate = listOf(TmdbProvider(8, "Netflix", "/n.png"), TmdbProvider(1899, "Max", "/m.png")),
          rent = listOf(TmdbProvider(8, "Netflix", "/n.png")),
        ),
        "US" to TmdbWatchCountry(link = "https://example.com/us", flatrate = listOf(TmdbProvider(337, "Disney+", "/d.png"))),
      ),
    )
    val (link, providers) = providersFrom(response, "MX")
    assertEquals("https://example.com/mx", link)
    assertEquals("rent duplicado se filtra", listOf("Netflix", "Max"), providers.map { it.providerName })
    // Región sin datos: cae a US.
    val (usLink, usProviders) = providersFrom(response, "AR")
    assertEquals("https://example.com/us", usLink)
    assertEquals(listOf("Disney+"), usProviders.map { it.providerName })
  }

  // MARK: creditHeadline

  private fun detail(createdBy: List<TmdbPerson> = emptyList(), crew: List<TmdbPerson> = emptyList()) =
    TmdbFullDetail(id = 1, createdBy = createdBy, credits = TmdbCredits(cast = emptyList(), crew = crew))

  @Test
  fun movieShowsDirectorsDeduped() {
    val headline = creditHeadline(
      detail(crew = listOf(
        TmdbPerson(id = 1, name = "Denis Villeneuve", job = "Director"),
        TmdbPerson(id = 1, name = "Denis Villeneuve", job = "Director"),
        TmdbPerson(id = 2, name = "Jon Spaihts", job = "Screenplay"),
      )),
      MediaKind.MOVIE,
    )
    assertEquals("Dirección", headline?.first)
    assertEquals("dedupe del mismo director", "Denis Villeneuve", headline?.second)
  }

  @Test
  fun showShowsCreatorsNotCrew() {
    val headline = creditHeadline(
      detail(createdBy = listOf(
        TmdbPerson(id = 1, name = "David Benioff"),
        TmdbPerson(id = 2, name = "D. B. Weiss"),
      ), crew = listOf(TmdbPerson(id = 3, name = "Alguien", job = "Director"))),
      MediaKind.TV,
    )
    assertEquals("Creado por", headline?.first)
    assertEquals("David Benioff, D. B. Weiss", headline?.second)
  }

  @Test
  fun noCreditsNoHeadline() {
    assertNull(creditHeadline(detail(), MediaKind.MOVIE))
    assertNull(creditHeadline(detail(), MediaKind.TV))
  }

  // MARK: Biblioteca local

  private fun store() = LibraryStore()
  private val fightClub = MediaItem(id = 550, title = "El club de la pelea", rating = 8.4)

  @Test
  fun watchlistToggleAndWatchedRemovesFromWatchlist() {
    val store = store()
    store.set(fightClub, LibraryStore.Kind.WATCHLIST, on = true)
    assertTrue(store.state.value.contains(fightClub.key, LibraryStore.Kind.WATCHLIST))
    store.set(fightClub, LibraryStore.Kind.WATCHED, on = true)
    assertTrue(store.state.value.contains(fightClub.key, LibraryStore.Kind.WATCHED))
    assertFalse(
      "marcar vista la quita de la watchlist (como iOS)",
      store.state.value.contains(fightClub.key, LibraryStore.Kind.WATCHLIST),
    )
  }

  @Test
  fun rateKeepsReviewAndScoreRoundsToHalf() {
    val store = store()
    store.rate(fightClub, score = 8.3)
    assertEquals("redondeo a pasos de 0.5", 8.5, store.state.value.score(fightClub.key)!!, 0.001)
    store.setReview(fightClub, "Imposible verla una sola vez.")
    assertEquals("Imposible verla una sola vez.", store.state.value.review(fightClub.key))
    store.rate(fightClub, score = null)
    org.junit.Assert.assertNull("quitar nota", store.state.value.score(fightClub.key))
    assertEquals("la reseña sobrevive", "Imposible verla una sola vez.", store.state.value.review(fightClub.key))
    assertFalse("con reseña no se marca borrada", store.state.value.ratings[fightClub.key]!!.deleted)
  }

  @Test
  fun emptyReviewDeletesWhenNoScore() {
    val store = store()
    store.setReview(fightClub, "x")
    store.setReview(fightClub, "   ")
    assertTrue(store.state.value.ratings[fightClub.key]!!.deleted)
    assertNull(store.state.value.review(fightClub.key))
  }

  @Test
  fun rememberMergesRicherItem() {
    val store = store()
    store.remember(MediaItem(id = 1, title = "A"))
    store.remember(MediaItem(id = 1, title = "A", overview = "Sinopsis", year = "1999"))
    val merged = store.item(MediaKey(MediaKind.MOVIE, 1))!!
    assertEquals("Sinopsis", merged.overview)
    assertEquals("1999", merged.year)
  }

  @Test
  fun episodesMarkSeasonCountAndToggleAll() {
    val store = store()
    store.setEpisode(1399, 1, 1, watched = true)
    store.setEpisode(1399, 1, 2, watched = true)
    assertEquals(2, store.state.value.seasonWatchedCount(1399, 1))
    store.toggleSeason(1399, 1, listOf(1, 2))
    assertEquals(0, store.state.value.seasonWatchedCount(1399, 1))
    store.toggleSeason(1399, 1, listOf(1, 2))
    assertEquals(2, store.state.value.seasonWatchedCount(1399, 1))
  }

  // MARK: Héroe (lógica compartida con F1, usada también por el detalle)

  @Test
  fun heroMergeKeepsBackdropOnly() {
    val day = listOf(MediaItem(id = 1, title = "A", backdropPath = ""), MediaItem(id = 2, title = "B", backdropPath = "/b.jpg"))
    val shows = listOf(MediaItem(id = 11, title = "S", backdropPath = "/s.jpg", kind = MediaKind.TV))
    val heroes = buildHeroes(day, shows)
    assertTrue("sin fondo no entra al héroe", heroes.map { it.id }.none { it == 1 })
  }
}
