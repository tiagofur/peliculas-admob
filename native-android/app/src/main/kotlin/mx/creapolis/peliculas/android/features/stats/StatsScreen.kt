package mx.creapolis.peliculas.android.features.stats

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKey
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Cálculo puro de estadísticas (port de `LibraryStats` en iOS): ventana fija
 * de 12 meses con ceros, décadas por año de estreno, media sin notas borradas.
 */
data class LibraryStats(
  val watchedTotal: Int,
  val watchedMovies: Int,
  val watchedShows: Int,
  val averageScore: Double,
  val episodeCount: Int,
  val byMonth: List<ActivityMonth>,
  val byDecade: List<DecadeCount>,
) {
  data class ActivityMonth(val id: String, val label: String, val count: Int)
  data class DecadeCount(val id: String, val label: String, val count: Int)

  companion object {
    fun build(
      watched: Map<MediaKey, LibraryStore.Stamp>,
      ratings: Map<MediaKey, LibraryStore.RatingStamp>,
      episodeCount: Int,
      items: Map<MediaKey, MediaItem>,
      now: LocalDate = LocalDate.now(),
    ): LibraryStats {
      val live = watched.filter { !it.value.deleted }
      val scores = ratings.values.filter { !it.deleted && it.score > 0 }.map { it.score }
      val average = if (scores.isEmpty()) 0.0 else scores.sum() / scores.size

      // Ventana de 12 meses naturales, con ceros donde no hubo marcas.
      val stampFmt = DateTimeFormatter.ofPattern("yyyy-MM")
      val nameFmt = DateTimeFormatter.ofPattern("MMM", java.util.Locale.getDefault())
      val window = (0 until 12).reversed().map { back -> now.minusMonths(back.toLong()) }
      val ids = window.associate { m -> stampFmt.format(m) to nameFmt.format(m).replaceFirstChar { it.uppercase() } }
      val counts = mutableMapOf<String, Int>()
      for ((_, mark) in live) {
        val id = stampFmt.format(mark.updatedAt.toInstant().atZone(ZoneId.systemDefault()))
        if (ids.containsKey(id)) counts[id] = (counts[id] ?: 0) + 1
      }
      val byMonth = ids.entries.map { (id, label) ->
        ActivityMonth(id, label, counts[id] ?: 0)
      }

      // Épocas: año de estreno de lo visto.
      val perDecade = mutableMapOf<String, Int>()
      for ((key, _) in live) {
        val year = items[key]?.year?.take(4)?.toIntOrNull() ?: continue
        if (year < 1920) continue
        val decade = (year - year % 10).toString()
        perDecade[decade] = (perDecade[decade] ?: 0) + 1
      }
      val byDecade = perDecade.toSortedMap().map { (decade, count) ->
        DecadeCount(decade, "${decade.takeLast(2)}s", count)
      }

      return LibraryStats(
        watchedTotal = live.size,
        watchedMovies = live.count { it.key.kind == MediaKind.MOVIE },
        watchedShows = live.count { it.key.kind == MediaKind.TV },
        averageScore = average,
        episodeCount = episodeCount,
        byMonth = byMonth,
        byDecade = byDecade,
      )
    }
  }
}

/** Estadísticas (port de `StatsView` en iOS, con Canvas en vez de Swift Charts). */
@Composable
fun StatsScreen(library: LibraryStore) {
  val state by library.state.collectAsState()
  val stats = remember(state) {
    LibraryStats.build(
      watched = state.marks[LibraryStore.Kind.WATCHED].orEmpty(),
      ratings = state.ratings,
      episodeCount = state.episodes.values.count { !it.deleted },
      items = state.items,
    )
  }

  if (stats.watchedTotal == 0 && stats.episodeCount == 0) {
    Column(
      Modifier.fillMaxSize().padding(24.dp),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.Center,
    ) {
      Text(stringResource(R.string.stats_empty), style = MaterialTheme.typography.titleSmall, textAlign = TextAlign.Center)
      Text(
        stringResource(R.string.stats_empty_hint),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textAlign = TextAlign.Center,
      )
    }
    return
  }

  LazyColumn(
    Modifier.fillMaxSize(),
    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp, vertical = 16.dp),
    verticalArrangement = Arrangement.spacedBy(16.dp),
  ) {
    item {
      Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        StatTile(
          stringResource(R.string.stats_watched), "${stats.watchedTotal}",
          "${stats.watchedMovies} · ${stats.watchedShows}", Modifier.weight(1f),
        )
        StatTile(
          stringResource(R.string.stats_episodes), "${stats.episodeCount}",
          stringResource(R.string.stats_from_shows), Modifier.weight(1f),
        )
      }
    }
    item {
      Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        StatTile(
          stringResource(R.string.stats_avg),
          if (stats.averageScore > 0) "%.1f".format(stats.averageScore) else "—",
          stringResource(R.string.stats_out_of_10), Modifier.weight(1f),
        )
        StatTile(
          stringResource(R.string.stats_watchlist), "${state.count(LibraryStore.Kind.WATCHLIST)}",
          stringResource(R.string.stats_in_watchlist), Modifier.weight(1f),
        )
      }
    }
    if (stats.byMonth.any { it.count > 0 }) {
      item {
        ChartCard(stringResource(R.string.stats_activity), stringResource(R.string.stats_watched_month)) {
          BarChartVertical(
            values = stats.byMonth.map { it.count },
            labels = stats.byMonth.map { it.label },
            top = Color(0xFFFF7043), bottom = Color(0xFFE53935),
          )
        }
      }
    }
    if (stats.byDecade.isNotEmpty()) {
      item {
        ChartCard(stringResource(R.string.stats_eras), stringResource(R.string.stats_decade)) {
          BarChartHorizontal(
            entries = stats.byDecade.map { it.label to it.count },
            start = Color(0xFF5C6BC0), end = Color(0xFF42A5F5),
          )
        }
      }
    }
  }
}

@Composable
private fun StatTile(title: String, value: String, detail: String, modifier: Modifier = Modifier) {
  Column(
    modifier
      .clip(RoundedCornerShape(16.dp))
      .background(MaterialTheme.colorScheme.surfaceVariant)
      .padding(14.dp),
  ) {
    Text(title, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
    Text(value, style = MaterialTheme.typography.headlineMedium)
    Text(detail, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
  }
}

@Composable
private fun ChartCard(title: String, subtitle: String, chart: @Composable () -> Unit) {
  Column(
    Modifier
      .fillMaxWidth()
      .clip(RoundedCornerShape(16.dp))
      .background(MaterialTheme.colorScheme.surfaceVariant)
      .padding(16.dp),
  ) {
    Text(title, style = MaterialTheme.typography.titleSmall)
    Text(subtitle, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    Spacer(Modifier.height(12.dp))
    chart()
  }
}

/** Barras verticales con Canvas (actividad mensual). */
@Composable
private fun BarChartVertical(values: List<Int>, labels: List<String>, top: Color, bottom: Color) {
  val max = (values.maxOrNull() ?: 1).coerceAtLeast(1)
  Column {
    Canvas(
      Modifier
        .fillMaxWidth()
        .height(110.dp),
    ) {
      val gap = 6.dp.toPx()
      val barWidth = (size.width - gap * (values.size - 1)) / values.size
      values.forEachIndexed { i, v ->
        val h = size.height * (v.toFloat() / max)
        drawRoundRect(
          brush = Brush.verticalGradient(listOf(top, bottom)),
          topLeft = Offset(i * (barWidth + gap), size.height - h),
          size = androidx.compose.ui.geometry.Size(barWidth, h),
          cornerRadius = androidx.compose.ui.geometry.CornerRadius(4.dp.toPx()),
        )
      }
    }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      labels.filterIndexed { i, _ -> i % 3 == 0 }.forEach {
        Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
      }
    }
  }
}

/** Barras horizontales con etiqueta (épocas). */
@Composable
private fun BarChartHorizontal(
  entries: List<Pair<String, Int>>,
  start: Color, end: Color,
) {
  val max = (entries.maxOfOrNull { it.second } ?: 1).coerceAtLeast(1)
  Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
    entries.forEach { (label, v) ->
      Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.labelMedium, modifier = Modifier.width(36.dp))
        Canvas(
          Modifier
            .weight(1f)
            .height(16.dp),
        ) {
          val w = size.width * (v.toFloat() / max)
          drawRoundRect(
            brush = Brush.horizontalGradient(listOf(start, end)),
            topLeft = Offset.Zero,
            size = androidx.compose.ui.geometry.Size(w, size.height),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(6.dp.toPx()),
          )
        }
        Text(
          "$v",
          style = MaterialTheme.typography.labelMedium,
          modifier = Modifier.width(28.dp),
          textAlign = TextAlign.End,
        )
      }
    }
  }
}
