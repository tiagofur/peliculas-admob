package mx.creapolis.peliculas.android.features.detail

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import mx.creapolis.peliculas.android.core.network.TmdbProvider

/**
 * Tap en proveedor abre LA APP del proveedor, no la página de TMDB (paridad
 * con `ProviderLinks` en iOS y Flutter).
 *
 * En Android no hacen falta esquemas propios: la búsqueda web en el dominio de
 * cada proveedor (netflix.com, primevideo.com, disneyplus.com, play.max.com…)
 * está verificada como App Link por su app, así que el sistema abre la app si
 * está instalada y el navegador si no. Desconocido → JustWatch regional.
 * El `link` de TMDB apunta a `themoviedb.org/.../watch` y nunca se usa.
 *
 * IDs espejo de iOS (Max migró de 384/425 a 1899; Prime tiene 9/119/2100/10…).
 */
object ProviderLinks {

  fun webUrl(providerId: Int, providerName: String, title: String, region: String): String {
    val q = java.net.URLEncoder.encode(title.trim(), "UTF-8").replace("+", "%20")
    val name = providerName.lowercase()
    return when (providerId) {
      8, 1796 -> "https://www.netflix.com/search?q=$q"
      9, 119, 2100, 10 -> "https://www.primevideo.com/search/ref=atv_nb_sr?phrase=$q"
      337 -> "https://www.disneyplus.com/search?q=$q"
      2, 350 -> "https://tv.apple.com/search?term=$q"
      1899, 1825, 384, 425 -> "https://play.max.com/search?q=$q"
      531, 582, 2303, 1853 -> "https://www.paramountplus.com/search?q=$q"
      386, 387 -> "https://www.peacocktv.com/search?q=$q"
      7 -> "https://www.vudu.com/content/movies/search?query=$q"
      3 -> "https://play.google.com/store/search?q=$q&c=movies"
      else -> when {
        "netflix" in name -> "https://www.netflix.com/search?q=$q"
        "prime" in name || name == "amazon video" -> "https://www.primevideo.com/search/ref=atv_nb_sr?phrase=$q"
        "disney" in name -> "https://www.disneyplus.com/search?q=$q"
        "apple" in name -> "https://tv.apple.com/search?term=$q"
        "max" in name || "hbo" in name -> "https://play.max.com/search?q=$q"
        "paramount" in name -> "https://www.paramountplus.com/search?q=$q"
        "peacock" in name -> "https://www.peacocktv.com/search?q=$q"
        else -> "https://www.justwatch.com/${region.lowercase()}/search?q=$q"
      }
    }
  }

  fun open(context: Context, provider: TmdbProvider, title: String, region: String) {
    val url = webUrl(provider.providerId, provider.providerName, title, region)
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try {
      context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
      // Sin navegador ni app que lo abra: nada que hacer.
    }
  }
}
