package mx.creapolis.peliculas.android.features.upnext

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
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

/** Episodio en una serie, ordenable (T1E10 < T2E1) — port de `EpisodeRef`. */
data class EpisodeRef(val season: Int, val episode: Int) : Comparable<EpisodeRef> {
  override fun compareTo(other: EpisodeRef): Int = compareValuesBy(this, other, { it.season }, { it.episode })
  val label: String get() = "T$season · E$episode"
}

/**
 * Lógica pura de "qué toca ver ahora" (port de `UpNextCalculator`,
 * testeable sin red). La temporada 0 (especiales) no cuenta.
 */
object UpNextCalculator {

  /** Primer episodio ya emitido que no has visto, en orden. */
  fun next(seasons: List<Pair<Int, Int>>, lastAired: EpisodeRef?, watched: Set<EpisodeRef>): EpisodeRef? {
    lastAired ?: return null
    for ((number, count) in seasons.filter { it.first > 0 }.sortedBy { it.first }) {
      if (count <= 0) continue
      for (e in 1..count) {
        val ref = EpisodeRef(number, e)
        if (ref > lastAired) return null
        if (ref !in watched) return ref
      }
    }
    return null
  }

  /** Episodios emitidos hasta `lastAired` (para la barra de progreso). */
  fun airedCount(seasons: List<Pair<Int, Int>>, lastAired: EpisodeRef?): Int {
    lastAired ?: return 0
    return seasons.filter { it.first > 0 && it.first <= lastAired.season }
      .sumOf { (number, count) -> if (number == lastAired.season) minOf(count, lastAired.episode) else count }
  }
}

data class UpNextEntry(
  val show: MediaItem,
  val next: EpisodeRef,
  val episodeTitle: String = "",
  val stillPath: String = "",
  val watchedCount: Int,
  val airedCount: Int,
  val started: Boolean,
) {
  val id: Int get() = show.id
  val progress: Double get() = if (airedCount > 0) watchedCount.toDouble() / airedCount else 0.0
}

data class UpcomingEntry(
  val show: MediaItem,
  val episode: EpisodeRef,
  val name: String,
  val airDate: java.time.LocalDate,
) {
  val id: Int get() = show.id
}

/** Pestaña "Siguiente" (port de `UpNextStore` en iOS). */
class UpNextViewModel(private val library: LibraryStore) : ViewModel() {

  data class UiState(
    val entries: List<UpNextEntry> = emptyList(),
    val upcoming: List<UpcomingEntry> = emptyList(),
    val loading: Boolean = false,
    val loadedOnce: Boolean = false,
  )

  private val _state = MutableStateFlow(UiState())
  val state: StateFlow<UiState> = _state.asStateFlow()

  fun load() {
    viewModelScope.launch { loadInternal() }
  }

  /** Marca visto y pasa al siguiente recargando (como iOS; optimizable). */
  fun markWatched(entry: UpNextEntry) {
    library.setEpisode(entry.show.id, entry.next.season, entry.next.episode, watched = true)
    load()
  }

  suspend fun loadInternal() {
    val followed = library.followedShows()
    if (followed.isEmpty()) {
      _state.value = UiState(loadedOnce = true)
      return
    }
    _state.update { it.copy(loading = true) }
    try {
      coroutineScope {
        val details = followed.take(60).map { base ->
          async { base.id to runCatching { TmdbClient.show(base.id) }.getOrNull() }
        }.map { it.await() }.toMap()

        val entries = mutableListOf<UpNextEntry>()
        val upcoming = mutableListOf<UpcomingEntry>()
        val today = java.time.LocalDate.now()
        for (base in followed) {
          val d = details[base.id] ?: continue
          val show = base.mergedWith(d.toMediaItem(MediaKind.TV))
          library.remember(show)
          val seasons = d.seasons.orEmpty().map { it.seasonNumber to (it.episodeCount ?: 0) }
          val last = d.lastEpisodeToAir?.let { EpisodeRef(it.seasonNumber, it.episodeNumber) }
          val watched = library.watchedEpisodes(d.id)
            .map { EpisodeRef(it.season, it.episode) }.toSet()
          val aired = UpNextCalculator.airedCount(seasons, last)
          val next = UpNextCalculator.next(seasons, last, watched)
          if (next != null) {
            entries.add(
              UpNextEntry(
                show = show, next = next,
                watchedCount = minOf(watched.size, aired), airedCount = aired,
                started = watched.isNotEmpty(),
              ),
            )
          }
          val upcomingRef = d.nextEpisodeToAir
          val upcomingDate = upcomingRef?.airDate?.let { parseDay(it) }
          if (upcomingRef != null && upcomingDate != null && !upcomingDate.isBefore(today)) {
            upcoming.add(
              UpcomingEntry(show, EpisodeRef(upcomingRef.seasonNumber, upcomingRef.episodeNumber),
                upcomingRef.name.orEmpty(), upcomingDate),
            )
          }
        }
        // Primero lo que ya empezaste (más avanzado arriba), luego lo pendiente.
        val sorted = entries.sortedWith(
          compareByDescending<UpNextEntry> { it.started }.thenByDescending { it.progress },
        )
        _state.update { st ->
          st.copy(
            entries = sorted,
            upcoming = upcoming.sortedBy { it.airDate },
            loading = false,
            loadedOnce = true,
          )
        }
        enrich(sorted)
      }
    } catch (e: kotlinx.coroutines.CancellationException) {
      throw e
    } catch (_: Exception) {
      _state.update { it.copy(loading = false, loadedOnce = true) }
    }
  }

  /** Título e imagen de cada siguiente episodio (una temporada por serie, como iOS). */
  private suspend fun enrich(current: List<UpNextEntry>) = coroutineScope {
    val details = current.take(30).map { e ->
      async {
        val eps = runCatching { TmdbClient.season(e.show.id, e.next.season) }.getOrNull()
        e.show.id to eps?.firstOrNull { it.episodeNumber == e.next.episode }
      }
    }.map { it.await() }.toMap()
    _state.update { st ->
      st.copy(
        entries = st.entries.map { e ->
          val ep = details[e.show.id] ?: return@map e
          e.copy(
            episodeTitle = ep.name.orEmpty(),
            stillPath = ep.stillPath.orEmpty(),
          )
        },
      )
    }
  }

  companion object {
    fun parseDay(s: String): java.time.LocalDate? = try {
      java.time.LocalDate.parse(s)
    } catch (_: Exception) {
      null
    }

    fun factory(library: LibraryStore): androidx.lifecycle.ViewModelProvider.Factory =
      androidx.lifecycle.viewmodel.viewModelFactory {
        initializer { UpNextViewModel(library) }
      }
  }
}
