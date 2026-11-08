package mx.creapolis.peliculas.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import mx.creapolis.peliculas.android.ui.root.RootScaffold
import mx.creapolis.peliculas.android.ui.theme.PeliculasTheme

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)
    setContent {
      PeliculasTheme {
        RootScaffold()
      }
    }
  }
}
