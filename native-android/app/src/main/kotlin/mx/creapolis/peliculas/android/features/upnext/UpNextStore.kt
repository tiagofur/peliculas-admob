package mx.creapolis.peliculas.android.features.upnext

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.model.toMediaItem
import mx.creapolis.peliculas.android.core.network.TmdbClient
import mx.creapolis.peliculas.android.core.network.TmdbFullDetail
import java.time.LocalDate
import java.util.concurrent.ConcurrentHashMap

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

  /** "Hoy" / "Mañana" / "En N días" (la UI pone el texto localizado). */
  fun daysUntil(date: LocalDate, today: LocalDate = LocalDate.now()): Long =
    java.time.temporal.ChronoUnit.DAYS.between(today, date)
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
  val airDate: LocalDate,
) {
  val id: Int get() = show.id
}

/**
 * "Siguiente": el próximo episodio de cada serie que sigues y los estrenos que
 * vienen (port de `UpNextStore` en iOS). Vive en AppContainer para que Inicio
 * ("Continuar viendo") y la pestaña compartan datos y caché: el detalle de cada
 * serie se pide una vez y solo se recalcula lo local al marcar episodios.
 */
class UpNextStore(
  private val library: LibraryStore,
  private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
  private val fetchShow: suspend (Int) -> TmdbFullDetail = { TmdbClient.show(it) },
  private val fetchSeason: suspend (Int, Int) -> List<mx.creapolis.peliculas.android.core.network.TmdbEpisode> =
    { tv, season -> TmdbClient.season(tv, season) },
) {

  data class UiState(
    val entries: List<UpNextEntry> = emptyList(),
    val upcoming: List<UpcomingEntry> = emptyList(),
    val loading: Boolean = false,
    val loadedOnce: Boolean = false,
  )

  private val _state = MutableStateFlow(UiState())
  val state: StateFlow<UiState> = _state.asStateFlow()

  private val shows = ConcurrentHashMap<Int, TmdbFullDetail>()
  private val episodeInfo = ConcurrentHashMap<String, Pair<String, String>>() // "id:s:e" → (título, still)
  private val mutex = Mutex()
  private var job: Job? = null

  /** Carga (o recalcula con la caché). `force` vuelve a pedir cada serie. */
  fun load(force: Boolean = false) {
    job?.cancel()
    job = scope.launch { loadNow(force) }
  }

  suspend fun loadNow(force: Boolean = false) = mutex.withLock {
    val followed = library.followedShows()
    if (followed.isEmpty()) {
      _state.value = UiState(loadedOnce = true)
      return@withLock
    }
    _state.update { it.copy(loading = true) }
    try {
      coroutineScope {
        followed.map { it.id }.filter { force || !shows.containsKey(it) }.take(60).map { id ->
          async { runCatching { fetchShow(id) }.getOrNull()?.let { shows[id] = it } }
        }.awaitAll()
      }
      val (entries, upcoming) = compute(followed)
      _state.update { it.copy(entries = entries, upcoming = upcoming, loading = false, loadedOnce = true) }
      enrich(entries)
    } catch (e: kotlinx.coroutines.CancellationException) {
      _state.update { it.copy(loading = false) }
      throw e
    } catch (_: Exception) {
      _state.update { it.copy(loading = false, loadedOnce = true) }
    }
  }

  private fun compute(followed: List<MediaItem>): Pair<List<UpNextEntry>, List<UpcomingEntry>> {
    val entries = mutableListOf<UpNextEntry>()
    val upcoming = mutableListOf<UpcomingEntry>()
    val today = LocalDate.now()
    for (base in followed) {
      val d = shows[base.id] ?: continue
      val show = library.remember(base.mergedWith(d.toMediaItem(MediaKind.TV)))
      val seasons = d.seasons.orEmpty().map { it.seasonNumber to (it.episodeCount ?: 0) }
      val last = d.lastEpisodeToAir?.let { EpisodeRef(it.seasonNumber, it.episodeNumber) }
      val watched = library.watchedEpisodes(d.id).map { EpisodeRef(it.season, it.episode) }.toSet()
      val aired = UpNextCalculator.airedCount(seasons, last)
      UpNextCalculator.next(seasons, last, watched)?.let { next ->
        val info = episodeInfo["${d.id}:${next.season}:${next.episode}"]
        entries.add(
          UpNextEntry(
            show = show, next = next,
            episodeTitle = info?.first.orEmpty(), stillPath = info?.second.orEmpty(),
            watchedCount = minOf(watched.size, aired), airedCount = aired,
            started = watched.isNotEmpty(),
          ),
        )
      }
      val n = d.nextEpisodeToAir
      val date = n?.airDate?.let { parseDay(it) }
      if (n != null && date != null && !date.isBefore(today)) {
        upcoming.add(UpcomingEntry(show, EpisodeRef(n.seasonNumber, n.episodeNumber), n.name.orEmpty(), date))
      }
    }
    // Primero lo que ya empezaste (más avanzado arriba), luego lo pendiente.
    val sorted = entries.sortedWith(compareByDescending<UpNextEntry> { it.started }.thenByDescending { it.progress })
    return sorted to upcoming.sortedBy { it.airDate }
  }

  /** Título e imagen de cada siguiente episodio (una temporada por serie, como iOS). */
  private suspend fun enrich(current: List<UpNextEntry>) = coroutineScope {
    val missing = current.take(30).filter { episodeInfo["${it.show.id}:${it.next.season}:${it.next.episode}"] == null }
    if (missing.isEmpty()) return@coroutineScope
    missing.map { e ->
      async {
        val eps = runCatching { fetchSeason(e.show.id, e.next.season) }.getOrNull() ?: return@async
        eps.forEach { ep ->
          episodeInfo["${e.show.id}:${e.next.season}:${ep.episodeNumber}"] = ep.name.orEmpty() to ep.stillPath.orEmpty()
        }
      }
    }.awaitAll()
    _state.update { st ->
      st.copy(
        entries = st.entries.map { e ->
          val info = episodeInfo["${e.show.id}:${e.next.season}:${e.next.episode}"] ?: return@map e
          e.copy(episodeTitle = info.first, stillPath = info.second)
        },
      )
    }
  }

  /** Marca visto y pasa al siguiente sin volver a pedir la serie (caché). */
  fun markWatched(entry: UpNextEntry) {
    library.setEpisode(entry.show.id, entry.next.season, entry.next.episode, watched = true)
    load()
  }

  /** Al cerrar sesión: nada de la cuenta anterior. */
  fun reset() {
    job?.cancel()
    shows.clear()
    _state.value = UiState()
  }

  companion object {
    fun parseDay(s: String): LocalDate? = try {
      LocalDate.parse(s)
    } catch (_: Exception) {
      null
    }
  }
}
