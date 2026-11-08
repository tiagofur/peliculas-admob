package mx.creapolis.peliculas.android

import android.app.Application

/**
 * Contenedor manual de dependencias (espejo de los `@EnvironmentObject` de
 * iOS): aquí viven los singletons con estado; las pantallas los reciben.
 * F0 aún no tiene stores — se irán añadiendo por fase.
 */
class AppContainer(private val appContext: android.content.Context) {
  /** Biblioteca persistente compartida (outbox + sync, port de iOS). */
  val library = mx.creapolis.peliculas.android.core.library.LibraryStore.fromContext(appContext)

  /** Logros locales (persistidos en SharedPreferences). */
  val achievements = mx.creapolis.peliculas.android.features.gamification.AchievementStore(appContext)

  /** ProStore: compras y suscripciones Google Play Billing (port de StoreKit 2). */
  val proStore = mx.creapolis.peliculas.android.features.pro.ProStore(appContext)

  /** Recordatorios periódicos locales con WorkManager (port de ReminderManager). */
  val reminders = mx.creapolis.peliculas.android.core.notifications.ReminderManager(appContext)

  /** Push notifications FCM (preparación y tokens en /v1/devices). */
  val push = mx.creapolis.peliculas.android.core.notifications.PushManager(appContext)

  /** Sesión con refresh rotativo (tokens cifrados en Keystore). */
  val session = mx.creapolis.peliculas.android.core.auth.SessionStore(
    mx.creapolis.peliculas.android.core.auth.EncryptedSessionStorage(appContext),
  )

  init {
    // Conexión sesión↔biblioteca↔push (espejo de wireUp() en iOS):
    // al entrar se sube todo y se baja todo; al salir se vacía lo local y desregistra push.
    // El 401 en refresh pasa por forceSignOut → willSignOut: sin mezclar cuentas.
    library.signedInCheck = { session.state.value.isSignedIn }
    session.didSignIn.add { library.mergeAfterSignIn() }
    session.didSignIn.add { session.refreshProfile() }
    session.didSignIn.add { push.upload() }
    session.willSignOut.add { push.unregister() }
    session.willSignOut.add { library.resetForSignOut() }
  }
}

class PeliculasApp : Application() {
  lateinit var container: AppContainer
    private set

  override fun onCreate() {
    super.onCreate()
    container = AppContainer(applicationContext)
    mx.creapolis.peliculas.android.features.ads.AdsManager.initialize(this)
  }
}
