package mx.creapolis.peliculas.android

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKey
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.model.toMediaItem
import mx.creapolis.peliculas.android.core.network.ApiClient
import mx.creapolis.peliculas.android.core.network.DiscoverSort
import mx.creapolis.peliculas.android.core.network.MediaListSource
import mx.creapolis.peliculas.android.core.network.TmdbClient
import mx.creapolis.peliculas.android.core.network.TmdbMovie
import mx.creapolis.peliculas.android.core.network.TmdbPagedMovies
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** F0: modelos y decodificación sin red (port de ModelTests + PaginationTests de iOS). */
class F0ModelTests {

  private val json: Json = ApiClient.json

  // MARK: MediaKey

  @Test
  fun mediaKeySeparatesMoviesAndShowsWithSameId() {
    val movie = MediaKey(MediaKind.MOVIE, 1399)
    val show = MediaKey(MediaKind.TV, 1399)
    assertNotEquals(movie, show)
    assertEquals(movie, MediaKey.parse(movie.description))
    assertEquals(show, MediaKey.parse(show.description))
    assertNull(MediaKey.parse("nada"))
    assertNull(MediaKey.parse("movie:abc"))
  }

  // MARK: MediaItem

  @Test
  fun oldCacheWithoutKindAndYearStillDecodes() {
    val raw = """{"id":1,"title":"T","overview":"","posterPath":"","backdropPath":"","rating":7.5}"""
    val item = json.decodeFromString<MediaItem>(raw)
    assertEquals(MediaKind.MOVIE, item.kind)
    assertEquals("", item.year)
  }

  @Test
  fun mediaItemRoundTripsThroughJson() {
    val item = MediaItem(id = 550, title = "El club de la pelea", rating = 8.4, kind = MediaKind.MOVIE, year = "1999")
    val decoded = json.decodeFromString<MediaItem>(json.encodeToString(item))
    assertEquals(item, decoded)
  }

  @Test
  fun mergeKeepsRicherFields() {
    val minimal = MediaItem.minimal(MediaKey(MediaKind.TV, 1), "Serie", "/p.jpg", "2020")
    val full = MediaItem(id = 1, title = "Serie", overview = "Sinopsis", rating = 8.0, kind = MediaKind.TV)
    val merged = minimal.mergedWith(full)
    assertEquals("/p.jpg", merged.posterPath)
    assertEquals("Sinopsis", merged.overview)
    assertEquals("2020", merged.year)
  }

  @Test
  fun tmdbMovieMapsToMediaItem() {
    val tmdb = TmdbMovie(
      id = 550, title = "Fight Club", posterPath = "/p.jpg",
      voteAverage = 8.4, releaseDate = "1999-10-15",
    )
    val item = tmdb.toMediaItem(MediaKind.MOVIE)
    assertEquals("1999", item.year)
    assertEquals(8.4, item.rating, 0.001)
    assertEquals(MediaKey(MediaKind.MOVIE, 550), item.key)
  }

  // MARK: Decode paginado TMDB (snake_case)

  @Test
  fun pagedMoviesDecodeTotalPages() {
    val raw = """
      {"page":2,"total_pages":500,
       "results":[{"id":1400940,"title":"Otra","poster_path":"/p.jpg","vote_average":7.1}]}
    """.trimIndent()
    val page = json.decodeFromString<TmdbPagedMovies>(raw)
    assertEquals(2, page.page)
    assertEquals(500, page.totalPages)
    assertEquals(1, page.results.size)
    assertEquals("/p.jpg", page.results[0].posterPath)
  }

  // MARK: DiscoverSort

  @Test
  fun discoverSortDatesDifferByKind() {
    assertEquals("primary_release_date.desc", DiscoverSort.NEWEST.sortBy(MediaKind.MOVIE))
    assertEquals("first_air_date.desc", DiscoverSort.NEWEST.sortBy(MediaKind.TV))
    assertEquals("vote_average.desc", DiscoverSort.RATING.sortBy(MediaKind.MOVIE))
    assertEquals(150, DiscoverSort.RATING.voteFloor)
    assertEquals(10, DiscoverSort.NEWEST.voteFloor)
    assertEquals(50, DiscoverSort.POPULARITY.voteFloor)
  }

  // MARK: Rutas por source (sin red)

  @Test
  fun genreRouteCarriesYearSortAndDateCap() {
    val (path, query) = TmdbClient.route(
      MediaListSource.Genre(MediaKind.TV, genreId = 18, year = 2024, sort = DiscoverSort.NEWEST), page = 3)
    assertEquals("/discover/tv", path)
    assertEquals("first_air_date.desc", query["sort_by"])
    assertEquals("2024", query["first_air_date_year"])
    assertNotNull(query["first_air_date.lte"])
    assertEquals("18", query["with_genres"])
    assertEquals("3", query["page"])
  }

  @Test
  fun discoverRouteIncludesMinRatingOnlyWhenSet() {
    val with = TmdbClient.route(
      MediaListSource.Discover(MediaKind.MOVIE, "878,9648", 300, minRating = 7.0), 1)
    assertEquals("7.0", with.second["vote_average.gte"])
    val without = TmdbClient.route(
      MediaListSource.Discover(MediaKind.MOVIE, "10749", 200), 1)
    assertNull(without.second["vote_average.gte"])
    assertEquals("popularity.desc", without.second["sort_by"])
  }

  @Test
  fun searchRouteUsesQueryAndPage() {
    val (path, query) = TmdbClient.route(MediaListSource.Search("dune", MediaKind.MOVIE), 2)
    assertEquals("/search/movie", path)
    assertEquals("dune", query["query"])
    assertEquals("2", query["page"])
    assertEquals("false", query["include_adult"])
  }

  @Test
  fun nowPlayingRouteCarriesRegion() {
    val (_, query) = TmdbClient.route(MediaListSource.NowPlaying, 1)
    assertTrue(query.containsKey("region"))
  }
}
