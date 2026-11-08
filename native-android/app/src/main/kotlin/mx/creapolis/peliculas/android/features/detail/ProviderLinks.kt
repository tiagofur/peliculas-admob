package mx.creapolis.peliculas.android.features.detail

import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Abre el título en la app del proveedor si está instalada; si no, su web.
 * (Paridad con `ProviderLinks` en iOS, que usa esquemas de app.)
 */
object ProviderLinks {

  /** Package de la app Android por nombre de proveedor (id TMDB). */
  private val appPackages = mapOf(
    8 to "com.netflix.mediaclient", // Netflix
    9 to "com.amazon.avod.thirdpartyclient.samsung", // Prime Video (fallback genérico abajo)
    119 to "com.amazon.avod.thirdpartyclient.samsung",
    337 to "com.disney.disneyplus", // Disney+
    350 to "com.apple.android.tv", // Apple TV+
    1899 to "com.hbo.hbonow", // Max
    384 to "com.hbo.hbonow",
    189 to "com.hbo.hbonow",
  )

  /** URLs web conocidas por proveedor (fallback sin app). */
  private val webUrls = mapOf(
    8 to "https://www.netflix.com/search?q=",
    9 to "https://www.primevideo.com/search/ref=atv_nb_sr?phrase=",
    119 to "https://www.primevideo.com/search/ref=atv_nb_sr?phrase=",
    337 to "https://www.disneyplus.com/search?q=",
    350 to "https://tv.apple.com/search?term=",
    1899 to "https://play.max.com/search?q=",
    384 to "https://play.max.com/search?q=",
    189 to "https://play.max.com/search?q=",
  )

  fun open(context: Context, providerId: Int, title: String, fallbackUrl: String?) {
    // 1) enlace directo del proveedor (el `link` de TMDB) vía navegador,
    // 2) si no lo hay, búsqueda en la web del proveedor.
    val target = fallbackUrl ?: webUrls[providerId]?.let { it + Uri.encode(title) } ?: return
    val pkg = appPackages[providerId]
    val intent = if (pkg != null) {
      context.packageManager.getLaunchIntentForPackage(pkg)?.let { launch ->
        // La app del proveedor se abre; el título lo busca el usuario.
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return context.startActivity(launch)
      } ?: Intent(Intent.ACTION_VIEW, Uri.parse(target))
    } else {
      Intent(Intent.ACTION_VIEW, Uri.parse(target))
    }
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(intent)
  }
}
