package mx.creapolis.peliculas.android.core.auth

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.serialization.encodeToString
import mx.creapolis.peliculas.android.core.network.ApiClient

/**
 * Sesión cifrada con Keystore (equivalente Android del Llavero de iOS).
 * Si el archivo está corrupto, se empieza de cero: el usuario vuelve a entrar.
 */
class EncryptedSessionStorage(context: Context) : SessionStorage {

  private val prefs by lazy {
    try {
      val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()
      EncryptedSharedPreferences.create(
        context, "peliculas.session.v2", masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
      )
    } catch (_: Exception) {
      // Fallback sin cifrado si el Keystore del dispositivo falla (raro).
      context.getSharedPreferences("peliculas.session.v2.plain", Context.MODE_PRIVATE)
    }
  }

  override fun load(): StoredSession? =
    prefs.getString(KEY, null)?.let { raw ->
      runCatching { ApiClient.decodeFromString<StoredSession>(raw) }.getOrNull()
    }

  override fun save(session: StoredSession) {
    prefs.edit().putString(KEY, ApiClient.encodeToString(session)).apply()
  }

  override fun clear() {
    prefs.edit().remove(KEY).apply()
  }

  private companion object { const val KEY = "session" }
}
