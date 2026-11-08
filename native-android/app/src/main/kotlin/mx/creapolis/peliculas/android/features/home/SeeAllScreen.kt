package mx.creapolis.peliculas.android.features.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.InitializerViewModelFactoryBuilder
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.lists.PagedListViewModel
import mx.creapolis.peliculas.android.ui.components.PosterCard

/** Factory con la clave de la ruta: un ViewModel por lista. */
fun pagedListFactory(route: mx.creapolis.peliculas.android.ui.navigation.SeeAllRoute): androidx.lifecycle.ViewModelProvider.Factory =
  viewModelFactory {
    initializer { PagedListViewModel(route.source) }
  }

/** "Ver todo" con infinite scroll (port de `SeeAllView` en iOS). */
@Composable
fun SeeAllScreen(route: mx.creapolis.peliculas.android.ui.navigation.SeeAllRoute, onOpenItem: (mx.creapolis.peliculas.android.core.model.MediaItem) -> Unit = {}) {
  val vm: PagedListViewModel = androidx.lifecycle.viewmodel.compose.viewModel(
    key = route.key,
    factory = pagedListFactory(route),
  )
  val state by vm.state.collectAsState()

  when {
    state.items.isEmpty() && state.failed -> FullError { vm.loadMore() }
    state.items.isEmpty() && state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
      CircularProgressIndicator()
    }
    state.items.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
      Text(
        stringResource(R.string.seeall_empty),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
    else -> LazyVerticalGrid(
      columns = GridCells.Adaptive(minSize = 104.dp),
      contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
      horizontalArrangement = Arrangement.spacedBy(14.dp),
      verticalArrangement = Arrangement.spacedBy(20.dp),
      modifier = Modifier.fillMaxSize(),
    ) {
      items(state.items, key = { it.key.description }) { PosterCard(it, Modifier.fillMaxWidth()) { onOpenItem(it) } }
      if (!state.done) {
        item(span = { GridItemSpan(maxLineSpan) }) {
            Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
              when {
                state.loadMoreFailed -> Button(onClick = vm::loadMore) { Text(stringResource(R.string.retry)) }
                else -> CircularProgressIndicator(
                  Modifier.padding(8.dp),
                  strokeWidth = 3.dp,
                  color = if (state.loading) MaterialTheme.colorScheme.primary
                  else MaterialTheme.colorScheme.primary.copy(alpha = 0f),
                )
              }
            }
        }
      }
    }
  }
}

@Composable
private fun FullError(retry: () -> Unit) {
  Column(
    Modifier.fillMaxSize().padding(24.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.Center,
  ) {
    Text(
      stringResource(R.string.offline_title),
      style = MaterialTheme.typography.titleSmall,
      textAlign = TextAlign.Center,
    )
    Text(
      stringResource(R.string.offline_message),
      style = MaterialTheme.typography.bodyMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      textAlign = TextAlign.Center,
    )
    Button(onClick = retry, modifier = Modifier.padding(top = 12.dp)) {
      Text(stringResource(R.string.retry))
    }
  }
}
