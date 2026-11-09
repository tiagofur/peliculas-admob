package mx.creapolis.peliculas.android.core.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import mx.creapolis.peliculas.android.BuildConfig
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Error del backend Go: `{"error": "<código>"}` + estado HTTP.
 * Port de `APIError`; los mensajes se localizarán vía recursos en la fase de l10n.
 */
data class ApiError(val status: Int, val code: String) : Exception("api $status $code") {
  val isOffline: Boolean get() = status == 0

  companion object {
    val OFFLINE = ApiError(0, "offline")
    val NOT_SIGNED_IN = ApiError(401, "missing_token")
  }
}

/** Config visible para toda la app (viene de Gradle, como el xcconfig de iOS). */
object AppConfig {
  /** Override solo para el e2e de JVM (el release usa BuildConfig). */
  @Volatile
  var baseUrlOverride: String? = null

  val apiBaseUrl: String get() = baseUrlOverride ?: BuildConfig.API_BASE_URL

  const val PRIVACY_URL = BuildConfig.PRIVACY_URL
  const val TERMS_URL = BuildConfig.TERMS_URL
  const val SUPPORT_URL = BuildConfig.SUPPORT_URL
  const val GOOGLE_WEB_CLIENT_ID = BuildConfig.GOOGLE_WEB_CLIENT_ID

  /** "1.0 (1)" como en Ajustes de iOS. */
  const val APP_VERSION = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"

  /**
   * Avisos push de episodios nuevos. En iOS van por APNs; en Android necesitan
   * FCM en la app y `platform: "android"` + sender FCM en el backend, que aún
   * no existen. Mientras sea `false` no se promete en la UI (paywall, Siguiente,
   * Cuenta): Play prohíbe anunciar funciones que no funcionan.
   */
  const val EPISODE_PUSH_AVAILABLE = false

  /** Compras simuladas solo en debug (emulador sin Play Store). Nunca en release. */
  val SIMULATE_PURCHASES: Boolean get() = BuildConfig.DEBUG

  object Pro {
    const val MONTHLY = "peliculas_pro_monthly"
    const val YEARLY = "peliculas_pro_yearly"
    const val LIFETIME = "peliculas_pro_lifetime"
    val ALL = listOf(YEARLY, MONTHLY, LIFETIME)
    const val FREE_LIST_LIMIT = 3

    /**
     * Venta de Pro. Mientras sea `false` no se vende nada (uso no comercial de
     * TMDB) y Pro no existe para el usuario: sin paywall, sin sección Pro en
     * Cuenta y sin funciones Pro visibles; el límite de listas avisa sin
     * mencionar Pro. Cómo reactivarlo: `docs/PRO.md`.
     */
    const val SALES_ENABLED = false
  }
}

/** Proveedor de tokens que `ApiClient.authed` usa para autorizar y renovar. */
interface TokenProvider {
  suspend fun validAccessToken(): String
  suspend fun forceRefreshedAccessToken(): String
}

/**
 * Cliente HTTP del backend (port de `APIClient` en iOS). Sin Retrofit a
 * propósito: espejo del cliente iOS con OkHttp y el mismo manejo de errores.
 */
object ApiClient {

  /** Lo registra `SessionStore` al crearse (una sola sesión por proceso). */
  @Volatile
  var tokenProvider: TokenProvider? = null

  val json: Json = Json {
    ignoreUnknownKeys = true
    encodeDefaults = false
    explicitNulls = false
  }

  val client: OkHttpClient = OkHttpClient.Builder()
    .connectTimeout(20, TimeUnit.SECONDS)
    .readTimeout(20, TimeUnit.SECONDS)
    .writeTimeout(20, TimeUnit.SECONDS)
    .build()

  @Serializable
  data class ErrorBody(val error: String)

  /** Construye la URL final (pura y testeable; misma normalización que iOS). */
  fun buildUrl(base: String, path: String, query: Map<String, String> = emptyMap()): HttpUrl {
    val root = base.toHttpUrlOrNull() ?: throw ApiError(0, "bad_base_url")
    val trimmedRoot = root.encodedPath.trimEnd('/')
    val builder = root.newBuilder().encodedPath(trimmedRoot + path)
    query.toSortedMap().forEach { (k, v) -> builder.addQueryParameter(k, v) }
    return builder.build()
  }

  fun url(path: String, query: Map<String, String> = emptyMap()): HttpUrl =
    buildUrl(AppConfig.apiBaseUrl, path, query)

  /**
   * Petición con sesión. Añade el Bearer y, si el servidor responde 401,
   * renueva el token una vez y repite la petición (port de `authed` en iOS).
   */
  suspend fun authed(method: String, path: String, query: Map<String, String> = emptyMap(), body: String? = null): ByteArray {
    val provider = tokenProvider ?: throw ApiError.NOT_SIGNED_IN
    fun request(token: String): Request = Request.Builder()
      .url(url(path, query))
      .method(method, body?.toRequestBody("application/json".toMediaType()))
      .header("Authorization", "Bearer $token")
      .header("Cache-Control", "no-cache")
      .build()
    return try {
      perform(request(provider.validAccessToken()))
    } catch (e: ApiError) {
      if (e.status == 401) perform(request(provider.forceRefreshedAccessToken())) else throw e
    }
  }

  /** Petición sin sesión (health, login, registro, proxy TMDB…). Body crudo. */
  suspend fun send(method: String, path: String, query: Map<String, String> = emptyMap(), body: String? = null): ByteArray =
    perform(Request.Builder()
      .url(url(path, query))
      .method(method, body?.toRequestBody("application/json".toMediaType()))
      .build())

  /** Ejecuta y mapea errores igual que `perform` en iOS. */
  suspend fun perform(request: Request): ByteArray = withContext(Dispatchers.IO) {
    val response = try {
      client.newCall(request).execute()
    } catch (_: IOException) {
      throw ApiError.OFFLINE
    }
    response.use { resp ->
      val data = resp.body?.bytes() ?: ByteArray(0)
      if (!resp.isSuccessful) {
        val code = runCatching { json.decodeFromString<ErrorBody>(data.decodeToString()).error }
          .getOrDefault("http_${resp.code}")
        throw ApiError(resp.code, code)
      }
      data
    }
  }

  inline fun <reified T> encode(value: T): String = json.encodeToString(value)
  inline fun <reified T> encodeToString(value: T): String = json.encodeToString(value)
  inline fun <reified T> decodeFromString(value: String): T = json.decodeFromString(value)
  inline fun <reified T> decode(data: ByteArray): T = json.decodeFromString(data.decodeToString())
}
