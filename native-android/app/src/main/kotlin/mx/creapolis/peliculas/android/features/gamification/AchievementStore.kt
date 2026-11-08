package mx.creapolis.peliculas.android.features.gamification

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.network.ApiClient
import java.time.Instant
import java.util.Date

/** Conteos de la biblioteca que alimentan los logros (port de `LibraryCounts`). */
data class LibraryCounts(
  val favorites: Int = 0,
  val watchlist: Int = 0,
  val watched: Int = 0,
  val lists: Int = 0,
  val ratings: Int = 0,
  val episodes: Int = 0,
) {
  companion object {
    fun from(store: LibraryStore, state: LibraryStore.State): LibraryCounts = LibraryCounts(
      favorites = state.count(LibraryStore.Kind.FAVORITE),
      watchlist = state.count(LibraryStore.Kind.WATCHLIST),
      watched = state.count(LibraryStore.Kind.WATCHED),
      lists = state.visibleLists.size,
      ratings = state.ratedCount,
      episodes = state.episodes.values.count { !it.deleted },
    )
  }
}

/** Logro con progreso (port de `Achievement`). */
data class Achievement(
  val id: String,
  val name: String,
  val description: String,
  val icon: String,
  val points: Int,
  val progress: Int,
  val target: Int,
  val unlockedAt: Date?,
) {
  val isUnlocked: Boolean get() = unlockedAt != null
}

/** Nivel por puntos: mismos 7 umbrales que `Level.defaultLevels` de Flutter. */
data class UserLevel(val level: Int, val nameRes: Int, val pointsRequired: Int) {
  companion object {
    val ALL = listOf(
      UserLevel(1, R.string.level_1, 0),
      UserLevel(2, R.string.level_2, 150),
      UserLevel(3, R.string.level_3, 400),
      UserLevel(4, R.string.level_4, 800),
      UserLevel(5, R.string.level_5, 1500),
      UserLevel(6, R.string.level_6, 2500),
      UserLevel(7, R.string.level_7, 4000),
    )

    fun levelFor(points: Int): UserLevel = ALL.last { points >= it.pointsRequired }
  }

  val next: UserLevel? get() = ALL.firstOrNull { it.pointsRequired > pointsRequired }

  fun pointsToNext(from: Int): Int? = next?.let { maxOf(0, it.pointsRequired - from) }

  fun progress(from: Int): Double {
    val n = next ?: return 1.0
    val span = (n.pointsRequired - pointsRequired).toDouble()
    if (span <= 0) return 1.0
    return ((from - pointsRequired) / span).coerceIn(0.0, 1.0)
  }
}

/** Logros locales: mismos ids, nombres y puntos que la app Flutter/iOS. */
class AchievementStore(context: Context? = null) {

  @Serializable
  private data class Saved(val unlocked: Map<String, String>) // id → ISO instant

  data class UiState(
    val all: List<Achievement> = emptyList(),
    val unlockedCount: Int = 0,
    val totalCount: Int = DEFS.size,
    val totalPoints: Int = 0,
    val level: UserLevel = UserLevel.levelFor(0),
    val toast: Achievement? = null,
  )

  private val appContext = context?.applicationContext
  private val prefs = context?.getSharedPreferences("peliculas.achievements.v1", Context.MODE_PRIVATE)
  private val unlocked = mutableMapOf<String, Instant>()
  /** Al arrancar se evalúa en silencio: no se celebra lo que ya tenías. */
  private var primed = false

  private val _state = MutableStateFlow(UiState())
  val state: StateFlow<UiState> = _state.asStateFlow()

  init {
    if (prefs != null) {
      prefs.getString(KEY, null)?.let { raw ->
        runCatching { ApiClient.decodeFromString<Saved>(raw) }.getOrNull().let { saved ->
          saved?.unlocked?.forEach { (id, iso) -> IsoDateParse(iso)?.let { unlocked[id] = it } }
        }
      }
    }
  }

  private data class Def(
    val id: String,
    val nameRes: Int,
    val descriptionRes: Int,
    val icon: String,
    val points: Int,
    val target: Int,
    val count: (LibraryCounts) -> Int,
  )

  private companion object {
    const val KEY = "unlocked"

    val DEFS = listOf(
      Def("first_movie", R.string.ach_first_movie, R.string.ach_first_movie_d, "favorite", 10, 1) { it.favorites },
      Def("movie_enthusiast", R.string.ach_enthusiast, R.string.ach_enthusiast_d, "heart", 50, 10) { it.favorites },
      Def("movie_collector", R.string.ach_collector, R.string.ach_collector_d, "stack", 150, 50) { it.favorites },
      Def("movie_curator", R.string.ach_curator, R.string.ach_curator_d, "rosette", 300, 100) { it.favorites },
      Def("movie_master", R.string.ach_master, R.string.ach_master_d, "crown", 500, 200) { it.favorites },
      Def("first_watchlist", R.string.ach_first_watchlist, R.string.ach_first_watchlist_d, "bookmark", 10, 1) { it.watchlist },
      Def("first_watched", R.string.ach_first_watched, R.string.ach_first_watched_d, "eye", 10, 1) { it.watched },
      Def("cinephile", R.string.ach_cinephile, R.string.ach_cinephile_d, "film", 50, 10) { it.watched },
      Def("list_creator", R.string.ach_list_creator, R.string.ach_list_creator_d, "list", 25, 1) { it.lists },
      Def("first_rating", R.string.ach_first_rating, R.string.ach_first_rating_d, "star", 10, 1) { it.ratings },
      Def("critic", R.string.ach_critic, R.string.ach_critic_d, "star_circle", 75, 25) { it.ratings },
      Def("first_episode", R.string.ach_first_episode, R.string.ach_first_episode_d, "tv", 10, 1) { it.episodes },
      Def("binge_watcher", R.string.ach_binge, R.string.ach_binge_d, "flame", 100, 50) { it.episodes },
      Def("series_addict", R.string.ach_series_addict, R.string.ach_series_addict_d, "sparkles", 300, 250) { it.episodes },
    )

    fun IsoDateParse(s: String): Instant? = mx.creapolis.peliculas.android.core.sync.IsoDate.parse(s)
  }

  /** Evalúa los logros contra los conteos actuales y celebra el más nuevo. */
  fun check(counts: LibraryCounts) {
    var newest: Achievement? = null
    val now = Date()
    for (def in DEFS) {
      if (unlocked.containsKey(def.id)) continue
      val progress = minOf(def.count(counts), def.target)
      if (progress < def.target) continue
      unlocked[def.id] = now.toInstant()
      newest = Achievement(def.id, nameOf(def), descriptionOf(def), def.icon, def.points, progress, def.target, now)
    }
    if (newest != null) persist()
    refresh(counts)
    if (primed && newest != null) {
      _state.value = _state.value.copy(toast = newest)
    }
    primed = true
  }

  fun dismissToast() {
    _state.value = _state.value.copy(toast = null)
  }

  fun refresh(counts: LibraryCounts) {
    _state.value = _state.value.copy(
      all = DEFS.map { def ->
        Achievement(
          def.id, nameOf(def), descriptionOf(def), def.icon, def.points,
          minOf(def.count(counts), def.target), def.target, unlocked[def.id]?.let { Date.from(it) },
        )
      },
      unlockedCount = unlocked.size,
      totalPoints = DEFS.filter { unlocked.containsKey(it.id) }.sumOf { it.points },
      level = UserLevel.levelFor(DEFS.filter { unlocked.containsKey(it.id) }.sumOf { it.points }),
    )
  }

  private fun persist() {
    val p = prefs ?: return
    val saved = Saved(unlocked.mapValues { (_, v) -> v.toString() })
    p.edit().putString(KEY, ApiClient.encodeToString(saved)).apply()
  }

  private fun nameOf(def: Def): String = appContext?.getString(def.nameRes) ?: def.id
  private fun descriptionOf(def: Def): String = appContext?.getString(def.descriptionRes) ?: def.id
}
