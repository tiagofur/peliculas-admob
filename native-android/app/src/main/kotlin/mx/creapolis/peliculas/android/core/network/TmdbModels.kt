package mx.creapolis.peliculas.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import mx.creapolis.peliculas.android.core.model.MediaKind

/** Modelos TMDB con las claves snake_case explícitas (port de los de iOS). */
@Serializable
data class TmdbMovie(
  val id: Int,
  val title: String? = null,
  val name: String? = null,
  val overview: String? = null,
  @SerialName("poster_path") val posterPath: String? = null,
  @SerialName("backdrop_path") val backdropPath: String? = null,
  @SerialName("vote_average") val voteAverage: Double? = null,
  @SerialName("release_date") val releaseDate: String? = null,
  @SerialName("first_air_date") val firstAirDate: String? = null,
  @SerialName("media_type") val mediaType: String? = null,
  @SerialName("genre_ids") val genreIds: List<Int>? = null,
)

@Serializable
data class TmdbResponse(val results: List<TmdbMovie> = emptyList())

/** Respuesta paginada de TMDB (`page`, `results`, `total_pages`). */
@Serializable
data class TmdbPagedMovies(
  val page: Int = 1,
  val results: List<TmdbMovie> = emptyList(),
  @SerialName("total_pages") val totalPages: Int = 1,
)

@Serializable
data class TmdbGenre(val id: Int, val name: String)

@Serializable
data class TmdbGenreList(val genres: List<TmdbGenre> = emptyList())

@Serializable
data class TmdbPerson(
  val id: Int,
  val name: String? = null,
  val character: String? = null,
  val job: String? = null,
  @SerialName("profile_path") val profilePath: String? = null,
)

@Serializable
data class TmdbPersonsResponse(val results: List<TmdbPerson> = emptyList())

/** Ficha de persona (port de `TMDBPersonDetail`). */
@Serializable
data class TmdbPersonDetail(
  val id: Int,
  val name: String? = null,
  val biography: String? = null,
  val birthday: String? = null,
  @SerialName("place_of_birth") val placeOfBirth: String? = null,
  @SerialName("profile_path") val profilePath: String? = null,
  @SerialName("known_for_department") val knownForDepartment: String? = null,
)

@Serializable
data class TmdbMovieCredits(val cast: List<TmdbMovie> = emptyList())

/** Orden de "Explorar por género" (port de `DiscoverSort`). */
enum class DiscoverSort(val voteFloor: Int) {
  POPULARITY(50), RATING(150), NEWEST(10);

  /** TMDB usa campos de fecha distintos para película y serie. */
  fun sortBy(kind: MediaKind): String = when (this) {
    POPULARITY -> "popularity.desc"
    RATING -> "vote_average.desc"
    NEWEST -> if (kind == MediaKind.TV) "first_air_date.desc" else "primary_release_date.desc"
  }
}

/** De dónde sale una lista paginada (port de `MediaListSource`). */
sealed interface MediaListSource {
  val kind: MediaKind

  data class Trending(override val kind: MediaKind, val window: String) : MediaListSource
  data class TopRated(override val kind: MediaKind) : MediaListSource
  data object NowPlaying : MediaListSource {
    override val kind: MediaKind = MediaKind.MOVIE
  }
  data object Upcoming : MediaListSource {
    override val kind: MediaKind = MediaKind.MOVIE
  }
  data class Genre(
    override val kind: MediaKind,
    val genreId: Int,
    val year: Int? = null,
    val sort: DiscoverSort = DiscoverSort.POPULARITY,
  ) : MediaListSource
  data class Discover(
    override val kind: MediaKind,
    val genreIds: String,
    val voteFloor: Int,
    val minRating: Double? = null,
    val order: String = "popularity.desc",
  ) : MediaListSource
  data class Search(val query: String, override val kind: MediaKind) : MediaListSource
}
