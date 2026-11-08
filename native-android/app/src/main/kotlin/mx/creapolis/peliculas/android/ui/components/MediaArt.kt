package mx.creapolis.peliculas.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.network.TmdbImage

/** Póster con título y pie (año · nota). Gemelo de `PosterCard` en iOS. */
@Composable
fun PosterCard(item: MediaItem, modifier: Modifier = Modifier, badge: String? = null, onClick: () -> Unit = {}) {
  Column(modifier = modifier.width(104.dp).clickable(onClick = onClick)) {
    Box(
      Modifier
        .fillMaxWidth()
        .aspectRatio(2f / 3f)
        .clip(RoundedCornerShape(12.dp))
        .background(MaterialTheme.colorScheme.surfaceVariant),
    ) {
      AsyncImage(
        model = TmdbImage.url(item.posterPath, "w342"),
        contentDescription = item.title,
        contentScale = ContentScale.Crop,
        modifier = Modifier.fillMaxSize(),
      )
      if (badge != null) {
        Text(
          badge,
          style = MaterialTheme.typography.labelSmall,
          color = Color.White,
          modifier = Modifier
            .align(Alignment.TopEnd)
            .padding(6.dp)
            .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(6.dp))
            .padding(horizontal = 6.dp, vertical = 2.dp),
        )
      }
    }
    Text(
      item.title,
      style = MaterialTheme.typography.bodySmall,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
      modifier = Modifier.padding(top = 6.dp),
    )
    val meta = listOfNotNull(item.year.takeIf { it.isNotEmpty() }, item.rating.takeIf { it > 0 }?.let { "%.1f".format(it) })
    if (meta.isNotEmpty()) {
      Text(
        meta.joinToString(" · "),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        maxLines = 1,
      )
    }
  }
}

/** Imagen de fondo (héroe, cabecera de detalle). */
@Composable
fun BackdropImage(path: String, modifier: Modifier = Modifier, size: String = "w780") {
  Box(modifier) {
    AsyncImage(
      model = TmdbImage.url(path, size),
      contentDescription = null,
      contentScale = ContentScale.Crop,
      modifier = Modifier.fillMaxSize(),
    )
  }
}

/** Velo degradado para texto legible sobre imágenes. */
fun BottomScrim(heightFraction: Float = 0.6f): Brush = Brush.verticalGradient(
  0f to Color.Transparent,
  (1f - heightFraction) to Color.Transparent,
  1f to Color.Black.copy(alpha = 0.75f),
)
