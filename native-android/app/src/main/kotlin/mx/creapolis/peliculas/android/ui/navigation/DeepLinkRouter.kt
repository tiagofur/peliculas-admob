package mx.creapolis.peliculas.android.ui.navigation

import android.net.Uri
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import mx.creapolis.peliculas.android.core.model.MediaKind
import java.net.URI

/**
 * Evento de navegación por deep link o App Link.
 */
sealed interface DeepLinkTarget {
  data object Home : DeepLinkTarget
  data object Search : DeepLinkTarget
  data object Library : DeepLinkTarget
  data object UpNext : DeepLinkTarget
  data object Account : DeepLinkTarget
  data object Pro : DeepLinkTarget
  data class Detail(val kind: MediaKind, val id: Int) : DeepLinkTarget
}

/**
 * Gestor global de deep links y App Links (port de `DeepLinkRouter` en iOS).
 * - Maneja `https://peliculas.creapolis.dev/...`
 * - Maneja `peliculas://...`
 */
object DeepLinkRouter {

  const val WEB_DOMAIN = "peliculas.creapolis.dev"

  private val _targets = MutableSharedFlow<DeepLinkTarget>(
    replay = 1,
    onBufferOverflow = kotlinx.coroutines.channels.BufferOverflow.DROP_OLDEST,
  )
  val targets: SharedFlow<DeepLinkTarget> = _targets.asSharedFlow()

  fun parse(rawUrl: String?): DeepLinkTarget? {
    rawUrl ?: return null
    val uri = try {
      URI(rawUrl)
    } catch (_: Exception) {
      return null
    }

    val scheme = uri.scheme?.lowercase() ?: return null

    if (scheme == "https" && uri.host?.equals(WEB_DOMAIN, ignoreCase = true) == true) {
      val segments = (uri.path ?: "").split("/").filter { it.isNotEmpty() }
      val first = segments.getOrNull(0)?.lowercase()
      val secondId = segments.getOrNull(1)?.toIntOrNull()
      return when (first) {
        "movie", "pelicula" -> secondId?.let { DeepLinkTarget.Detail(MediaKind.MOVIE, it) }
        "serie", "tv" -> secondId?.let { DeepLinkTarget.Detail(MediaKind.TV, it) }
        "trending" -> DeepLinkTarget.Home
        "library" -> DeepLinkTarget.Library
        else -> DeepLinkTarget.Home
      }
    }

    if (scheme == "peliculas") {
      val host = uri.host?.lowercase() ?: return null
      val segments = (uri.path ?: "").split("/").filter { it.isNotEmpty() }
      val firstId = segments.getOrNull(0)?.toIntOrNull()
      return when (host) {
        "trending", "home" -> DeepLinkTarget.Home
        "search" -> DeepLinkTarget.Search
        "library" -> DeepLinkTarget.Library
        "upnext", "siguiente" -> DeepLinkTarget.UpNext
        "account" -> DeepLinkTarget.Account
        "pro" -> DeepLinkTarget.Pro
        "movie", "pelicula" -> firstId?.let { DeepLinkTarget.Detail(MediaKind.MOVIE, it) }
        "serie", "tv" -> firstId?.let { DeepLinkTarget.Detail(MediaKind.TV, it) }
        else -> DeepLinkTarget.Home
      }
    }

    return null
  }

  fun parse(uri: Uri?): DeepLinkTarget? = parse(uri?.toString())

  fun handle(uri: Uri?) {
    parse(uri)?.let { _targets.tryEmit(it) }
  }

  fun handle(url: String?) {
    parse(url)?.let { _targets.tryEmit(it) }
  }

  fun consume() {
    _targets.resetReplayCache()
  }
}
