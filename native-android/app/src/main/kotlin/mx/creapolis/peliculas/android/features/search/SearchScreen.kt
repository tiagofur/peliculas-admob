package mx.creapolis.peliculas.android.features.search

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.TmdbGenre
import mx.creapolis.peliculas.android.ui.components.PosterCard

/** Acciones de navegación que necesita Buscar (hacia géneros, moods y personas). */
data class SearchNav(
  val openGenre: (kind: MediaKind, genre: TmdbGenre) -> Unit,
  val openMood: (Mood) -> Unit,
  val openPerson: (id: Int, name: String) -> Unit,
)

/** Buscar (port de `SearchView`): búsqueda, moods, géneros, personas, historial. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(
  nav: SearchNav,
  onOpenItem: (mx.creapolis.peliculas.android.core.model.MediaItem) -> Unit = {},
  onOpenAccount: () -> Unit = {},
  vm: SearchViewModel = viewModel(factory = SearchViewModel.factory(LocalContext.current)),
) {
  val state by vm.state.collectAsState()
  val scopeTitles = listOf(
    SearchScope.ALL to stringResource(R.string.search_scope_all),
    SearchScope.MOVIES to stringResource(R.string.search_scope_movies),
    SearchScope.SERIES to stringResource(R.string.search_scope_series),
  )

  Column(Modifier.fillMaxSize()) {
    mx.creapolis.peliculas.android.ui.components.RootTitleBar(stringResource(R.string.tab_search)) {
      mx.creapolis.peliculas.android.ui.components.AccountButton(onClick = onOpenAccount)
    }
    // Caja de búsqueda (OutlinedTextField + chips de ámbito, como iOS searchable+scopes).
    OutlinedTextField(
      value = state.query,
      onValueChange = vm::onQueryChange,
      modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 20.dp, vertical = 10.dp),
      placeholder = { Text(stringResource(R.string.search_prompt)) },
      leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
      singleLine = true,
      shape = RoundedCornerShape(18.dp),
      colors = OutlinedTextFieldDefaults.colors(
        focusedBorderColor = MaterialTheme.colorScheme.primary,
        focusedLeadingIconColor = MaterialTheme.colorScheme.primary,
      ),
    )
    Row(
      Modifier
        .fillMaxWidth()
        .padding(horizontal = 20.dp),
      horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
      scopeTitles.forEach { (scope, title) ->
        FilterChip(
          selected = state.scope == scope,
          onClick = { vm.onScopeChange(scope) },
          label = { Text(title) },
          shape = RoundedCornerShape(20.dp),
          colors = FilterChipDefaults.filterChipColors(
            selectedContainerColor = MaterialTheme.colorScheme.primary,
            selectedLabelColor = Color.White,
          ),
        )
      }
    }

    val query = state.query.trim()
    when {
      query.length < 2 -> Browse(state, vm, nav)
      state.searching && state.results.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
      }
      state.results.isEmpty() && state.failed -> EmptyStateItem(
        icon = "wifi", title = stringResource(R.string.offline_title), message = stringResource(R.string.offline_message),
      )
      state.results.isEmpty() -> EmptyStateItem(
        icon = "search", title = stringResource(R.string.search_no_results), message = stringResource(R.string.search_no_results_hint),
      )
      else -> Results(state, vm, nav, onOpenItem)
    }
  }
}

@Composable
private fun Results(state: SearchViewModel.UiState, vm: SearchViewModel, nav: SearchNav, onOpenItem: (mx.creapolis.peliculas.android.core.model.MediaItem) -> Unit) {
  LazyVerticalGrid(
    columns = GridCells.Adaptive(minSize = 104.dp),
    contentPadding = PaddingValues(horizontal = 20.dp, vertical = 14.dp),
    horizontalArrangement = Arrangement.spacedBy(14.dp),
    verticalArrangement = Arrangement.spacedBy(20.dp),
    modifier = Modifier.fillMaxSize(),
  ) {
    if (state.people.isNotEmpty()) {
      item(span = { GridItemSpan(maxLineSpan) }) {
        Column {
          Text(
            stringResource(R.string.search_people),
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(vertical = 8.dp),
          )
          state.people.forEach { person ->
            Row(
              Modifier
                .fillMaxWidth()
                .clickable { nav.openPerson(person.id, person.name ?: "") }
                .padding(vertical = 8.dp),
              verticalAlignment = Alignment.CenterVertically,
            ) {
              Box(
                Modifier
                  .size(40.dp)
                  .clip(RoundedCornerShape(20.dp))
                  .background(MaterialTheme.colorScheme.surfaceVariant),
                contentAlignment = Alignment.Center,
              ) {
                Text(
                  (person.name ?: "?").split(" ").take(2).mapNotNull { it.firstOrNull() }.joinToString(""),
                  style = MaterialTheme.typography.labelLarge,
                )
              }
              Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text(person.name ?: "", style = MaterialTheme.typography.bodyLarge)
                Text(
                  stringResource(R.string.search_view_filmography),
                  style = MaterialTheme.typography.labelMedium,
                  color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
              }
              Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
          }
        }
      }
    }
    items(state.results, key = { it.key.description }) { item ->
      PosterCard(
        item,
        Modifier.fillMaxWidth(),
        badge = if (item.kind == MediaKind.TV && state.scope == SearchScope.ALL) stringResource(R.string.badge_show) else null,
      ) { onOpenItem(item) }
    }
    if (!state.done) {
      item(span = { GridItemSpan(maxLineSpan) }) {
        Box(Modifier.fillMaxWidth().padding(14.dp), contentAlignment = Alignment.Center) {
          if (state.loadingMore) CircularProgressIndicator(strokeWidth = 3.dp)
          else {
            // El pie dispara el load-more al aparecer (como en iOS).
            LaunchedLoadMore(vm::loadMore)
          }
        }
      }
    }
  }
}

@Composable
private fun LaunchedLoadMore(loadMore: () -> Unit) {
  androidx.compose.runtime.LaunchedEffect(Unit) { loadMore() }
  androidx.compose.foundation.layout.Spacer(Modifier.size(1.dp))
}

@Composable
private fun Browse(state: SearchViewModel.UiState, vm: SearchViewModel, nav: SearchNav) {
  val exploreMovies = stringResource(R.string.explore_movies)
  val exploreSeries = stringResource(R.string.explore_series)
  LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 24.dp)) {
    if (state.history.isNotEmpty()) {
      item {
        Row(
          Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Text(
            stringResource(R.string.search_recent),
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.weight(1f),
          )
          TextButton(onClick = vm::clearHistory) { Text(stringResource(R.string.search_clear)) }
        }
      }
      items(state.history) { term ->
        Row(
          Modifier
            .fillMaxWidth()
            .clickable { vm.onQueryChange(term, immediate = true) }
            .padding(horizontal = 20.dp, vertical = 8.dp),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Icon(Icons.Filled.Schedule, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
          Text(term, modifier = Modifier.padding(start = 12.dp))
        }
      }
    }
    item {
      Text(
        stringResource(R.string.discover_title),
        style = MaterialTheme.typography.titleMedium,
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
      )
    }
    item {
      LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        modifier = Modifier
          .fillMaxWidth()
          .height(((Mood.entries.size + 1) / 2 * 96).dp),
        userScrollEnabled = false,
        contentPadding = PaddingValues(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
      ) {
        items(Mood.entries) { mood ->
          MoodTile(mood = mood, onClick = { nav.openMood(mood) })
        }
      }
    }
    genreSection(exploreMovies, state.movieGenres, MediaKind.MOVIE, nav)
    genreSection(exploreSeries, state.tvGenres, MediaKind.TV, nav)
  }
}

private fun androidx.compose.foundation.lazy.LazyListScope.genreSection(
  title: String,
  genres: List<TmdbGenre>,
  kind: MediaKind,
  nav: SearchNav,
) {
  if (genres.isEmpty()) return
  item { Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) }
  item {
    // Grid estático dentro del scroll: altura fija por filas.
    val rows = (genres.size + 1) / 2
    LazyVerticalGrid(
      columns = GridCells.Fixed(2),
      modifier = Modifier
        .fillMaxWidth()
        .height((rows * 72).dp),
      userScrollEnabled = false,
      contentPadding = PaddingValues(horizontal = 20.dp),
      horizontalArrangement = Arrangement.spacedBy(12.dp),
      verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
      items(genres) { genre ->
        GenreTile(genre = genre, onClick = { nav.openGenre(kind, genre) })
      }
    }
  }
}

/** Mosaico de mood (port de `MoodTile` en iOS). */
@Composable
private fun MoodTile(mood: Mood, onClick: () -> Unit) {
  Column(
    Modifier
      .fillMaxWidth()
      .height(84.dp)
      .clip(RoundedCornerShape(14.dp))
      .background(Brush.linearGradient(listOf(mood.colors.first, mood.colors.second)))
      .clickable(onClick = onClick)
      .padding(12.dp),
    verticalArrangement = Arrangement.Bottom,
  ) {
    Icon(mood.icon, contentDescription = null, tint = Color.White)
    Text(
      stringResource(mood.titleRes),
      style = MaterialTheme.typography.titleSmall,
      color = Color.White,
    )
  }
}

/** Mosaico de género (port de `GenreTile` en iOS, paleta propia). */
@Composable
private fun GenreTile(genre: TmdbGenre, onClick: () -> Unit) {
  // Misma paleta de 10 pares que `GenreTile` en iOS.
  val palette = listOf(
    Color(0xFFFF9500) to Color(0xFFFF3B30),
    Color(0xFFFF2D55) to Color(0xFFAF52DE),
    Color(0xFF5856D6) to Color(0xFF007AFF),
    Color(0xFF30B0C7) to Color(0xFF34C759),
    Color(0xFFAF52DE) to Color(0xFF5856D6),
    Color(0xFFFF3B30) to Color(0xFFFF2D55),
    Color(0xFF007AFF) to Color(0xFF32ADE6),
    Color(0xFF34C759) to Color(0xFF00C7BE),
    Color(0xFFFFCC00) to Color(0xFFFF9500),
    Color(0xFFA2845E) to Color(0xFFFF9500),
  )
  val colors = palette[kotlin.math.abs(genre.id) % palette.size]
  Box(
    Modifier
      .fillMaxWidth()
      .height(60.dp)
      .clip(RoundedCornerShape(14.dp))
      .background(Brush.linearGradient(listOf(colors.first, colors.second)))
      .clickable(onClick = onClick)
      .padding(horizontal = 12.dp),
    contentAlignment = Alignment.BottomStart,
  ) {
    Text(
      genre.name,
      style = MaterialTheme.typography.titleSmall,
      color = Color.White,
    )
  }
}

@Composable
private fun EmptyStateItem(icon: String, title: String, message: String) {
  Column(
    Modifier
      .fillMaxSize()
      .padding(32.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.Center,
  ) {
    Text(title, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
    Text(
      message,
      style = MaterialTheme.typography.bodyMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      textAlign = TextAlign.Center,
    )
  }
}
