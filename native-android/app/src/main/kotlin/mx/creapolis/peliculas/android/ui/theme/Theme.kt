package mx.creapolis.peliculas.android.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.MaterialExpressiveTheme
import androidx.compose.material3.MotionScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val LightColors = lightColorScheme(
  primary = BrandCoralLight,
  onPrimary = Color.White,
  primaryContainer = BrandCoralLight.copy(alpha = 0.15f),
  onPrimaryContainer = BrandCoralLight,
  secondary = Teal400,
  tertiary = Pink400,
  background = LightBackground,
  surface = LightSurface,
  surfaceVariant = Color(0xFFE5E5EA),
  onSurfaceVariant = Color(0xFF6C6C70),
)

private val DarkColors = darkColorScheme(
  primary = BrandCoralDark,
  onPrimary = Color.White,
  primaryContainer = BrandCoralDark.copy(alpha = 0.20f),
  onPrimaryContainer = BrandCoralDark,
  secondary = Teal400,
  tertiary = Pink400,
  background = DarkBackground,
  surface = DarkSurface,
  surfaceVariant = Color(0xFF2C2C2E),
  onSurfaceVariant = Color(0xFF8E8E93),
)

/**
 * Tema Material 3 Expressive con la paleta de marca oficial (coral-rojizo iOS).
 * dynamicColor se desactiva por defecto para mantener la identidad visual consistente.
 */
@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun PeliculasTheme(
  darkTheme: Boolean = isSystemInDarkTheme(),
  dynamicColor: Boolean = false,
  content: @Composable () -> Unit,
) {
  val context = LocalContext.current
  val colorScheme = when {
    dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
      if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
    darkTheme -> DarkColors
    else -> LightColors
  }

  MaterialExpressiveTheme(
    colorScheme = colorScheme,
    motionScheme = MotionScheme.expressive(),
    content = content,
  )
}
