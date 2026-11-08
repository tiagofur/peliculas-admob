package mx.creapolis.peliculas.android.core.library

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKey
import java.util.Date

/**
 * Biblioteca local (núcleo del port de `LibraryStore` en iOS). En F3 guarda
 * en memoria las marcas que usa el Detalle: watchlist/favoritos/vistos,
 * notas+reseñas y episodios vistos. F4 añade persistencia JSON, outbox y
 * sync con el backend — sin cambiar esta superficie.
 */
class LibraryStore : ViewModel() {

  enum class Kind { WATCHLIST, FAVORITE, WATCHED }

  data class RatingStamp(val score: Double, val review: String, val updatedAt: Date, val deleted: Boolean)

  data class EpisodeStamp(val tvId: Int, val season: Int, val episode: Int, val updatedAt: Date, val deleted: Boolean)

  data class State(
    val marks: Map<Kind, Map<MediaKey, Date>> = emptyMap(),
    val ratings: Map<MediaKey, RatingStamp> = emptyMap(),
    val episodes: Map<String, EpisodeStamp> = emptyMap(),
    val items: Map<MediaKey, MediaItem> = emptyMap(),
  ) {
    fun contains(key: MediaKey, kind: Kind): Boolean = marks[kind]?.get(key) != null
    fun score(key: MediaKey): Double? = ratings[key]?.takeIf { !it.deleted && it.score > 0 }?.score
    fun review(key: MediaKey): String? =
      ratings[key]?.takeIf { !it.deleted && it.review.isNotEmpty() }?.review
    fun isEpisodeWatched(tvId: Int, season: Int, episode: Int): Boolean =
      episodes[episodeKey(tvId, season, episode)]?.deleted == false

    fun seasonWatchedCount(tvId: Int, season: Int): Int =
      episodes.values.count { it.tvId == tvId && it.season == season && !it.deleted }

    companion object {
      fun episodeKey(tvId: Int, season: Int, episode: Int) = "$tvId:$season:$episode"
    }
  }

  private val _state = MutableStateFlow(State())
  val state: StateFlow<State> = _state.asStateFlow()

  /** Guarda la foto más rica del título (para pintar sin red). */
  fun remember(item: MediaItem) {
    _state.update { it.copy(items = it.items + (item.key to ((it.items[item.key])?.mergedWith(item) ?: item))) }
  }

  fun item(key: MediaKey): MediaItem? = _state.value.items[key]

  fun set(item: MediaItem, kind: Kind, on: Boolean) {
    remember(item)
    val now = Date()
    _state.update { st ->
      st.copy(marks = st.marks + (kind to ((st.marks[kind].orEmpty()) + (item.key to now))))
    }
    // Marcar vista quita de la watchlist (patrón de Apple TV y Letterboxd, como iOS).
    if (kind == Kind.WATCHED && on) {
      _state.update { st ->
        val wl = st.marks[Kind.WATCHLIST].orEmpty() - item.key
        st.copy(marks = st.marks + (Kind.WATCHLIST to wl))
      }
    }
  }

  fun toggle(item: MediaItem, kind: Kind) = set(item, kind, !state.value.contains(item.key, kind))

  /** Nota 1–10 en pasos de 0.5; `null` la borra (la reseña se conserva). */
  fun rate(item: MediaItem, score: Double?) {
    remember(item)
    val now = Date()
    _state.update { st ->
      val previous = st.ratings[item.key]
      val value = score?.let { (kotlin.math.round(it * 2) / 2.0).coerceIn(1.0, 10.0) }
      val review = previous?.review.orEmpty()
      val deleted = value == null && review.isEmpty()
      st.copy(ratings = st.ratings + (item.key to RatingStamp(value ?: 0.0, review, now, deleted)))
    }
  }

  /** Reseña personal (viaja con la nota en el sync, F4). Vacía la borra sin nota. */
  fun setReview(item: MediaItem, text: String) {
    remember(item)
    val now = Date()
    _state.update { st ->
      val previous = st.ratings[item.key]
      val review = text.trim()
      val score = previous?.score ?: 0.0
      val deleted = review.isEmpty() && score == 0.0
      st.copy(ratings = st.ratings + (item.key to RatingStamp(score, review, now, deleted)))
    }
  }

  fun setEpisode(tvId: Int, season: Int, episode: Int, watched: Boolean) {
    val now = Date()
    _state.update { st ->
      val key = State.episodeKey(tvId, season, episode)
      val stamp = EpisodeStamp(tvId, season, episode, now, deleted = !watched)
      st.copy(episodes = st.episodes + (key to stamp))
    }
  }

  fun toggleEpisode(tvId: Int, season: Int, episode: Int) =
    setEpisode(tvId, season, episode, !state.value.isEpisodeWatched(tvId, season, episode))

  fun seasonWatchedCount(tvId: Int, season: Int): Int =
    _state.value.episodes.values.count { it.tvId == tvId && it.season == season && !it.deleted }

  fun toggleSeason(tvId: Int, season: Int, episodeNumbers: List<Int>) {
    val allWatched = episodeNumbers.all { state.value.isEpisodeWatched(tvId, season, it) }
    episodeNumbers.forEach { setEpisode(tvId, season, it, watched = !allWatched) }
  }
}
