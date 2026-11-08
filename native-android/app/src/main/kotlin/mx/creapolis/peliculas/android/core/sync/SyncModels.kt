package mx.creapolis.peliculas.android.core.sync

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder


import kotlinx.serialization.json.JsonElement




import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement

import java.time.Instant
import java.util.Date
import mx.creapolis.peliculas.android.core.model.MediaKind

/** Clase de fila de biblioteca en el wire (favorito/watchlist/vista). */
@Serializable
enum class LibraryKind(val wire: String) {
  @SerialName("favorite") FAVORITE("favorite"),
  @SerialName("watchlist") WATCHLIST("watchlist"),
  @SerialName("watched") WATCHED("watched");
}

/** Fechas ISO-8601 tolerantes (fracciones de 0 a 9 dígitos, offsets). */
object IsoDateSerializer : KSerializer<Date> {
  override val descriptor: SerialDescriptor =
    PrimitiveSerialDescriptor("Date", PrimitiveKind.STRING)
  override fun serialize(encoder: Encoder, value: Date) {
    encoder.encodeString(IsoDate.format(value.toInstant()))
  }
  override fun deserialize(decoder: Decoder): Date =
    Date.from(IsoDate.parse(decoder.decodeString()) ?: Instant.EPOCH)
}

/** Fecha nullable para `watched_at`. */
object IsoDateNullableSerializer : KSerializer<Date?> {
  override val descriptor: SerialDescriptor =
    PrimitiveSerialDescriptor("Date?", PrimitiveKind.STRING)
  override fun serialize(encoder: Encoder, value: Date?) {
    if (value == null) encoder.encodeNull() else encoder.encodeString(IsoDate.format(value.toInstant()))
  }
  override fun deserialize(decoder: Decoder): Date? {
    if (decoder.decodeNotNullMark()) { return IsoDate.parse(decoder.decodeString())?.let { Date.from(it) } } else return null
    return IsoDate.parse(decoder.decodeString())?.let { Date.from(it) }
  }
}

// MARK: Filas (mismo wire que iOS/SyncModels)

@Serializable
data class LibraryRow(
  val kind: LibraryKind,
  @SerialName("media_type") val mediaType: MediaKind,
  @SerialName("tmdb_id") val tmdbId: Int,
  val title: String,
  @SerialName("poster_path") val posterPath: String,
  val year: String,
  @SerialName("updated_at") @Serializable(with = IsoDateSerializer::class) val updatedAt: Date,
  val deleted: Boolean,
)

@Serializable
data class ListRow(
  val id: String,
  val name: String,
  val description: String,
  val position: Int,
  @SerialName("updated_at") @Serializable(with = IsoDateSerializer::class) val updatedAt: Date,
  val deleted: Boolean,
)

@Serializable
data class ListItemRow(
  @SerialName("list_id") val listId: String,
  @SerialName("media_type") val mediaType: MediaKind,
  @SerialName("tmdb_id") val tmdbId: Int,
  val title: String,
  @SerialName("poster_path") val posterPath: String,
  val year: String,
  val position: Int,
  @SerialName("updated_at") @Serializable(with = IsoDateSerializer::class) val updatedAt: Date,
  val deleted: Boolean,
)

@Serializable
data class RatingRow(
  @SerialName("media_type") val mediaType: MediaKind,
  @SerialName("tmdb_id") val tmdbId: Int,
  val score: Double,
  val review: String,
  val title: String,
  @SerialName("poster_path") val posterPath: String,
  @SerialName("updated_at") @Serializable(with = IsoDateSerializer::class) val updatedAt: Date,
  val deleted: Boolean,
)

@Serializable
data class EpisodeRow(
  @SerialName("tv_id") val tvId: Int,
  val season: Int,
  val episode: Int,
  @SerialName("watched_at") @Serializable(with = IsoDateNullableSerializer::class) val watchedAt: Date?,
  @SerialName("updated_at") @Serializable(with = IsoDateSerializer::class) val updatedAt: Date,
  val deleted: Boolean,
)

// MARK: SyncOp (lógica de clave/orden portada de iOS)

/** Un cambio pendiente de subir. */
sealed class SyncOp {
  /** Dos ops con la misma clave se pisan: solo sube la última. */
  abstract val key: String

  /** Las listas suben antes que sus elementos (el servidor exige que existan). */
  abstract val order: Int

  data class Library(val row: LibraryRow) : SyncOp() {
    override val key: String get() = "lib:${row.kind.wire}:${row.mediaType.rawValue}:${row.tmdbId}"
    override val order: Int get() = 1
  }
  data class List(val row: ListRow) : SyncOp() {
    override val key: String get() = "list:${row.id}"
    override val order: Int get() = 0
  }
  data class ListItem(val row: ListItemRow) : SyncOp() {
    override val key: String get() = "li:${row.listId}:${row.mediaType.rawValue}:${row.tmdbId}"
    override val order: Int get() = 2
  }
  data class Rating(val row: RatingRow) : SyncOp() {
    override val key: String get() = "rate:${row.mediaType.rawValue}:${row.tmdbId}"
    override val order: Int get() = 1
  }
  data class Episode(val row: EpisodeRow) : SyncOp() {
    override val key: String get() = "ep:${row.tvId}:${row.season}:${row.episode}"
    override val order: Int get() = 1
  }
}

/** Formato de wire de una op: `{"entity": "...", "data": {...}}`. */
@Serializable
data class SyncOpEnvelope(val entity: String, val data: JsonElement)

fun SyncOp.toEnvelope(json: kotlinx.serialization.json.Json): SyncOpEnvelope = when (this) {
  is SyncOp.Library -> SyncOpEnvelope("library", json.encodeToJsonElement(LibraryRow.serializer(), row))
  is SyncOp.List -> SyncOpEnvelope("list", json.encodeToJsonElement(ListRow.serializer(), row))
  is SyncOp.ListItem -> SyncOpEnvelope("list_item", json.encodeToJsonElement(ListItemRow.serializer(), row))
  is SyncOp.Rating -> SyncOpEnvelope("rating", json.encodeToJsonElement(RatingRow.serializer(), row))
  is SyncOp.Episode -> SyncOpEnvelope("episode", json.encodeToJsonElement(EpisodeRow.serializer(), row))
}

fun SyncOpEnvelope.toOp(json: kotlinx.serialization.json.Json): SyncOp? = when (entity) {
  "library" -> SyncOp.Library(json.decodeFromJsonElement(LibraryRow.serializer(), data))
  "list" -> SyncOp.List(json.decodeFromJsonElement(ListRow.serializer(), data))
  "list_item" -> SyncOp.ListItem(json.decodeFromJsonElement(ListItemRow.serializer(), data))
  "rating" -> SyncOp.Rating(json.decodeFromJsonElement(RatingRow.serializer(), data))
  "episode" -> SyncOp.Episode(json.decodeFromJsonElement(EpisodeRow.serializer(), data))
  else -> null
}

// MARK: Push / Pull

@Serializable
data class SyncPushBody(val ops: List<SyncOpEnvelope>)

@Serializable
data class SyncPushResultItem(val index: Int, val status: String, val error: String? = null)

@Serializable
data class SyncPushResult(val results: List<SyncPushResultItem> = emptyList())

@Serializable
data class SyncPull(
  val cursor: String,
  @SerialName("has_more") val hasMore: Boolean,
  val library: List<LibraryRow>? = null,
  val lists: List<ListRow>? = null,
  @SerialName("list_items") val listItems: List<ListItemRow>? = null,
  val ratings: List<RatingRow>? = null,
  val episodes: List<EpisodeRow>? = null,
)

/** Decodifica una lista de envelopes desde un array JSON (persistencia del outbox). */
fun decodeEnvelopes(json: kotlinx.serialization.json.Json, element: JsonElement): List<SyncOp> =
  json.decodeFromJsonElement(ListSerializer(SyncOpEnvelope.serializer()), element)
    .mapNotNull { it.toOp(json) }

fun encodeEnvelopes(json: kotlinx.serialization.json.Json, ops: List<SyncOp>): JsonElement =
  json.encodeToJsonElement(ListSerializer(SyncOpEnvelope.serializer()), ops.map { it.toEnvelope(json) })
