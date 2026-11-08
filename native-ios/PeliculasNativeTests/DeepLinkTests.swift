import XCTest
@testable import PeliculasNative

/// Rutas `peliculas://`: el widget y las notificaciones dependen de que existan.
@MainActor
final class DeepLinkTests: XCTestCase {
  func testTrendingOpensHomeTab() {
    let router = DeepLinkRouter()
    router.open(URL(string: "peliculas://trending")!)
    XCTAssertEqual(router.tab, .home, "el widget y el recordatorio semanal apuntan aquí")
  }

  func testTabsRoutes() {
    let router = DeepLinkRouter()
    router.open(URL(string: "peliculas://siguiente")!)
    XCTAssertEqual(router.tab, .upNext)
    router.open(URL(string: "peliculas://library")!)
    XCTAssertEqual(router.tab, .library)
    router.open(URL(string: "peliculas://search")!)
    XCTAssertEqual(router.tab, .search)
  }

  func testMovieAndShowDetail() {
    let router = DeepLinkRouter()
    router.open(URL(string: "peliculas://movie/550")!)
    XCTAssertEqual(router.presented?.key, MediaKey(kind: .movie, id: 550))
    router.open(URL(string: "peliculas://serie/1399")!)
    XCTAssertEqual(router.presented?.key, MediaKey(kind: .tv, id: 1399))
  }

  func testForeignSchemeIgnored() {
    let router = DeepLinkRouter()
    router.open(URL(string: "https://example.com/movie/550")!)
    XCTAssertNil(router.presented)
    XCTAssertEqual(router.tab, .home)
  }
}
