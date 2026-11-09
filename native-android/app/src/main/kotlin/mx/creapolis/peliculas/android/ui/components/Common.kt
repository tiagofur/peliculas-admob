package mx.creapolis.peliculas.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mx.creapolis.peliculas.android.LocalAppContainer
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.auth.ApiUser

/** Nombre visible y sus iniciales (port de `shownName`/`initials` de `APIUser`). */
val ApiUser.shownName: String
  get() = displayName?.takeIf { it.isNotBlank() } ?: email.substringBefore("@").ifEmpty { "?" }

val ApiUser.initials: String
  get() = shownName.split(" ").filter { it.isNotEmpty() }.take(2)
    .mapNotNull { it.firstOrNull()?.toString() }.joinToString("").uppercase().ifEmpty { "?" }

/** Avatar con iniciales y el degradado de marca (gemelo de `InitialsAvatar`). */
@Composable
fun InitialsAvatar(initials: String, size: Dp = 36.dp) {
  Box(
    Modifier
      .size(size)
      .clip(CircleShape)
      .background(Brush.linearGradient(listOf(Color(0xFFFF8C4D), Color(0xFFDB4066)))),
    contentAlignment = Alignment.Center,
  ) {
    Text(
      initials,
      color = Color.White,
      fontWeight = FontWeight.SemiBold,
      fontSize = (size.value * 0.4f).sp,
    )
  }
}

/** Botón de cuenta (avatar con sesión, icono sin ella), como en las raíces de iOS. */
@Composable
fun AccountButton(onClick: () -> Unit) {
  val session = LocalAppContainer.current.session
  val state by session.state.collectAsState()
  IconButton(onClick = onClick) {
    val user = state.user
    if (user != null) {
      InitialsAvatar(user.initials, 32.dp)
    } else {
      Icon(
        Icons.Filled.AccountCircle,
        contentDescription = stringResource(R.string.account_and_settings),
        tint = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.size(30.dp),
      )
    }
  }
}

/** Título grande de pantalla raíz con acciones a la derecha (patrón iOS/Android 16). */
@Composable
fun RootTitleBar(title: String, actions: @Composable RowScope.() -> Unit = {}) {
  Row(
    Modifier
      .fillMaxWidth()
      .statusBarsPadding()
      .padding(start = 20.dp, end = 8.dp, top = 12.dp, bottom = 4.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Text(
      title,
      style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold),
      color = MaterialTheme.colorScheme.onBackground,
      modifier = Modifier
        .weight(1f)
        .semantics { heading() },
    )
    actions()
  }
}

/** Estado vacío (gemelo de `EmptyState` / `ContentUnavailableView`). */
@Composable
fun EmptyState(
  icon: ImageVector,
  title: String,
  message: String,
  modifier: Modifier = Modifier,
  action: (@Composable () -> Unit)? = null,
) {
  Column(
    modifier.padding(horizontal = 32.dp, vertical = 28.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.Center,
  ) {
    Box(
      Modifier
        .size(64.dp)
        .clip(RoundedCornerShape(16.dp))
        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
      contentAlignment = Alignment.Center,
    ) {
      Icon(icon, contentDescription = null, modifier = Modifier.size(32.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    Spacer(Modifier.height(14.dp))
    Text(
      title,
      style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
      textAlign = TextAlign.Center,
    )
    Spacer(Modifier.height(4.dp))
    Text(
      message,
      style = MaterialTheme.typography.bodyMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      textAlign = TextAlign.Center,
    )
    if (action != null) {
      Spacer(Modifier.height(16.dp))
      action()
    }
  }
}

/** Distintivo "PRO" (gemelo de `ProBadge`). */
@Composable
fun ProBadge() {
  Text(
    "PRO",
    color = Color.White,
    fontSize = 10.sp,
    fontWeight = FontWeight.Black,
    modifier = Modifier
      .clip(CircleShape)
      .background(Brush.horizontalGradient(listOf(Color(0xFFFF9800), Color(0xFFEC407A))))
      .padding(horizontal = 6.dp, vertical = 2.dp),
  )
}

/** Crédito obligatorio de TMDB con su distintivo (gemelo de `TMDBAttribution`). */
@Composable
fun TmdbAttribution(modifier: Modifier = Modifier) {
  Row(modifier, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
    Text(
      "TMDB",
      color = Color.White,
      fontSize = 10.sp,
      fontWeight = FontWeight.Black,
      modifier = Modifier
        .clip(RoundedCornerShape(4.dp))
        .background(Brush.horizontalGradient(listOf(Color(0xFF90CEA1), Color(0xFF01B4E4))))
        .padding(horizontal = 6.dp, vertical = 3.dp),
    )
    Text(
      stringResource(R.string.tmdb_attribution),
      style = MaterialTheme.typography.labelSmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
  }
}
