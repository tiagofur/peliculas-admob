import XCTest
@testable import PeliculasNative

/// Regresión T40/T41: el decode de `/watch/providers` debe convertir
/// `snake_case` (`logo_path`, `provider_id`...) y juntar plana+renta+compra.
/// JSON con la forma real verificada contra TMDB en vivo.
final class WatchProvidersTests: XCTestCase {
  func testDecodesSnakeCaseAndMergesOfferTypes() throws {
    let json = """
    {"id":693134,"results":{
      "MX":{"link":"https://www.themoviedb.org/movie/693134-watch?locale=MX",
        "flatrate":[{"logo_path":"/a.png","provider_id":8,"provider_name":"Netflix","display_priority":0}],
        "rent":[{"logo_path":"/b.png","provider_id":8,"provider_name":"Netflix","display_priority":1},
                {"logo_path":"/c.png","provider_id":2,"provider_name":"Apple TV","display_priority":2}],
        "buy":[]},
      "US":{"link":"https://www.themoviedb.org/movie/693134-watch?locale=US",
        "flatrate":[{"logo_path":"/d.png","provider_id":9,"provider_name":"Hulu","display_priority":0}],
        "rent":[],"buy":[]}
    }}
    """.data(using: .utf8)!

    let mx = try TMDBClient.decodeWatchProviders(json, region: "MX")
    XCTAssertEqual(mx.flatrate.map(\.providerName), ["Netflix", "Apple TV"])
    XCTAssertEqual(mx.link, "https://www.themoviedb.org/movie/693134-watch?locale=MX")

    let us = try TMDBClient.decodeWatchProviders(json, region: "US")
    XCTAssertEqual(us.flatrate.map(\.providerName), ["Hulu"])
  }

  func testFallsBackToUSWhenRegionMissing() throws {
    let json = """
    {"id":1,"results":{
      "US":{"link":"https://example.invalid/us","flatrate":[],"rent":[],"buy":[]}
    }}
    """.data(using: .utf8)!

    let result = try TMDBClient.decodeWatchProviders(json, region: "AR")
    XCTAssertEqual(result.link, "https://example.invalid/us")
    XCTAssertTrue(result.flatrate.isEmpty)
  }
}
