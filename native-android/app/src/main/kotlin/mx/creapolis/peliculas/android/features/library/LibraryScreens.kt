package mx.creapolis.peliculas.android.features.library

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.LibraryBooks
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.filled.PlaylistAdd
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.ui.components.AccountButton
import mx.creapolis.peliculas.android.ui.components.EmptyState
import mx.creapolis.peliculas.android.ui.components.PosterCard
import mx.creapolis.peliculas.android.ui.components.RootTitleBar

/** Callbacks de navegación de la Biblioteca. */
data class LibraryNav(
  val openAccount: () -> Unit,
  val openSignIn: () -> Unit,
  val openGrid: (LibraryStore.Kind) -> Unit,
  val openRated: () -> Unit,
  val openLists: () -> Unit,
  val openList: (id: String, name: String) -> Unit,
  val openItem: (MediaItem) -> Unit,
  val explore: () -> Unit,
  val openStats: () -> Unit = {},
  val openAchievements: () -> Unit = {},
  val openHistory: () -> Unit = {},
)

/** Biblioteca estilo Música (port de `LibraryView` en iOS). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(
  library: LibraryStore,
  signedIn: Boolean,
  nav: LibraryNav,
) {
  val state by library.state.collectAsState()
  val recent = remember(state) { library.recentlyAddedItems() }
  val scope = rememberCoroutineScope()

  Column(Modifier.fillMaxSize()) {
    RootTitleBar(stringResource(R.string.tab_library)) {
      IconButton(onClick = nav.openHistory) {
        Icon(Icons.Filled.History, contentDescription = stringResource(R.string.history_title))
      }
      AccountButton(onClick = nav.openAccount)
    }
    PullToRefreshBox(isRefreshing = state.syncing, onRefresh = { scope.launch { library.sync() } }) {
      LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 104.dp),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 24.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
        modifier = Modifier.fillMaxSize(),
      ) {
        fullWidth("categories") { Categories(state, nav) }
        if (!signedIn) fullWidth("sync-banner") { SyncBanner(nav.openSignIn) }
        if (recent.isEmpty()) {
          fullWidth("empty") {
            EmptyState(
              icon = Icons.AutoMirrored.Filled.LibraryBooks,
              title = stringResource(R.string.library_empty),
              message = stringResource(R.string.library_empty_hint),
              modifier = Modifier.fillMaxWidth(),
            ) {
              Button(onClick = nav.explore) { Text(stringResource(R.string.explore_cta)) }
            }
          }
        } else {
          fullWidth("recent-title") {
            Text(
              stringResource(R.string.recently_added),
              style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
          }
          items(recent, key = { it.key.description }) { item ->
            PosterCard(item, Modifier.fillMaxWidth()) { nav.openItem(item) }
          }
        }
      }
    }
  }
}

private fun LazyGridScope.fullWidth(key: String, content: @Composable () -> Unit) {
  item(key = key, span = { GridItemSpan(maxLineSpan) }) { content() }
}

@Composable
private fun Categories(state: LibraryStore.State, nav: LibraryNav) {
  val divider: @Composable () -> Unit = {
    HorizontalDivider(
      modifier = Modifier.padding(start = 60.dp),
      thickness = 0.5.dp,
      color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
    )
  }
  Column(
    Modifier
      .fillMaxWidth()
      .clip(RoundedCornerShape(20.dp))
      .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
  ) {
    CategoryRow(stringResource(R.string.cat_watchlist), Icons.Filled.Bookmark, Color(0xFFFF9500), state.count(LibraryStore.Kind.WATCHLIST)) {
      nav.openGrid(LibraryStore.Kind.WATCHLIST)
    }
    divider()
    CategoryRow(stringResource(R.string.cat_favorites), Icons.Filled.Favorite, Color(0xFFFF2D55), state.count(LibraryStore.Kind.FAVORITE)) {
      nav.openGrid(LibraryStore.Kind.FAVORITE)
    }
    divider()
    CategoryRow(stringResource(R.string.cat_watched), Icons.Filled.CheckCircle, Color(0xFF34C759), state.count(LibraryStore.Kind.WATCHED)) {
      nav.openGrid(LibraryStore.Kind.WATCHED)
    }
    divider()
    CategoryRow(stringResource(R.string.cat_rated), Icons.Filled.Star, Color(0xFFFFCC00), state.ratedCount, nav.openRated)
    divider()
    CategoryRow(stringResource(R.string.cat_lists), Icons.AutoMirrored.Filled.List, Color(0xFF5856D6), state.visibleLists.size, nav.openLists)
    divider()
    CategoryRow(stringResource(R.string.achievements_title), Icons.Filled.EmojiEvents, Color(0xFFFF9F0A), 0, nav.openAchievements)
    divider()
    CategoryRow(stringResource(R.string.stats_title), Icons.Filled.BarChart, Color(0xFF30B0C7), 0, nav.openStats)
  }
}

/** Fila de categoría (icono de color + título + conteo), como la Biblioteca de Música. */
@Composable
private fun CategoryRow(title: String, icon: ImageVector, color: Color, count: Int, onClick: () -> Unit) {
  Row(
    Modifier
      .fillMaxWidth()
      .clickable(onClick = onClick)
      .padding(horizontal = 16.dp, vertical = 12.dp)
      .semantics(mergeDescendants = true) { contentDescription = if (count > 0) "$title, $count" else title },
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Box(
      Modifier
        .size(30.dp)
        .clip(RoundedCornerShape(8.dp))
        .background(Brush.verticalGradient(listOf(color.copy(alpha = 0.85f), color))),
      contentAlignment = Alignment.Center,
    ) { Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(17.dp)) }
    Text(
      title,
      style = MaterialTheme.typography.bodyLarge,
      modifier = Modifier.weight(1f).padding(start = 14.dp),
    )
    if (count > 0) {
      Text(
        "$count",
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(end = 4.dp),
      )
    }
    Icon(
      Icons.AutoMirrored.Filled.KeyboardArrowRight,
      contentDescription = null,
      tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
      modifier = Modifier.size(20.dp),
    )
  }
}

@Composable
private fun SyncBanner(onSignIn: () -> Unit) {
  Row(
    Modifier
      .fillMaxWidth()
      .clip(RoundedCornerShape(20.dp))
      .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f))
      .padding(16.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(Icons.Filled.CloudUpload, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(28.dp))
    Column(Modifier.weight(1f).padding(horizontal = 14.dp)) {
      Text(stringResource(R.string.sync_banner_title), style = MaterialTheme.typography.titleSmall)
      Text(
        stringResource(R.string.sync_banner_message),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
    FilledTonalButton(onClick = onSignIn) { Text(stringResource(R.string.sync_banner_cta)) }
  }
}

/** Cuadrícula de una sección con filtro Películas/Series (port de `LibraryGridView`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryGridScreen(
  kind: LibraryStore.Kind,
  library: LibraryStore,
  onOpenItem: (MediaItem) -> Unit,
) {
  val state by library.state.collectAsState()
  var filter by rememberSaveable { mutableStateOf<MediaKind?>(null) }
  val scope = rememberCoroutineScope()
  val entries = state.items(kind).filter { filter == null || it.kind == filter }
  val (icon, messageRes) = when (kind) {
    LibraryStore.Kind.WATCHLIST -> Icons.Filled.BookmarkBorder to R.string.empty_watchlist
    LibraryStore.Kind.FAVORITE -> Icons.Filled.FavoriteBorder to R.string.empty_favorites
    LibraryStore.Kind.WATCHED -> Icons.Outlined.CheckCircle to R.string.empty_watched
  }

  PullToRefreshBox(isRefreshing = state.syncing, onRefresh = { scope.launch { library.sync() } }) {
    PosterGridScreen(
      items = entries,
      onOpenItem = onOpenItem,
      header = { KindFilter(filter) { filter = it } },
      empty = { EmptyState(icon, stringResource(R.string.grid_empty), stringResource(messageRes), Modifier.fillMaxWidth()) },
    )
  }
}

/** Calificadas con tu nota en el póster (port de `RatedGridView`). */
@Composable
fun RatedGridScreen(library: LibraryStore, onOpenItem: (MediaItem) -> Unit) {
  val state by library.state.collectAsState()
  PosterGridScreen(
    items = state.ratedItems,
    onOpenItem = onOpenItem,
    badge = { item -> state.score(item.key)?.let { if (it % 1.0 == 0.0) "★ %.0f".format(it) else "★ %.1f".format(it) } },
    empty = {
      EmptyState(Icons.Filled.StarBorder, stringResource(R.string.rated_empty), stringResource(R.string.rated_empty_hint), Modifier.fillMaxWidth())
    },
  )
}

/** Títulos de una lista propia (port de `ListDetailView`). */
@Composable
fun ListItemsScreen(listId: String, library: LibraryStore, onOpenItem: (MediaItem) -> Unit) {
  val state by library.state.collectAsState()
  PosterGridScreen(
    items = state.itemsOfList(listId),
    onOpenItem = onOpenItem,
    empty = {
      EmptyState(
        Icons.AutoMirrored.Filled.PlaylistAdd,
        stringResource(R.string.list_empty_title),
        stringResource(R.string.list_empty_hint),
        Modifier.fillMaxWidth(),
      )
    },
  )
}

/** Cuadrícula adaptable de pósters con scroll (gemelo de `PosterGrid`). */
@Composable
fun PosterGridScreen(
  items: List<MediaItem>,
  onOpenItem: (MediaItem) -> Unit,
  header: (@Composable () -> Unit)? = null,
  badge: (MediaItem) -> String? = { null },
  empty: @Composable () -> Unit,
) {
  LazyVerticalGrid(
    columns = GridCells.Adaptive(minSize = 104.dp),
    contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 24.dp),
    horizontalArrangement = Arrangement.spacedBy(14.dp),
    verticalArrangement = Arrangement.spacedBy(20.dp),
    modifier = Modifier.fillMaxSize(),
  ) {
    if (header != null) fullWidth("header") { header() }
    if (items.isEmpty()) {
      fullWidth("empty") { Box(Modifier.fillMaxWidth().padding(top = 48.dp)) { empty() } }
    } else {
      items(items, key = { it.key.description }) { item ->
        PosterCard(item, Modifier.fillMaxWidth(), badge = badge(item)) { onOpenItem(item) }
      }
    }
  }
}

/** Todo / Películas / Series (segmented como el Picker de iOS, en M3). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun KindFilter(filter: MediaKind?, onFilter: (MediaKind?) -> Unit) {
  val options = listOf(
    null to stringResource(R.string.search_scope_all),
    MediaKind.MOVIE to stringResource(R.string.search_scope_movies),
    MediaKind.TV to stringResource(R.string.search_scope_series),
  )
  SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
    options.forEachIndexed { i, (kind, label) ->
      SegmentedButton(
        selected = filter == kind,
        onClick = { onFilter(kind) },
        shape = SegmentedButtonDefaults.itemShape(index = i, count = options.size),
      ) { Text(label) }
    }
  }
}
