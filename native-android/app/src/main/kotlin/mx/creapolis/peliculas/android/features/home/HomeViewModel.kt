package mx.creapolis.peliculas.android.features.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.model.toMediaItem
import mx.creapolis.peliculas.android.core.network.MediaListSource
import mx.creapolis.peliculas.android.core.network.TmdbClient
import mx.creapolis.peliculas.android.core.network.TmdbMovie

/** Sources fijos del Inicio (mismos endpoints que iOS). */
object HomeSources {
  val trendingMovieDay = MediaListSource.Trending(MediaKind.MOVIE, "day")
  val trendingMovieWeek = MediaListSource.Trending(MediaKind.MOVIE, "week")
  val trendingTvWeek = MediaListSource.Trending(MediaKind.TV, "week")
  val nowPlaying = MediaListSource.NowPlaying
  val upcoming = MediaListSource.Upcoming
  val topRatedMovie = MediaListSource.TopRated(MediaKind.MOVIE)
}

/**
 * Datos de Inicio (port de `HomeLoader` en iOS). Carga todo en paralelo;
 * si una fila falla, las demás se muestran igual.
 */
class HomeViewModel : ViewModel() {

  data class UiState(
    val featured: List<MediaItem> = emptyList(),
    val trending: List<MediaItem> = emptyList(),
    val trendingShows: List<MediaItem> = emptyList(),
    val nowPlaying: List<MediaItem> = emptyList(),
    val upcoming: List<MediaItem> = emptyList(),
    val topRated: List<MediaItem> = emptyList(),
    val loading: Boolean = false,
    /** Todo el Inicio falló (sin red al arrancar). */
    val failed: Boolean = false,
    /** El héroe (`/trending/day`) falló o vino vacío aunque el resto cargó.
     *  Espejo de `featuredFailed` en iOS: el placeholder ofrece reintentar. */
    val featuredFailed: Boolean = false,
  ) {
    val isEmpty: Boolean get() = featured.isEmpty() && trending.isEmpty()
  }

  private val _state = MutableStateFlow(UiState())
  val state: StateFlow<UiState> = _state.asStateFlow()

  fun refresh() {
    viewModelScope.launch { load() }
  }

  init {
    refresh()
  }

  suspend fun load() = coroutineScope {
    _state.update { it.copy(loading = true) }
    val day = async { runCatching { TmdbClient.pagedList(HomeSources.trendingMovieDay, 1).results } }
    val week = async { runCatching { TmdbClient.pagedList(HomeSources.trendingMovieWeek, 1).results } }
    val shows = async { runCatching { TmdbClient.pagedList(HomeSources.trendingTvWeek, 1).results } }
    val cinema = async { runCatching { TmdbClient.pagedList(HomeSources.nowPlaying, 1).results } }
    val soon = async { runCatching { TmdbClient.pagedList(HomeSources.upcoming, 1).results } }
    val rated = async { runCatching { TmdbClient.pagedList(HomeSources.topRatedMovie, 1).results } }

    val dayMovies = day.await().getOrDefault(emptyList()).map { it.toMediaItem(MediaKind.MOVIE) }
    val weekMovies = week.await().getOrDefault(emptyList()).map { it.toMediaItem(MediaKind.MOVIE) }
    val weekShows = shows.await().getOrDefault(emptyList()).map { it.toMediaItem(MediaKind.TV) }
    val cinemaMovies = cinema.await().getOrDefault(emptyList()).map { it.toMediaItem(MediaKind.MOVIE) }
    val upcomingMovies = filterUpcoming(soon.await().getOrDefault(emptyList()), TodayIso())
      .map { it.toMediaItem(MediaKind.MOVIE) }
    val topRatedMovies = rated.await().getOrDefault(emptyList()).map { it.toMediaItem(MediaKind.MOVIE) }

    val heroes = buildHeroes(dayMovies, weekShows)
    _state.update { st ->
      st.copy(
        featured = if (heroes.isEmpty()) st.featured else heroes,
        trending = weekMovies,
        trendingShows = weekShows,
        nowPlaying = cinemaMovies,
        upcoming = upcomingMovies,
        topRated = topRatedMovies,
        loading = false,
        featuredFailed = heroes.isEmpty(),
        failed = weekMovies.isEmpty() && cinemaMovies.isEmpty() && topRatedMovies.isEmpty() && heroes.isEmpty(),
      )
    }
  }
}

/** Sustituible en tests; en producción, la fecha de hoy en ISO (como iOS). */
internal var TodayIso: () -> String = {
  java.time.LocalDate.now().format(java.time.format.DateTimeFormatter.ISO_LOCAL_DATE)
}

/** Héroe: mezcla de películas y series del día con fondo disponible (misma
 *  receta que iOS: intercalar las 4 primeras de cada una + resto de películas). */
fun buildHeroes(dayMovies: List<MediaItem>, weekShows: List<MediaItem>): List<MediaItem> {
  val mixed = dayMovies.take(4).zip(weekShows.take(4)).flatMap { (m, s) -> listOf(m, s) } +
    dayMovies.drop(4)
  return mixed.filter { it.backdropPath.isNotEmpty() }.take(6)
}

/** "Próximos estrenos": solo estrenos con fecha >= hoy (filtra sobre la fecha
 *  completa de TMDB antes de mapear, igual que iOS). */
fun filterUpcoming(movies: List<TmdbMovie>, todayIso: String): List<TmdbMovie> =
  movies.filter { (it.releaseDate ?: "") >= todayIso }
