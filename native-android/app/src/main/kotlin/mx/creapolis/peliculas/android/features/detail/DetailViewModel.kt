package mx.creapolis.peliculas.android.features.detail

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.model.toMediaItem
import mx.creapolis.peliculas.android.core.network.TmdbClient
import mx.creapolis.peliculas.android.core.network.TmdbEpisode
import mx.creapolis.peliculas.android.core.network.TmdbFullDetail
import mx.creapolis.peliculas.android.core.network.TmdbPerson
import mx.creapolis.peliculas.android.core.network.TmdbProvider
import mx.creapolis.peliculas.android.core.network.bestTrailer
import mx.creapolis.peliculas.android.core.network.creditHeadline
import mx.creapolis.peliculas.android.core.network.providersFrom

/**
 * Detalle (port de `DetailLoader` en iOS): una petición con
 * `append_to_response` y tráiler/provider tras el detalle. Con biblioteca
 * local para las acciones (F4 la conecta al sync).
 */
class DetailViewModel(
  val base: MediaItem,
  val library: LibraryStore,
) : ViewModel() {

  data class EpisodeRow(
    val id: Int,
    val number: Int,
    val title: String,
    val overview: String,
    val stillPath: String,
    val runtime: Int?,
    val airDate: String,
  ) {
    val hasAired: Boolean get() = (airDate.takeIf { it.isNotEmpty() } ?: "9999-12-31") <= TODAY_ISO
  }

  data class UiState(
    val item: MediaItem,
    val detail: TmdbFullDetail? = null,
    val trailerKey: String? = null,
    val cast: List<TmdbPerson> = emptyList(),
    val similar: List<MediaItem> = emptyList(),
    val providers: List<TmdbProvider> = emptyList(),
    val providerLink: String? = null,
    val seasons: List<mx.creapolis.peliculas.android.core.network.TmdbSeasonSummary> = emptyList(),
    val episodes: List<EpisodeRow> = emptyList(),
    val loadingEpisodes: Boolean = false,
    val failed: Boolean = false,
    val selectedSeason: Int = 1,
    /** "Dirección"/"Creado por": etiqueta y nombres. */
    val creditLabel: String? = null,
    val creditNames: String? = null,
  )

  private val _state = MutableStateFlow(UiState(item = base))
  val state: StateFlow<UiState> = _state.asStateFlow()

  private var loadedFor: mx.creapolis.peliculas.android.core.model.MediaKey? = null

  init {
    load()
  }

  fun reload() {
    loadedFor = null
    load()
  }

  fun load() {
    if (loadedFor == base.key) return
    loadedFor = base.key
    _state.update { it.copy(failed = false, item = base) }
    library.remember(base)
    viewModelScope.launch {
      try {
        coroutineScope {
          val d = async { TmdbClient.detail(base.kind, base.id) }
          val trailer = async { runCatching { TmdbClient.trailerOf(base.kind, base.id, d) }.getOrNull() }
          val detail = d.await()
          val recs = detail.recommendations?.results.orEmpty()
          val similar = (if (recs.isEmpty()) detail.similar?.results.orEmpty() else recs)
            .filter { !it.posterPath.isNullOrEmpty() }
            .take(15)
            .map { it.toMediaItem(base.kind) }
          val providers = providersFrom(detail.watchProviders)
          val seasons = detail.seasons.orEmpty().filter { it.seasonNumber > 0 && (it.episodeCount ?: 0) > 0 }
          val headline = creditHeadline(detail, base.kind)
          _state.update { st ->
            st.copy(
              item = base.mergedWith(detail.toMediaItem(base.kind)),
              detail = detail,
              trailerKey = trailer.await(),
              cast = detail.credits?.cast.orEmpty().take(15),
              similar = similar,
              providers = providers.second.take(10),
              providerLink = providers.first,
              seasons = seasons,
              selectedSeason = seasons.firstOrNull()?.seasonNumber ?: 1,
              creditLabel = headline?.first,
              creditNames = headline?.second,
            )
          }
          if (base.kind == MediaKind.TV) loadEpisodes(seasons.firstOrNull()?.seasonNumber ?: 1)
        }
      } catch (e: kotlinx.coroutines.CancellationException) {
        throw e
      } catch (_: Exception) {
        _state.update { st -> st.copy(failed = st.detail == null) }
        if (_state.value.failed) loadedFor = null
      }
    }
  }

  fun selectSeason(season: Int) {
    _state.update { it.copy(selectedSeason = season) }
    loadEpisodes(season)
  }

  private fun loadEpisodes(season: Int) {
    viewModelScope.launch {
      _state.update { it.copy(loadingEpisodes = true) }
      try {
        val eps = TmdbClient.season(base.id, season)
        // Si el usuario cambió de temporada mientras cargaba, no pisar (como iOS).
        if (_state.value.selectedSeason != season) return@launch
        _state.update { st ->
          st.copy(
            loadingEpisodes = false,
            episodes = eps.map { e ->
              EpisodeRow(
                id = e.id, number = e.episodeNumber,
                title = e.name ?: "Episodio ${e.episodeNumber}",
                overview = e.overview.orEmpty(),
                stillPath = e.stillPath.orEmpty(),
                runtime = e.runtime,
                airDate = e.airDate.orEmpty(),
              )
            },
          )
        }
      } catch (_: Exception) {
        // Falló la temporada: no dejar colgados los episodios de la anterior (como iOS).
        if (_state.value.selectedSeason == season) {
          _state.update { it.copy(loadingEpisodes = false, episodes = emptyList()) }
        }
      }
    }
  }
}

private val TODAY_ISO: String
  get() = java.time.LocalDate.now().format(java.time.format.DateTimeFormatter.ISO_LOCAL_DATE)

/** Tráiler: el del detalle o la petición dedicada sin idioma (como iOS). */
private suspend fun TmdbClient.trailerOf(
  kind: MediaKind,
  id: Int,
  detail: kotlinx.coroutines.Deferred<TmdbFullDetail>,
): String? {
  val fromDetail = bestTrailer(detail.await().videos?.results.orEmpty())
  if (fromDetail != null) return fromDetail
  val all = fetch<mx.creapolis.peliculas.android.core.network.TmdbVideos>(
    "/${kind.rawValue}/$id/videos",
    query = mapOf("language" to "en-US"),
    localized = false,
  )
  return bestTrailer(all.results)
}

/** Factory con biblioteca compartida (la misma instancia en toda la app). */
class DetailViewModelFactory(
  private val item: MediaItem,
  private val library: LibraryStore,
) : ViewModelProvider.Factory {
  @Suppress("UNCHECKED_CAST")
  override fun <T : ViewModel> create(modelClass: Class<T>): T = DetailViewModel(item, library) as T
}
