package mx.creapolis.peliculas.android.features.home

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.delay
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.ui.components.BackdropImage
import mx.creapolis.peliculas.android.ui.components.BottomScrim
import mx.creapolis.peliculas.android.ui.components.PosterCard
import mx.creapolis.peliculas.android.ui.navigation.SeeAllRoute

/** Inicio (port de `HomeView` en iOS): héroe a sangre, rails, pull-to-refresh. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
  onSeeAll: (SeeAllRoute) -> Unit,
  vm: HomeViewModel = viewModel(),
) {
  val state by vm.state.collectAsState()
  // Fuera del LazyColumn: su lambda de contenido no es composable.
  val railShowsTitle = stringResource(R.string.rail_trending_shows)
  val railNowPlayingTitle = stringResource(R.string.rail_now_playing)
  val railUpcomingTitle = stringResource(R.string.rail_upcoming)
  val railTopRatedTitle = stringResource(R.string.rail_top_rated)

  PullToRefreshBox(isRefreshing = state.loading, onRefresh = vm::refresh) {
    LazyColumn(
      modifier = Modifier.fillMaxSize(),
      contentPadding = PaddingValues(bottom = 24.dp),
    ) {
      // Héroe
      item {
        if (state.featured.isNotEmpty()) {
          HeroCarousel(items = state.featured)
        } else {
          HeroPlaceholder(
            loading = state.loading,
            failed = state.failed || state.featuredFailed,
            retry = vm::refresh,
          )
        }
      }

      // Top 10 de la semana
      if (state.trending.isNotEmpty()) {
        item {
          SectionHeader(
            title = stringResource(R.string.top10_title),
            subtitle = stringResource(R.string.top10_subtitle),
            onSeeAll = { onSeeAll(SeeAllRoute.TRENDING_WEEK) },
          )
        }
        item {
          LazyRow(
            contentPadding = PaddingValues(horizontal = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
          ) {
            itemsIndexed(state.trending.take(10)) { i, item -> Top10Card(rank = i + 1, item = item) }
          }
        }
      }

      rail(railShowsTitle, state.trendingShows, SeeAllRoute.TRENDING_TV, onSeeAll)
      rail(railNowPlayingTitle, state.nowPlaying, SeeAllRoute.NOW_PLAYING, onSeeAll)
      rail(railUpcomingTitle, state.upcoming, SeeAllRoute.UPCOMING, onSeeAll)
      rail(railTopRatedTitle, state.topRated, SeeAllRoute.TOP_RATED, onSeeAll)

      item { TmdbAttribution() }
    }
  }
}

private fun LazyListScope.rail(
  title: String,
  items: List<MediaItem>,
  route: SeeAllRoute,
  onSeeAll: (SeeAllRoute) -> Unit,
) {
  if (items.isEmpty()) return
  item { SectionHeader(title = title, onSeeAll = { onSeeAll(route) }) }
  item {
    LazyRow(
      contentPadding = PaddingValues(horizontal = 20.dp),
      horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
      items(items) { PosterCard(it) }
    }
  }
}

@Composable
fun SectionHeader(title: String, subtitle: String? = null, onSeeAll: (() -> Unit)? = null) {
  Row(
    modifier = Modifier
      .fillMaxWidth()
      .padding(horizontal = 20.dp, vertical = 12.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Column(Modifier.weight(1f)) {
      Text(title, style = MaterialTheme.typography.titleMedium)
      if (subtitle != null) {
        Text(
          subtitle,
          style = MaterialTheme.typography.labelMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
    }
    if (onSeeAll != null) {
      TextButton(onClick = onSeeAll) { Text(stringResource(R.string.see_all)) }
    }
  }
}

@Composable
private fun HeroCarousel(items: List<MediaItem>) {
  val context = LocalContext.current
  val pagerState = rememberPagerState(pageCount = { items.size })
  val reduceMotion = remember { isAnimatorDisabled(context) }

  // Avance automático cada 7 s (como iOS), salvo con animaciones desactivadas.
  LaunchedEffect(pagerState.currentPage, reduceMotion) {
    if (!reduceMotion && items.size > 1) {
      delay(7_000)
      pagerState.animateScrollToPage((pagerState.currentPage + 1) % items.size)
    }
  }

  Box(
    Modifier
      .fillMaxWidth()
      .height(460.dp),
  ) {
    HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { page ->
      HeroPage(item = items[page])
    }
    Row(
      Modifier
        .align(Alignment.BottomCenter)
        .padding(bottom = 14.dp),
      horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
      repeat(items.size) { i ->
        val selected = i == pagerState.currentPage
        Box(
          Modifier
            .size(width = if (selected) 18.dp else 6.dp, height = 6.dp)
            .clip(CircleShape)
            .background(
              if (selected) MaterialTheme.colorScheme.primary
              else MaterialTheme.colorScheme.outlineVariant,
            ),
        )
      }
    }
  }
}

@Composable
private fun HeroPage(item: MediaItem) {
  Box(Modifier.fillMaxSize()) {
    BackdropImage(path = item.backdropPath, modifier = Modifier.fillMaxSize(), size = "w1280")
    Box(Modifier.fillMaxSize().background(BottomScrim(0.75f)))
    Column(
      Modifier
        .align(Alignment.BottomStart)
        .padding(20.dp)
        .padding(bottom = 28.dp),
    ) {
      Text(
        if (item.kind == MediaKind.TV) stringResource(R.string.badge_show) else stringResource(R.string.badge_movie),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
      Text(
        item.title,
        style = MaterialTheme.typography.headlineMedium,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
      )
      val meta = listOfNotNull(
        item.year.takeIf { it.isNotEmpty() },
        item.rating.takeIf { it > 0 }?.let { "%.1f".format(it) },
      )
      if (meta.isNotEmpty()) {
        Text(
          meta.joinToString(" · "),
          style = MaterialTheme.typography.bodyMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
      if (item.overview.isNotEmpty()) {
        Text(
          item.overview,
          style = MaterialTheme.typography.bodyMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
          maxLines = 2,
          overflow = TextOverflow.Ellipsis,
        )
      }
      // Los botones (Ver ficha / Watchlist) llegan con Detalle (F3) y Biblioteca (F4).
    }
  }
}

/** Tarjeta del Top 10 con el número gigante (como `Top10Rail` en iOS). */
@Composable
private fun Top10Card(rank: Int, item: MediaItem) {
  Row(verticalAlignment = Alignment.Bottom) {
    Text(
      "$rank",
      style = MaterialTheme.typography.displayLarge,
      fontWeight = androidx.compose.ui.text.font.FontWeight.Black,
      color = MaterialTheme.colorScheme.primary.copy(alpha = 0.85f),
      modifier = Modifier.padding(end = 0.dp),
    )
    Spacer(Modifier.size(0.dp))
    PosterCard(item)
  }
}

@Composable
private fun HeroPlaceholder(loading: Boolean, failed: Boolean, retry: () -> Unit) {
  Box(
    Modifier
      .fillMaxWidth()
      .height(360.dp),
    contentAlignment = Alignment.Center,
  ) {
    when {
      loading -> CircularProgressIndicator()
      failed -> Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier.padding(24.dp),
      ) {
        Text(
          stringResource(R.string.home_load_error),
          style = MaterialTheme.typography.titleSmall,
          textAlign = TextAlign.Center,
        )
        Button(onClick = retry) { Text(stringResource(R.string.retry)) }
      }
      else -> Spacer(Modifier.height(1.dp))
    }
  }
}

@Composable
private fun TmdbAttribution() {
  Text(
    stringResource(R.string.tmdb_attribution),
    style = MaterialTheme.typography.labelSmall,
    color = MaterialTheme.colorScheme.onSurfaceVariant,
    modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp),
  )
}

/** "Reducir movimiento" aproximado en Android: escala de animación a 0. */
private fun isAnimatorDisabled(context: android.content.Context): Boolean = try {
  android.provider.Settings.Global.getFloat(
    context.contentResolver,
    android.provider.Settings.Global.ANIMATOR_DURATION_SCALE,
    1f,
  ) == 0f
} catch (_: Exception) {
  false
}
