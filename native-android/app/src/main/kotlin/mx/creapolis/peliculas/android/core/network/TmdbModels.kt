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

// MARK: Detalle (port de TMDBFullDetail y amigos en iOS)

@Serializable
data class TmdbVideo(
  val key: String,
  val site: String,
  val type: String? = null,
  val official: Boolean? = null,
)

@Serializable
data class TmdbVideos(val results: List<TmdbVideo> = emptyList())

@Serializable
data class TmdbCredits(val cast: List<TmdbPerson> = emptyList(), val crew: List<TmdbPerson> = emptyList())

@Serializable
data class TmdbProvider(
  @SerialName("provider_id") val providerId: Int,
  @SerialName("provider_name") val providerName: String,
  @SerialName("logo_path") val logoPath: String? = null,
)

@Serializable
data class TmdbWatchCountry(
  val link: String? = null,
  val flatrate: List<TmdbProvider>? = null,
  val rent: List<TmdbProvider>? = null,
  val buy: List<TmdbProvider>? = null,
)

@Serializable
data class TmdbWatchResponse(val results: Map<String, TmdbWatchCountry> = emptyMap())

@Serializable
data class TmdbSeasonSummary(
  @SerialName("season_number") val seasonNumber: Int,
  @SerialName("episode_count") val episodeCount: Int? = null,
  val name: String? = null,
  @SerialName("air_date") val airDate: String? = null,
  @SerialName("poster_path") val posterPath: String? = null,
)

@Serializable
data class TmdbEpisodeRef(
  @SerialName("season_number") val seasonNumber: Int,
  @SerialName("episode_number") val episodeNumber: Int,
  val name: String? = null,
  val overview: String? = null,
  @SerialName("air_date") val airDate: String? = null,
  @SerialName("still_path") val stillPath: String? = null,
  val runtime: Int? = null,
)

@Serializable
data class TmdbEpisode(
  val id: Int,
  @SerialName("episode_number") val episodeNumber: Int,
  @SerialName("season_number") val seasonNumber: Int? = null,
  val name: String? = null,
  val overview: String? = null,
  @SerialName("still_path") val stillPath: String? = null,
  val runtime: Int? = null,
  @SerialName("vote_average") val voteAverage: Double? = null,
  @SerialName("air_date") val airDate: String? = null,
)

@Serializable
data class TmdbSeason(val episodes: List<TmdbEpisode> = emptyList())

/** Detalle completo de película o serie (`append_to_response`). */
@Serializable
data class TmdbFullDetail(
  val id: Int,
  val title: String? = null,
  val name: String? = null,
  val overview: String? = null,
  val tagline: String? = null,
  @SerialName("poster_path") val posterPath: String? = null,
  @SerialName("backdrop_path") val backdropPath: String? = null,
  @SerialName("vote_average") val voteAverage: Double? = null,
  @SerialName("release_date") val releaseDate: String? = null,
  @SerialName("first_air_date") val firstAirDate: String? = null,
  val runtime: Int? = null,
  @SerialName("episode_run_time") val episodeRunTime: List<Int>? = null,
  @SerialName("number_of_seasons") val numberOfSeasons: Int? = null,
  @SerialName("number_of_episodes") val numberOfEpisodes: Int? = null,
  val status: String? = null,
  val genres: List<TmdbGenre>? = null,
  val seasons: List<TmdbSeasonSummary>? = null,
  @SerialName("next_episode_to_air") val nextEpisodeToAir: TmdbEpisodeRef? = null,
  @SerialName("last_episode_to_air") val lastEpisodeToAir: TmdbEpisodeRef? = null,
  val videos: TmdbVideos? = null,
  val credits: TmdbCredits? = null,
  @SerialName("created_by") val createdBy: List<TmdbPerson>? = null,
  val similar: TmdbResponse? = null,
  val recommendations: TmdbResponse? = null,
  @SerialName("watch/providers") val watchProviders: TmdbWatchResponse? = null,
) {
  val displayTitle: String get() = title ?: name ?: ""
  val displayDate: String? get() = releaseDate ?: firstAirDate
}
