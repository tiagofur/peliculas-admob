package mx.creapolis.peliculas.android.core.auth

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import mx.creapolis.peliculas.android.core.network.ApiClient
import mx.creapolis.peliculas.android.core.network.ApiError
import mx.creapolis.peliculas.android.core.network.TokenProvider
import java.time.Instant
import java.util.Date

/** Usuario del backend (port de `APIUser`). */
@Serializable
data class ApiUser(
  val id: String,
  val email: String,
  @SerialName("email_verified") val emailVerified: Boolean? = null,
  @SerialName("display_name") val displayName: String? = null,
  @SerialName("avatar_url") val avatarUrl: String? = null,
  val providers: List<String>? = null,
)

@Serializable
data class StoredSession(
  @SerialName("access_token") val accessToken: String,
  @SerialName("refresh_token") val refreshToken: String,
  @SerialName("expires_at") @Serializable(with = mx.creapolis.peliculas.android.core.sync.IsoDateSerializer::class)
  val expiresAt: Date,
  val user: ApiUser,
)

/** Persistencia de la sesión (SharedPreferences cifradas; memoria en tests). */
interface SessionStorage {
  fun load(): StoredSession?
  fun save(session: StoredSession)
  fun clear()
}

class InMemorySessionStorage : SessionStorage {
  private var stored: StoredSession? = null
  override fun load(): StoredSession? = stored
  override fun save(session: StoredSession) { stored = session }
  override fun clear() { stored = null }
}

/**
 * Sesión con el backend Go: access de 15 min + refresh rotativo (port de
 * `SessionStore` en iOS). Al renovar con 401 se corren los hooks de salida:
 * sin eso, el siguiente login subiría la biblioteca del usuario anterior.
 */
class SessionStore(
  private val storage: SessionStorage,
  private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO),
) {

  @Serializable
  private data class SessionResponse(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("expires_in") val expiresIn: Int,
    val user: ApiUser,
  )

  @Serializable
  private data class Credentials(
    val email: String,
    val password: String,
    val name: String?,
    val device: String,
  )

  @Serializable
  private data class GoogleBody(
    @SerialName("id_token") val idToken: String,
    val nonce: String?,
    val name: String?,
    val device: String,
  )

  @Serializable
  private data class RefreshBody(@SerialName("refresh_token") val refreshToken: String)

  @Serializable
  private data class LogoutBody(@SerialName("refresh_token") val refreshToken: String)

  @Serializable
  private data class NameBody(@SerialName("display_name") val displayName: String)

  data class UiState(
    val user: ApiUser? = null,
    val busy: Boolean = false,
  ) {
    val isSignedIn: Boolean get() = user != null
  }

  private val _state = MutableStateFlow(UiState())
  val state: StateFlow<UiState> = _state.asStateFlow()

  private var stored: StoredSession? = storage.load()

  /** Antes de borrar la sesión (token aún válido): unregister push, vaciar biblioteca… */
  val willSignOut = mutableListOf<suspend () -> Unit>()
  /** Tras iniciar sesión: merge de biblioteca, reclamar compras… */
  val didSignIn = mutableListOf<suspend () -> Unit>()

  private val refreshMutex = Mutex()
  private var refreshDeferred: kotlinx.coroutines.Deferred<StoredSession>? = null

  init {
    _state.value = UiState(user = stored?.user)
    ApiClient.tokenProvider = object : TokenProvider {
      override suspend fun validAccessToken(): String = this@SessionStore.validAccessToken()
      override suspend fun forceRefreshedAccessToken(): String = this@SessionStore.validAccessToken(forceRefresh = true)
    }
  }

  private fun deviceName(): String = "Android · API ${android.os.Build.VERSION.SDK_INT}"

  // MARK: Email

  suspend fun signIn(email: String, password: String) =
    authenticate("/v1/auth/email/login", ApiClient.encodeToString(Credentials(email, password, null, deviceName())))

  suspend fun signUp(email: String, password: String, name: String) =
    authenticate("/v1/auth/email/signup", ApiClient.encodeToString(Credentials(email, password, name.ifEmpty { null }, deviceName())))

  /**
   * Login con Google (Credential Manager → ID token). El backend valida el
   * token contra GOOGLE_CLIENT_IDS y el nonce crudo (Google no lo hashea).
   */
  suspend fun signInWithGoogle(idToken: String, nonce: String?, name: String?) =
    authenticate("/v1/auth/google", ApiClient.encodeToString(GoogleBody(idToken, nonce, name, deviceName())))

  // MARK: Olvidé mi contraseña

  @Serializable
  private data class ForgotBody(val email: String, val lang: String)

  @Serializable
  private data class ResetBody(val email: String, val code: String, val password: String, val device: String)

  /** Pide el código de 6 dígitos por correo. El servidor responde igual exista o no la cuenta. */
  suspend fun requestPasswordReset(email: String) {
    _state.value = _state.value.copy(busy = true)
    try {
      ApiClient.send(
        "POST", "/v1/auth/password/forgot",
        body = ApiClient.encodeToString(ForgotBody(email, java.util.Locale.getDefault().toLanguageTag())),
      )
    } finally {
      _state.value = _state.value.copy(busy = false)
    }
  }

  /** Código + contraseña nueva: el backend cierra las demás sesiones y devuelve una nueva. */
  suspend fun resetPassword(email: String, code: String, password: String) =
    authenticate("/v1/auth/password/reset", ApiClient.encodeToString(ResetBody(email, code, password, deviceName())))

  // MARK: Sesión

  /** Token válido; renueva si le queda < 1 min. Single-flight como iOS. */
  suspend fun validAccessToken(forceRefresh: Boolean = false): String {
    val current = stored ?: throw ApiError.NOT_SIGNED_IN
    if (!forceRefresh && current.expiresAt.time - System.currentTimeMillis() > 60_000) {
      return current.accessToken
    }
    refreshDeferred?.let { return it.await().accessToken }
    val deferred = scope.async {
      refreshMutex.withLock {
        val refreshToken = stored?.refreshToken ?: throw ApiError.NOT_SIGNED_IN
        try {
          val data = ApiClient.send(
            "POST", "/v1/auth/refresh",
            body = ApiClient.encodeToString(RefreshBody(refreshToken)),
          )
          decodeSession(data)
        } catch (e: ApiError) {
          if (e.status == 401) {
            // Refresh revocado o caducado: mismos efectos que cerrar sesión,
            // sin llamar al servidor (evita mezclar cuentas — como iOS).
            forceSignOut()
          }
          throw e
        }
      }
    }
    refreshDeferred = deferred
    return try {
      val fresh = deferred.await()
      save(fresh)
      fresh.accessToken
    } finally {
      refreshDeferred = null
    }
  }

  suspend fun refreshProfile() {
    val s = stored ?: return
    val data = runCatching { ApiClient.authed("GET", "/v1/me") }.getOrNull() ?: return
    val user = runCatching { ApiClient.decodeFromString<ApiUser>(data.decodeToString()) }.getOrNull() ?: return
    save(s.copy(user = user))
  }

  suspend fun updateName(name: String) {
    val data = ApiClient.authed("PATCH", "/v1/me", body = ApiClient.encodeToString(NameBody(name)))
    val user = ApiClient.decodeFromString<ApiUser>(data.decodeToString())
    stored?.let { save(it.copy(user = user)) }
  }

  suspend fun signOut() {
    val current = stored ?: return
    for (hook in willSignOut) hook()
    runCatching {
      ApiClient.send("POST", "/v1/auth/logout", body = ApiClient.encodeToString(LogoutBody(current.refreshToken)))
    }
    clearLocal()
  }

  /** Borra la cuenta y sus datos en el servidor (App Review 5.1.1(v)). */
  suspend fun deleteAccount() {
    _state.value = _state.value.copy(busy = true)
    try {
      for (hook in willSignOut) hook()
      ApiClient.authed("DELETE", "/v1/me")
      clearLocal()
    } finally {
      _state.value = _state.value.copy(busy = false)
    }
  }

  /** Sesión muerta (401 al renovar): hooks + limpieza local, sin servidor. */
  private suspend fun forceSignOut() {
    for (hook in willSignOut) hook()
    clearLocal()
  }

  // MARK: Privado

  private suspend fun authenticate(path: String, body: String) {
    _state.value = _state.value.copy(busy = true)
    try {
      val data = ApiClient.send("POST", path, body = body)
      save(decodeSession(data))
      for (hook in didSignIn) hook()
    } finally {
      _state.value = _state.value.copy(busy = false)
    }
  }

  private fun save(s: StoredSession) {
    stored = s
    _state.value = UiState(user = s.user)
    storage.save(s)
  }

  private fun clearLocal() {
    stored = null
    _state.value = UiState()
    storage.clear()
  }

  private fun decodeSession(data: ByteArray): StoredSession {
    val r = ApiClient.decodeFromString<SessionResponse>(data.decodeToString())
    return StoredSession(
      accessToken = r.accessToken,
      refreshToken = r.refreshToken,
      expiresAt = Date.from(Instant.now().plusSeconds(r.expiresIn.toLong())),
      user = r.user,
    )
  }
}
