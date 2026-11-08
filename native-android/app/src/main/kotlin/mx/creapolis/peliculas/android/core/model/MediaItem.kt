package mx.creapolis.peliculas.android.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import mx.creapolis.peliculas.android.core.network.TmdbFullDetail
import mx.creapolis.peliculas.android.core.network.TmdbMovie

/** Equivalente de `MediaKind` en iOS: película o serie. */
@Serializable
enum class MediaKind(val rawValue: String) {
  @SerialName("movie") MOVIE("movie"),
  @SerialName("tv") TV("tv");
}

/**
 * Identidad de un título (port de `MediaKey`). TMDB reutiliza números entre
 * películas y series, así que la clave lleva el tipo.
 */
@Serializable
data class MediaKey(val kind: MediaKind, val id: Int) {
  val description: String get() = "${kind.rawValue}:$id"

  companion object {
    fun parse(string: String): MediaKey? {
      val parts = string.split(":")
      val kind = parts.getOrNull(0)?.let { runCatching { MediaKind.valueOf(it.uppercase()) }.getOrNull() }
      val id = parts.getOrNull(1)?.toIntOrNull()
      return if (parts.size == 2 && kind != null && id != null) MediaKey(kind, id) else null
    }
  }
}

/**
 * Modelo de título en la app (port de `MediaItem`). Serializable para guardar
 * la biblioteca sin red; los campos toleran cachés viejas (defaults, como iOS).
 */
@Serializable
data class MediaItem(
  val id: Int,
  val title: String,
  val overview: String = "",
  val posterPath: String = "",
  val backdropPath: String = "",
  val rating: Double = 0.0,
  val kind: MediaKind = MediaKind.MOVIE,
  val year: String = "",
) {
  val key: MediaKey get() = MediaKey(kind, id)

  val shareUrl: String
    get() = "https://peliculas.creapolis.dev/${if (kind == MediaKind.MOVIE) "movie" else "serie"}/$id"

  val shareText: String
    get() = "Mira «$title» — la encontré en Películas $shareUrl"

  /** Une dos fotos del mismo título quedándose con los campos más ricos. */
  fun mergedWith(other: MediaItem): MediaItem = MediaItem(
    id = id,
    title = if (other.title.isEmpty()) title else other.title,
    overview = if (other.overview.isEmpty()) overview else other.overview,
    posterPath = if (other.posterPath.isEmpty()) posterPath else other.posterPath,
    backdropPath = if (other.backdropPath.isEmpty()) backdropPath else other.backdropPath,
    rating = if (other.rating == 0.0) rating else other.rating,
    kind = kind,
    year = if (other.year.isEmpty()) year else other.year,
  )

  companion object {
    /** Título "mínimo" guardado en el servidor (sin sinopsis ni fondo). */
    fun minimal(key: MediaKey, title: String, posterPath: String, year: String) =
      MediaItem(id = key.id, title = title, posterPath = posterPath, year = year, kind = key.kind)
  }
}

/** Construye `MediaItem` desde el JSON crudo de TMDB. */
fun TmdbMovie.toMediaItem(kind: MediaKind): MediaItem = MediaItem(
  id = id,
  title = title ?: name ?: "Sin título",
  overview = overview ?: "",
  posterPath = posterPath ?: "",
  backdropPath = backdropPath ?: "",
  rating = voteAverage ?: 0.0,
  kind = kind,
  year = (releaseDate ?: firstAirDate ?: "").take(4),
)


/** Desde el detalle completo (port de `init(detail:kind:)` en iOS). */
fun TmdbFullDetail.toMediaItem(kind: MediaKind): MediaItem = MediaItem(
  id = id,
  title = displayTitle,
  overview = overview ?: "",
  posterPath = posterPath ?: "",
  backdropPath = backdropPath ?: "",
  rating = voteAverage ?: 0.0,
  kind = kind,
  year = (displayDate ?: "").take(4),
)
