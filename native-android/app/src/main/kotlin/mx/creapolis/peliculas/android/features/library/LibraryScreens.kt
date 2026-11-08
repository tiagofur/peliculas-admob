package mx.creapolis.peliculas.android.features.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.ui.components.PosterCard

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
@Composable
fun LibraryScreen(
  library: LibraryStore,
  signedIn: Boolean,
  nav: LibraryNav,
) {
  val state by library.state.collectAsState()
  val recent = remember(state) { library.recentlyAddedItems() }

  LazyColumn(
    Modifier.fillMaxSize(),
    contentPadding = PaddingValues(bottom = 24.dp),
  ) {
    item {
      Row(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
      ) {
        Text(
          stringResource(R.string.tab_library),
          style = MaterialTheme.typography.headlineSmall,
          modifier = Modifier.weight(1f),
        )
        IconButton(onClick = nav.openHistory) {
          Icon(Icons.Filled.Refresh, contentDescription = stringResource(R.string.history_title))
        }
        IconButton(onClick = nav.openAccount) {
          Icon(Icons.Filled.Person, contentDescription = stringResource(R.string.account))
        }
      }
    }
    item {
      Column(Modifier.padding(horizontal = 20.dp)) {
        CategoryRow(
          title = stringResource(R.string.cat_watchlist),
          icon = { Icon(Icons.Filled.Bookmark, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp)) },
          color = Color(0xFFFF9800),
          count = state.count(LibraryStore.Kind.WATCHLIST),
          onClick = { nav.openGrid(LibraryStore.Kind.WATCHLIST) },
        )
        CategoryRow(
          title = stringResource(R.string.cat_favorites),
          icon = { Icon(Icons.Filled.Favorite, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp)) },
          color = Color(0xFFEC407A),
          count = state.count(LibraryStore.Kind.FAVORITE),
          onClick = { nav.openGrid(LibraryStore.Kind.FAVORITE) },
        )
        CategoryRow(
          title = stringResource(R.string.cat_watched),
          icon = { Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp)) },
          color = Color(0xFF66BB6A),
          count = state.count(LibraryStore.Kind.WATCHED),
          onClick = { nav.openGrid(LibraryStore.Kind.WATCHED) },
        )
        CategoryRow(
          title = stringResource(R.string.cat_rated),
          icon = { Icon(Icons.Filled.Star, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp)) },
          color = Color(0xFFFFC94D),
          count = state.ratedCount,
          onClick = nav.openRated,
        )
        CategoryRow(
          title = stringResource(R.string.cat_lists),
          icon = { Icon(Icons.Filled.Edit, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp)) },
          color = Color(0xFF5C6BC0),
          count = state.visibleLists.size,
          onClick = nav.openLists,
        )
        CategoryRow(
          title = stringResource(R.string.achievements_title),
          icon = { Icon(Icons.Filled.Star, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp)) },
          color = Color(0xFFFFC94D),
          count = 0,
          onClick = nav.openAchievements,
        )
        CategoryRow(
          title = stringResource(R.string.stats_title),
          icon = { Icon(Icons.Filled.BarChart, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp)) },
          color = Color(0xFF26A69A),
          count = 0,
          onClick = nav.openStats,
        )
      }
    }
    if (!signedIn) {
      item {
        Column(
          Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(16.dp),
        ) {
          Text(stringResource(R.string.sync_banner_title), style = MaterialTheme.typography.titleSmall)
          Text(
            stringResource(R.string.sync_banner_message),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
          )
          Button(onClick = nav.openSignIn, modifier = Modifier.padding(top = 8.dp)) {
            Text(stringResource(R.string.sync_banner_cta))
          }
        }
      }
    }
    if (recent.isEmpty()) {
      item {
        Column(
          Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 32.dp),
          horizontalAlignment = Alignment.CenterHorizontally,
        ) {
          Text(stringResource(R.string.library_empty), style = MaterialTheme.typography.titleSmall, textAlign = TextAlign.Center)
          Text(
            stringResource(R.string.library_empty_hint),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
          )
          Button(onClick = nav.explore, modifier = Modifier.padding(top = 12.dp)) {
            Text(stringResource(R.string.explore_cta))
          }
        }
      }
    } else {
      item {
        Text(
          stringResource(R.string.recently_added),
          style = MaterialTheme.typography.titleMedium,
          modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
        )
      }
      item {
        Column(Modifier.padding(horizontal = 20.dp)) {
          GridWrapped(items = recent) { nav.openItem(it) }
        }
      }
    }
  }
}

/** Fila de categoría (icono de color + título + conteo). */
@Composable
private fun CategoryRow(
  title: String,
  icon: @Composable () -> Unit,
  color: Color,
  count: Int,
  onClick: () -> Unit,
) {
  Row(
    Modifier
      .fillMaxWidth()
      .clickable(onClick = onClick)
      .padding(vertical = 10.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Box(
      Modifier
        .size(34.dp)
        .clip(RoundedCornerShape(9.dp))
        .background(color),
      contentAlignment = Alignment.Center,
    ) { icon() }
    Text(title, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f).padding(start = 14.dp))
    if (count > 0) {
      Text("$count", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
  }
}

/** Grid de una sección con filtro Películas/Series (port de `LibraryGridView`). */
@Composable
fun LibraryGridScreen(
  kind: LibraryStore.Kind,
  library: LibraryStore,
  onBack: () -> Unit,
  onOpenItem: (MediaItem) -> Unit,
) {
  val state by library.state.collectAsState()
  var filter by remember { mutableStateOf<MediaKind?>(null) }
  val title = stringResource(
    when (kind) {
      LibraryStore.Kind.WATCHLIST -> R.string.cat_watchlist
      LibraryStore.Kind.FAVORITE -> R.string.cat_favorites
      LibraryStore.Kind.WATCHED -> R.string.cat_watched
    },
  )
  val entries = state.marks[kind].orEmpty()
    .filter { !it.value.deleted && (filter == null || it.key.kind == filter) }
    .entries.sortedByDescending { it.value.updatedAt }
    .mapNotNull { state.items[it.key] }

  GridScreenScaffold(title, onBack) {
    FilterChips(filter = filter, onFilter = { filter = it })
    if (entries.isEmpty()) {
      Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(stringResource(R.string.grid_empty), color = MaterialTheme.colorScheme.onSurfaceVariant)
      }
    } else {
      GridWrapped(items = entries, onOpenItem = onOpenItem)
    }
  }
}

/** Calificadas (port de `RatedGridView`). */
@Composable
fun RatedGridScreen(library: LibraryStore, onBack: () -> Unit, onOpenItem: (MediaItem) -> Unit) {
  val state by library.state.collectAsState()
  val entries = state.ratings.filter { !it.value.deleted && it.value.score > 0 }
    .entries.sortedByDescending { it.value.updatedAt }
    .mapNotNull { state.items[it.key] }
  GridScreenScaffold(stringResource(R.string.cat_rated), onBack) {
    if (entries.isEmpty()) {
      Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(stringResource(R.string.grid_empty), color = MaterialTheme.colorScheme.onSurfaceVariant)
      }
    } else {
      GridWrapped(items = entries, onOpenItem = onOpenItem)
    }
  }
}

/** Grid de una lista propia. */
@Composable
fun ListItemsScreen(
  listId: String,
  listName: String,
  library: LibraryStore,
  onBack: () -> Unit,
  onOpenItem: (MediaItem) -> Unit,
) {
  val state by library.state.collectAsState()
  val entries = state.itemsOfList(listId)
  GridScreenScaffold(listName, onBack) {
    if (entries.isEmpty()) {
      Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(stringResource(R.string.grid_empty), color = MaterialTheme.colorScheme.onSurfaceVariant)
      }
    } else {
      GridWrapped(items = entries, onOpenItem = onOpenItem)
    }
  }
}

@Composable
private fun GridScreenScaffold(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
  Column(Modifier.fillMaxSize()) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
      IconButton(onClick = onBack) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
      }
      Text(title, style = MaterialTheme.typography.titleLarge)
    }
    content()
  }
}

@Composable
private fun FilterChips(filter: MediaKind?, onFilter: (MediaKind?) -> Unit) {
  Row(
    Modifier.padding(horizontal = 20.dp, vertical = 6.dp),
    horizontalArrangement = Arrangement.spacedBy(8.dp),
  ) {
    FilterChip(
      selected = filter == null,
      onClick = { onFilter(null) },
      label = { Text(stringResource(R.string.search_scope_all)) },
    )
    FilterChip(
      selected = filter == MediaKind.MOVIE,
      onClick = { onFilter(MediaKind.MOVIE) },
      label = { Text(stringResource(R.string.search_scope_movies)) },
    )
    FilterChip(
      selected = filter == MediaKind.TV,
      onClick = { onFilter(MediaKind.TV) },
      label = { Text(stringResource(R.string.search_scope_series)) },
    )
  }
}

/** Grid no-lazy anidado (los padres ya son LazyColumn/grid). */
@Composable
private fun GridWrapped(items: List<MediaItem>, onOpenItem: (MediaItem) -> Unit) {
  val rows = items.chunked(3)
  Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
    rows.forEach { row ->
      Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        row.forEach { item ->
          Box(Modifier.weight(1f)) {
            PosterCard(item, Modifier.fillMaxWidth()) { onOpenItem(item) }
          }
        }
        repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
      }
    }
  }
}
