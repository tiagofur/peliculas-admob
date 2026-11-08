import XCTest
@testable import PeliculasNative

/// Modelos y decodificación sin red.
final class ModelTests: XCTestCase {
  func testOldCacheWithoutKindAndYearStillDecodes() throws {
    let json = #"{"id":1,"title":"T","overview":"","posterPath":"","backdropPath":"","rating":7.5}"#.data(using: .utf8)!
    let item = try JSONDecoder().decode(MediaItem.self, from: json)
    XCTAssertEqual(item.kind, .movie)
    XCTAssertEqual(item.year, "")
  }

  func testMediaKeySeparatesMoviesAndShowsWithSameId() {
    let movie = MediaKey(kind: .movie, id: 1399)
    let show = MediaKey(kind: .tv, id: 1399)
    XCTAssertNotEqual(movie, show)
    XCTAssertEqual(MediaKey(show.description), show)
    XCTAssertNil(MediaKey("nada"))
  }

  func testMergeKeepsRicherFields() {
    let minimal = MediaItem(key: MediaKey(kind: .tv, id: 1), title: "Serie", posterPath: "/p.jpg", year: "2020")
    let full = MediaItem(id: 1, title: "Serie", overview: "Sinopsis", posterPath: "", backdropPath: "/b.jpg", rating: 8, kind: .tv, year: "")
    let merged = minimal.merged(with: full)
    XCTAssertEqual(merged.posterPath, "/p.jpg")
    XCTAssertEqual(merged.backdropPath, "/b.jpg")
    XCTAssertEqual(merged.overview, "Sinopsis")
    XCTAssertEqual(merged.year, "2020")
  }

  func testFullDetailDecodesAppendedWatchProviders() throws {
    let json = """
    {"id":1399,"name":"Juego de tronos","seasons":[{"season_number":0,"episode_count":10},{"season_number":1,"episode_count":10}],
     "last_episode_to_air":{"season_number":1,"episode_number":10,"air_date":"2011-06-19"},
     "watch/providers":{"results":{"MX":{"flatrate":[{"provider_id":1899,"provider_name":"Max","logo_path":"/m.png"}]}}}}
    """.data(using: .utf8)!
    let d = try TMDBClient.decoder.decode(TMDBFullDetail.self, from: json)
    XCTAssertEqual(d.seasons?.count, 2)
    XCTAssertEqual(d.lastEpisodeToAir?.episodeNumber, 10)
    XCTAssertEqual(TMDBClient.providers(from: d.watchProviders, region: "MX").providers.first?.providerName, "Max")
  }

  func testBackendDatesWithNanosecondsParse() {
    XCTAssertNotNil(ISO8601.parse("2026-11-07T12:00:00Z"))
    XCTAssertNotNil(ISO8601.parse("2026-11-07T12:00:00.123Z"))
    XCTAssertNotNil(ISO8601.parse("2026-11-07T23:42:08.76292796Z"))
    XCTAssertNotNil(ISO8601.parse("2026-11-07T17:42:08.762927-06:00"))
  }

  func testBestTrailerPrefersOfficialTrailer() {
    let videos = [
      TMDBVideo(key: "teaser", site: "YouTube", type: "Teaser", official: true),
      TMDBVideo(key: "fan", site: "YouTube", type: "Trailer", official: false),
      TMDBVideo(key: "vimeo", site: "Vimeo", type: "Trailer", official: true),
      TMDBVideo(key: "oficial", site: "YouTube", type: "Trailer", official: true),
    ]
    XCTAssertEqual(TMDBClient.bestTrailer(videos), "oficial")
  }
}
