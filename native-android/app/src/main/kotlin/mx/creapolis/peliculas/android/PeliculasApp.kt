package mx.creapolis.peliculas.android

import android.app.Application

/**
 * Contenedor manual de dependencias (espejo de los `@EnvironmentObject` de
 * iOS): aquí viven los singletons con estado; las pantallas los reciben.
 * F0 aún no tiene stores — se irán añadiendo por fase.
 */
class AppContainer {
  /** Biblioteca compartida; en F3 vive en memoria, F4 la persiste y sincroniza. */
  val library = mx.creapolis.peliculas.android.core.library.LibraryStore()
}

class PeliculasApp : Application() {
  lateinit var container: AppContainer
    private set

  override fun onCreate() {
    super.onCreate()
    container = AppContainer()
  }
}
