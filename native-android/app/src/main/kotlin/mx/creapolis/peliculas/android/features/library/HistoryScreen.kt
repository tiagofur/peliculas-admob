package mx.creapolis.peliculas.android.features.library

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.TmdbImage
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Historial completo de lo visto, agrupado por mes (port de `HistoryView`). */
@Composable
fun HistoryScreen(library: LibraryStore, onBack: () -> Unit, onOpenItem: (MediaItem) -> Unit) {
  val state by library.state.collectAsState()
  val fmt = DateTimeFormatter.ofPattern("MMMM yyyy", Locale.getDefault())
  val dayFmt = DateTimeFormatter.ofPattern("d MMM", Locale.getDefault())

  val grouped = remember(state) {
    val order = mutableListOf<String>()
    val buckets = mutableMapOf<String, MutableList<Pair<MediaItem, java.util.Date>>>()
    for ((item, date) in library.watchedLog()) {
      val key = fmt.format(date.toInstant().atZone(ZoneId.systemDefault())).replaceFirstChar { it.uppercase() }
      if (buckets[key] == null) order.add(key)
      buckets.getOrPut(key) { mutableListOf() }.add(item to date)
    }
    order.map { it to buckets[it].orEmpty() }
  }

  Column(Modifier.fillMaxSize()) {
    if (grouped.isEmpty()) {
      Column(
        Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
      ) {
        Text(
          stringResource(R.string.history_empty),
          style = MaterialTheme.typography.titleSmall,
          textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        Text(
          stringResource(R.string.history_empty_hint),
          style = MaterialTheme.typography.bodyMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
          textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
      }
      return
    }
    LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
      grouped.forEach { (month, entries) ->
        item(key = month) {
          Text(
            month,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp),
          )
        }
        items(entries.size) { i ->
          val (item, date) = entries[i]
          Row(
            Modifier
              .fillMaxWidth()
              .clickable { onOpenItem(item) }
              .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
          ) {
            AsyncImage(
              model = TmdbImage.url(item.posterPath, "w185"),
              contentDescription = item.title,
              contentScale = ContentScale.Crop,
              modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(8.dp)),
            )
            Column(Modifier.weight(1f).padding(start = 12.dp)) {
              Text(item.title, style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
              val kindLabel = if (item.kind == MediaKind.TV) stringResource(R.string.badge_show) else stringResource(R.string.badge_movie)
              val meta = listOfNotNull(item.year.takeIf { it.isNotEmpty() }, kindLabel).joinToString(" · ")
              if (meta.isNotEmpty()) {
                Text(meta, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
              }
            }
            Text(
              dayFmt.format(date.toInstant().atZone(ZoneId.systemDefault())),
              style = MaterialTheme.typography.labelMedium,
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
        }
      }
    }
  }
}
