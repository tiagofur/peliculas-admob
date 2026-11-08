package mx.creapolis.peliculas.android.features.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.LiveTv
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import mx.creapolis.peliculas.android.R

/**
 * Bienvenida de primer uso (port de `OnboardingView` en iOS).
 * Presenta las 4 propuestas de valor centrales de la app y opciones de entrada.
 */
@Composable
fun OnboardingScreen(
  onDone: () -> Unit,
  onSignIn: () -> Unit,
) {
  Surface(
    modifier = Modifier.fillMaxSize(),
    color = MaterialTheme.colorScheme.background,
  ) {
    Column(
      modifier = Modifier
        .fillMaxSize()
        .padding(horizontal = 24.dp)
        .padding(top = 40.dp, bottom = 24.dp),
    ) {
      Column(
        modifier = Modifier
          .weight(1f)
          .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
      ) {
        Spacer(Modifier.height(20.dp))

        // Icono de cabecera con gradiente
        Box(
          modifier = Modifier
            .size(72.dp)
            .clip(CircleShape)
            .background(
              Brush.linearGradient(
                listOf(Color(0xFFFFC107), Color(0xFFFF5722), Color(0xFFE91E63)),
              ),
            ),
          contentAlignment = Alignment.Center,
        ) {
          Icon(
            imageVector = Icons.Filled.Movie,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(40.dp),
          )
        }

        Spacer(Modifier.height(16.dp))

        Text(
          text = stringResource(R.string.onboarding_welcome),
          style = MaterialTheme.typography.headlineLarge,
          fontWeight = FontWeight.ExtraBold,
          textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(36.dp))

        // Filas de características
        Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
          OnboardingFeatureRow(
            icon = Icons.Filled.PlayCircle,
            iconTint = Color(0xFFFF9800),
            title = stringResource(R.string.onboarding_f1_title),
            subtitle = stringResource(R.string.onboarding_f1_desc),
          )
          OnboardingFeatureRow(
            icon = Icons.Filled.AutoAwesome,
            iconTint = Color(0xFFE91E63),
            title = stringResource(R.string.onboarding_f2_title),
            subtitle = stringResource(R.string.onboarding_f2_desc),
          )
          OnboardingFeatureRow(
            icon = Icons.Filled.LiveTv,
            iconTint = Color(0xFF2196F3),
            title = stringResource(R.string.onboarding_f3_title),
            subtitle = stringResource(R.string.onboarding_f3_desc),
          )
          OnboardingFeatureRow(
            icon = Icons.Filled.CloudDone,
            iconTint = Color(0xFF673AB7),
            title = stringResource(R.string.onboarding_f4_title),
            subtitle = stringResource(R.string.onboarding_f4_desc),
          )
        }

        Spacer(Modifier.height(24.dp))
      }

      // Botones inferiores
      Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
      ) {
        Button(
          onClick = onDone,
          modifier = Modifier
            .fillMaxWidth()
            .height(52.dp),
          shape = RoundedCornerShape(16.dp),
        ) {
          Text(
            stringResource(R.string.onboarding_continue),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
          )
        }

        TextButton(
          onClick = {
            onDone()
            onSignIn()
          },
        ) {
          Text(
            stringResource(R.string.onboarding_already_have_account),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
          )
        }
      }
    }
  }
}

@Composable
private fun OnboardingFeatureRow(
  icon: ImageVector,
  iconTint: Color,
  title: String,
  subtitle: String,
) {
  Row(
    verticalAlignment = Alignment.Top,
    modifier = Modifier.fillMaxWidth(),
  ) {
    Box(
      modifier = Modifier
        .size(44.dp)
        .clip(RoundedCornerShape(12.dp))
        .background(iconTint.copy(alpha = 0.15f)),
      contentAlignment = Alignment.Center,
    ) {
      Icon(
        imageVector = icon,
        contentDescription = null,
        tint = iconTint,
        modifier = Modifier.size(26.dp),
      )
    }
    Spacer(Modifier.width(16.dp))
    Column(modifier = Modifier.weight(1f)) {
      Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
      Spacer(Modifier.height(2.dp))
      Text(
        subtitle,
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
  }
}
