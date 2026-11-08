import XCTest
@testable import PeliculasNative

/// Punta a punta contra el backend Go de verdad (Debug → http://127.0.0.1:8787).
/// Se salta solo si el backend no responde. Para correrlo:
///   cd backend && API_PORT=8787 docker compose up -d
@MainActor
final class BackendIntegrationTests: XCTestCase {
  private var tempDir: URL!

  override func setUp() async throws {
    var req = URLRequest(url: APIClient.url("/healthz"))
    req.timeoutInterval = 2
    guard (try? await APIClient.perform(req)) != nil else {
      throw XCTSkip("Backend no disponible en \(AppConfig.apiBaseURL)")
    }
    tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    await SessionStore.shared.signOut()
  }

  override func tearDown() async throws {
    if SessionStore.shared.isSignedIn { try? await SessionStore.shared.deleteAccount() }
    if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
  }

  func testTMDBGoesThroughBackendCache() async throws {
    let trending = try await TMDBClient.trending(.movie)
    XCTAssertFalse(trending.isEmpty)
    let detail = try await TMDBClient.detail(kind: .tv, id: 1399)
    XCTAssertEqual(detail.id, 1399)
    XCTAssertFalse(detail.seasons?.isEmpty ?? true)
  }

  /// El infinite scroll ("Ver todo") vive de esto: `page` atraviesa el proxy
  /// del backend y TMDB devuelve páginas distintas con `total_pages`.
  func testPagedListFetchesDistinctPages() async throws {
    let page1 = try await TMDBClient.pagedList(.trending(kind: .movie, window: "week"), page: 1)
    let page2 = try await TMDBClient.pagedList(.trending(kind: .movie, window: "week"), page: 2)
    XCTAssertGreaterThan(page1.totalPages, 1)
    XCTAssertFalse(page1.results.isEmpty)
    XCTAssertFalse(page2.results.isEmpty)
    XCTAssertNotEqual(page1.results.first?.id, page2.results.first?.id, "la página 2 no debe repetir la 1")
  }

  func testSignUpSyncAcrossTwoDevicesAndDeleteAccount() async throws {
    let session = SessionStore.shared
    let email = "ios-e2e-\(UUID().uuidString.prefix(8).lowercased())@peliculas.test"
    try await session.signUp(email: email, password: "Prueba-\(UUID().uuidString.prefix(12))", name: "Prueba iOS")
    XCTAssertTrue(session.isSignedIn)
    XCTAssertEqual(session.user?.email, email)

    // Dispositivo A: guarda cosas y sube.
    let a = LibraryStore(fileURL: tempDir.appendingPathComponent("a.json"))
    a.resetForSignOut()
    let movie = MediaItem(id: 550, title: "El club de la pelea", overview: "", posterPath: "/p.jpg", backdropPath: "", rating: 8.4, kind: .movie, year: "1999")
    let show = MediaItem(id: 1399, title: "Juego de tronos", overview: "", posterPath: "/g.jpg", backdropPath: "", rating: 8.5, kind: .tv, year: "2011")
    a.set(movie, in: .watchlist, on: true)
    a.set(show, in: .favorite, on: true)
    a.rate(movie, score: 9)
    let list = a.createList(named: "Clásicos")
    a.toggle(movie, inList: list)
    a.setEpisode(tvId: 1399, season: 1, episode: 1, watched: true)
    await a.sync()
    XCTAssertNil(a.lastSyncError)
    XCTAssertEqual(a.pendingChanges, 0, "la cola debe quedar vacía tras subir")

    // Dispositivo B: biblioteca vacía, baja todo.
    let b = LibraryStore(fileURL: tempDir.appendingPathComponent("b.json"))
    b.resetForSignOut()
    await b.sync()
    XCTAssertTrue(b.isInWatchlist(movie))
    XCTAssertTrue(b.isFavorite(show))
    XCTAssertFalse(b.isFavorite(MediaItem(key: MediaKey(kind: .movie, id: 1399), title: "", posterPath: "", year: "")))
    XCTAssertEqual(b.rating(for: movie.key), 9)
    // La app anfitriona del test también sube su biblioteca local al iniciar
    // sesión (fusión al entrar), así que puede haber más listas.
    XCTAssertTrue(b.visibleLists.map(\.name).contains("Clásicos"))
    XCTAssertEqual(b.itemsOfList(list).map(\.key), [movie.key])
    XCTAssertTrue(b.isEpisodeWatched(tvId: 1399, season: 1, episode: 1))
    XCTAssertEqual(b.item(for: show.key)?.title, "Juego de tronos", "la foto mínima viaja con la fila")

    // B quita de la watchlist; A lo recibe (last-write-wins).
    b.set(movie, in: .watchlist, on: false)
    await b.sync()
    await a.sync()
    XCTAssertFalse(a.isInWatchlist(movie))

    // Token renovado a la fuerza: el refresh rotativo funciona.
    _ = try await session.validAccessToken(forceRefresh: true)
    await session.refreshProfile()
    XCTAssertEqual(session.user?.shownName, "Prueba iOS")

    // Borrar la cuenta (App Review) deja la sesión cerrada.
    try await session.deleteAccount()
    XCTAssertFalse(session.isSignedIn)
  }

  func testWrongPasswordShowsLocalizedError() async {
    do {
      try await SessionStore.shared.signIn(email: "nadie-\(UUID().uuidString.prefix(6))@peliculas.test", password: "incorrecta123")
      XCTFail("no debería entrar")
    } catch let error as APIError {
      XCTAssertEqual(error.code, "invalid_credentials")
      // En el idioma del simulador (la clave base es la frase en español).
      XCTAssertEqual(error.errorDescription, String(localized: "Correo o contraseña incorrectos."))
    } catch {
      XCTFail("error inesperado \(error)")
    }
  }
}
