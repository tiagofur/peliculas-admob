package mx.creapolis.peliculas.android.features.people

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.model.toMediaItem
import mx.creapolis.peliculas.android.core.network.TmdbClient
import mx.creapolis.peliculas.android.core.network.TmdbImage
import mx.creapolis.peliculas.android.core.network.TmdbPersonDetail

/** Ficha de persona (port de `ActorView` en iOS): foto, bio y filmografía. */
@Composable
fun ActorScreen(personId: Int, fallbackName: String) {
  var detail by remember { mutableStateOf<TmdbPersonDetail?>(null) }
  var credits by remember { mutableStateOf<List<mx.creapolis.peliculas.android.core.model.MediaItem>>(emptyList()) }
  var failed by remember { mutableStateOf(false) }
  var bioExpanded by remember { mutableStateOf(false) }

  LaunchedEffect(personId) {
    failed = false
    val d = runCatching { TmdbClient.person(personId) }.getOrNull()
    if (d == null) failed = true else detail = d
    val cast = runCatching { TmdbClient.personCredits(personId) }.getOrDefault(emptyList())
    credits = cast.mapNotNull { m ->
      val kind = when {
        m.mediaType == "tv" || m.firstAirDate != null -> MediaKind.TV
        else -> MediaKind.MOVIE
      }
      m.toMediaItem(kind)
    }
  }

  if (failed && detail == null) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
      Text(
        stringResource(R.string.offline_title),
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
    return
  }

  val d = detail
  LazyVerticalGrid(
    columns = GridCells.Adaptive(minSize = 104.dp),
    contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 24.dp),
    horizontalArrangement = Arrangement.spacedBy(14.dp),
    verticalArrangement = Arrangement.spacedBy(20.dp),
    modifier = Modifier.fillMaxSize(),
  ) {
    item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
      Column(Modifier.padding(top = 16.dp)) {
        if (d == null) {
          CircularProgressIndicator()
        } else {
          Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            AsyncImage(
              model = TmdbImage.url(d.profilePath, "w185"),
              contentDescription = d.name,
              contentScale = ContentScale.Crop,
              modifier = Modifier
                .size(96.dp)
                .clip(RoundedCornerShape(14.dp)),
            )
            Column(Modifier.weight(1f)) {
              Text(d.name ?: fallbackName, style = MaterialTheme.typography.titleLarge)
              d.knownForDepartment?.let {
                Text(
                  if (it == "Acting") stringResource(R.string.person_acting) else it,
                  style = MaterialTheme.typography.labelLarge,
                  color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
              }
              d.birthday?.takeIf { it.isNotEmpty() }?.let {
                Text(
                  "${it.take(4)}${d.placeOfBirth?.let { b -> " · $b" } ?: ""}",
                  style = MaterialTheme.typography.labelMedium,
                  color = MaterialTheme.colorScheme.onSurfaceVariant,
                  maxLines = 2,
                  overflow = TextOverflow.Ellipsis,
                )
              }
            }
          }
          val bio = d.biography.orEmpty()
          if (bio.isNotEmpty()) {
            Text(
              bio,
              style = MaterialTheme.typography.bodyMedium,
              color = MaterialTheme.colorScheme.onSurfaceVariant,
              maxLines = if (bioExpanded) Int.MAX_VALUE else 3,
              overflow = TextOverflow.Ellipsis,
              modifier = Modifier
                .padding(top = 12.dp)
                .clickable(enabled = bio.length > 240) { bioExpanded = !bioExpanded },
            )
          }
        }
        Text(
          stringResource(R.string.person_filmography),
          style = MaterialTheme.typography.titleMedium,
          modifier = Modifier.padding(top = 16.dp, bottom = 4.dp),
        )
      }
    }
    if (credits.isEmpty() && detail != null) {
      item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
        CircularProgressIndicator(Modifier.padding(16.dp))
      }
    }
    items(credits, key = { it.key.description }) {
      mx.creapolis.peliculas.android.ui.components.PosterCard(it, Modifier.fillMaxWidth())
    }
  }
}
