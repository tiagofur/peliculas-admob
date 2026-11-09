package mx.creapolis.peliculas.android.core.lists

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.toMediaItem
import mx.creapolis.peliculas.android.core.network.MediaListSource
import mx.creapolis.peliculas.android.core.network.TmdbClient
import mx.creapolis.peliculas.android.core.network.TmdbMovie
import mx.creapolis.peliculas.android.core.network.TmdbPagedMovies

/**
 * Carga paginada con infinite scroll (port de `PagedListLoader` en iOS):
 * deduplica títulos y se detiene al agotar `total_pages` o al tope defensivo.
 * `loadMore` es suspend puro: el llamador le da scope (VM en producción,
 * `runTest` en tests). El `fetch` se inyecta para probar sin red.
 * `keep` filtra resultados crudos (p. ej. estrenos ya pasados en "Próximos").
 */
class PagedListState(
  private val source: MediaListSource,
  seed: List<MediaItem> = emptyList(),
  private val maxPages: Int = 10,
  private val keep: (TmdbMovie) -> Boolean = { true },
  private val fetch: suspend (MediaListSource, Int) -> TmdbPagedMovies = { s, p -> TmdbClient.pagedList(s, p) },
) {
  data class UiState(
    val items: List<MediaItem> = emptyList(),
    val loading: Boolean = false,
    /** Una primera página fallida deja la pantalla vacía: se muestra error con reintentar. */
    val failed: Boolean = false,
    /** Un load-more fallido es recuperable en el pie de la lista. */
    val loadMoreFailed: Boolean = false,
    val done: Boolean = false,
  )

  private val _state = MutableStateFlow(UiState(items = seed))
  val state: StateFlow<UiState> = _state.asStateFlow()

  private var page = if (seed.isEmpty()) 0 else 1

  suspend fun loadMore() {
    val current = _state.value
    if (current.loading || current.done) return
    _state.update { it.copy(loading = true, failed = false, loadMoreFailed = false) }
    try {
      // Una página que no aporta títulos nuevos (repetidos o filtrados) no deja
      // la lista atascada con el pie visible: se pide la siguiente, hasta el tope.
      while (true) {
        val next = page + 1
        val result = fetch(source, next)
        page = next
        val before = _state.value.items.size
        _state.update { st ->
          val fresh = result.results.filter(keep).map { it.toMediaItem(source.kind) }
            .filter { m -> st.items.none { it.key == m.key } }
            .distinctBy { it.key }
          val done = result.results.isEmpty() || next >= minOf(maxPages, maxOf(1, result.totalPages))
          st.copy(items = st.items + fresh, done = done)
        }
        if (_state.value.items.size > before || _state.value.done) break
      }
      _state.update { it.copy(loading = false) }
    } catch (e: kotlinx.coroutines.CancellationException) {
      // Lista compartida: si cancelan a mitad, que no se quede "cargando" para siempre.
      _state.update { it.copy(loading = false) }
      throw e
    } catch (_: Exception) {
      _state.update { st ->
        if (st.items.isEmpty()) st.copy(loading = false, failed = true)
        else st.copy(loading = false, loadMoreFailed = true)
      }
    }
  }
}

/**
 * Un [PagedListState] atado al scope de quien lo posee. Las filas del Inicio
 * y "Ver todo" comparten la misma instancia: "Ver todo" sigue donde va la fila.
 */
class PagedList(private val list: PagedListState, private val scope: CoroutineScope) {
  val state: StateFlow<PagedListState.UiState> get() = list.state

  fun loadMore() {
    scope.launch { list.loadMore() }
  }
}

/** ViewModel mínimo que expone un [PagedList] propio a la UI (le da el scope). */
class PagedListViewModel(
  source: MediaListSource,
  seed: List<MediaItem> = emptyList(),
) : ViewModel() {
  val list = PagedList(PagedListState(source, seed), viewModelScope)

  init {
    if (seed.isEmpty()) list.loadMore()
  }
}
