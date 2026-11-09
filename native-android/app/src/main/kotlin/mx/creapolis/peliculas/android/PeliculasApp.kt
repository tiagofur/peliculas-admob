package mx.creapolis.peliculas.android

import android.app.Application
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import mx.creapolis.peliculas.android.core.auth.EncryptedSessionStorage
import mx.creapolis.peliculas.android.core.auth.SessionStore
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.notifications.PushManager
import mx.creapolis.peliculas.android.core.notifications.ReminderManager
import mx.creapolis.peliculas.android.features.gamification.AchievementStore
import mx.creapolis.peliculas.android.features.pro.ProStore
import mx.creapolis.peliculas.android.features.upnext.UpNextStore

/**
 * Contenedor manual de dependencias (espejo de los `@EnvironmentObject` de
 * iOS): aquí viven los singletons con estado; las pantallas los reciben o
 * los leen de [LocalAppContainer].
 */
class AppContainer(private val appContext: android.content.Context) {
  private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

  /** Biblioteca persistente compartida (outbox + sync, port de iOS). */
  val library = LibraryStore.fromContext(appContext)

  /** Logros locales (persistidos en SharedPreferences). */
  val achievements = AchievementStore(appContext)

  /** Recordatorios semanales locales con WorkManager (port de ReminderManager). */
  val reminders = ReminderManager(appContext)

  /** Registro de dispositivo para avisos (FCM pendiente; ver AppConfig.EPISODE_PUSH_AVAILABLE). */
  val push = PushManager(appContext)

  /** Sesión con refresh rotativo (tokens cifrados en Keystore). */
  val session = SessionStore(EncryptedSessionStorage(appContext))

  /** Compras y suscripciones con Google Play Billing (port de StoreKit 2). */
  val proStore = ProStore(appContext, signedInCheck = { session.state.value.isSignedIn })

  /** "Siguiente" compartido entre Inicio y su pestaña (port de `UpNextStore`). */
  val upNext = UpNextStore(library)

  init {
    // Conexión sesión↔biblioteca↔compras↔push (espejo de wireUp() en iOS):
    // al entrar se sube todo y se reclaman las compras; al salir se vacía lo local.
    // El 401 en refresh pasa por forceSignOut → willSignOut: sin mezclar cuentas.
    library.signedInCheck = { session.state.value.isSignedIn }
    proStore.accountId = session.state.value.user?.id
    session.didSignIn.add { library.mergeAfterSignIn() }
    session.didSignIn.add {
      proStore.accountId = session.state.value.user?.id
      proStore.claimAll()
    }
    session.didSignIn.add { push.upload() }
    session.didSignIn.add { session.refreshProfile() }
    session.willSignOut.add { push.unregister() }
    session.willSignOut.add { library.resetForSignOut() }
    session.willSignOut.add {
      proStore.accountId = null
      upNext.reset()
    }
  }

  /** App en primer plano (como `scenePhase == .active` en iOS). */
  fun onForeground() {
    appScope.launch {
      library.sync()
      proStore.refresh()
      reminders.reschedule(library.state.value.count(LibraryStore.Kind.WATCHLIST))
    }
  }

  /** App en segundo plano: guardar ya, sin esperar al debounce. */
  fun onBackground() {
    library.saveNow()
  }
}

/** Acceso al contenedor desde cualquier composable (menús contextuales, banners…). */
val LocalAppContainer = staticCompositionLocalOf<AppContainer> { error("AppContainer no provisto") }

class PeliculasApp : Application() {
  lateinit var container: AppContainer
    private set

  override fun onCreate() {
    super.onCreate()
    container = AppContainer(applicationContext)
    ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
      override fun onStart(owner: LifecycleOwner) = container.onForeground()
      override fun onStop(owner: LifecycleOwner) = container.onBackground()
    })
  }
}
