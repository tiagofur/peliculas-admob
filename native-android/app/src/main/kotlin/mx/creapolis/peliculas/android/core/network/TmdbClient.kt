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

  /** Detalle completo en una petición (cacheada por el backend), como iOS. */
  suspend fun detail(kind: MediaKind, id: Int): TmdbFullDetail =
    fetch("/${kind.rawValue}/$id", mapOf("append_to_response" to "videos,credits,recommendations,similar,watch/providers"))

  /** Episodios de una temporada. */
  suspend fun season(tvId: Int, season: Int): List<TmdbEpisode> =
    fetch<TmdbSeason>("/tv/$tvId/season/$season").episodes

  /** Detalle ligero de serie (temporadas + episodios al aire) para "Siguiente". */
  suspend fun show(id: Int): TmdbFullDetail = fetch("/tv/$id")

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


/** Tráiler: oficial de YouTube primero; teaser; cualquiera (port de `bestTrailer`). */
fun bestTrailer(videos: List<TmdbVideo>): String? {
  val yt = videos.filter { it.site == "YouTube" }
  return yt.firstOrNull { it.type == "Trailer" && it.official == true }?.key
    ?: yt.firstOrNull { it.type == "Trailer" }?.key
    ?: yt.firstOrNull { it.type == "Teaser" }?.key
    ?: yt.firstOrNull()?.key
}

/**
 * "Dónde verla" en la región del teléfono (fallback US): junta
 * suscripción + renta + compra sin duplicar (port de `providers(from:)`).
 */
fun providersFrom(
  response: TmdbWatchResponse?,
  region: String = TmdbClient.userRegion,
): Pair<String?, List<TmdbProvider>> {
  val local = response?.results?.get(region) ?: response?.results?.get("US")
  val seen = mutableSetOf<Int>()
  val all = (local?.flatrate.orEmpty()) + (local?.rent.orEmpty()) + (local?.buy.orEmpty())
  return local?.link to all.filter { seen.add(it.providerId) }
}

/** "Dirección" (películas) o "Creado por" (series) — port de `creditHeadline`. */
fun creditHeadline(detail: TmdbFullDetail, kind: MediaKind): Pair<String, String>? {
  if (kind == MediaKind.TV) {
    val creators = detail.createdBy.orEmpty().mapNotNull { it.name }.filter { it.isNotEmpty() }.take(2)
    if (creators.isNotEmpty()) return "Creado por" to creators.joinToString(", ")
    return null
  }
  val seen = mutableSetOf<String>()
  val directors = detail.credits?.crew.orEmpty()
    .filter { it.job == "Director" }
    .mapNotNull { it.name }
    .filter { it.isNotEmpty() && seen.add(it) }
    .take(2)
  if (directors.isNotEmpty()) return "Dirección" to directors.joinToString(", ")
  return null
}
