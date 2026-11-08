import XCTest
@testable import PeliculasNative

/// Fase 4: estadísticas, moods, búsqueda de personas e historial.
@MainActor
final class PhaseFourTests: XCTestCase {
  private func monthDate(_ year: Int, _ month: Int, calendar: Calendar) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: 5))!
  }

  func testStatsCountsAveragesAndWindows() {
    let cal = Calendar(identifier: .gregorian)
    let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12))!
    let watched: [MediaKey: Stamp] = [
      MediaKey(kind: .movie, id: 1): Stamp(updatedAt: monthDate(2026, 11, calendar: cal), deleted: false),
      MediaKey(kind: .movie, id: 2): Stamp(updatedAt: monthDate(2026, 10, calendar: cal), deleted: false),
      MediaKey(kind: .movie, id: 3): Stamp(updatedAt: monthDate(2026, 10, calendar: cal), deleted: true),
      MediaKey(kind: .tv, id: 4): Stamp(updatedAt: monthDate(2025, 12, calendar: cal), deleted: false),
    ]
    func item(_ id: Int, kind: MediaKind, year: String) -> MediaItem {
      MediaItem(id: id, title: "T\(id)", overview: "", posterPath: "", backdropPath: "", rating: 0, kind: kind, year: year)
    }
    let items: [MediaKey: MediaItem] = [
      MediaKey(kind: .movie, id: 1): item(1, kind: .movie, year: "1994"),
      MediaKey(kind: .movie, id: 2): item(2, kind: .movie, year: "2023"),
      MediaKey(kind: .tv, id: 4): item(4, kind: .tv, year: "1999"),
    ]
    let ratings: [MediaKey: RatingStamp] = [
      MediaKey(kind: .movie, id: 1): RatingStamp(score: 8, review: "", updatedAt: now, deleted: false),
      MediaKey(kind: .movie, id: 2): RatingStamp(score: 7, review: "", updatedAt: now, deleted: false),
      MediaKey(kind: .movie, id: 3): RatingStamp(score: 10, review: "", updatedAt: now, deleted: true),
    ]

    let stats = LibraryStats.build(watched: watched, ratings: ratings, episodeCount: 42, items: items, now: now, calendar: cal)
    XCTAssertEqual(stats.watchedTotal, 3, "las filas borradas no cuentan")
    XCTAssertEqual(stats.watchedMovies, 2)
    XCTAssertEqual(stats.watchedShows, 1)
    XCTAssertEqual(stats.averageScore, 7.5, accuracy: 0.001, "las notas borradas no cuentan")
    XCTAssertEqual(stats.episodeCount, 42)
    XCTAssertEqual(stats.byMonth.count, 12, "ventana fija de 12 meses")
    XCTAssertEqual(stats.byMonth.last?.count, 1, "mes actual: 1 vista")
    XCTAssertEqual(stats.byMonth[stats.byMonth.count - 2].count, 1, "octubre 2026: cuenta id 2; id 3 está borrado")
    XCTAssertEqual(stats.byMonth.first?.count, 1, "dic 2025 dentro de la ventana")
    XCTAssertEqual(stats.byDecade.map(\.id), ["1990", "2020"])
    XCTAssertEqual(stats.byDecade.map(\.count), [2, 1])
  }

  func testMoodSourcesCarryGenresAndDiffer() {
    XCTAssertNotEqual(Mood.romantic.source, Mood.hiddenGems.source)
    XCTAssertEqual(Mood.allCases.count, 8)
    guard case .discover(_, let gemsGenres, let gemsFloor, let gemsRating, _) = Mood.hiddenGems.source else {
      return XCTFail("hiddenGems debe ser discover")
    }
    XCTAssertEqual(gemsGenres, "18")
    XCTAssertEqual(gemsFloor, 300)
    XCTAssertEqual(gemsRating, 7.2)
    guard case .discover(_, let romanceGenres, let romanceFloor, nil, _) = Mood.romantic.source else {
      return XCTFail("romantic no lleva nota mínima")
    }
    XCTAssertEqual(romanceGenres, "10749")
    XCTAssertEqual(romanceFloor, 200)
  }

  func testPersonSearchDecode() throws {
    let json = #"{"page":1,"results":[{"id":10859,"name":"Kevin Bacon","profile_path":"/x.jpg","known_for_department":"Acting"}]}"#.data(using: .utf8)!
    let r = try TMDBClient.decoder.decode(TMDBPersonsResponse.self, from: json)
    XCTAssertEqual(r.results.first?.name, "Kevin Bacon")
    XCTAssertNil(r.results.first?.job, "job no viene en search/person")
  }

  func testWatchedLogOrderNewestFirst() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = LibraryStore(fileURL: dir)
    let a = MediaItem(id: 1, title: "A", overview: "", posterPath: "", backdropPath: "", rating: 0)
    let b = MediaItem(id: 2, title: "B", overview: "", posterPath: "", backdropPath: "", rating: 0)
    store.set(a, in: .watched, on: true)
    Thread.sleep(forTimeInterval: 0.02)
    store.set(b, in: .watched, on: true)
    XCTAssertEqual(store.watchedLog().map { $0.item.id }, [2, 1])
  }
}
