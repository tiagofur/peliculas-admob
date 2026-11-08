package mx.creapolis.peliculas.android

import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.notifications.ReminderManager
import mx.creapolis.peliculas.android.ui.navigation.DeepLinkRouter
import mx.creapolis.peliculas.android.ui.navigation.DeepLinkTarget
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDateTime

/** F8: pruebas de Deep Links, App Links, shareURL y programación de recordatorios. */
class F8SystemTests {

  @Test
  fun `shareURL genera enlace en el dominio propio`() {
    val movie = MediaItem(id = 550, title = "Fight Club", kind = MediaKind.MOVIE)
    val show = MediaItem(id = 1399, title = "Game of Thrones", kind = MediaKind.TV)

    assertEquals("https://peliculas.creapolis.dev/movie/550", movie.shareUrl)
    assertEquals("https://peliculas.creapolis.dev/serie/1399", show.shareUrl)
    assertTrue(movie.shareText.contains("Fight Club"))
    assertTrue(movie.shareText.contains(movie.shareUrl))
  }

  @Test
  fun `deepLinkRouter parsea App Links universales de peliculas creapolis dev`() {
    assertEquals(DeepLinkTarget.Detail(MediaKind.MOVIE, 550), DeepLinkRouter.parse("https://peliculas.creapolis.dev/movie/550"))
    assertEquals(DeepLinkTarget.Detail(MediaKind.MOVIE, 550), DeepLinkRouter.parse("https://peliculas.creapolis.dev/pelicula/550"))
    assertEquals(DeepLinkTarget.Detail(MediaKind.TV, 1399), DeepLinkRouter.parse("https://peliculas.creapolis.dev/serie/1399"))
    assertEquals(DeepLinkTarget.Detail(MediaKind.TV, 1399), DeepLinkRouter.parse("https://peliculas.creapolis.dev/tv/1399"))
    assertEquals(DeepLinkTarget.Home, DeepLinkRouter.parse("https://peliculas.creapolis.dev/trending"))
    assertEquals(DeepLinkTarget.Library, DeepLinkRouter.parse("https://peliculas.creapolis.dev/library"))
  }

  @Test
  fun `deepLinkRouter parsea esquema custom peliculas`() {
    assertEquals(DeepLinkTarget.Home, DeepLinkRouter.parse("peliculas://trending"))
    assertEquals(DeepLinkTarget.Home, DeepLinkRouter.parse("peliculas://home"))
    assertEquals(DeepLinkTarget.Search, DeepLinkRouter.parse("peliculas://search"))
    assertEquals(DeepLinkTarget.Library, DeepLinkRouter.parse("peliculas://library"))
    assertEquals(DeepLinkTarget.UpNext, DeepLinkRouter.parse("peliculas://upnext"))
    assertEquals(DeepLinkTarget.UpNext, DeepLinkRouter.parse("peliculas://siguiente"))
    assertEquals(DeepLinkTarget.Account, DeepLinkRouter.parse("peliculas://account"))
    assertEquals(DeepLinkTarget.Pro, DeepLinkRouter.parse("peliculas://pro"))
    assertEquals(DeepLinkTarget.Detail(MediaKind.MOVIE, 550), DeepLinkRouter.parse("peliculas://movie/550"))
    assertEquals(DeepLinkTarget.Detail(MediaKind.TV, 1399), DeepLinkRouter.parse("peliculas://serie/1399"))
  }

  @Test
  fun `deepLinkRouter ignora esquemas o dominios ajenos`() {
    assertNull(DeepLinkRouter.parse("https://google.com/movie/550"))
    assertNull(DeepLinkRouter.parse("https://themoviedb.org/movie/550"))
    assertNull(DeepLinkRouter.parse(null as String?))
  }

  @Test
  fun `reminderManager calcula delay positivo hacia el proximo dia fijado`() {
    val now = LocalDateTime.of(2026, 11, 8, 12, 0) // Domingo 12:00
    val delaySunday18 = ReminderManager.calculateDelayToNext(DayOfWeek.SUNDAY, 18, 0, now)
    assertEquals(6 * 3600L, delaySunday18.seconds) // 6 horas hasta las 18:00 hoy

    val delayFriday19 = ReminderManager.calculateDelayToNext(DayOfWeek.FRIDAY, 19, 0, now)
    assertTrue(delayFriday19.toHours() in 1..168)
  }
}
