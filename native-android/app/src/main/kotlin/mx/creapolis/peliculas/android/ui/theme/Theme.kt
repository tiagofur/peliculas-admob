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
  primary = Orange700,
  onPrimary = Color.White,
  primaryContainer = Orange500.copy(alpha = 0.18f),
  secondary = Teal400,
  tertiary = Pink400,
  background = LightBackground,
  surface = LightSurface,
)

private val DarkColors = darkColorScheme(
  primary = Orange500,
  secondary = Teal400,
  tertiary = Pink400,
  background = DarkBackground,
  surface = DarkSurface,
)

/**
 * Tema Material 3 Expressive: dynamic color en Android 12+ con fallback a la
 * paleta de marca, y el esquema de movimiento expresive (springs).
 */
@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun PeliculasTheme(
  darkTheme: Boolean = isSystemInDarkTheme(),
  dynamicColor: Boolean = true,
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
