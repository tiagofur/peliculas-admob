package mx.creapolis.peliculas.android.features.search

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.model.toMediaItem
import mx.creapolis.peliculas.android.core.network.MediaListSource
import mx.creapolis.peliculas.android.core.network.TmdbClient
import mx.creapolis.peliculas.android.core.network.TmdbGenre
import mx.creapolis.peliculas.android.core.network.TmdbPerson

/** Ámbitos de búsqueda (port de `SearchLoader.Scope`). */
enum class SearchScope { ALL, MOVIES, SERIES }

/** Historial de búsquedas persistente (8, más reciente primero) — como iOS. */
interface SearchHistory {
  fun load(): List<String>
  fun add(term: String)
  fun clear()
}

class SharedPrefsSearchHistory(context: Context) : SearchHistory {
  private val prefs = context.getSharedPreferences("peliculas.search.history.v1", Context.MODE_PRIVATE)
  private val json = Json { ignoreUnknownKeys = true }

  override fun load(): List<String> =
    prefs.getString(KEY, null)?.let { runCatching { json.decodeFromString<List<String>>(it) }.getOrNull() } ?: emptyList()

  override fun add(term: String) {
    val trimmed = term.trim()
    if (trimmed.isEmpty()) return
    val next = (listOf(trimmed) + load().filterNot { it.equals(trimmed, ignoreCase = true) }).take(8)
    prefs.edit().putString(KEY, json.encodeToString(next)).apply()
  }

  override fun clear() = prefs.edit().remove(KEY).apply()

  private companion object { const val KEY = "history" }
}

/**
 * Búsqueda (port de `SearchLoader`): debounce 350 ms, scopes, mezcla por
 * relevancia aproximada en "Todo", personas en paralelo, infinite scroll.
 */
class SearchViewModel(private val history: SearchHistory) : ViewModel() {

  data class UiState(
    val query: String = "",
    val scope: SearchScope = SearchScope.ALL,
    val results: List<MediaItem> = emptyList(),
    val people: List<TmdbPerson> = emptyList(),
    val searching: Boolean = false,
    val failed: Boolean = false,
    val done: Boolean = false,
    val loadingMore: Boolean = false,
    val history: List<String> = emptyList(),
    val movieGenres: List<TmdbGenre> = emptyList(),
    val tvGenres: List<TmdbGenre> = emptyList(),
  )

  private val _state = MutableStateFlow(UiState(history = history.load()))
  val state: StateFlow<UiState> = _state.asStateFlow()

  private var page = 1
  private val maxPages = 10
  private var debounce: Job? = null

  init {
    viewModelScope.launch {
      val movies = runCatching { TmdbClient.genres(MediaKind.MOVIE) }.getOrDefault(emptyList())
      val tv = runCatching { TmdbClient.genres(MediaKind.TV) }.getOrDefault(emptyList())
      _state.update { it.copy(movieGenres = movies, tvGenres = tv) }
    }
  }

  fun onQueryChange(q: String, immediate: Boolean = false) {
    _state.update { it.copy(query = q) }
    debounce?.cancel()
    if (q.trim().length < 2) {
      _state.update { it.copy(results = emptyList(), people = emptyList(), searching = false, failed = false, done = false) }
      return
    }
    debounce = viewModelScope.launch {
      if (!immediate) delay(350)
      search(q)
    }
  }

  fun onSubmit() = onQueryChange(_state.value.query, immediate = true)

  fun onScopeChange(scope: SearchScope) {
    if (scope == _state.value.scope) return
    _state.update { it.copy(scope = scope) }
    val q = _state.value.query
    if (q.trim().length >= 2) onQueryChange(q, immediate = true)
  }

  fun clearHistory() {
    history.clear()
    _state.update { it.copy(history = emptyList()) }
  }

  private suspend fun search(q: String) {
    val trimmed = q.trim()
    _state.update { it.copy(searching = true, people = emptyList()) }
    try {
      val page1 = fetchPage(trimmed, 1)
      // Personas solo en "Todo" y en paralelo tolerante a fallo (como iOS).
      val people = if (_state.value.scope == SearchScope.ALL) {
        runCatching { TmdbClient.searchPeople(trimmed) }.getOrDefault(emptyList())
          .filter { !it.name.isNullOrEmpty() && !it.profilePath.isNullOrEmpty() }
          .take(3)
      } else emptyList()
      page = 1
      _state.update {
        it.copy(
          results = page1.second,
          people = people,
          searching = false,
          failed = false,
          done = page1.second.isEmpty() || 1 >= minOf(maxPages, maxOf(1, page1.first)),
          history = if (page1.second.isEmpty()) it.history else historyWith(trimmed),
        )
      }
    } catch (e: kotlinx.coroutines.CancellationException) {
      throw e
    } catch (_: Exception) {
      _state.update { it.copy(results = emptyList(), searching = false, failed = true, done = false) }
    }
  }

  private fun historyWith(term: String): List<String> {
    history.add(term)
    return history.load()
  }

  /** Página de búsqueda: (totalPages, items). La mezcla "Todo" replica el score de iOS. */
  private suspend fun fetchPage(q: String, page: Int): Pair<Int, List<MediaItem>> {
    val scope = _state.value.scope
    return when (scope) {
      SearchScope.MOVIES -> {
        val r = TmdbClient.pagedList(MediaListSource.Search(q, MediaKind.MOVIE), page)
        r.totalPages to r.results.map { it.toMediaItem(MediaKind.MOVIE) }
      }
      SearchScope.SERIES -> {
        val r = TmdbClient.pagedList(MediaListSource.Search(q, MediaKind.TV), page)
        r.totalPages to r.results.map { it.toMediaItem(MediaKind.TV) }
      }
      SearchScope.ALL -> {
        val m = TmdbClient.pagedList(MediaListSource.Search(q, MediaKind.MOVIE), page)
        val t = TmdbClient.pagedList(MediaListSource.Search(q, MediaKind.TV), page)
        val mixed = m.results.map { it.toMediaItem(MediaKind.MOVIE) } +
          t.results.map { it.toMediaItem(MediaKind.TV) }
        minOf(m.totalPages, t.totalPages) to mixed.sortedByDescending { score(it, q) }
      }
    }
  }

  /** Relevancia aproximada (port de `score` en iOS): nota + póster + coincidencia. */
  fun score(item: MediaItem, q: String): Double {
    var s = item.rating
    if (item.posterPath.isEmpty()) s -= 5
    val title = item.title.lowercase()
    val needle = q.lowercase()
    s += when {
      title == needle -> 10
      title.startsWith(needle) -> 3
      else -> 0
    }
    return s
  }

  /** Infinite scroll de resultados (dedupe + tope, como iOS). */
  fun loadMore() {
    val st = _state.value
    if (st.searching || st.loadingMore || st.done || st.results.isEmpty()) return
    viewModelScope.launch {
      _state.update { it.copy(loadingMore = true) }
      try {
        val q = st.query.trim()
        val next = page + 1
        val (totalPages, items) = fetchPage(q, next)
        page = next
        _state.update { cur ->
          val existing = cur.results.map { it.key }.toSet()
          cur.copy(
            results = cur.results + items.filter { it.key !in existing },
            loadingMore = false,
            done = items.isEmpty() || next >= minOf(maxPages, maxOf(1, totalPages)),
          )
        }
      } catch (e: kotlinx.coroutines.CancellationException) {
        throw e
      } catch (_: Exception) {
        // Silencioso: el pie reintenta la misma página (como iOS).
        _state.update { it.copy(loadingMore = false) }
      }
    }
  }

  companion object {
    fun factory(context: Context): ViewModelProvider.Factory =
      viewModelFactory {
        initializer { SearchViewModel(SharedPrefsSearchHistory(context.applicationContext)) }
      }
  }
}
