package mx.creapolis.peliculas.android

import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKey
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.features.gamification.AchievementStore
import mx.creapolis.peliculas.android.features.gamification.LibraryCounts
import mx.creapolis.peliculas.android.features.gamification.UserLevel
import mx.creapolis.peliculas.android.features.stats.LibraryStats
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.util.Date

/** F6: niveles, logros y estadísticas (ports de los tests de iOS/Flutter). */
class F6GamificationTests {

  // MARK: Niveles (mismos umbrales que Flutter)

  @Test
  fun `niveles por puntos`() {
    assertEquals(1, UserLevel.levelFor(0).level)
    assertEquals(1, UserLevel.levelFor(149).level)
    assertEquals(2, UserLevel.levelFor(150).level)
    assertEquals(7, UserLevel.levelFor(4000).level)
    assertEquals(7, UserLevel.levelFor(9999).level)
  }

  @Test
  fun `progreso dentro del nivel`() {
    val level2 = UserLevel.levelFor(150)
    assertEquals(150, level2.pointsRequired)
    assertEquals("faltan 250 para nivel 3 (400)", 250, level2.pointsToNext(150)!!)
    assertEquals(0.4, level2.progress(250), 0.001)
    val max = UserLevel.levelFor(5000)
    assertEquals(1.0, max.progress(5000), 0.001)
    org.junit.Assert.assertNull(max.pointsToNext(5000))
  }

  // MARK: Logros

  @Test
  fun `primer check no celebra pero si desbloquea silenciosamente`() {
    val store = AchievementStore()
    store.check(LibraryCounts(favorites = 1))
    val state = store.state.value
    assertTrue(state.all.first { it.id == "first_movie" }.isUnlocked)
    org.junit.Assert.assertNull("arranque: no se celebra lo que ya tenías", state.toast)
    assertEquals(10, state.totalPoints)
  }

  @Test
  fun `cambio posterior celebra con toast`() {
    val store = AchievementStore()
    store.check(LibraryCounts()) // primed
    store.check(LibraryCounts(watched = 1, watchlist = 1))
    val toast = store.state.value.toast
    assertNotNull("tras primed sí celebra", toast)
    assertTrue("celebra el más nuevo", toast!!.id == "first_watched" || toast.id == "first_watchlist")
    store.dismissToast()
    assertNull(store.state.value.toast)
  }

  @Test
  fun `nivel no rebaja al seguir evaluando`() {
    val store = AchievementStore()
    store.check(LibraryCounts(favorites = 200, watched = 10, ratings = 25, lists = 1, watchlist = 1, episodes = 50))
    val first = store.state.value.totalPoints
    store.check(LibraryCounts()) // sin contenido: los desbloqueados persisten
    assertEquals("los desbloqueados persisten", first, store.state.value.totalPoints)
    assertTrue(store.state.value.unlockedCount >= 8)
  }

  // MARK: Stats (port de PhaseFourTests de iOS)

  private fun monthDate(year: Int, month: Int): Date =
    Date.from(LocalDate.of(year, month, 5).atStartOfDay(java.time.ZoneId.systemDefault()).toInstant())

  @Test
  fun `stats cuentan ventanas y decadas`() {
    val now = LocalDate.of(2026, 11, 8)
    val watched = mapOf(
      MediaKey(MediaKind.MOVIE, 1) to LibraryStore.Stamp(monthDate(2026, 11), false),
      MediaKey(MediaKind.MOVIE, 2) to LibraryStore.Stamp(monthDate(2026, 10), false),
      MediaKey(MediaKind.MOVIE, 3) to LibraryStore.Stamp(monthDate(2026, 10), true),
      MediaKey(MediaKind.TV, 4) to LibraryStore.Stamp(monthDate(2025, 12), false),
    )
    val items = mapOf(
      MediaKey(MediaKind.MOVIE, 1) to MediaItem(id = 1, title = "A", year = "1994"),
      MediaKey(MediaKind.MOVIE, 2) to MediaItem(id = 2, title = "B", year = "2023"),
      MediaKey(MediaKind.TV, 4) to MediaItem(id = 4, title = "C", kind = MediaKind.TV, year = "1999"),
    )
    val ratings = mapOf(
      MediaKey(MediaKind.MOVIE, 1) to LibraryStore.RatingStamp(8.0, "", monthDate(2026, 11), false),
      MediaKey(MediaKind.MOVIE, 2) to LibraryStore.RatingStamp(7.0, "", monthDate(2026, 10), false),
      MediaKey(MediaKind.MOVIE, 3) to LibraryStore.RatingStamp(10.0, "", monthDate(2026, 10), true),
    )
    val stats = LibraryStats.build(watched, ratings, episodeCount = 42, items = items, now = now)
    assertEquals(3, stats.watchedTotal)
    assertEquals("pelis vistas", 2, stats.watchedMovies)
    assertEquals("series vistas", 1, stats.watchedShows)
    assertEquals(7.5, stats.averageScore, 0.001)
    assertEquals(12, stats.byMonth.size)
    assertEquals(1, stats.byMonth.last().count)
    assertEquals(1, stats.byMonth[stats.byMonth.size - 2].count)
    assertEquals(listOf("1990", "2020"), stats.byDecade.map { it.id })
    assertEquals(listOf(2, 1), stats.byDecade.map { it.count })
  }
}
