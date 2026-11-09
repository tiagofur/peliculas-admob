package mx.creapolis.peliculas.android.ui.components

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.PlaylistAdd
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import mx.creapolis.peliculas.android.LocalAppContainer
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.TmdbImage

/** Imagen de TMDB con fondo e icono mientras carga o si no hay imagen (como `RemoteImage`). */
@Composable
fun RemoteImage(
  path: String?,
  size: String,
  modifier: Modifier = Modifier,
  placeholder: ImageVector = Icons.Filled.Movie,
  contentDescription: String? = null,
) {
  Box(modifier.background(MaterialTheme.colorScheme.surfaceVariant), contentAlignment = Alignment.Center) {
    Icon(
      placeholder,
      contentDescription = null,
      tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.35f),
      modifier = Modifier.size(28.dp),
    )
    if (!path.isNullOrEmpty()) {
      AsyncImage(
        model = TmdbImage.url(path, size),
        contentDescription = contentDescription,
        contentScale = ContentScale.Crop,
        modifier = Modifier.fillMaxSize(),
      )
    }
  }
}

/** Póster 2:3 con esquinas redondeadas (gemelo de `PosterImage` en iOS). */
@Composable
fun PosterImage(path: String, modifier: Modifier = Modifier, width: Dp = 104.dp) {
  RemoteImage(
    path = path,
    size = if (width > 160.dp) "w500" else "w342",
    modifier = modifier
      .width(width)
      .aspectRatio(2f / 3f)
      .clip(RoundedCornerShape(12.dp)),
  )
}

/**
 * Póster con título y pie (año · nota). Gemelo de `PosterCard` en iOS:
 * toque abre la ficha, pulsación larga abre las acciones rápidas.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun PosterCard(
  item: MediaItem,
  modifier: Modifier = Modifier,
  badge: String? = null,
  width: Dp = 104.dp,
  onClick: () -> Unit = {},
) {
  var menuOpen by remember { mutableStateOf(false) }
  val haptics = LocalHapticFeedback.current
  val kindLabel = stringResource(if (item.kind == MediaKind.TV) R.string.kind_show else R.string.kind_movie)
  Box(modifier.width(width)) {
    Column(
      Modifier
        .fillMaxWidth()
        .combinedClickable(
          onClick = onClick,
          onLongClick = {
            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            menuOpen = true
          },
          onLongClickLabel = stringResource(R.string.more_options),
        )
        .semantics { contentDescription = listOf(item.title, item.year, kindLabel).filter { it.isNotEmpty() }.joinToString(", ") },
    ) {
      Box(
        Modifier
          .fillMaxWidth()
          .aspectRatio(2f / 3f)
          .clip(RoundedCornerShape(12.dp)),
      ) {
        RemoteImage(item.posterPath, "w342", Modifier.fillMaxSize())
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
    MediaContextMenu(item = item, expanded = menuOpen, onDismiss = { menuOpen = false })
  }
}

/**
 * Acciones rápidas de un título (port de `MediaContextMenu` en iOS):
 * watchlist, favorito, visto, listas propias y compartir.
 */
@Composable
fun MediaContextMenu(item: MediaItem, expanded: Boolean, onDismiss: () -> Unit) {
  if (!expanded) return
  val container = LocalAppContainer.current
  val library = container.library
  val lib by library.state.collectAsState()
  val context = LocalContext.current
  val haptics = LocalHapticFeedback.current

  fun toggle(kind: LibraryStore.Kind) {
    library.toggle(item, kind)
    haptics.performHapticFeedback(HapticFeedbackType.ToggleOn)
    onDismiss()
  }

  DropdownMenu(expanded = true, onDismissRequest = onDismiss) {
    val inWatchlist = lib.contains(item.key, LibraryStore.Kind.WATCHLIST)
    DropdownMenuItem(
      text = { Text(stringResource(if (inWatchlist) R.string.remove_from_watchlist else R.string.add_to_watchlist)) },
      leadingIcon = { Icon(if (inWatchlist) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder, null) },
      onClick = { toggle(LibraryStore.Kind.WATCHLIST) },
    )
    val isFav = lib.contains(item.key, LibraryStore.Kind.FAVORITE)
    DropdownMenuItem(
      text = { Text(stringResource(if (isFav) R.string.remove_favorite else R.string.favorite)) },
      leadingIcon = { Icon(if (isFav) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder, null) },
      onClick = { toggle(LibraryStore.Kind.FAVORITE) },
    )
    val watched = lib.contains(item.key, LibraryStore.Kind.WATCHED)
    DropdownMenuItem(
      text = { Text(stringResource(if (watched) R.string.mark_unwatched else R.string.mark_watched)) },
      leadingIcon = { Icon(if (watched) Icons.Filled.VisibilityOff else Icons.Filled.CheckCircle, null) },
      onClick = { toggle(LibraryStore.Kind.WATCHED) },
    )
    if (lib.visibleLists.isNotEmpty()) {
      HorizontalDivider()
      Text(
        stringResource(R.string.add_to_list),
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
      )
      lib.visibleLists.forEach { list ->
        val inList = lib.isInList(list.id, item.key)
        DropdownMenuItem(
          text = { Text(list.name) },
          leadingIcon = { Icon(if (inList) Icons.Filled.Check else Icons.AutoMirrored.Filled.PlaylistAdd, null) },
          onClick = {
            library.toggleInList(item, list.id)
            onDismiss()
          },
        )
      }
    }
    HorizontalDivider()
    DropdownMenuItem(
      text = { Text(stringResource(R.string.share)) },
      leadingIcon = { Icon(Icons.Filled.Share, null) },
      onClick = {
        shareItem(context, library.item(item.key) ?: item)
        onDismiss()
      },
    )
  }
}

/** Hoja de compartir del sistema con el enlace universal (como `ShareLink` en iOS). */
fun shareItem(context: Context, item: MediaItem) {
  val text = context.getString(R.string.share_text, item.title, item.shareUrl)
  val send = Intent(Intent.ACTION_SEND).apply {
    type = "text/plain"
    putExtra(Intent.EXTRA_SUBJECT, item.title)
    putExtra(Intent.EXTRA_TEXT, text)
  }
  context.startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

/** Imagen de fondo (héroe, cabecera de detalle). */
@Composable
fun BackdropImage(path: String, modifier: Modifier = Modifier, size: String = "w780") {
  RemoteImage(path = path, size = size, modifier = modifier)
}

/** Velo degradado para texto legible sobre imágenes. */
fun BottomScrim(heightFraction: Float = 0.6f): Brush = Brush.verticalGradient(
  0f to Color.Transparent,
  (1f - heightFraction) to Color.Transparent,
  1f to Color.Black.copy(alpha = 0.75f),
)
