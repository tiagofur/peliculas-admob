package mx.creapolis.peliculas.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.LoadingIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import mx.creapolis.peliculas.android.ui.root.AppTab
import mx.creapolis.peliculas.android.ui.root.labelRes

/**
 * Marcador de fase F0: prueba el tema (M3 Expressive), la navegación y los
 * strings. Cada pestaña se sustituye por su pantalla real en F1+.
 */
@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun PlaceholderScreen(tab: AppTab) {
  Column(
    modifier = Modifier.fillMaxSize().padding(24.dp),
    verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
    horizontalAlignment = Alignment.CenterHorizontally,
  ) {
    LoadingIndicator()
    Text(
      text = stringResource(tab.labelRes),
      style = MaterialTheme.typography.headlineMedium,
      textAlign = TextAlign.Center,
    )
    Text(
      text = "F0 · fundaciones",
      style = MaterialTheme.typography.bodyMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
  }
}
