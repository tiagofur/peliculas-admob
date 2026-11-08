package mx.creapolis.peliculas.android.features.ads

import android.content.Context
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.MobileAds
import mx.creapolis.peliculas.android.features.pro.ProStore

/**
 * Gestor del SDK de Google Mobile Ads (AdMob).
 * Inicializa el SDK en segundo plano al arrancar la app.
 */
object AdsManager {
  private var initialized = false

  fun initialize(context: Context) {
    if (initialized) return
    initialized = true
    MobileAds.initialize(context) {}
  }
}

/**
 * Banner publicitario adaptativo de AdMob (port de `AdBannerView` en iOS).
 * - Invisible y no solicita anuncios si el usuario es Pro (`isPro = true`).
 * - Usa el Ad Unit ID de prueba oficial de Google para banners en desarrollo.
 */
@Composable
fun AdBannerView(
  proStore: ProStore,
  modifier: Modifier = Modifier,
  adUnitId: String = "ca-app-pub-3940256099942544/6300978111", // ID oficial de prueba de Google
) {
  val proState by proStore.state.collectAsState()

  // Si el usuario es Pro, nunca mostramos anuncios ni consumimos datos de red
  if (proState.isPro) return

  Box(
    modifier = modifier
      .fillMaxWidth()
      .height(60.dp)
      .padding(vertical = 4.dp),
    contentAlignment = Alignment.Center,
  ) {
    AndroidView(
      modifier = Modifier.fillMaxWidth(),
      factory = { ctx ->
        AdView(ctx).apply {
          setAdSize(AdSize.BANNER)
          this.adUnitId = adUnitId
          loadAd(AdRequest.Builder().build())
        }
      },
    )
  }
}
