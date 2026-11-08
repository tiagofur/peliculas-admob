package mx.creapolis.peliculas.android

import kotlinx.coroutines.test.runTest
import mx.creapolis.peliculas.android.core.auth.InMemorySessionStorage
import mx.creapolis.peliculas.android.core.auth.SessionStore
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKey
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.ApiClient
import mx.creapolis.peliculas.android.core.network.AppConfig
import mx.creapolis.peliculas.android.core.sync.IsoDate
import mx.creapolis.peliculas.android.core.sync.LibraryKind
import mx.creapolis.peliculas.android.core.sync.LibraryRow
import mx.creapolis.peliculas.android.core.sync.SyncOp
import mx.creapolis.peliculas.android.core.sync.SyncPull
import mx.creapolis.peliculas.android.core.sync.toEnvelope
import okhttp3.OkHttpClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File
import java.time.Instant
import java.util.Date
import java.util.UUID
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive


/** F4: wire de sync, lww, outbox y e2e de dos dispositivos contra el backend. */
class F4SyncTests {

  private fun date(s: String) = Date.from(Instant.parse(s))

  // MARK: Wire

  @Test
  fun `op de biblioteca se codifica igual que iOS`() {
    val op = SyncOp.Library(
      LibraryRow(
        kind = LibraryKind.WATCHLIST, mediaType = MediaKind.MOVIE, tmdbId = 550,
        title = "El club de la pelea", posterPath = "/p.jpg", year = "1999",
        updatedAt = date("2026-11-08T12:00:00Z"), deleted = false,
      ),
    )
    val envelope = op.toEnvelope(ApiClient.json)
    assertEquals("library", envelope.entity)
    val data = envelope.data.jsonObject
    assertEquals("watchlist", data["kind"]!!.jsonPrimitive.content)
    assertEquals("movie", data["media_type"]!!.jsonPrimitive.content)
    assertEquals("550", data["tmdb_id"]!!.jsonPrimitive.content)
    assertEquals("1999", data["year"]!!.jsonPrimitive.content)
    assertTrue(data.containsKey("updated_at"))
    assertEquals(op.key, "lib:watchlist:movie:550")
  }

  @Test
  fun `syncpull con fechas de 9 decimales decodifica`() {
    val raw = """
      {"cursor":"abc","has_more":false,
       "library":[{"kind":"watchlist","media_type":"tv","tmdb_id":1399,"title":"GoT",
                   "poster_path":"/g.jpg","year":"2011","updated_at":"2026-11-07T12:00:00.762927960Z","deleted":false}],
       "ratings":[{"media_type":"movie","tmdb_id":550,"score":9,"review":"obra maestra",
                   "title":"Fight","poster_path":"/p.jpg","updated_at":"2026-11-07T12:00:00Z","deleted":false}]}
    """.trimIndent()
    val page = ApiClient.decodeFromString<SyncPull>(raw)
    assertEquals("abc", page.cursor)
    assertFalse(page.hasMore)
    assertEquals(1399, page.library!!.first().tmdbId)
    assertEquals("obra maestra", page.ratings!!.first().review)
  }

  @Test
  fun `iso date tolera fracciones y offsets`() {
    assertNotNull(IsoDate.parse("2026-11-07T12:00:00Z"))
    assertNotNull(IsoDate.parse("2026-11-07T12:00:00.123Z"))
    assertNotNull(IsoDate.parse("2026-11-07T23:42:08.762927960Z"))
    assertNotNull(IsoDate.parse("2026-11-07T17:42:08.762927-06:00"))
  }

  // MARK: apply con last-write-wins

  @Test
  fun `apply gana el updated_at mas reciente`() {
    val store = LibraryStore()
    val fresh = """
      {"cursor":"c","has_more":false,"ratings":[
        {"media_type":"movie","tmdb_id":1,"score":8,"review":"","title":"A",
         "poster_path":"","updated_at":"2026-11-08T00:00:00Z","deleted":false}]}
    """.trimIndent()
    val stale = """
      {"cursor":"c","has_more":false,"ratings":[
        {"media_type":"movie","tmdb_id":1,"score":3,"review":"vieja","title":"A",
         "poster_path":"","updated_at":"2026-11-01T00:00:00Z","deleted":false}]}
    """.trimIndent()
    store.apply(ApiClient.decodeFromString<SyncPull>(fresh))
    store.apply(ApiClient.decodeFromString<SyncPull>(stale))
    assertEquals(8.0, store.state.value.score(MediaKey(MediaKind.MOVIE, 1))!!, 0.001)
    org.junit.Assert.assertNull(store.state.value.review(MediaKey(MediaKind.MOVIE, 1)))
  }

  @Test
  fun `outbox pisa ops con la misma clave`() {
    val store = LibraryStore()
    val item = MediaItem(id = 550, title = "A")
    store.rate(item, score = 7.0)
    store.rate(item, score = 9.0)
    store.setReview(item, "cambio")
    assertEquals("solo la última op por clave", 1, store.pendingChanges)
  }

  // MARK: e2e contra el backend local (dos dispositivos, port del test iOS)

  private fun backendUp(): Boolean = try {
    val url = okhttp3.Request.Builder().url("http://127.0.0.1:8787/healthz").build()
    okhttp3.OkHttpClient().newCall(url).execute().use { it.isSuccessful }
  } catch (_: Exception) {
    false
  }

  @Test
  fun `e2e dos dispositivos comparten biblioteca por sync`() = runTest {
    assumeTrue("Backend local no disponible: se salta el e2e", backendUp())
    val original = AppConfig.baseUrlOverride
    try {
      AppConfig.baseUrlOverride = "http://127.0.0.1:8787"

      val email = "android-e2e-${UUID.randomUUID().toString().take(8)}@peliculas.test"
      val password = "Prueba-${UUID.randomUUID().toString().take(12)}"
      val session = SessionStore(InMemorySessionStorage(), this.backgroundScope)
      try {
        session.signUp(email, password, "Prueba Android")
      } catch (e: Exception) {
        org.junit.Assert.fail("signUp falló: $e")
      }
      assertTrue(session.state.value.isSignedIn)

      // Dispositivo A: guarda y sube.
      val dirA = File(System.getProperty("java.io.tmpdir"), UUID.randomUUID().toString())
      dirA.mkdirs()
      val a = LibraryStore(dirA, this.backgroundScope)
      a.signedInCheck = { session.state.value.isSignedIn }
      val movie = MediaItem(id = 550, title = "El club de la pelea", posterPath = "/p.jpg", rating = 8.4, year = "1999")
      a.set(movie, LibraryStore.Kind.WATCHLIST, on = true)
      a.rate(movie, score = 9.0)
      val listId = a.createList("Clásicos")
      a.toggleInList(movie, listId)
      a.setEpisode(1399, 1, 1, watched = true)
      a.sync()
      assertEquals("la cola queda vacía tras subir", 0, a.pendingChanges)

      // Dispositivo B: sesión nueva, baja todo.
      val sessionB = SessionStore(InMemorySessionStorage(), this.backgroundScope)
      sessionB.signIn(email, password)
      val dirB = File(System.getProperty("java.io.tmpdir"), UUID.randomUUID().toString())
      dirB.mkdirs()
      val b = LibraryStore(dirB, this.backgroundScope)
      b.signedInCheck = { sessionB.state.value.isSignedIn }
      b.sync()
      assertTrue(b.state.value.contains(movie.key, LibraryStore.Kind.WATCHLIST))
      assertEquals(9.0, b.state.value.score(movie.key)!!, 0.001)
      assertTrue(b.state.value.visibleLists.map { it.name }.contains("Clásicos"))
      assertTrue(b.state.value.itemsOfList(listId).map { it.key }.contains(movie.key))
      assertTrue(b.state.value.isEpisodeWatched(1399, 1, 1))

      // B borra de la watchlist; A lo recibe (last-write-wins).
      b.set(movie, LibraryStore.Kind.WATCHLIST, on = false)
      b.sync()
      a.sync()
      assertFalse(a.state.value.contains(movie.key, LibraryStore.Kind.WATCHLIST))

      // Borrar cuenta deja la sesión cerrada (App Review).
      session.deleteAccount()
      assertFalse(session.state.value.isSignedIn)
      Unit
    } finally {
      AppConfig.baseUrlOverride = original
    }
  }

}

