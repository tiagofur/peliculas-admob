package mx.creapolis.peliculas.android.core.library

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKey
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.ApiClient
import mx.creapolis.peliculas.android.core.network.ApiError
import mx.creapolis.peliculas.android.core.sync.EpisodeRow
import mx.creapolis.peliculas.android.core.sync.IsoDateNullableSerializer
import mx.creapolis.peliculas.android.core.sync.IsoDateSerializer
import mx.creapolis.peliculas.android.core.sync.LibraryKind
import mx.creapolis.peliculas.android.core.sync.LibraryRow
import mx.creapolis.peliculas.android.core.sync.ListItemRow
import mx.creapolis.peliculas.android.core.sync.ListRow
import mx.creapolis.peliculas.android.core.sync.RatingRow
import mx.creapolis.peliculas.android.core.sync.SyncOp
import mx.creapolis.peliculas.android.core.sync.SyncPull
import mx.creapolis.peliculas.android.core.sync.SyncPushBody
import mx.creapolis.peliculas.android.core.sync.SyncPushResult
import mx.creapolis.peliculas.android.core.sync.toEnvelope
import mx.creapolis.peliculas.android.core.sync.decodeEnvelopes
import mx.creapolis.peliculas.android.core.sync.encodeEnvelopes
import java.io.File
import java.util.Date
import java.util.UUID

/**
 * Biblioteca local sincronizada (port de `LibraryStore` en iOS): estado en
 * memoria con stamps + outbox de cambios + pull con cursor (last-write-wins),
 * persistencia JSON atómica y merge al iniciar sesión. La superficie usada
 * por el Detalle (F3) no cambia.
 */
class LibraryStore(
  filesDir: File? = null,
  private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO),
) {

  enum class Kind { WATCHLIST, FAVORITE, WATCHED }

  @Serializable
  data class Stamp(
    @kotlinx.serialization.Serializable(with = IsoDateSerializer::class) val updatedAt: Date,
    val deleted: Boolean,
  )

  @Serializable
  data class RatingStamp(
    val score: Double,
    val review: String,
    @kotlinx.serialization.Serializable(with = IsoDateSerializer::class) val updatedAt: Date,
    val deleted: Boolean,
  )

  @Serializable
  data class ListStamp(
    val id: String,
    val name: String,
    val position: Int,
    @kotlinx.serialization.Serializable(with = IsoDateSerializer::class) val updatedAt: Date,
    val deleted: Boolean,
  )

  @Serializable
  data class ListItemStamp(
    val listId: String,
    val key: MediaKey,
    val position: Int,
    @kotlinx.serialization.Serializable(with = IsoDateSerializer::class) val updatedAt: Date,
    val deleted: Boolean,
  )

  @Serializable
  data class EpisodeStamp(
    val tvId: Int,
    val season: Int,
    val episode: Int,
    @kotlinx.serialization.Serializable(with = IsoDateSerializer::class) val updatedAt: Date,
    val deleted: Boolean,
  )

  @Serializable
  data class Snapshot(
    val marks: Map<String, Map<String, Stamp>> = emptyMap(),
    val ratings: Map<String, RatingStamp> = emptyMap(),
    val lists: Map<String, ListStamp> = emptyMap(),
    val listItems: Map<String, ListItemStamp> = emptyMap(),
    val episodes: Map<String, EpisodeStamp> = emptyMap(),
    val recent: List<String> = emptyList(),
    val items: Map<String, MediaItem> = emptyMap(),
    val outbox: kotlinx.serialization.json.JsonElement? = null,
    val cursor: String? = null,
    @kotlinx.serialization.Serializable(with = IsoDateNullableSerializer::class) val lastSync: Date? = null,
  )

  data class State(
    val marks: Map<Kind, Map<MediaKey, Stamp>> = emptyMap(),
    val ratings: Map<MediaKey, RatingStamp> = emptyMap(),
    val lists: Map<String, ListStamp> = emptyMap(),
    val listItems: Map<String, ListItemStamp> = emptyMap(),
    val episodes: Map<String, EpisodeStamp> = emptyMap(),
    val recent: List<MediaKey> = emptyList(),
    val items: Map<MediaKey, MediaItem> = emptyMap(),
    val syncing: Boolean = false,
    val lastSync: Date? = null,
    val lastSyncError: String? = null,
  ) {
    fun contains(key: MediaKey, kind: Kind): Boolean = marks[kind]?.get(key)?.deleted == false
    fun score(key: MediaKey): Double? = ratings[key]?.takeIf { !it.deleted && it.score > 0 }?.score
    fun review(key: MediaKey): String? = ratings[key]?.takeIf { !it.deleted && it.review.isNotEmpty() }?.review
    fun isEpisodeWatched(tvId: Int, season: Int, episode: Int): Boolean =
      episodes[episodeKey(tvId, season, episode)]?.deleted == false
    fun seasonWatchedCount(tvId: Int, season: Int): Int =
      episodes.values.count { it.tvId == tvId && it.season == season && !it.deleted }
    fun count(kind: Kind): Int = marks[kind].orEmpty().count { !it.value.deleted }
    val ratedCount: Int get() = ratings.values.count { !it.deleted && it.score > 0 }
    fun isInList(id: String, key: MediaKey): Boolean = listItems["$id|${key.kind.rawValue}:${key.id}"]?.deleted == false
    fun itemsOfList(id: String): List<MediaItem> =
      listItems.values.filter { it.listId == id && !it.deleted }
        .sortedBy { it.position }
        .mapNotNull { items[it.key] }
    val visibleLists: List<ListStamp>
      get() = lists.values.filter { !it.deleted }.sortedBy { it.position }
  }

  private val fileURL: File? = filesDir?.let { File(it, "library.v2.json") }
  private val isPersistent: Boolean get() = fileURL != null

  private val _state = MutableStateFlow(State())
  val state: StateFlow<State> = _state.asStateFlow()

  /** ¿Hay sesión? Lo cablea AppContainer (evita dependencia con SessionStore). */
  @Volatile
  var signedInCheck: () -> Boolean = { false }

  private var outbox: MutableList<SyncOp> = mutableListOf()
  private var cursor: String? = null
  private val syncMutex = Mutex()
  private var saveJob: Job? = null
  private var syncJob: Job? = null

  init {
    if (isPersistent) load()
  }

  // MARK: Lecturas de conveniencia (superficie F3 intacta)

  fun item(key: MediaKey): MediaItem? = _state.value.items[key]

  fun watchedItems(): List<MediaItem> =
    _state.value.marks[Kind.WATCHED].orEmpty().filter { !it.value.deleted }
      .keys.mapNotNull { _state.value.items[it] }

  /** Lo visto ordenado de más a menos reciente (historial, F6). */
  fun watchedLog(): List<Pair<MediaItem, Date>> =
    _state.value.marks[Kind.WATCHED].orEmpty().filter { !it.value.deleted }
      .entries.sortedByDescending { it.value.updatedAt }
      .mapNotNull { e -> _state.value.items[e.key]?.let { it to e.value.updatedAt } }

  /** Lo añadido recientemente (todas las secciones), más reciente primero. */
  fun recentlyAddedItems(): List<MediaItem> {
    val st = _state.value
    val all = Kind.entries.flatMap { kind ->
      st.marks[kind].orEmpty().filter { !it.value.deleted }.map { it.key to it.value.updatedAt }
    }
    val seen = mutableSetOf<MediaKey>()
    return all.sortedByDescending { it.second }
      .mapNotNull { (key, _) -> if (seen.add(key)) st.items[key] else null }
      .take(24)
  }

  // MARK: Cambios (superficie F3 + outbox)

  fun remember(item: MediaItem) {
    _state.update { st ->
      val merged = st.items[item.key]?.mergedWith(item) ?: item
      st.copy(items = st.items + (item.key to merged))
    }
    scheduleSave()
  }

  fun set(item: MediaItem, kind: Kind, on: Boolean) {
    remember(item)
    val now = Date()
    val wireKind = kind.wire()
    _state.update { st ->
      st.copy(marks = st.marks + (kind to (st.marks[kind].orEmpty() + (item.key to Stamp(now, !on)))))
    }
    enqueue(
      SyncOp.Library(
        LibraryRow(
          wireKind, item.kind, item.id, item.title,
          item.posterPath, item.year, now, !on,
        ),
      ),
    )
    // Marcar vista quita de la watchlist (Apple TV / Letterboxd, como iOS).
    if (kind == Kind.WATCHED && on) {
      set(item, Kind.WATCHLIST, on = false)
    }
  }

  fun toggle(item: MediaItem, kind: Kind) = set(item, kind, !state.value.contains(item.key, kind))

  /** Nota 1–10 en pasos de 0.5. `null` la borra (la reseña se conserva). */
  fun rate(item: MediaItem, score: Double?) {
    remember(item)
    val now = Date()
    val value = score?.let { (kotlin.math.round(it * 2) / 2.0).coerceIn(1.0, 10.0) }
    val previous = _state.value.ratings[item.key]
    val review = previous?.review.orEmpty()
    val deleted = value == null && review.isEmpty()
    _state.update { st ->
      st.copy(ratings = st.ratings + (item.key to RatingStamp(value ?: 0.0, review, now, deleted)))
    }
    enqueue(
      SyncOp.Rating(
        RatingRow(
          item.kind, item.id, value ?: 0.0, review,
          item.title, item.posterPath, now, deleted,
        ),
      ),
    )
  }

  /** Reseña personal (viaja en el sync junto a la nota). Vacía la borra sin nota. */
  fun setReview(item: MediaItem, text: String) {
    remember(item)
    val now = Date()
    val review = text.trim()
    val score = _state.value.ratings[item.key]?.score ?: 0.0
    val deleted = review.isEmpty() && score == 0.0
    _state.update { st ->
      st.copy(ratings = st.ratings + (item.key to RatingStamp(score, review, now, deleted)))
    }
    enqueue(
      SyncOp.Rating(
        RatingRow(
          item.kind, item.id, score, review,
          item.title, item.posterPath, now, deleted,
        ),
      ),
    )
  }

  fun setEpisode(tvId: Int, season: Int, episode: Int, watched: Boolean) {
    val now = Date()
    _state.update { st ->
      st.copy(
        episodes = st.episodes + (episodeKey(tvId, season, episode) to EpisodeStamp(tvId, season, episode, now, !watched)),
      )
    }
    enqueue(
      SyncOp.Episode(
        EpisodeRow(
          tvId, season, episode,
          if (watched) now else null, now, !watched,
        ),
      ),
    )
  }

  fun toggleEpisode(tvId: Int, season: Int, episode: Int) =
    setEpisode(tvId, season, episode, !_state.value.isEpisodeWatched(tvId, season, episode))

  fun toggleSeason(tvId: Int, season: Int, episodeNumbers: List<Int>) {
    val allWatched = episodeNumbers.all { _state.value.isEpisodeWatched(tvId, season, it) }
    episodeNumbers.forEach { setEpisode(tvId, season, it, watched = !allWatched) }
  }

  // MARK: Listas propias

  fun createList(name: String): String {
    val trimmed = name.trim()
    val id = UUID.randomUUID().toString().lowercase()
    val now = Date()
    val position = (_state.value.lists.values.maxOfOrNull { it.position } ?: -1) + 1
    _state.update { st -> st.copy(lists = st.lists + (id to ListStamp(id, trimmed, position, now, false))) }
    enqueue(SyncOp.List(ListRow(id, trimmed, "", position, now, false)))
    return id
  }

  fun renameList(id: String, name: String) {
    val list = _state.value.lists[id] ?: return
    val updated = list.copy(name = name.trim(), updatedAt = Date())
    _state.update { st -> st.copy(lists = st.lists + (id to updated)) }
    enqueue(SyncOp.List(ListRow(id, updated.name, "", updated.position, updated.updatedAt, false)))
  }

  fun deleteList(id: String) {
    val list = _state.value.lists[id] ?: return
    val updated = list.copy(deleted = true, updatedAt = Date())
    _state.update { st -> st.copy(lists = st.lists + (id to updated)) }
    enqueue(SyncOp.List(ListRow(id, updated.name, "", updated.position, updated.updatedAt, true)))
  }

  fun toggleInList(item: MediaItem, listId: String) {
    remember(item)
    val k = listItemKey(listId, item.key)
    val on = _state.value.listItems[k]?.deleted != false
    val now = Date()
    val position = _state.value.listItems.values.count { it.listId == listId }
    _state.update { st ->
      st.copy(listItems = st.listItems + (k to ListItemStamp(listId, item.key, position, now, !on)))
    }
    enqueue(
      SyncOp.ListItem(
        ListItemRow(
          listId, item.kind, item.id, item.title,
          item.posterPath, item.year, position, now, !on,
        ),
      ),
    )
  }

  // MARK: Sync

  /** Sube la cola y baja lo nuevo. Sin sesión no hace nada (como iOS). */
  suspend fun sync() {
    if (!isPersistent) return
    if (!signedInCheck()) return
    syncMutex.withLock {
      if (_state.value.syncing) return@withLock
      _state.update { it.copy(syncing = true) }
      try {
        pushOutbox()
        var more = true
        var pages = 0
        while (more && pages < 50) {
          val data = ApiClient.authed("GET", "/v1/sync", query = cursor?.let { mapOf("cursor" to it) } ?: emptyMap())
          val page = ApiClient.decodeFromString<SyncPull>(data.decodeToString())
          apply(page)
          cursor = page.cursor
          more = page.hasMore
          pages++
        }
        _state.update { it.copy(lastSync = Date(), lastSyncError = null) }
        scheduleSave()
      } catch (e: ApiError) {
        if (e.code == "invalid_cursor") {
          cursor = null
          _state.update { it.copy(lastSyncError = null) }
        } else {
          _state.update { it.copy(lastSyncError = e.message) }
        }
      } catch (e: kotlinx.coroutines.CancellationException) {
        throw e
      } catch (_: Exception) {
        _state.update { it.copy(lastSyncError = "sync error") }
      } finally {
        _state.update { it.copy(syncing = false) }
      }
    }
  }

  private suspend fun pushOutbox() {
    while (outbox.isNotEmpty()) {
      val batch = outbox.sortedBy { it.order }.take(500)
      val data = ApiClient.authed(
        "POST", "/v1/sync",
        body = ApiClient.encodeToString(SyncPushBody(batch.map { it.toEnvelope(ApiClient.json) })),
      )
      val result = ApiClient.decodeFromString<SyncPushResult>(data.decodeToString())
      // applied / stale / invalid: la op ya no debe reintentarse en los tres casos.
      val sent = result.results.mapNotNull { batch.getOrNull(it.index) }.map { it.key }.toSet()
      outbox.removeAll { op -> op.key in sent }
      scheduleSave()
      if (result.results.size < batch.size) break
    }
  }

  /** Aplica una página del servidor: gana el `updated_at` más reciente. */
  fun apply(page: SyncPull) {
    _state.update { st ->
      var marks = st.marks
      var lists = st.lists
      var listItems = st.listItems
      var ratings = st.ratings
      var episodes = st.episodes
      var items = st.items

      fun rememberMinimal(key: MediaKey, title: String, poster: String, year: String) {
        if (title.isEmpty() && poster.isEmpty()) return
        val minimal = MediaItem.minimal(key, title, poster, year)
        items = items + (key to (items[key]?.mergedWith(minimal) ?: minimal))
      }

      for (row in page.library.orEmpty()) {
        val key = MediaKey(row.mediaType, row.tmdbId)
        val kind = row.kind.toKind()
        val local = marks[kind]?.get(key)
        if (local == null || row.updatedAt >= local.updatedAt) {
          marks = marks + (kind to ((marks[kind].orEmpty()) + (key to Stamp(row.updatedAt, row.deleted))))
        }
        rememberMinimal(key, row.title, row.posterPath, row.year)
      }
      for (row in page.lists.orEmpty()) {
        val id = row.id.lowercase()
        val local = lists[id]
        if (local == null || row.updatedAt >= local.updatedAt) {
          lists = lists + (id to ListStamp(id, row.name, row.position, row.updatedAt, row.deleted))
        }
      }
      for (row in page.listItems.orEmpty()) {
        val key = MediaKey(row.mediaType, row.tmdbId)
        val listId = row.listId.lowercase()
        val k = listItemKey(listId, key)
        val local = listItems[k]
        if (local == null || row.updatedAt >= local.updatedAt) {
          listItems = listItems + (k to ListItemStamp(listId, key, row.position, row.updatedAt, row.deleted))
        }
        rememberMinimal(key, row.title, row.posterPath, row.year)
      }
      for (row in page.ratings.orEmpty()) {
        val key = MediaKey(row.mediaType, row.tmdbId)
        val local = ratings[key]
        if (local == null || row.updatedAt >= local.updatedAt) {
          ratings = ratings + (key to RatingStamp(row.score, row.review, row.updatedAt, row.deleted))
        }
        rememberMinimal(key, row.title, row.posterPath, "")
      }
      for (row in page.episodes.orEmpty()) {
        val k = episodeKey(row.tvId, row.season, row.episode)
        val local = episodes[k]
        if (local == null || row.updatedAt >= local.updatedAt) {
          episodes = episodes + (k to EpisodeStamp(row.tvId, row.season, row.episode, row.updatedAt, row.deleted))
        }
      }
      st.copy(marks = marks, lists = lists, listItems = listItems, ratings = ratings, episodes = episodes, items = items)
    }
  }

  /** Primera vez con cuenta: sube todo lo local y baja todo lo del servidor. */
  suspend fun mergeAfterSignIn() {
    cursor = null
    outbox = fullSnapshotOps().toMutableList()
    scheduleSave()
    sync()
  }

  /** Al cerrar sesión o borrar la cuenta: la biblioteca pertenece a la cuenta. */
  fun resetForSignOut() {
    _state.update { st ->
      st.copy(
        marks = emptyMap(), ratings = emptyMap(), lists = emptyMap(),
        listItems = emptyMap(), episodes = emptyMap(), recent = emptyList(),
        lastSync = null, lastSyncError = null,
      )
    }
    outbox.clear()
    cursor = null
    scheduleSave()
  }

  private fun enqueue(op: SyncOp) {
    outbox.removeAll { it.key == op.key }
    outbox.add(op)
    scheduleSave()
    scheduleSync()
  }

  private fun scheduleSync() {
    if (!isPersistent) return
    syncJob?.cancel()
    syncJob = scope.launch {
      delay(3_000)
      sync()
    }
  }

  private fun fullSnapshotOps(): List<SyncOp> {
    val st = _state.value
    val ops = mutableListOf<SyncOp>()
    for (l in st.lists.values) {
      ops.add(SyncOp.List(ListRow(l.id, l.name, "", l.position, l.updatedAt, l.deleted)))
    }
    for ((kind, dict) in st.marks) {
      for ((key, s) in dict) {
        val item = st.items[key]
        ops.add(
          SyncOp.Library(
            LibraryRow(
              kind.wire(), key.kind, key.id, item?.title.orEmpty(),
              item?.posterPath.orEmpty(), item?.year.orEmpty(), s.updatedAt, s.deleted,
            ),
          ),
        )
      }
    }
    for ((key, r) in st.ratings) {
      val item = st.items[key]
      ops.add(
        SyncOp.Rating(
          RatingRow(
            key.kind, key.id, if (r.deleted) 0.0 else r.score, r.review,
            item?.title.orEmpty(), item?.posterPath.orEmpty(), r.updatedAt, r.deleted,
          ),
        ),
      )
    }
    for (li in st.listItems.values) {
      val item = st.items[li.key]
      ops.add(
        SyncOp.ListItem(
          ListItemRow(
            li.listId, li.key.kind, li.key.id, item?.title.orEmpty(),
            item?.posterPath.orEmpty(), item?.year.orEmpty(), li.position, li.updatedAt, li.deleted,
          ),
        ),
      )
    }
    for (e in st.episodes.values) {
      ops.add(
        SyncOp.Episode(
          EpisodeRow(
            e.tvId, e.season, e.episode,
            if (e.deleted) null else e.updatedAt, e.updatedAt, e.deleted,
          ),
        ),
      )
    }
    return ops
  }

  val pendingChanges: Int get() = outbox.size

  // MARK: Disco

  private fun scheduleSave() {
    if (!isPersistent) return
    saveJob?.cancel()
    saveJob = scope.launch {
      delay(400)
      saveNow()
    }
  }

  fun saveNow() {
    if (!isPersistent) return
    val st = _state.value
    val snapshot = Snapshot(
      marks = st.marks.mapKeys { e -> e.key.wireName() }
        .mapValues { (_, dict) -> dict.mapKeys { d -> d.key.description } },
      ratings = st.ratings.mapKeys { e -> e.key.description },
      lists = st.lists,
      listItems = st.listItems,
      episodes = st.episodes,
      recent = st.recent.map { it.description },
      items = st.items.mapKeys { e -> e.key.description },
      outbox = encodeEnvelopes(ApiClient.json, outbox),
      cursor = cursor,
      lastSync = st.lastSync,
    )
    runCatching {
      fileURL?.writeText(ApiClient.encodeToString(snapshot))
    }
  }

  private fun load() {
    val data = runCatching { fileURL?.readText() }.getOrNull() ?: return
    val snapshot = runCatching { ApiClient.decodeFromString<Snapshot>(data) }.getOrNull() ?: return

    val marks = mutableMapOf<Kind, MutableMap<MediaKey, Stamp>>()
    snapshot.marks.forEach { (wire, dict) ->
      val kind = wire.wireToKind() ?: return@forEach
      val bucket = marks.getOrPut(kind) { mutableMapOf() }
      dict.forEach { (k, v) -> MediaKey.parse(k)?.let { bucket[it] = v } }
    }
    val ratings = snapshot.ratings.mapNotNull { (k, v) -> MediaKey.parse(k)?.let { it to v } }.toMap()
    val items = snapshot.items.mapNotNull { (k, v) -> MediaKey.parse(k)?.let { it to v } }.toMap()

    _state.update { st ->
      st.copy(
        marks = marks,
        ratings = ratings,
        lists = snapshot.lists,
        listItems = snapshot.listItems,
        episodes = snapshot.episodes,
        recent = snapshot.recent.mapNotNull { MediaKey.parse(it) },
        items = items,
        lastSync = snapshot.lastSync,
      )
    }
    outbox = (snapshot.outbox?.let { decodeEnvelopes(ApiClient.json, it) } ?: emptyList()).toMutableList()
    cursor = snapshot.cursor
  }

  // MARK: Claves y conversiones

  private fun Kind.wire(): LibraryKind = when (this) {
    Kind.WATCHLIST -> LibraryKind.WATCHLIST
    Kind.FAVORITE -> LibraryKind.FAVORITE
    Kind.WATCHED -> LibraryKind.WATCHED
  }

  private fun Kind.wireName(): String = wire().wire

  private fun String.wireToKind(): Kind? = when (this) {
    "watchlist" -> Kind.WATCHLIST
    "favorite" -> Kind.FAVORITE
    "watched" -> Kind.WATCHED
    else -> null
  }

  private fun LibraryKind.toKind(): Kind = when (this) {
    LibraryKind.WATCHLIST -> Kind.WATCHLIST
    LibraryKind.FAVORITE -> Kind.FAVORITE
    LibraryKind.WATCHED -> Kind.WATCHED
  }

  companion object {
    fun listItemKey(listId: String, key: MediaKey): String = "$listId|${key.kind.rawValue}:${key.id}"
    fun episodeKey(tvId: Int, season: Int, episode: Int): String = "$tvId:$season:$episode"

    /** Store persistente de producción. */
    fun fromContext(context: Context): LibraryStore =
      LibraryStore(filesDir = context.filesDir)
  }
}
