package mx.creapolis.peliculas.android

import mx.creapolis.peliculas.android.features.upnext.EpisodeRef
import mx.creapolis.peliculas.android.features.upnext.UpNextCalculator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** F5: lógica pura de "qué toca ver ahora" (port de UpNextCalculator en iOS). */
class F5UpNextTests {

  private val seasons = listOf(1 to 10, 2 to 8) // T1: 10 eps, T2: 8 eps

  @Test
  fun `primer no visto de la primera temporada`() {
    val next = UpNextCalculator.next(seasons, lastAired = EpisodeRef(2, 8), watched = emptySet())
    assertEquals(EpisodeRef(1, 1), next)
  }

  @Test
  fun `cruza a la temporada siguiente al terminar una`() {
    val watched = (1..10).map { EpisodeRef(1, it) }.toSet()
    val next = UpNextCalculator.next(seasons, lastAired = EpisodeRef(2, 8), watched = watched)
    assertEquals(EpisodeRef(2, 1), next)
  }

  @Test
  fun `todo visto no devuelve nada`() {
    val watched = (1..10).map { EpisodeRef(1, it) }.toSet() + (1..8).map { EpisodeRef(2, it) }.toSet()
    assertNull(UpNextCalculator.next(seasons, lastAired = EpisodeRef(2, 8), watched = watched))
  }

  @Test
  fun `sin nada emitido no hay siguiente`() {
    assertNull(UpNextCalculator.next(seasons, lastAired = null, watched = emptySet()))
  }

  @Test
  fun `episodios no emitidos no se sugieren`() {
    val watched = (1..10).map { EpisodeRef(1, it) }.toSet() + (1..3).map { EpisodeRef(2, it) }.toSet()
    // Solo se emitieron hasta T2E3 y ya están vistos: nada pendiente por ver.
    assertNull(UpNextCalculator.next(seasons, lastAired = EpisodeRef(2, 3), watched = watched))
    // Cuando emiten T2E5 y viste T2E4, el siguiente es T2E5.
    val watched4 = watched + EpisodeRef(2, 4)
    val next = UpNextCalculator.next(seasons, lastAired = EpisodeRef(2, 5), watched = watched4)
    assertEquals(EpisodeRef(2, 5), next)
  }

  @Test
  fun `la temporada cero especiales no cuenta`() {
    val seasonsWithSpecials = listOf(0 to 5, 1 to 3)
    val next = UpNextCalculator.next(seasonsWithSpecials, lastAired = EpisodeRef(1, 3), watched = emptySet())
    assertEquals(EpisodeRef(1, 1), next)
    val aired = UpNextCalculator.airedCount(seasonsWithSpecials, lastAired = EpisodeRef(1, 2))
    assertEquals("los especiales no suman al emitido", 2, aired)
  }

  @Test
  fun `airedCount suma temporadas completas y parcial en la ultima`() {
    assertEquals(10, UpNextCalculator.airedCount(seasons, lastAired = EpisodeRef(1, 10)))
    assertEquals(13, UpNextCalculator.airedCount(seasons, lastAired = EpisodeRef(2, 3)))
    assertEquals(18, UpNextCalculator.airedCount(seasons, lastAired = EpisodeRef(2, 8)))
    assertEquals(0, UpNextCalculator.airedCount(seasons, lastAired = null))
  }

  @Test
  fun `orden de episodios T1E10 menor que T2E1`() {
    assertTrue(EpisodeRef(1, 10) < EpisodeRef(2, 1))
    assertTrue(EpisodeRef(2, 1) > EpisodeRef(1, 10))
  }
}
