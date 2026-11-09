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
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.VideoLibrary
import androidx.compose.material.icons.filled.Tv
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import mx.creapolis.peliculas.android.LocalAppContainer
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.network.AppConfig
import mx.creapolis.peliculas.android.features.home.SectionHeader
import mx.creapolis.peliculas.android.ui.components.AccountButton
import mx.creapolis.peliculas.android.ui.components.EmptyState
import mx.creapolis.peliculas.android.ui.components.PosterCard
import mx.creapolis.peliculas.android.ui.components.PosterImage
import mx.creapolis.peliculas.android.ui.components.RemoteImage
import mx.creapolis.peliculas.android.ui.components.RootTitleBar
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

/** Pestaña "Siguiente" (port de `UpNextView` en iOS). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UpNextScreen(
  onOpenItem: (MediaItem) -> Unit,
  onSearchSeries: () -> Unit = {},
  onOpenAccount: () -> Unit = {},
) {
  val container = LocalAppContainer.current
  val store = container.upNext
  val state by store.state.collectAsState()
  val pro by container.proStore.state.collectAsState()
  val scope = rememberCoroutineScope()
  var refreshing by remember { mutableStateOf(false) }

  // La raíz recalcula al marcar episodios o seguir series (RootScaffold).

  Column(Modifier.fillMaxSize()) {
    RootTitleBar(stringResource(R.string.tab_up_next)) { AccountButton(onClick = onOpenAccount) }

    val started = state.entries.filter { it.started }
    val notStarted = state.entries.filter { !it.started }
    when {
      state.entries.isEmpty() && state.upcoming.isEmpty() && (state.loading || !state.loadedOnce) ->
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
      state.entries.isEmpty() && state.upcoming.isEmpty() -> EmptyState(
        icon = Icons.Filled.VideoLibrary,
        title = stringResource(R.string.upnext_empty_title),
        message = stringResource(R.string.upnext_empty_hint),
        modifier = Modifier.fillMaxSize(),
      ) {
        Button(onClick = onSearchSeries) { Text(stringResource(R.string.search_series)) }
      }
      else -> PullToRefreshBox(
        isRefreshing = refreshing,
        onRefresh = {
          scope.launch {
            refreshing = true
            container.library.sync()
            store.loadNow(force = true)
            refreshing = false
          }
        },
      ) {
        LazyColumn(contentPadding = PaddingValues(bottom = 24.dp), modifier = Modifier.fillMaxSize()) {
          if (started.isNotEmpty()) {
            item { SectionHeader(stringResource(R.string.upnext_continue)) }
            items(started, key = { "s-${it.id}" }) { entry ->
              UpNextCard(
                entry = entry,
                onOpen = { onOpenItem(entry.show) },
                onWatched = { store.markWatched(entry) },
                width = null,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 7.dp),
              )
            }
          }
          if (state.upcoming.isNotEmpty()) {
            item { SectionHeader(stringResource(R.string.upnext_upcoming)) }
            items(state.upcoming, key = { "u-${it.id}" }) { entry -> UpcomingRow(entry) { onOpenItem(entry.show) } }
            if (AppConfig.EPISODE_PUSH_AVAILABLE && AppConfig.Pro.SALES_ENABLED && !pro.isPro) {
              item {
                val reason = stringResource(R.string.upnext_pro_reason)
                TextButton(
                  onClick = { container.proStore.presentPaywall(reason) },
                  modifier = Modifier.padding(horizontal = 12.dp),
                ) {
                  Icon(Icons.Filled.NotificationsActive, null, Modifier.size(18.dp))
                  Spacer(Modifier.width(8.dp))
                  Text(stringResource(R.string.upnext_notify), fontWeight = FontWeight.SemiBold)
                }
              }
            }
          }
          if (notStarted.isNotEmpty()) {
            item { SectionHeader(stringResource(R.string.upnext_to_start)) }
            item {
              LazyRow(
                contentPadding = PaddingValues(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
              ) {
                items(notStarted, key = { "n-${it.id}" }) { entry ->
                  PosterCard(entry.show, width = 112.dp) { onOpenItem(entry.show) }
                }
              }
            }
          }
        }
      }
    }
  }
}

/** Fila de estreno: bloque de fecha tipo calendario + póster + episodio (como iOS). */
@Composable
private fun UpcomingRow(entry: UpcomingEntry, onOpen: () -> Unit) {
  val locale = Locale.getDefault()
  val days = UpNextCalculator.daysUntil(entry.airDate)
  val relative = when (days) {
    0L -> stringResource(R.string.today)
    1L -> stringResource(R.string.tomorrow)
    else -> stringResource(R.string.in_n_days, days.toInt())
  }
  Row(
    Modifier
      .fillMaxWidth()
      .clickable(onClick = onOpen)
      .padding(horizontal = 20.dp, vertical = 8.dp),
    verticalAlignment = Alignment.CenterVertically,
    horizontalArrangement = Arrangement.spacedBy(14.dp),
  ) {
    Column(Modifier.width(48.dp), horizontalAlignment = Alignment.CenterHorizontally) {
      Text(
        entry.airDate.month.getDisplayName(TextStyle.SHORT, locale).uppercase(locale).trimEnd('.'),
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.primary,
      )
      Text(
        entry.airDate.format(DateTimeFormatter.ofPattern("d")),
        style = MaterialTheme.typography.headlineSmall,
        fontWeight = FontWeight.Bold,
      )
    }
    PosterImage(entry.show.posterPath, width = 44.dp)
    Column(Modifier.weight(1f)) {
      Text(
        entry.show.title,
        style = MaterialTheme.typography.bodyMedium,
        fontWeight = FontWeight.SemiBold,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
      Text(
        listOf(entry.episode.label, entry.name).filter { it.isNotEmpty() }.joinToString(" · "),
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
      Text(relative, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
  }
}

/**
 * Tarjeta horizontal de episodio (fotograma + progreso + check), como
 * `UpNextCard` de iOS. `width = null` ocupa todo el ancho (lista vertical).
 */
@Composable
fun UpNextCard(
  entry: UpNextEntry,
  onOpen: () -> Unit,
  onWatched: () -> Unit,
  width: Dp? = 280.dp,
  modifier: Modifier = Modifier,
) {
  val haptics = LocalHapticFeedback.current
  val markLabel = stringResource(R.string.mark_episode_watched_fmt, entry.next.label)
  Column(
    modifier
      .then(if (width != null) Modifier.width(width) else Modifier.fillMaxWidth())
      .clickable(onClick = onOpen),
  ) {
    Box(
      Modifier
        .fillMaxWidth()
        .then(if (width != null) Modifier.height(width * 9 / 16) else Modifier.height(190.dp))
        .clip(RoundedCornerShape(14.dp)),
    ) {
      RemoteImage(
        path = entry.stillPath.ifEmpty { entry.show.backdropPath },
        size = "w780",
        placeholder = Icons.Filled.Tv,
        modifier = Modifier.fillMaxSize(),
      )
      Box(
        Modifier.fillMaxSize().background(
          Brush.verticalGradient(0.5f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.7f)),
        ),
      )
      Column(Modifier.align(Alignment.BottomStart).padding(12.dp)) {
        Text(
          entry.next.label,
          style = MaterialTheme.typography.labelLarge,
          fontWeight = FontWeight.Bold,
          color = Color.White.copy(alpha = 0.9f),
        )
        if (entry.airedCount > 0) {
          LinearProgressIndicator(
            progress = { entry.progress.toFloat() },
            modifier = Modifier
              .width(110.dp)
              .padding(top = 6.dp)
              .height(4.dp)
              .clip(RoundedCornerShape(2.dp)),
            color = Color.White,
            trackColor = Color.White.copy(alpha = 0.3f),
          )
        }
      }
      FilledIconButton(
        onClick = {
          haptics.performHapticFeedback(HapticFeedbackType.Confirm)
          onWatched()
        },
        modifier = Modifier
          .align(Alignment.TopEnd)
          .padding(8.dp)
          .size(36.dp)
          .semantics { },
        colors = IconButtonDefaults.filledIconButtonColors(containerColor = Color.Black.copy(alpha = 0.45f)),
      ) {
        Icon(Icons.Filled.Check, contentDescription = markLabel, tint = Color.White, modifier = Modifier.size(20.dp))
      }
    }
    Column(Modifier.padding(top = 8.dp)) {
      Text(
        entry.show.title,
        style = MaterialTheme.typography.bodyMedium,
        fontWeight = FontWeight.SemiBold,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
      Text(
        when {
          entry.episodeTitle.isNotEmpty() -> entry.episodeTitle
          entry.started -> stringResource(R.string.upnext_next_episode)
          else -> stringResource(R.string.upnext_start_show)
        },
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
    }
  }
}
