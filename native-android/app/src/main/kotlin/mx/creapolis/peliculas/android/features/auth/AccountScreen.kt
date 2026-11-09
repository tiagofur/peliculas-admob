package mx.creapolis.peliculas.android.features.auth

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.text.format.DateUtils
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.PanTool
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import kotlinx.coroutines.launch
import mx.creapolis.peliculas.android.LocalAppContainer
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.network.ApiError
import mx.creapolis.peliculas.android.core.network.AppConfig
import mx.creapolis.peliculas.android.features.ads.AdsManager
import mx.creapolis.peliculas.android.features.library.NameDialog
import mx.creapolis.peliculas.android.ui.components.InitialsAvatar
import mx.creapolis.peliculas.android.ui.components.ProBadge
import mx.creapolis.peliculas.android.ui.components.TmdbAttribution
import mx.creapolis.peliculas.android.ui.components.initials
import mx.creapolis.peliculas.android.ui.components.shownName

/**
 * Cuenta y ajustes (port de `AccountView`): perfil, Pro, actividad, avisos,
 * sincronización, privacidad y ayuda, versión, cerrar sesión y borrar cuenta.
 */
@Composable
fun AccountScreen(
  onSignIn: () -> Unit,
  onOpenAchievements: () -> Unit,
  onReplayOnboarding: () -> Unit,
) {
  val container = LocalAppContainer.current
  val session = container.session
  val library = container.library
  val proStore = container.proStore
  val context = LocalContext.current
  val scope = rememberCoroutineScope()

  val sessionState by session.state.collectAsState()
  val lib by library.state.collectAsState()
  val pro by proStore.state.collectAsState()
  val achievements by container.achievements.state.collectAsState()
  val remindersOn by container.reminders.enabled.collectAsState()
  val ads by AdsManager.state.collectAsState()

  var confirmSignOut by remember { mutableStateOf(false) }
  var confirmDelete by remember { mutableStateOf(false) }
  var editingName by remember { mutableStateOf(false) }
  var errorMessage by remember { mutableStateOf<String?>(null) }
  var notificationsDenied by remember { mutableStateOf(false) }

  val watchlistCount = lib.count(LibraryStore.Kind.WATCHLIST)
  val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
    notificationsDenied = !granted
    container.reminders.setEnabled(granted, watchlistCount)
  }

  fun setReminders(on: Boolean) {
    if (!on) {
      container.reminders.setEnabled(false, watchlistCount)
      return
    }
    // Permiso en contexto (Android 13+), nunca al abrir la app (como iOS).
    val needsPermission = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
      ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
    if (needsPermission) {
      permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    } else {
      container.reminders.setEnabled(true, watchlistCount)
    }
  }

  LazyColumn(
    Modifier.fillMaxSize(),
    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 32.dp),
    verticalArrangement = Arrangement.spacedBy(20.dp),
  ) {
    // ---- Perfil ----
    item {
      Card {
        val user = sessionState.user
        if (user != null) {
          Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            InitialsAvatar(user.initials, 56.dp)
            Column(Modifier.weight(1f).padding(start = 14.dp)) {
              Text(user.shownName, style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.SemiBold))
              Text(
                user.email,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
              )
            }
            TextButton(onClick = { editingName = true }) { Text(stringResource(R.string.account_edit_name)) }
          }
        } else {
          Row(
            Modifier
              .fillMaxWidth()
              .clickable(onClick = onSignIn)
              .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
          ) {
            Icon(Icons.Filled.AccountCircle, null, Modifier.size(52.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            Column(Modifier.weight(1f).padding(start = 14.dp)) {
              Text(stringResource(R.string.signin_title), style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.SemiBold))
              Text(
                stringResource(R.string.account_signin_pitch),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
              )
            }
          }
        }
      }
    }

    // ---- Pro ----
    item {
      Card {
        if (pro.isPro) {
          Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.AutoAwesome, null, tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.width(12.dp))
            Text(stringResource(pro.planNameRes), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
          }
          if (pro.activeProductId != AppConfig.Pro.LIFETIME) {
            Divider()
            ActionRow(stringResource(R.string.pro_manage)) {
              proStore.manageSubscriptionIntent()?.let { runCatching { context.startActivity(it) } }
            }
          }
        } else {
          Row(
            Modifier
              .fillMaxWidth()
              .clickable { proStore.presentPaywall() }
              .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
          ) {
            Icon(Icons.Filled.AutoAwesome, null, Modifier.size(30.dp), tint = Color(0xFFFF9800))
            Column(Modifier.weight(1f).padding(horizontal = 14.dp)) {
              Text(stringResource(R.string.paywall_title), style = MaterialTheme.typography.titleMedium)
              Text(
                stringResource(if (AppConfig.EPISODE_PUSH_AVAILABLE) R.string.pro_pitch_short else R.string.pro_pitch_short_no_push),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
              )
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
          }
        }
        Divider()
        ActionRow(stringResource(R.string.paywall_restore)) { proStore.restore() }
      }
    }

    // ---- Tu actividad ----
    item {
      Section(stringResource(R.string.account_activity)) {
        Row(Modifier.fillMaxWidth().padding(vertical = 14.dp)) {
          Stat(lib.count(LibraryStore.Kind.WATCHED), stringResource(R.string.cat_watched))
          Stat(lib.watchedEpisodeCount, stringResource(R.string.stats_episodes))
          Stat(lib.ratedCount, stringResource(R.string.account_ratings))
          Stat(achievements.totalPoints, stringResource(R.string.account_points))
        }
        Divider()
        Row(
          Modifier
            .fillMaxWidth()
            .clickable(onClick = onOpenAchievements)
            .padding(16.dp),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Icon(Icons.Filled.EmojiEvents, null, tint = Color(0xFFFF9F0A))
          Spacer(Modifier.width(12.dp))
          Text(stringResource(R.string.achievements_title), modifier = Modifier.weight(1f))
          Text("${achievements.unlockedCount}/${achievements.totalCount}", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
      }
    }

    // ---- Avisos ----
    item {
      Section(
        stringResource(R.string.account_notifications),
        footer = if (AppConfig.EPISODE_PUSH_AVAILABLE && !sessionState.isSignedIn) stringResource(R.string.account_alerts_need_account) else null,
      ) {
        ToggleRow(
          title = stringResource(R.string.reminders_title),
          subtitle = stringResource(R.string.reminders_desc),
          checked = remindersOn,
          onChange = ::setReminders,
        )
        if (notificationsDenied) {
          Divider()
          ActionRow(stringResource(R.string.notifications_open_settings)) {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
              .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
              .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            runCatching { context.startActivity(intent) }
          }
        }
      }
    }

    // ---- Sincronización ----
    if (sessionState.isSignedIn) {
      item {
        val pending = library.pendingChanges
        Section(
          stringResource(R.string.account_sync),
          footer = if (pending > 0) stringResource(R.string.sync_pending_fmt, pending) else null,
        ) {
          Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Sync, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.width(12.dp))
            Text(stringResource(R.string.account_sync), modifier = Modifier.weight(1f))
            when {
              lib.syncing -> CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
              lib.lastSyncError != null -> Text(
                stringResource(R.string.sync_error),
                style = MaterialTheme.typography.labelMedium,
                color = Color(0xFFFF9500),
              )
              lib.lastSync != null -> Text(
                DateUtils.getRelativeTimeSpanString(lib.lastSync!!.time).toString(),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
              )
            }
          }
          Divider()
          ActionRow(stringResource(R.string.sync_now), enabled = !lib.syncing) { scope.launch { library.sync() } }
        }
      }
    }

    // ---- Privacidad y ayuda ----
    item {
      Section(stringResource(R.string.account_privacy_help)) {
        if (ads.privacyOptionsRequired && !pro.isPro) {
          LinkRow(Icons.Filled.PanTool, stringResource(R.string.ads_privacy)) {
            context.findActivity()?.let { AdsManager.presentPrivacyOptions(it) }
          }
          Divider()
        }
        LinkRow(Icons.Filled.PrivacyTip, stringResource(R.string.privacy_policy)) { openUrl(context, AppConfig.PRIVACY_URL) }
        Divider()
        LinkRow(Icons.Filled.Description, stringResource(R.string.terms_of_use)) { openUrl(context, AppConfig.TERMS_URL) }
        Divider()
        LinkRow(Icons.AutoMirrored.Filled.HelpOutline, stringResource(R.string.help_contact)) { openUrl(context, AppConfig.SUPPORT_URL) }
        Divider()
        LinkRow(Icons.Filled.AutoAwesome, stringResource(R.string.replay_onboarding), onClick = onReplayOnboarding)
      }
    }

    // ---- Acerca de ----
    item {
      Card {
        Row(Modifier.padding(16.dp)) {
          Text(stringResource(R.string.version), modifier = Modifier.weight(1f))
          Text(AppConfig.APP_VERSION, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Divider()
        TmdbAttribution(Modifier.padding(16.dp))
      }
    }

    // ---- Cuenta ----
    if (sessionState.isSignedIn) {
      item {
        Card {
          ActionRow(stringResource(R.string.account_signout)) { confirmSignOut = true }
          Divider()
          ActionRow(stringResource(R.string.account_delete), destructive = true, enabled = !sessionState.busy) { confirmDelete = true }
        }
      }
    }
  }

  if (editingName) {
    NameDialog(
      title = stringResource(R.string.account_edit_name),
      initial = sessionState.user?.displayName.orEmpty(),
      onDismiss = { editingName = false },
      onConfirm = { name ->
        editingName = false
        scope.launch {
          try {
            session.updateName(name.trim())
          } catch (e: ApiError) {
            errorMessage = context.getString(authErrorRes(e.code))
          }
        }
      },
    )
  }
  if (confirmSignOut) {
    AlertDialog(
      onDismissRequest = { confirmSignOut = false },
      title = { Text(stringResource(R.string.signout_confirm_title)) },
      text = { Text(stringResource(R.string.signout_confirm_message)) },
      confirmButton = {
        TextButton(onClick = {
          confirmSignOut = false
          scope.launch { session.signOut() }
        }) { Text(stringResource(R.string.account_signout), color = MaterialTheme.colorScheme.error) }
      },
      dismissButton = { TextButton(onClick = { confirmSignOut = false }) { Text(stringResource(R.string.cancel)) } },
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
            try {
              session.deleteAccount()
            } catch (e: ApiError) {
              errorMessage = context.getString(authErrorRes(e.code))
            }
          }
        }) { Text(stringResource(R.string.account_delete_cta), color = MaterialTheme.colorScheme.error) }
      },
      dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(stringResource(R.string.cancel)) } },
    )
  }
  errorMessage?.let { msg ->
    AlertDialog(
      onDismissRequest = { errorMessage = null },
      text = { Text(msg) },
      confirmButton = { TextButton(onClick = { errorMessage = null }) { Text(stringResource(R.string.dialog_ok)) } },
    )
  }
}

@Composable
private fun Card(content: @Composable ColumnScope.() -> Unit) {
  Column(
    Modifier
      .fillMaxWidth()
      .clip(RoundedCornerShape(20.dp))
      .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
    content = content,
  )
}

@Composable
private fun Section(title: String, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
  Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
    Text(
      title.uppercase(),
      style = MaterialTheme.typography.labelMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      modifier = Modifier.padding(horizontal = 16.dp),
    )
    Card(content)
    if (footer != null) {
      Text(
        footer,
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 16.dp),
      )
    }
  }
}

@Composable
private fun Divider() =
  HorizontalDivider(Modifier.padding(start = 16.dp), thickness = 0.5.dp, color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

@Composable
private fun ActionRow(title: String, destructive: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
  Text(
    title,
    color = when {
      !enabled -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
      destructive -> MaterialTheme.colorScheme.error
      else -> MaterialTheme.colorScheme.primary
    },
    modifier = Modifier
      .fillMaxWidth()
      .clickable(enabled = enabled, onClick = onClick)
      .padding(16.dp),
  )
}

@Composable
private fun LinkRow(icon: ImageVector, title: String, onClick: () -> Unit) {
  Row(
    Modifier
      .fillMaxWidth()
      .clickable(onClick = onClick)
      .padding(16.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(icon, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(22.dp))
    Spacer(Modifier.width(12.dp))
    Text(title, modifier = Modifier.weight(1f))
  }
}

@Composable
private fun ToggleRow(title: String, subtitle: String, checked: Boolean, pro: Boolean = false, onChange: (Boolean) -> Unit) {
  Row(
    Modifier
      .fillMaxWidth()
      .clickable { onChange(!checked) }
      .padding(16.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Column(Modifier.weight(1f)) {
      Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title)
        if (pro) ProBadge()
      }
      Text(subtitle, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    Switch(checked = checked, onCheckedChange = onChange)
  }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.Stat(value: Int, label: String) {
  Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
    Text("$value", style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold))
    Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
  }
}

private fun Context.findActivity(): Activity? {
  var ctx: Context? = this
  while (ctx is ContextWrapper) {
    if (ctx is Activity) return ctx
    ctx = ctx.baseContext
  }
  return null
}
