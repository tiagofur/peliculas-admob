package mx.creapolis.peliculas.android.ui.navigation

import androidx.annotation.StringRes
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.MediaListSource

/**
 * Destinos "Ver todo" del Inicio (clave de navegación + título + source).
 * Espejo de los SeeAll de iOS; los géneros/moods de F2 añadirán los suyos.
 */
enum class SeeAllRoute(val key: String, val titleRes: Int, val source: MediaListSource) {
  TRENDING_WEEK("trending-week", R.string.seeall_trending_week,
    MediaListSource.Trending(MediaKind.MOVIE, "week")),
  TRENDING_TV("trending-tv", R.string.seeall_trending_tv,
    MediaListSource.Trending(MediaKind.TV, "week")),
  NOW_PLAYING("now-playing", R.string.seeall_now_playing, MediaListSource.NowPlaying),
  UPCOMING("upcoming", R.string.seeall_upcoming, MediaListSource.Upcoming),
  TOP_RATED("top-rated", R.string.seeall_top_rated,
    MediaListSource.TopRated(MediaKind.MOVIE));

  companion object {
    fun fromKey(key: String): SeeAllRoute? = entries.firstOrNull { it.key == key }
  }
}
