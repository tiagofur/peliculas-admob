package mx.creapolis.peliculas.android

import mx.creapolis.peliculas.android.core.network.AppConfig
import mx.creapolis.peliculas.android.features.pro.ProStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** F7: pruebas unitarias del estado Pro y paywall (port de ProStoreTests en iOS). */
class F7ProTests {

  @Test
  fun `proStore inicia no-pro sin compras`() {
    val store = ProStore()
    assertFalse(store.isPro)
    assertNull(store.state.value.activeProductId)
    assertFalse(store.state.value.showingPaywall)
  }

  @Test
  fun `presentPaywall y dismissPaywall actualizan estado`() {
    val store = ProStore()
    store.presentPaywall("Con Pro creas todas las listas que quieras.")
    assertTrue(store.state.value.showingPaywall)
    assertEquals("Con Pro creas todas las listas que quieras.", store.state.value.paywallReason)

    store.dismissPaywall()
    assertFalse(store.state.value.showingPaywall)
    assertNull(store.state.value.paywallReason)
  }

  @Test
  fun `setProForTesting activa Pro y producto activo`() {
    val store = ProStore()
    store.setProForTesting(true, AppConfig.Pro.YEARLY)
    assertTrue(store.isPro)
    assertEquals(AppConfig.Pro.YEARLY, store.state.value.activeProductId)

    store.setProForTesting(false, null)
    assertFalse(store.isPro)
    assertNull(store.state.value.activeProductId)
  }

  @Test
  fun `loadProducts puebla productos con los 3 identificadores`() {
    val store = ProStore()
    store.loadProducts()
    val products = store.state.value.products
    assertEquals(3, products.size)
    val ids = products.map { it.id }.toSet()
    assertTrue(ids.contains(AppConfig.Pro.YEARLY))
    assertTrue(ids.contains(AppConfig.Pro.MONTHLY))
    assertTrue(ids.contains(AppConfig.Pro.LIFETIME))

    val yearly = products.first { it.id == AppConfig.Pro.YEARLY }
    assertTrue(yearly.isSubscription)
    val lifetime = products.first { it.id == AppConfig.Pro.LIFETIME }
    assertFalse(lifetime.isSubscription)
  }

  @Test
  fun `restore informa estado al usuario`() {
    val store = ProStore()
    store.restore()
    assertNotNull(store.state.value.message)
    assertTrue(store.state.value.message!!.contains("No encontramos compras"))

    store.clearMessage()
    assertNull(store.state.value.message)

    store.setProForTesting(true, AppConfig.Pro.MONTHLY)
    store.restore()
    assertTrue(store.state.value.message!!.contains("¡Listo!"))
  }
}
