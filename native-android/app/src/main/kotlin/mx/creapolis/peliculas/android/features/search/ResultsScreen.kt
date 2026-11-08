package mx.creapolis.peliculas.android.features.search

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.FilterAlt
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.lists.PagedListState
import mx.creapolis.peliculas.android.core.network.DiscoverSort
import mx.creapolis.peliculas.android.core.network.MediaListSource
import mx.creapolis.peliculas.android.ui.components.PosterCard

/**
 * Resultados de género o mood (port de `GenreResultsView`/`PagedResultsView`).
 * Cambiar filtro (orden/año) reconstruye la lista desde la página 1: el source
 * es la identidad del estado (equivalente a `.id(source)` en iOS).
 */
@Composable
fun ResultsScreen(
  title: String,
  baseSource: MediaListSource,
  filtersEnabled: Boolean = false,
  emptyMessage: String? = null,
) {
  var sort by remember { mutableStateOf(DiscoverSort.POPULARITY) }
  var year by remember { mutableStateOf<Int?>(null) }
  val source = when (baseSource) {
    is MediaListSource.Genre -> baseSource.copy(sort = sort, year = year)
    else -> baseSource
  }
  val list = remember(source) { PagedListState(source) }
  var retryTick by remember { mutableIntStateOf(0) }
  LaunchedEffect(source, retryTick) { list.loadMore() }
  val state by list.state.collectAsState()

  Column(Modifier.fillMaxSize()) {
    if (filtersEnabled && baseSource is MediaListSource.Genre) {
      FilterBar(sort = sort, year = year, onSort = { sort = it }, onYear = { year = it })
    }
    when {
      state.items.isEmpty() && state.failed -> FullError { retryTick++ }
      state.items.isEmpty() && state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
      }
      state.items.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(
          emptyMessage ?: stringResource(R.string.seeall_empty),
          style = MaterialTheme.typography.bodyMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
          textAlign = TextAlign.Center,
        )
      }
      else -> LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 104.dp),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
        modifier = Modifier.fillMaxSize(),
      ) {
        items(state.items, key = { it.key.description }) { PosterCard(it, Modifier.fillMaxWidth()) }
        if (!state.done) {
          item(span = { GridItemSpan(maxLineSpan) }) {
            Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
              when {
                state.loadMoreFailed -> Button(onClick = { retryTick++ }) {
                  Text(stringResource(R.string.retry))
                }
                else -> LaunchedLoadMore(list::loadMore)
              }
            }
          }
        }
      }
    }
  }
}

/** Pie de infinite scroll: dispara la siguiente página al aparecer. */
@Composable
private fun LaunchedLoadMore(loadMore: suspend () -> Unit) {
  LaunchedEffect(Unit) { loadMore() }
  CircularProgressIndicator(strokeWidth = 3.dp)
}

@Composable
private fun FilterBar(sort: DiscoverSort, year: Int?, onSort: (DiscoverSort) -> Unit, onYear: (Int?) -> Unit) {
  var sortOpen by remember { mutableStateOf(false) }
  var yearOpen by remember { mutableStateOf(false) }
  val currentYear = java.util.Calendar.getInstance().get(java.util.Calendar.YEAR)
  val years = (currentYear - 25..currentYear).sortedDescending()

  Row(
    Modifier
      .fillMaxWidth()
      .padding(horizontal = 20.dp, vertical = 6.dp),
    horizontalArrangement = Arrangement.spacedBy(8.dp),
  ) {
    Box {
      IconButton(onClick = { sortOpen = true }) {
        Icon(Icons.Filled.FilterAlt, contentDescription = stringResource(R.string.filter))
      }
      DropdownMenu(expanded = sortOpen, onDismissRequest = { sortOpen = false }) {
        DropdownMenuItem(
          text = { Text(stringResource(R.string.sort_popular)) },
          leadingIcon = { Icon(Icons.Filled.LocalFireDepartment, contentDescription = null) },
          onClick = { onSort(DiscoverSort.POPULARITY); sortOpen = false },
        )
        DropdownMenuItem(
          text = { Text(stringResource(R.string.sort_rating)) },
          leadingIcon = { Icon(Icons.Filled.Star, contentDescription = null) },
          onClick = { onSort(DiscoverSort.RATING); sortOpen = false },
        )
        DropdownMenuItem(
          text = { Text(stringResource(R.string.sort_newest)) },
          leadingIcon = { Icon(Icons.Filled.DateRange, contentDescription = null) },
          onClick = { onSort(DiscoverSort.NEWEST); sortOpen = false },
        )
      }
    }
    Box {
      TextButton(onClick = { yearOpen = true }) {
        Text(year?.toString() ?: stringResource(R.string.filter_year_all))
      }
      DropdownMenu(expanded = yearOpen, onDismissRequest = { yearOpen = false }) {
        DropdownMenuItem(
          text = { Text(stringResource(R.string.filter_year_all)) },
          onClick = { onYear(null); yearOpen = false },
        )
        years.forEach { y ->
          DropdownMenuItem(text = { Text("$y") }, onClick = { onYear(y); yearOpen = false })
        }
      }
    }
  }
}

@Composable
private fun FullError(retry: () -> Unit) {
  Column(
    Modifier
      .fillMaxSize()
      .padding(24.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.Center,
  ) {
    Text(stringResource(R.string.offline_title), style = MaterialTheme.typography.titleSmall)
    Text(
      stringResource(R.string.offline_message),
      style = MaterialTheme.typography.bodyMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Button(onClick = retry, modifier = Modifier.padding(top = 12.dp)) {
      Text(stringResource(R.string.retry))
    }
  }
}
