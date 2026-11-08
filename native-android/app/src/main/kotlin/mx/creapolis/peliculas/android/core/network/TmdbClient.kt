package mx.creapolis.peliculas.android.core.network

import mx.creapolis.peliculas.android.core.model.MediaKind
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * TMDB a través de la caché del backend Go (`GET /v1/tmdb/{ruta}`).
 * Port de `TMDBClient` en iOS: la key vive en el servidor, imágenes en el CDN.
 */
object TmdbClient {

  /** Idioma del contenido según el teléfono (es / pt / en), como iOS. */
  val language: String
    get() {
      val preferred = Locale.getDefault().toLanguageTag().lowercase(Locale.ROOT)
      return when {
        preferred.startsWith("pt") -> "pt-BR"
        preferred.startsWith("en") -> "en-US"
        preferred.startsWith("es-es") -> "es-ES"
        else -> "es-MX"
      }
    }

  /** Región para "En cines"/"Próximos estrenos" y providers (fallback US). */
  val userRegion: String
    get() = Locale.getDefault().country.takeIf { it.isNotEmpty() } ?: "US"

  private val todayIso: String
    get() = LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE)

  suspend inline fun <reified T> fetch(
    path: String,
    query: Map<String, String> = emptyMap(),
    localized: Boolean = true,
  ): T {
    val q = if (localized) query + ("language" to language) else query
    val data = ApiClient.send("GET", "/v1/tmdb$path", query = q)
    return ApiClient.decode(data)
  }

  /** Lista completa paginada ("Ver todo", explorar, búsqueda). */
  suspend fun pagedList(source: MediaListSource, page: Int): TmdbPagedMovies {
    val (path, query) = route(source, page)
    return fetch(path, query)
  }

  /** Ruta + query de cada source (interno para testear sin red). */
  internal fun route(source: MediaListSource, page: Int): Pair<String, Map<String, String>> = when (source) {
    is MediaListSource.Trending ->
      "/trending/${source.kind.rawValue}/${source.window}" to mapOf("page" to "$page")
    is MediaListSource.TopRated ->
      "/${source.kind.rawValue}/top_rated" to mapOf("page" to "$page")
    MediaListSource.NowPlaying ->
      "/movie/now_playing" to mapOf("page" to "$page", "region" to userRegion)
    MediaListSource.Upcoming ->
      "/movie/upcoming" to mapOf("page" to "$page", "region" to userRegion)

    is MediaListSource.Genre -> {
      val kind = source.kind
      var q = mapOf(
        "sort_by" to source.sort.sortBy(kind),
        "include_adult" to "false",
        "page" to "$page",
        "vote_count.gte" to "${source.sort.voteFloor}",
        "with_genres" to "${source.genreId}",
      )
      source.year?.let { year ->
        val yearKey = if (kind == MediaKind.MOVIE) "primary_release_year" else "first_air_date_year"
        q = q + (yearKey to "$year")
      }
      if (source.sort == DiscoverSort.NEWEST) {
        // "Más recientes": sin esto entran estrenos futuros sin votos.
        val dateKey = if (kind == MediaKind.MOVIE) "primary_release_date.lte" else "first_air_date.lte"
        q = q + (dateKey to todayIso)
      }
      "/discover/${kind.rawValue}" to q
    }

    is MediaListSource.Discover -> {
      var q = mapOf(
        "sort_by" to source.order,
        "include_adult" to "false",
        "page" to "$page",
        "vote_count.gte" to "${source.voteFloor}",
        "with_genres" to source.genreIds,
      )
      source.minRating?.let { q = q + ("vote_average.gte" to "$it") }
      "/discover/${source.kind.rawValue}" to q
    }

    is MediaListSource.Search ->
      "/search/${source.kind.rawValue}" to mapOf(
        "query" to source.query,
        "include_adult" to "false",
        "page" to "$page",
      )
  }

  suspend fun genres(kind: MediaKind): List<TmdbGenre> =
    fetch<TmdbGenreList>("/genre/${kind.rawValue}/list").genres

  /** Actores/directores por nombre (solo primera página). */
  suspend fun searchPeople(query: String): List<TmdbPerson> =
    fetch<TmdbPersonsResponse>("/search/person", mapOf("query" to query, "include_adult" to "false")).results

  /** Ficha de persona (bio, cumpleaños, oficio). */
  suspend fun person(id: Int): TmdbPersonDetail =
    fetch("/person/$id")

  /** Filmografía: reparto de créditos combinados (como iOS `personCredits`). */
  suspend fun personCredits(id: Int): List<TmdbMovie> =
    fetch<TmdbMovieCredits>("/person/$id/combined_credits").cast
}

/** CDN de imágenes de TMDB (gemelo de `TMDBImage` en iOS). */
object TmdbImage {
  fun url(path: String?, size: String = "w500"): String? =
    path?.takeIf { it.isNotEmpty() }?.let { "https://image.tmdb.org/t/p/$size$it" }
}
