package mx.creapolis.peliculas.android.features.upnext

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil3.compose.AsyncImage
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.network.TmdbImage
import mx.creapolis.peliculas.android.ui.components.BackdropImage
import mx.creapolis.peliculas.android.ui.components.PosterCard

/** Pestaña "Siguiente" (port de `UpNextView` en iOS). */
@Composable
fun UpNextScreen(
  library: LibraryStore,
  onOpenItem: (mx.creapolis.peliculas.android.core.model.MediaItem) -> Unit,
  vm: UpNextViewModel = viewModel(factory = UpNextViewModel.factory(library)),
) {
  val state by vm.state.collectAsState()
  val lib by library.state.collectAsState()

  LaunchedEffect(lib) { vm.load() }

  when {
    state.entries.isEmpty() && state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
      CircularProgressIndicator()
    }
    state.entries.isEmpty() && state.upcoming.isEmpty() -> EmptyUpNext { vm.load() }
    else -> LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
      if (state.entries.isNotEmpty()) {
        item {
          Text(
            stringResource(R.string.upnext_continue),
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp),
          )
        }
        item {
          LazyRow(
            contentPadding = PaddingValues(horizontal = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
          ) {
            items(state.entries, key = { it.id }) { entry ->
              UpNextCard(entry = entry, onOpen = { onOpenItem(entry.show) }, onWatched = { vm.markWatched(entry) })
            }
          }
        }
      }
      if (state.upcoming.isNotEmpty()) {
        item {
          Text(
            stringResource(R.string.upnext_upcoming),
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp),
          )
        }
        items(state.upcoming, key = { "up-${it.id}" }) { entry ->
          Row(
            Modifier
              .fillMaxWidth()
              .clickable { onOpenItem(entry.show) }
              .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
          ) {
            PosterCard(entry.show)
            Column(Modifier.weight(1f).padding(start = 12.dp)) {
              Text(entry.show.title, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
              Text(
                entry.episode.label + (if (entry.name.isNotEmpty()) " · ${entry.name}" else ""),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
              )
              Text(
                entry.airDate.toString(),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
              )
            }
          }
        }
        item {
          // Los avisos de episodios son Pro (F7 conecta el paywall real).
          Column(
            Modifier
              .fillMaxWidth()
              .padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
          ) {
            OutlinedButton(onClick = { /* paywall en F7 */ }) {
              Icon(Icons.Filled.Notifications, contentDescription = null, modifier = Modifier.size(18.dp))
              Spacer(Modifier.width(8.dp))
              Text(stringResource(R.string.upnext_notify))
            }
          }
        }
      }
    }
  }
}

@Composable
private fun EmptyUpNext(retry: () -> Unit) {
  Column(
    Modifier.fillMaxSize().padding(24.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.Center,
  ) {
    Text(stringResource(R.string.upnext_empty), style = MaterialTheme.typography.titleSmall, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
    Text(
      stringResource(R.string.upnext_empty_hint),
      style = MaterialTheme.typography.bodyMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      textAlign = androidx.compose.ui.text.style.TextAlign.Center,
    )
    androidx.compose.material3.Button(onClick = retry, modifier = Modifier.padding(top = 12.dp)) {
      Text(stringResource(R.string.retry))
    }
  }
}

/** Tarjeta horizontal de episodio (fotograma + progreso + check), como iOS. */
@Composable
private fun UpNextCard(entry: UpNextEntry, onOpen: () -> Unit, onWatched: () -> Unit) {
  Column(
    Modifier
      .width(280.dp)
      .clickable(onClick = onOpen),
  ) {
    Box(
      Modifier
        .fillMaxWidth()
        .height(158.dp)
        .clip(RoundedCornerShape(14.dp)),
    ) {
      BackdropImage(
        path = entry.stillPath.ifEmpty { entry.show.backdropPath },
        modifier = Modifier.fillMaxSize(),
      )
      Box(
        Modifier.fillMaxSize().background(
          Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.7f))),
        ),
      )
      Column(Modifier.align(Alignment.BottomStart).padding(12.dp)) {
        Text(
          entry.next.label,
          style = MaterialTheme.typography.labelLarge,
          color = Color.White,
        )
        if (entry.airedCount > 0) {
          LinearProgressIndicator(
            progress = { entry.progress.toFloat() },
            modifier = Modifier
              .fillMaxWidth(0.4f)
              .padding(top = 6.dp)
              .height(4.dp)
              .clip(RoundedCornerShape(2.dp)),
            color = Color.White,
            trackColor = Color.White.copy(alpha = 0.3f),
          )
        }
      }
      androidx.compose.material3.FilledIconButton(
        onClick = onWatched,
        modifier = Modifier
          .align(Alignment.TopEnd)
          .padding(8.dp)
          .size(34.dp),
        colors = androidx.compose.material3.IconButtonDefaults.filledIconButtonColors(
          containerColor = Color.White.copy(alpha = 0.9f),
        ),
      ) {
        Icon(
          Icons.Filled.Check,
          contentDescription = stringResource(R.string.mark_watched),
          tint = Color.Black,
          modifier = Modifier.size(20.dp),
        )
      }
    }
    Column(Modifier.padding(top = 8.dp)) {
      Text(entry.show.title, style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
      Text(
        if (entry.episodeTitle.isNotEmpty()) entry.episodeTitle
        else if (entry.started) stringResource(R.string.upnext_next_episode)
        else stringResource(R.string.upnext_start_show),
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
    }
  }
}
