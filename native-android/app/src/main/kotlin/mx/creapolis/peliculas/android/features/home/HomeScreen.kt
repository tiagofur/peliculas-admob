package mx.creapolis.peliculas.android.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import kotlinx.coroutines.launch
import mx.creapolis.peliculas.android.LocalAppContainer
import mx.creapolis.peliculas.android.features.upnext.UpNextCard
import mx.creapolis.peliculas.android.ui.components.AccountButton
import mx.creapolis.peliculas.android.ui.components.MediaContextMenu
import mx.creapolis.peliculas.android.ui.components.PosterImage
import mx.creapolis.peliculas.android.ui.components.TmdbAttribution
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
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.delay
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.lists.PagedList
import mx.creapolis.peliculas.android.core.lists.PagedListState
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
  onOpenItem: (MediaItem) -> Unit = {},
  onOpenAccount: () -> Unit = {},
  vm: HomeViewModel = viewModel(),
) {
  val container = LocalAppContainer.current
  val library = container.library
  val state by vm.state.collectAsState()
  val lib by library.state.collectAsState()
  val upNext by container.upNext.state.collectAsState()
  val scope = rememberCoroutineScope()
  // Fuera del LazyColumn: su lambda de contenido no es composable.
  val railShowsTitle = stringResource(R.string.rail_trending_shows)
  val railNowPlayingTitle = stringResource(R.string.rail_now_playing)
  val railUpcomingTitle = stringResource(R.string.rail_upcoming)
  val railTopRatedTitle = stringResource(R.string.rail_top_rated)
  val recentTitle = stringResource(R.string.recently_viewed)
  val personalTitle = state.personalSeedTitle?.let { stringResource(R.string.because_you_liked, it) }
  val personalSubtitle = stringResource(R.string.recommended_for_you)

  // "Porque te gustó X" sigue a tu favorito más reciente (como iOS).
  val latestFavorite = lib.items(LibraryStore.Kind.FAVORITE).firstOrNull { it.title.isNotEmpty() }
  LaunchedEffect(latestFavorite?.key) { vm.loadPersonal(latestFavorite) }
  LaunchedEffect(Unit) { if (!upNext.loadedOnce) container.upNext.load() }

  Box(Modifier.fillMaxSize()) {
    PullToRefreshBox(
      isRefreshing = state.loading && state.featured.isNotEmpty(),
      onRefresh = {
        vm.refresh()
        scope.launch { library.sync() }
      },
    ) {
      LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 24.dp),
      ) {
        // Héroe
        item {
          if (state.featured.isNotEmpty()) {
            HeroCarousel(items = state.featured, onOpenItem = onOpenItem, library = library)
          } else {
            HeroPlaceholder(
              loading = state.loading,
              failed = state.failed || state.featuredFailed,
              retry = vm::refresh,
            )
          }
        }

        // Continuar viendo (siguiente episodio de tus series)
        if (upNext.entries.isNotEmpty()) {
          item { SectionHeader(title = stringResource(R.string.upnext_continue)) }
          item {
            LazyRow(
              contentPadding = PaddingValues(horizontal = 20.dp),
              horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
              items(upNext.entries.take(10), key = { it.id }) { entry ->
                UpNextCard(
                  entry = entry,
                  onOpen = { onOpenItem(entry.show) },
                  onWatched = { container.upNext.markWatched(entry) },
                )
              }
            }
          }
        }

        rail(recentTitle, lib.recentItems, null, onSeeAll, onOpenItem)
        if (personalTitle != null) {
          rail(personalTitle, state.personal, null, onSeeAll, onOpenItem, subtitle = personalSubtitle)
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
              itemsIndexed(state.trending.take(10), key = { _, it -> it.key.description }) { i, item ->
                Top10Card(rank = i + 1, item = item) { onOpenItem(item) }
              }
            }
          }
        }

        pagedRail(railShowsTitle, state.rails[SeeAllRoute.TRENDING_TV], SeeAllRoute.TRENDING_TV, onSeeAll, onOpenItem)
        pagedRail(railNowPlayingTitle, state.rails[SeeAllRoute.NOW_PLAYING], SeeAllRoute.NOW_PLAYING, onSeeAll, onOpenItem)
        pagedRail(railUpcomingTitle, state.rails[SeeAllRoute.UPCOMING], SeeAllRoute.UPCOMING, onSeeAll, onOpenItem)
        pagedRail(railTopRatedTitle, state.rails[SeeAllRoute.TOP_RATED], SeeAllRoute.TOP_RATED, onSeeAll, onOpenItem)

        item { TmdbAttribution(Modifier.padding(horizontal = 20.dp, vertical = 16.dp)) }
      }
    }
    // Botón de cuenta flotando sobre el héroe (toolbar de iOS).
    Box(
      Modifier
        .align(Alignment.TopEnd)
        .statusBarsPadding()
        .padding(end = 8.dp, top = 4.dp)
        .clip(CircleShape)
        .background(Color.Black.copy(alpha = 0.25f)),
    ) {
      AccountButton(onClick = onOpenAccount)
    }
  }
}

private fun LazyListScope.rail(
  title: String,
  items: List<MediaItem>,
  route: SeeAllRoute?,
  onSeeAll: (SeeAllRoute) -> Unit,
  onOpenItem: (MediaItem) -> Unit,
  subtitle: String? = null,
) {
  if (items.isEmpty()) return
  item(key = "h-$title") { SectionHeader(title = title, subtitle = subtitle, onSeeAll = route?.let { r -> { onSeeAll(r) } }) }
  item(key = "r-$title") {
    LazyRow(
      contentPadding = PaddingValues(horizontal = 20.dp),
      horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
      items(items, key = { it.key.description }) { item -> PosterCard(item) { onOpenItem(item) } }
    }
  }
}

/** Fila con infinite scroll horizontal: misma lista paginada que "Ver todo". */
private fun LazyListScope.pagedRail(
  title: String,
  list: PagedList?,
  route: SeeAllRoute,
  onSeeAll: (SeeAllRoute) -> Unit,
  onOpenItem: (MediaItem) -> Unit,
) {
  if (list == null) return
  item(key = "h-$title") { SectionHeader(title = title, onSeeAll = { onSeeAll(route) }) }
  item(key = "r-$title") {
    val st by list.state.collectAsState()
    LazyRow(
      contentPadding = PaddingValues(horizontal = 20.dp),
      horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
      items(st.items, key = { it.key.description }) { item -> PosterCard(item) { onOpenItem(item) } }
      if (!st.done) item(key = "load-more") { RailLoadMore(st, list::loadMore) }
    }
  }
}

/** Pie de la fila (como `LoadMoreFooter` compacto en iOS): pide la siguiente
 *  página al aparecer, spinner mientras llega, reintentar si falló. */
@Composable
private fun RailLoadMore(st: PagedListState.UiState, loadMore: () -> Unit) {
  // Alto del póster (104 dp a 2:3) para centrarlo en la imagen.
  Box(Modifier.width(48.dp).height(156.dp), contentAlignment = Alignment.Center) {
    if (st.loadMoreFailed) {
      IconButton(onClick = loadMore) {
        Icon(Icons.Filled.Refresh, contentDescription = stringResource(R.string.retry))
      }
    } else {
      LaunchedEffect(st.items.size) { loadMore() }
      if (st.loading) CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 2.5.dp)
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
      Text(
        title,
        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.semantics { heading() },
      )
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
private fun HeroCarousel(
  items: List<MediaItem>,
  onOpenItem: (MediaItem) -> Unit,
  library: LibraryStore? = null,
) {
  val context = LocalContext.current
  val pagerState = rememberPagerState(pageCount = { items.size })
  val reduceMotion = remember { isAnimatorDisabled(context) }

  // Avance automático cada 7 s (como iOS). Se dispara sobre settledPage para que:
  // 1. Cada deslizamiento manual reinicie limpiamente los 7 s.
  // 2. La animación nunca se cancele a medio camino (settledPage sólo cambia cuando la animación termina).
  LaunchedEffect(pagerState.settledPage, reduceMotion, items.size) {
    if (reduceMotion || items.size <= 1) return@LaunchedEffect
    delay(7_000)
    if (!pagerState.isScrollInProgress) {
      val next = (pagerState.settledPage + 1) % items.size
      pagerState.animateScrollToPage(
        page = next,
        animationSpec = androidx.compose.animation.core.tween(
          durationMillis = 450,
          easing = androidx.compose.animation.core.FastOutSlowInEasing,
        ),
      )
    }
  }

  Box(
    Modifier
      .fillMaxWidth()
      .height(560.dp),
  ) {
    HorizontalPager(
      state = pagerState,
      key = { page -> items.getOrNull(page)?.id ?: page },
      modifier = Modifier.fillMaxSize(),
    ) { page ->
      HeroPage(
        item = items[page],
        onOpen = { onOpenItem(items[page]) },
        library = library,
      )
    }
    Row(
      Modifier
        .align(Alignment.BottomCenter)
        .padding(bottom = 12.dp),
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
              else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.35f),
            ),
        )
      }
    }
  }
}

@Composable
private fun HeroPage(
  item: MediaItem,
  onOpen: () -> Unit,
  library: LibraryStore? = null,
) {
  val backgroundColor = MaterialTheme.colorScheme.background
  val heroGradient = remember(backgroundColor) {
    Brush.verticalGradient(
      0.00f to Color.Black.copy(alpha = 0.35f),
      0.22f to Color.Transparent,
      0.45f to Color.Transparent,
      0.78f to backgroundColor.copy(alpha = 0.85f),
      1.00f to backgroundColor,
    )
  }
  val libraryState by library?.state?.collectAsState() ?: remember { mutableStateOf(null) }

  Box(
    Modifier
      .fillMaxSize()
      .clickable(onClick = onOpen),
  ) {
    BackdropImage(
      path = item.backdropPath.ifEmpty { item.posterPath },
      modifier = Modifier.fillMaxSize(),
      size = "w1280",
    )
    Box(Modifier.fillMaxSize().background(heroGradient))
    Column(
      Modifier
        .align(Alignment.BottomStart)
        .padding(horizontal = 20.dp)
        .padding(bottom = 28.dp),
      verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
      Text(
        if (item.kind == MediaKind.TV) stringResource(R.string.badge_show).uppercase() else stringResource(R.string.badge_movie).uppercase(),
        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp),
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
      Text(
        item.title,
        style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Black),
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
        color = MaterialTheme.colorScheme.onBackground,
      )
      val meta = listOfNotNull(
        item.year.takeIf { it.isNotEmpty() },
        item.rating.takeIf { it > 0 }?.let { "%.1f".format(it) },
      )
      if (meta.isNotEmpty()) {
        Row(
          verticalAlignment = Alignment.CenterVertically,
          horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
          if (item.year.isNotEmpty()) {
            Text(
              item.year,
              style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
          if (item.rating > 0) {
            if (item.year.isNotEmpty()) {
              Text("·", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Icon(
              Icons.Filled.Star,
              contentDescription = null,
              tint = Color(0xFFFFC94D),
              modifier = Modifier.size(15.dp),
            )
            Text(
              "%.1f".format(item.rating),
              style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
        }
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

      // Botones de acción rápida: "Ver ficha" y "+" Watchlist (como iOS)
      Row(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(top = 4.dp),
      ) {
        Button(
          onClick = onOpen,
          shape = RoundedCornerShape(24.dp),
          colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = Color.White,
          ),
          contentPadding = PaddingValues(horizontal = 20.dp, vertical = 10.dp),
        ) {
          Icon(Icons.Filled.PlayArrow, contentDescription = null, modifier = Modifier.size(20.dp))
          Spacer(Modifier.width(6.dp))
          Text(
            stringResource(R.string.hero_view_detail),
            style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
          )
        }
        if (library != null && libraryState != null) {
          val inWatchlist = libraryState!!.contains(item.key, LibraryStore.Kind.WATCHLIST)
          IconButton(
            onClick = { library.toggle(item, LibraryStore.Kind.WATCHLIST) },
            modifier = Modifier
              .size(44.dp)
              .clip(CircleShape)
              .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.85f)),
          ) {
            Icon(
              imageVector = if (inWatchlist) Icons.Filled.Check else Icons.Filled.Add,
              contentDescription = stringResource(if (inWatchlist) R.string.remove_from_watchlist else R.string.add_to_watchlist),
              tint = if (inWatchlist) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
        }
      }
    }
  }
}

/** Tarjeta del Top 10 con el número gigante (como `Top10Rail` en iOS). */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun Top10Card(rank: Int, item: MediaItem, onOpen: () -> Unit) {
  var menuOpen by remember { mutableStateOf(false) }
  val onSurface = MaterialTheme.colorScheme.onSurface
  Box {
    // Número detrás y póster encima, solapados como el HStack(spacing: -18) de iOS.
    Box(Modifier.combinedClickable(onClick = onOpen, onLongClick = { menuOpen = true })) {
      Text(
        "$rank",
        style = TextStyle(
          brush = Brush.verticalGradient(listOf(onSurface.copy(alpha = 0.9f), onSurface.copy(alpha = 0.25f))),
          fontSize = 96.sp,
          fontWeight = FontWeight.Black,
        ),
        modifier = Modifier
          .align(Alignment.BottomStart)
          .offset(y = 22.dp)
          .clearAndSetSemantics { },
      )
      PosterImage(item.posterPath, modifier = Modifier.padding(start = if (rank >= 10) 76.dp else 42.dp), width = 112.dp)
    }
    MediaContextMenu(item = item, expanded = menuOpen, onDismiss = { menuOpen = false })
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
