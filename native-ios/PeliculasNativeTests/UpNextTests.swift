import XCTest
@testable import PeliculasNative

/// "Siguiente": qué episodio toca, sin red.
final class UpNextTests: XCTestCase {
  private let seasons = [(number: 0, count: 5), (number: 1, count: 3), (number: 2, count: 2)]

  func testStartsAtPilotIgnoringSpecials() {
    let next = UpNextCalculator.next(seasons: seasons, lastAired: EpisodeRef(season: 2, episode: 2), watched: [])
    XCTAssertEqual(next, EpisodeRef(season: 1, episode: 1))
  }

  func testFindsFirstGapAcrossSeasons() {
    let watched: Set<EpisodeRef> = [.init(season: 1, episode: 1), .init(season: 1, episode: 2), .init(season: 1, episode: 3)]
    XCTAssertEqual(UpNextCalculator.next(seasons: seasons, lastAired: .init(season: 2, episode: 2), watched: watched),
                   EpisodeRef(season: 2, episode: 1))
  }

  func testCaughtUpReturnsNilAndUnairedIsSkipped() {
    let watched: Set<EpisodeRef> = [.init(season: 1, episode: 1), .init(season: 1, episode: 2), .init(season: 1, episode: 3)]
    XCTAssertNil(UpNextCalculator.next(seasons: seasons, lastAired: .init(season: 1, episode: 3), watched: watched))
    XCTAssertNil(UpNextCalculator.next(seasons: seasons, lastAired: nil, watched: []))
  }

  func testAiredCountStopsAtLastAired() {
    XCTAssertEqual(UpNextCalculator.airedCount(seasons: seasons, lastAired: .init(season: 2, episode: 1)), 4)
  }
}
