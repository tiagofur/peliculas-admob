package mx.creapolis.peliculas.android.features.widget

import mx.creapolis.peliculas.android.core.network.TmdbImage
import mx.creapolis.peliculas.android.core.network.TmdbMovie

/** Un título del widget de Tendencias (gemelo de `TrendItem` en iOS, sin la imagen). */
data class TrendItem(
  val id: Int,
  val title: String,
  val rating: Double,
  val year: String,
  val posterPath: String?,
) {
  /** Enlace propio a la ficha; el widget lo abre dentro de la app. */
  val link: String get() = "https://peliculas.creapolis.dev/movie/$id"

  /** "2026 · ★ 8.2", sin las partes que falten. */
  val meta: String
    get() = listOfNotNull(
      year.takeIf { it.isNotEmpty() },
      if (rating > 0) "★ %.1f".format(java.util.Locale.US, rating) else null,
    ).joinToString(" · ")

  fun posterUrl(size: String): String? = TmdbImage.url(posterPath, size)
}

object TrendItems {
  /** Cuántos títulos enseña el tamaño mediano (igual que iOS). */
  const val MAX = 3

  /** Enlace cuando no hay título que abrir (sin conexión). */
  const val FALLBACK_LINK = "https://peliculas.creapolis.dev/trending"

  /** Los primeros [MAX] resultados con id y título válidos, en el orden de TMDB. */
  fun from(results: List<TmdbMovie>): List<TrendItem> =
    results.asSequence()
      .mapNotNull { m ->
        val title = (m.title ?: m.name).orEmpty().trim()
        if (m.id <= 0 || title.isEmpty()) return@mapNotNull null
        TrendItem(
          id = m.id,
          title = title,
          rating = m.voteAverage ?: 0.0,
          year = (m.releaseDate ?: m.firstAirDate).orEmpty().take(4),
          posterPath = m.posterPath?.takeIf { it.isNotEmpty() },
        )
      }
      .take(MAX)
      .toList()
}
