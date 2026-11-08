package mx.creapolis.peliculas.android.features.search

import androidx.annotation.StringRes
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.SentimentSatisfied
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Mood
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.FamilyRestroom
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.SentimentDissatisfied
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.MediaListSource

/**
 * Descubrimiento curado (port de `Mood` en iOS): cada mood es `discover`
 * con filtros fijos, paridad con las categorías de la app Flutter.
 */
enum class Mood(
  @StringRes val titleRes: Int,
  val icon: ImageVector,
  val colors: Pair<Color, Color>,
  val source: MediaListSource.Discover,
) {
  ROMANTIC(R.string.mood_romantic, Icons.Filled.Favorite, Color(0xFFF48FB1) to Color(0xFFE53935),
    MediaListSource.Discover(MediaKind.MOVIE, "10749", 200)),
  HIDDEN_GEMS(R.string.mood_hidden_gems, Icons.Filled.AutoAwesome, Color(0xFF26A69A) to Color(0xFF4DB6AC),
    MediaListSource.Discover(MediaKind.MOVIE, "18", 300, minRating = 7.2, order = "vote_count.desc")),
  ADRENALINE(R.string.mood_adrenaline, Icons.Filled.Bolt, Color(0xFFFF9800) to Color(0xFFE53935),
    MediaListSource.Discover(MediaKind.MOVIE, "28", 200)),
  CRY(R.string.mood_cry, Icons.Filled.SentimentDissatisfied, Color(0xFF5C6BC0) to Color(0xFF42A5F5),
    MediaListSource.Discover(MediaKind.MOVIE, "18", 300, minRating = 7.0)),
  FAMILY(R.string.mood_family, Icons.Filled.FamilyRestroom, Color(0xFFFFCA28) to Color(0xFFFF9800),
    MediaListSource.Discover(MediaKind.MOVIE, "10751", 150)),
  MIND_BENDING(R.string.mood_mind_bending, Icons.Filled.Psychology, Color(0xFFAB47BC) to Color(0xFF5C6BC0),
    MediaListSource.Discover(MediaKind.MOVIE, "878,9648", 300, minRating = 7.0)),
  COMFORT(R.string.mood_comfort, Icons.Filled.SentimentSatisfied, Color(0xFF66BB6A) to Color(0xFF4DB6AC),
    MediaListSource.Discover(MediaKind.MOVIE, "35", 200)),
  SCARY_NIGHT(R.string.mood_scary, Icons.Filled.DarkMode, Color(0xFF37474F) to Color(0xFF7B1FA2),
    MediaListSource.Discover(MediaKind.MOVIE, "27", 150));
}
