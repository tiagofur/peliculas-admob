package mx.creapolis.peliculas.android

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import mx.creapolis.peliculas.android.ui.navigation.DeepLinkRouter
import mx.creapolis.peliculas.android.ui.root.RootScaffold
import mx.creapolis.peliculas.android.ui.theme.PeliculasTheme

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)
    DeepLinkRouter.handle(intent?.data)
    setContent {
      PeliculasTheme {
        RootScaffold()
      }
    }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    DeepLinkRouter.handle(intent.data)
  }
}
