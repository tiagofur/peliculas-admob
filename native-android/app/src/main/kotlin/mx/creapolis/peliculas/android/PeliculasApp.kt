package mx.creapolis.peliculas.android

import android.app.Application

/**
 * Contenedor manual de dependencias (espejo de los `@EnvironmentObject` de
 * iOS): aquí viven los singletons con estado; las pantallas los reciben.
 * F0 aún no tiene stores — se irán añadiendo por fase.
 */
class AppContainer {
  // F1: HomeLoader / PagedListLoader
  // F4: SessionStore / LibraryStore / AppDatabase de prefs
}

class PeliculasApp : Application() {
  lateinit var container: AppContainer
    private set

  override fun onCreate() {
    super.onCreate()
    container = AppContainer()
  }
}
