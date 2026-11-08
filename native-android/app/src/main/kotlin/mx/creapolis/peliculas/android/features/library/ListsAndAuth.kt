package mx.creapolis.peliculas.android.features.library

import androidx.compose.foundation.clickable
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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.background
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore

/** Listas propias (port de `ListsView`): crear, renombrar, borrar. Límite 3 en gratis (F7 lo conecta al paywall). */
@Composable
fun ListsScreen(
  library: LibraryStore,
  freeListLimit: Int = 3,
  onBack: () -> Unit,
  onOpenList: (id: String, name: String) -> Unit,
) {
  val state by library.state.collectAsState()
  var showCreate by remember { mutableStateOf(false) }
  var renaming by remember { mutableStateOf<String?>(null) }
  var deleting by remember { mutableStateOf<String?>(null) }
  var nameDraft by remember { mutableStateOf("") }

  Box(Modifier.fillMaxSize()) {
    Column(Modifier.fillMaxSize()) {
      Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        IconButton(onClick = onBack) {
          Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
        }
        Text(stringResource(R.string.cat_lists), style = MaterialTheme.typography.titleLarge)
      }
      if (state.visibleLists.isEmpty()) {
        Column(
          Modifier.fillMaxWidth().padding(32.dp),
          horizontalAlignment = Alignment.CenterHorizontally,
        ) {
          Text(
            stringResource(R.string.lists_empty),
            style = MaterialTheme.typography.titleSmall,
            textAlign = TextAlign.Center,
          )
          Button(onClick = { showCreate = true }, modifier = Modifier.padding(top = 12.dp)) {
            Text(stringResource(R.string.list_new))
          }
        }
      } else {
        LazyColumn(contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp)) {
          items(state.visibleLists, key = { it.id }) { list ->
            var menuOpen by remember { mutableStateOf(false) }
            Row(
              Modifier
                .fillMaxWidth()
                .clickable { onOpenList(list.id, list.name) }
                .padding(vertical = 12.dp),
              verticalAlignment = Alignment.CenterVertically,
            ) {
              Column(Modifier.weight(1f)) {
                Text(list.name, style = MaterialTheme.typography.bodyLarge)
                Text(
                  stringResource(R.string.list_count_fmt, state.itemsOfList(list.id).size),
                  style = MaterialTheme.typography.labelMedium,
                  color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
              }
              Box {
                IconButton(onClick = { menuOpen = true }) {
                  Icon(Icons.Filled.MoreVert, contentDescription = null)
                }
                DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                  DropdownMenuItem(
                    text = { Text(stringResource(R.string.list_rename)) },
                    leadingIcon = { Icon(Icons.Filled.Edit, contentDescription = null) },
                    onClick = {
                      nameDraft = list.name
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
      }
    }
    FloatingActionButton(
      onClick = { showCreate = true },
      modifier = Modifier
        .align(Alignment.BottomEnd)
        .padding(20.dp),
    ) {
      Icon(Icons.Filled.Add, contentDescription = stringResource(R.string.list_new))
    }
  }

  // Diálogos crear / renombrar / borrar
  if (showCreate) {
    if (state.visibleLists.size >= freeListLimit) {
      AlertDialog(
        onDismissRequest = { showCreate = false },
        title = { Text(stringResource(R.string.list_limit_title)) },
        text = { Text(stringResource(R.string.list_limit_message)) },
        confirmButton = {
          TextButton(onClick = { showCreate = false }) { Text(stringResource(R.string.dialog_ok)) }
        },
      )
    } else {
      NameDialog(
        title = stringResource(R.string.list_new),
        initial = "",
        onDismiss = { showCreate = false },
        onConfirm = {
          library.createList(it)
          showCreate = false
        },
      )
    }
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
        }) { Text(stringResource(R.string.list_delete)) }
      },
      dismissButton = {
        TextButton(onClick = { deleting = null }) { Text(stringResource(R.string.cancel)) }
      },
    )
  }
}

@Composable
private fun NameDialog(title: String, initial: String, onDismiss: () -> Unit, onConfirm: (String) -> Unit) {
  var name by remember { mutableStateOf(initial) }
  AlertDialog(
    onDismissRequest = onDismiss,
    title = { Text(title) },
    text = {
      OutlinedTextField(
        value = name,
        onValueChange = { name = it },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
      )
    },
    confirmButton = {
      TextButton(
        enabled = name.isNotBlank(),
        onClick = { onConfirm(name) },
      ) { Text(stringResource(R.string.save)) }
    },
    dismissButton = {
      TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
    },
  )
}

/** Login / registro por email (port de `SignInView`; Google llega con Play Services). */
@Composable
fun SignInScreen(
  session: mx.creapolis.peliculas.android.core.auth.SessionStore,
  onDone: () -> Unit,
  onBack: () -> Unit,
) {
  val state by session.state.collectAsState()
  var isSignUp by remember { mutableStateOf(false) }
  var email by remember { mutableStateOf("") }
  var password by remember { mutableStateOf("") }
  var name by remember { mutableStateOf("") }
  var error by remember { mutableStateOf<String?>(null) }

  Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
      IconButton(onClick = onBack) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
      }
      Text(
        if (isSignUp) stringResource(R.string.signup_title) else stringResource(R.string.signin_title),
        style = MaterialTheme.typography.titleLarge,
      )
    }
    Column(
      Modifier
        .fillMaxWidth()
        .padding(24.dp),
      verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
      if (isSignUp) {
        OutlinedTextField(
          value = name,
          onValueChange = { name = it },
          label = { Text(stringResource(R.string.field_name)) },
          singleLine = true,
          modifier = Modifier.fillMaxWidth(),
        )
      }
      OutlinedTextField(
        value = email,
        onValueChange = { email = it },
        label = { Text(stringResource(R.string.field_email)) },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
      )
      OutlinedTextField(
        value = password,
        onValueChange = { password = it },
        label = { Text(stringResource(R.string.field_password)) },
        singleLine = true,
        visualTransformation = androidx.compose.ui.text.input.PasswordVisualTransformation(),
        modifier = Modifier.fillMaxWidth(),
      )
      error?.let {
        Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
      }
      val busy = state.busy
      val scope = remember { CoroutineScope(Dispatchers.Main) }
      Button(
        onClick = {
          error = null
          scope.launch {
            try {
              if (isSignUp) session.signUp(email.trim(), password, name.trim())
              else session.signIn(email.trim(), password)
              onDone()
            } catch (e: mx.creapolis.peliculas.android.core.network.ApiError) {
              error = friendlyAuthError(e)
            } catch (e: Exception) {
              error = friendlyAuthError(mx.creapolis.peliculas.android.core.network.ApiError.OFFLINE)
            }
          }
        },
        enabled = !busy && email.isNotBlank() && password.length >= 6 && (!isSignUp || name.isNotBlank()),
        modifier = Modifier.fillMaxWidth(),
      ) {
        if (busy) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
        else Text(if (isSignUp) stringResource(R.string.signup_cta) else stringResource(R.string.signin_cta))
      }
      TextButton(onClick = { isSignUp = !isSignUp; error = null }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
        Text(
          if (isSignUp) stringResource(R.string.switch_to_signin)
          else stringResource(R.string.switch_to_signup),
        )
      }
    }
  }
}

private fun friendlyAuthError(e: mx.creapolis.peliculas.android.core.network.ApiError): String = when (e.code) {
  "invalid_email" -> "Ese correo no parece válido."
  "weak_password" -> "La contraseña necesita al menos 8 caracteres."
  "email_taken" -> "Ya existe una cuenta con ese correo. Inicia sesión."
  "invalid_credentials" -> "Correo o contraseña incorrectos."
  "rate_limited" -> "Demasiados intentos. Espera unos segundos."
  "offline" -> "Sin conexión. Revisa tu red e inténtalo de nuevo."
  else -> "Algo salió mal. Inténtalo más tarde."
}

/** Cuenta (port de `AccountView`): perfil, cerrar sesión, borrar cuenta. */
@Composable
fun AccountScreen(
  session: mx.creapolis.peliculas.android.core.auth.SessionStore,
  onBack: () -> Unit,
  onSignedOut: () -> Unit,
  onSignIn: () -> Unit,
) {
  val state by session.state.collectAsState()
  var confirmDelete by remember { mutableStateOf(false) }
  var editingName by remember { mutableStateOf(false) }
  var nameDraft by remember { mutableStateOf("") }
  val scope = remember { CoroutineScope(Dispatchers.Main) }

  Column(Modifier.fillMaxSize()) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
      IconButton(onClick = onBack) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
      }
      Text(stringResource(R.string.account), style = MaterialTheme.typography.titleLarge)
    }
    Column(
      Modifier.fillMaxWidth().padding(24.dp),
      verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
      val user = state.user
      if (user != null) {
        Box(
          Modifier
            .size(64.dp)
            .clip(RoundedCornerShape(32.dp))
            .background(MaterialTheme.colorScheme.primaryContainer),
          contentAlignment = Alignment.Center,
        ) {
          Text(
            (sessionDisplayName(session)).ifEmpty { "?" },
            style = MaterialTheme.typography.titleMedium,
          )
        }
        Text(
          sessionDisplayName(session),
          style = MaterialTheme.typography.titleMedium,
        )
        Text(
          user.email,
          style = MaterialTheme.typography.bodyMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        TextButton(onClick = {
          nameDraft = user.displayName ?: sessionDisplayName(session)
          editingName = true
        }) {
          Text(stringResource(R.string.account_edit_name))
        }
        OutlinedButton(onClick = {
          scope.launch { session.signOut(); onSignedOut() }
        }, modifier = Modifier.fillMaxWidth()) {
          Text(stringResource(R.string.account_signout))
        }
        TextButton(
          onClick = { confirmDelete = true },
          colors = androidx.compose.material3.ButtonDefaults.textButtonColors(
            contentColor = MaterialTheme.colorScheme.error,
          ),
          modifier = Modifier.fillMaxWidth(),
        ) {
          Text(stringResource(R.string.account_delete))
        }
      } else {
        Text(
          stringResource(R.string.account_signed_out),
          style = MaterialTheme.typography.bodyMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Button(onClick = onSignIn, modifier = Modifier.fillMaxWidth()) {
          Text(stringResource(R.string.sync_banner_cta))
        }
      }
    }
  }

  if (editingName) {
    NameDialog(
      title = stringResource(R.string.account_edit_name),
      initial = nameDraft,
      onDismiss = { editingName = false },
      onConfirm = { name ->
        scope.launch { runCatching { session.updateName(name) } }
        editingName = false
      },
    )
  }
  if (confirmDelete) {
    AlertDialog(
      onDismissRequest = { confirmDelete = false },
      title = { Text(stringResource(R.string.account_delete_confirm_title)) },
      text = { Text(stringResource(R.string.account_delete_confirm_message)) },
      confirmButton = {
        TextButton(onClick = {
          confirmDelete = false
          scope.launch {
            runCatching { session.deleteAccount() }
            onSignedOut()
          }
        }) { Text(stringResource(R.string.list_delete)) }
      },
      dismissButton = {
        TextButton(onClick = { confirmDelete = false }) { Text(stringResource(R.string.cancel)) }
      },
    )
  }
}

private fun sessionDisplayName(session: mx.creapolis.peliculas.android.core.auth.SessionStore): String {
  val user = session.state.value.user ?: return ""
  return user.displayName?.takeIf { it.isNotEmpty() } ?: user.email.substringBefore("@")
}

