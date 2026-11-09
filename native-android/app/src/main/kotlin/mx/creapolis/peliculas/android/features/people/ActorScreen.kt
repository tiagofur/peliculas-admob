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
import androidx.compose.foundation.background
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.material.icons.filled.PersonOff
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
fun ActorScreen(
  personId: Int,
  fallbackName: String,
  onOpenItem: (mx.creapolis.peliculas.android.core.model.MediaItem) -> Unit = {},
) {
  var detail by remember { mutableStateOf<TmdbPersonDetail?>(null) }
  var credits by remember { mutableStateOf<List<mx.creapolis.peliculas.android.core.model.MediaItem>>(emptyList()) }
  var failed by remember { mutableStateOf(false) }
  var creditsLoaded by remember { mutableStateOf(false) }
  var bioExpanded by remember { mutableStateOf(false) }
  var attempt by remember { mutableIntStateOf(0) }

  LaunchedEffect(personId, attempt) {
    failed = false
    val d = runCatching { TmdbClient.person(personId) }.getOrNull()
    if (d == null) {
      failed = true
      return@LaunchedEffect
    }
    detail = d
    val cast = runCatching { TmdbClient.personCredits(personId) }.getOrDefault(emptyList())
    credits = actorFilmography(cast)
    creditsLoaded = true
  }

  if (failed && detail == null) {
    mx.creapolis.peliculas.android.ui.components.EmptyState(
      icon = androidx.compose.material.icons.Icons.Filled.PersonOff,
      title = stringResource(R.string.person_load_error),
      message = stringResource(R.string.offline_message),
      modifier = Modifier.fillMaxSize(),
    ) {
      androidx.compose.material3.Button(onClick = { attempt++ }) { Text(stringResource(R.string.retry)) }
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
                .size(110.dp)
                .clip(androidx.compose.foundation.shape.CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
            )
            Column(Modifier.weight(1f)) {
              Text(d.name ?: fallbackName, style = MaterialTheme.typography.titleLarge)
              d.knownForDepartment?.takeIf { it.isNotEmpty() }?.let {
                Text(
                  departmentRes(it)?.let { res -> stringResource(res) } ?: it,
                  style = MaterialTheme.typography.labelLarge,
                  color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
              }
              d.birthday?.takeIf { it.isNotEmpty() }?.let { b ->
                val shown = mx.creapolis.peliculas.android.features.upnext.UpNextStore.parseDay(b)
                  ?.format(java.time.format.DateTimeFormatter.ofLocalizedDate(java.time.format.FormatStyle.LONG)) ?: b
                Text(
                  stringResource(R.string.person_born, shown),
                  style = MaterialTheme.typography.labelMedium,
                  color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
              }
              d.placeOfBirth?.takeIf { it.isNotEmpty() }?.let {
                Text(
                  it,
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
    if (!creditsLoaded && detail != null) {
      item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
        CircularProgressIndicator(Modifier.padding(16.dp))
      }
    }
    items(credits, key = { it.key.description }) {
      mx.creapolis.peliculas.android.ui.components.PosterCard(it, Modifier.fillMaxWidth()) { onOpenItem(it) }
    }
  }
}

/**
 * Filmografía como iOS: sin duplicados (un actor puede salir dos veces en una
 * serie y Compose no admite claves repetidas), solo con póster y lo mejor
 * valorado primero. Android la muestra completa en cuadrícula (hasta 60).
 */
fun actorFilmography(cast: List<mx.creapolis.peliculas.android.core.network.TmdbMovie>): List<mx.creapolis.peliculas.android.core.model.MediaItem> {
  val seen = mutableSetOf<mx.creapolis.peliculas.android.core.model.MediaKey>()
  return cast.map { m ->
    val kind = if (m.mediaType == "tv" || (m.mediaType == null && m.firstAirDate != null)) MediaKind.TV else MediaKind.MOVIE
    m.toMediaItem(kind)
  }
    .filter { it.posterPath.isNotEmpty() && seen.add(it.key) }
    .sortedByDescending { it.rating }
    .take(60)
}

/** TMDB manda el departamento siempre en inglés (mismo mapa que iOS). */
private fun departmentRes(raw: String): Int? = when (raw) {
  "Acting" -> R.string.dept_acting
  "Directing" -> R.string.dept_directing
  "Writing" -> R.string.dept_writing
  "Production" -> R.string.dept_production
  "Creator" -> R.string.dept_creator
  "Sound" -> R.string.dept_sound
  "Camera" -> R.string.dept_camera
  "Editing" -> R.string.dept_editing
  "Art" -> R.string.dept_art
  "Visual Effects" -> R.string.dept_vfx
  "Costume & Make-Up" -> R.string.dept_costume
  "Crew" -> R.string.dept_crew
  else -> null
}
