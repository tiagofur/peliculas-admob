import XCTest
@testable import PeliculasNative

/// Regresión: el tap en un proveedor debe abrir LA APP del proveedor,
/// nunca la página de TMDB. Espejo del cascade de Flutter
/// (`DeepLinkService`: esquema de la app → web del proveedor).
/// El `link` de `/watch/providers` apunta a `themoviedb.org/.../watch`,
/// así que usarlo como destino del tap siempre cae en TMDB (bug reportado).
final class ProviderLinksTests: XCTestCase {
  private func provider(id: Int, name: String) -> TMDBProvider {
    try! JSONDecoder().decode(
      TMDBProvider.self,
      from: #"{"providerId":\#(id),"providerName":"\#(name)","logoPath":"/x.png"}"#.data(using: .utf8)!)
  }

  func testNetflixTriesAppFirstThenWeb() {
    let p = provider(id: 8, name: "Netflix")
    XCTAssertEqual(ProviderLinks.appURL(for: p, title: "Palomas negras")?.scheme, "netflix")
    let web = ProviderLinks.webURL(for: p, title: "Palomas negras", region: "MX")!
    XCTAssertEqual(web.host, "www.netflix.com")
    XCTAssertTrue(web.absoluteString.contains("Palomas"))
    XCTAssertFalse(web.host!.contains("themoviedb"))
  }

  func testAppleTVGoesStraightToTVApp() {
    let p = provider(id: 350, name: "Apple TV Plus")
    XCTAssertNil(ProviderLinks.appURL(for: p, title: "Severance"))
    let web = ProviderLinks.webURL(for: p, title: "Severance", region: "US")!
    XCTAssertEqual(web.host, "tv.apple.com")
    XCTAssertFalse(web.host!.contains("themoviedb"))
  }

  func testUnknownProviderFallsBackToJustWatchNotTMDB() {
    let p = provider(id: 999999, name: "Cine Raro")
    XCTAssertNil(ProviderLinks.appURL(for: p, title: "Algo"))
    XCTAssertNil(ProviderLinks.appStoreURL(for: p))
    let web = ProviderLinks.webURL(for: p, title: "Algo", region: "MX")!
    XCTAssertEqual(web.host, "www.justwatch.com")
    XCTAssertFalse(web.host!.contains("themoviedb"))
  }

  func testNetflixFallsBackToAppStore() {
    let store = ProviderLinks.appStoreURL(for: provider(id: 8, name: "Netflix"))!
    XCTAssertEqual(store.host, "apps.apple.com")
    XCTAssertTrue(store.absoluteString.contains("id363590051"))
  }
}
