package mx.creapolis.peliculas.android.features.ads

import android.app.Activity
import android.content.Context
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
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
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import mx.creapolis.peliculas.android.core.network.AppConfig
import mx.creapolis.peliculas.android.features.pro.ProStore

/**
 * AdMob solo como apoyo en la versión gratis: un banner discreto, nunca
 * intersticiales (port de `AdsManager` en iOS). Primero el consentimiento
 * (UMP: RGPD en la UE/RU), luego el SDK. Sin consentimiento no hay anuncios.
 */
object AdsManager {

  data class State(
    val canShowAds: Boolean = false,
    /** "Privacidad de anuncios" en Cuenta (obligatorio con UMP en la UE). */
    val privacyOptionsRequired: Boolean = false,
  )

  private val _state = MutableStateFlow(State())
  val state: StateFlow<State> = _state.asStateFlow()

  private var started = false
  private var sdkStarted = false

  /** Se llama desde la Activity (el formulario de consentimiento necesita una). */
  fun start(activity: Activity) {
    if (started) return
    started = true
    val consent = UserMessagingPlatform.getConsentInformation(activity)
    consent.requestConsentInfoUpdate(
      activity,
      ConsentRequestParameters.Builder().build(),
      {
        UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { _ ->
          startSdkIfAllowed(activity.applicationContext, consent)
        }
      },
      { _ -> startSdkIfAllowed(activity.applicationContext, consent) },
    )
    // Si ya había consentimiento de otra sesión, no hace falta esperar.
    startSdkIfAllowed(activity.applicationContext, consent)
  }

  private fun startSdkIfAllowed(context: Context, consent: ConsentInformation) {
    val privacyRequired = consent.privacyOptionsRequirementStatus ==
      ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
    _state.value = _state.value.copy(privacyOptionsRequired = privacyRequired)
    if (!consent.canRequestAds() || sdkStarted) return
    sdkStarted = true
    MobileAds.initialize(context) {}
    _state.value = _state.value.copy(canShowAds = true)
  }

  fun presentPrivacyOptions(activity: Activity) {
    UserMessagingPlatform.showPrivacyOptionsForm(activity) { _ ->
      startSdkIfAllowed(activity.applicationContext, UserMessagingPlatform.getConsentInformation(activity))
    }
  }
}

/**
 * Banner adaptativo anclado (port de `AdBannerView` en iOS).
 * Invisible para Pro y mientras no haya consentimiento.
 */
@Composable
fun AdBannerView(
  proStore: ProStore,
  modifier: Modifier = Modifier,
  adUnitId: String = AppConfig.ADMOB_BANNER_ID,
) {
  val proState by proStore.state.collectAsState()
  val ads by AdsManager.state.collectAsState()
  if (proState.isPro || !ads.canShowAds || adUnitId.isBlank()) return

  BoxWithConstraints(
    modifier = modifier
      .fillMaxWidth()
      .padding(vertical = 8.dp),
    contentAlignment = Alignment.Center,
  ) {
    val widthDp = maxWidth.value.toInt().coerceAtLeast(320)
    Box(Modifier.fillMaxWidth().height(60.dp), contentAlignment = Alignment.Center) {
      AndroidView(
        modifier = Modifier.fillMaxWidth(),
        factory = { ctx ->
          AdView(ctx).apply {
            setAdSize(AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(ctx, widthDp))
            this.adUnitId = adUnitId
            loadAd(AdRequest.Builder().build())
          }
        },
        onRelease = { it.destroy() },
      )
    }
  }
}
