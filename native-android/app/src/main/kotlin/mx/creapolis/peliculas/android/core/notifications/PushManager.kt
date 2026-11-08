package mx.creapolis.peliculas.android.core.notifications

import android.content.Context
import kotlinx.serialization.Serializable
import mx.creapolis.peliculas.android.core.network.ApiClient

/**
 * Gestión del registro de dispositivos para notificaciones push (FCM)
 * de nuevos episodios para usuarios Pro (port de `PushManager` en iOS).
 *
 * Registra en `POST /v1/devices` con `{ "token": "...", "platform": "android" }`
 * y elimina en `DELETE /v1/devices/{token}` al cerrar sesión.
 */
class PushManager(private val context: Context) {

  @Serializable
  private data class DeviceBody(val token: String, val platform: String)

  private val prefs = context.getSharedPreferences("peliculas.push.v1", Context.MODE_PRIVATE)

  var deviceToken: String?
    get() = prefs.getString(KEY_TOKEN, null)
    set(value) = prefs.edit().putString(KEY_TOKEN, value).apply()

  suspend fun upload(token: String? = deviceToken) {
    val t = token ?: return
    deviceToken = t
    runCatching {
      ApiClient.authed(
        "POST", "/v1/devices",
        body = ApiClient.encodeToString(DeviceBody(token = t, platform = "android")),
      )
    }
  }

  suspend fun unregister() {
    val t = deviceToken ?: return
    runCatching {
      ApiClient.authed("DELETE", "/v1/devices/$t")
    }
  }

  companion object {
    private const val KEY_TOKEN = "fcm_token"
  }
}
