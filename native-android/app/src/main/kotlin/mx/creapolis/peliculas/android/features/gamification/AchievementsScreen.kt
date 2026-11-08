package mx.creapolis.peliculas.android.features.gamification

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import mx.creapolis.peliculas.android.R

/** Logros (port de `AchievementsView` en iOS). */
@Composable
fun AchievementsScreen(store: AchievementStore, onBack: () -> Unit) {
  val state by store.state.collectAsState()
  val level = state.level

  Column(Modifier.fillMaxSize()) {
    LazyColumn(contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      item {
        Column(
          Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.primaryContainer)
            .padding(16.dp),
        ) {
          Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.EmojiEvents, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(level.nameRes), style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.weight(1f))
            Text("${state.totalPoints} pts", style = MaterialTheme.typography.labelLarge)
          }
          Spacer(Modifier.height(8.dp))
          LinearProgressIndicator(
            progress = { level.progress(state.totalPoints).toFloat() },
            modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)),
          )
          val toNext = level.pointsToNext(state.totalPoints)
          Text(
            if (toNext != null) stringResource(R.string.achievements_to_next, toNext)
            else stringResource(R.string.achievements_max_level),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp),
          )
          Text(
            stringResource(R.string.achievements_unlocked_fmt, state.unlockedCount, state.totalCount),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 2.dp),
          )
        }
      }
      items(state.all, key = { a -> a.id }) { ach: Achievement ->
        Row(
          Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(if (ach.isUnlocked) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.surface.copy(alpha = 0.5f))
            .padding(14.dp),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Box(
            Modifier
              .size(40.dp)
              .clip(CircleShape)
              .background(if (ach.isUnlocked) MaterialTheme.colorScheme.primary.copy(alpha = 0.18f) else MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
          ) {
            Icon(
              if (ach.isUnlocked) Icons.Filled.EmojiEvents else Icons.Filled.Lock,
              contentDescription = null,
              tint = if (ach.isUnlocked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
              modifier = Modifier.size(20.dp),
            )
          }
          Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
            Text(ach.name, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
              ach.description,
              style = MaterialTheme.typography.labelMedium,
              color = MaterialTheme.colorScheme.onSurfaceVariant,
              maxLines = 2,
              overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(6.dp))
            LinearProgressIndicator(
              progress = { if (ach.target > 0) ach.progress.toFloat() / ach.target else 0f },
              modifier = Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)),
            )
          }
          Column(horizontalAlignment = Alignment.End) {
            Text("${ach.points}", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
            Text(
              "${ach.progress}/${ach.target}",
              style = MaterialTheme.typography.labelSmall,
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
        }
      }
    }
  }
}

/** Toast de logro desbloqueado: cápsula que baja y se va sola (como iOS). */
@Composable
fun AchievementToast(achievement: Achievement?, onDismiss: () -> Unit) {
  if (achievement == null) return
  LaunchedEffectToast(onDismiss)
  Box(Modifier.fillMaxSize().padding(top = 48.dp), contentAlignment = Alignment.TopCenter) {
    Row(
      Modifier
        .clip(RoundedCornerShape(24.dp))
        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.97f))
        .padding(horizontal = 16.dp, vertical = 10.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Icon(Icons.Filled.EmojiEvents, contentDescription = null, tint = Color(0xFFFFC94D), modifier = Modifier.size(22.dp))
      Column(Modifier.padding(start = 10.dp)) {
        Text(stringResource(R.string.achievement_unlocked), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(achievement.name, style = MaterialTheme.typography.labelLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
      }
    }
  }
}

@Composable
private fun LaunchedEffectToast(onDismiss: () -> Unit) {
  androidx.compose.runtime.LaunchedEffect(Unit) {
    kotlinx.coroutines.delay(4_000)
    onDismiss()
  }
}
