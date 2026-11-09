package mx.creapolis.peliculas.android.features.library

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import mx.creapolis.peliculas.android.LocalAppContainer
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.network.AppConfig
import mx.creapolis.peliculas.android.ui.components.EmptyState
import mx.creapolis.peliculas.android.ui.components.RemoteImage

/**
 * Listas propias (port de `ListsView`): crear, renombrar y borrar.
 * Gratis hasta 3, ilimitadas con Pro. Borrar pide confirmación (mejora de Android).
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ListsScreen(
  library: LibraryStore,
  onOpenList: (id: String, name: String) -> Unit,
) {
  val proStore = LocalAppContainer.current.proStore
  val pro by proStore.state.collectAsState()
  val state by library.state.collectAsState()
  var showCreate by remember { mutableStateOf(false) }
  var renaming by remember { mutableStateOf<String?>(null) }
  var deleting by remember { mutableStateOf<String?>(null) }
  val limitReason = stringResource(R.string.list_limit_message, AppConfig.Pro.FREE_LIST_LIMIT)

  fun create() {
    if (pro.isPro || state.visibleLists.size < AppConfig.Pro.FREE_LIST_LIMIT) {
      showCreate = true
    } else {
      proStore.presentPaywall(limitReason)
    }
  }

  Box(Modifier.fillMaxSize()) {
    if (state.visibleLists.isEmpty()) {
      EmptyState(
        icon = Icons.AutoMirrored.Filled.List,
        title = stringResource(R.string.lists_empty),
        message = stringResource(R.string.lists_empty_hint),
        modifier = Modifier.fillMaxSize(),
      ) {
        Button(onClick = ::create) { Text(stringResource(R.string.list_new)) }
      }
    } else {
      LazyColumn(contentPadding = PaddingValues(start = 20.dp, end = 8.dp, top = 8.dp, bottom = 96.dp)) {
        items(state.visibleLists, key = { it.id }) { list ->
          var menuOpen by remember { mutableStateOf(false) }
          val items = state.itemsOfList(list.id)
          Row(
            Modifier
              .fillMaxWidth()
              .combinedClickable(onClick = { onOpenList(list.id, list.name) }, onLongClick = { menuOpen = true })
              .padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
          ) {
            ListCover(items)
            Column(Modifier.weight(1f).padding(start = 14.dp)) {
              Text(list.name, style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium))
              Text(
                stringResource(R.string.list_count_fmt, items.size),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
              )
            }
            Box {
              IconButton(onClick = { menuOpen = true }) {
                Icon(Icons.Filled.MoreVert, contentDescription = stringResource(R.string.more_options))
              }
              DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                DropdownMenuItem(
                  text = { Text(stringResource(R.string.list_rename)) },
                  leadingIcon = { Icon(Icons.Filled.Edit, contentDescription = null) },
                  onClick = {
                    renaming = list.id
                    menuOpen = false
                  },
                )
                DropdownMenuItem(
                  text = { Text(stringResource(R.string.list_delete)) },
                  leadingIcon = { Icon(Icons.Filled.Delete, contentDescription = null) },
                  onClick = {
                    deleting = list.id
                    menuOpen = false
                  },
                )
              }
            }
          }
        }
      }
      ExtendedFloatingActionButton(
        onClick = ::create,
        icon = { Icon(Icons.Filled.Add, contentDescription = null) },
        text = { Text(stringResource(R.string.list_new)) },
        modifier = Modifier
          .align(Alignment.BottomEnd)
          .padding(20.dp),
      )
    }
  }

  if (showCreate) {
    NameDialog(
      title = stringResource(R.string.list_new),
      initial = "",
      confirm = stringResource(R.string.create),
      onDismiss = { showCreate = false },
      onConfirm = {
        library.createList(it)
        showCreate = false
      },
    )
  }
  renaming?.let { id ->
    NameDialog(
      title = stringResource(R.string.list_rename),
      initial = state.lists[id]?.name.orEmpty(),
      onDismiss = { renaming = null },
      onConfirm = {
        library.renameList(id, it)
        renaming = null
      },
    )
  }
  deleting?.let { id ->
    AlertDialog(
      onDismissRequest = { deleting = null },
      title = { Text(stringResource(R.string.list_delete_confirm_title)) },
      text = { Text(stringResource(R.string.list_delete_confirm_message)) },
      confirmButton = {
        TextButton(onClick = {
          library.deleteList(id)
          deleting = null
        }) { Text(stringResource(R.string.list_delete), color = MaterialTheme.colorScheme.error) }
      },
      dismissButton = { TextButton(onClick = { deleting = null }) { Text(stringResource(R.string.cancel)) } },
    )
  }
}

/** Collage 2×2 de pósters como portada de la lista (gemelo de `ListCover`). */
@Composable
private fun ListCover(items: List<MediaItem>) {
  val paths = items.take(4).map { it.posterPath }
  Column(
    Modifier
      .size(54.dp)
      .clip(RoundedCornerShape(10.dp)),
    verticalArrangement = Arrangement.spacedBy(2.dp),
  ) {
    repeat(2) { row ->
      Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        repeat(2) { col ->
          RemoteImage(paths.getOrNull(row * 2 + col), "w92", Modifier.size(26.dp))
        }
      }
    }
  }
}

@Composable
internal fun NameDialog(
  title: String,
  initial: String,
  confirm: String = stringResource(R.string.save),
  onDismiss: () -> Unit,
  onConfirm: (String) -> Unit,
) {
  var name by remember { mutableStateOf(initial) }
  AlertDialog(
    onDismissRequest = onDismiss,
    title = { Text(title) },
    text = {
      OutlinedTextField(
        value = name,
        onValueChange = { name = it },
        singleLine = true,
        placeholder = { Text(stringResource(R.string.field_list_name)) },
        modifier = Modifier.fillMaxWidth(),
      )
    },
    confirmButton = { TextButton(enabled = name.isNotBlank(), onClick = { onConfirm(name) }) { Text(confirm) } },
    dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
  )
}
