import XCTest
@testable import PeliculasNative

/// Quick wins: reseñas personales, dirección/creador y orden de explorar.
@MainActor
final class QuickWinsTests: XCTestCase {
  private var tempDir: URL!
  private var store: LibraryStore!

  override func setUp() async throws {
    tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    store = LibraryStore(fileURL: tempDir.appendingPathComponent("q.json"))
  }

  override func tearDown() async throws {
    try? FileManager.default.removeItem(at: tempDir)
  }

  private var fightClub: MediaItem {
    MediaItem(id: 550, title: "El club de la pelea", overview: "", posterPath: "/p.jpg", backdropPath: "", rating: 8.4, kind: .movie, year: "1999")
  }

  // MARK: Reseñas

  func testReviewPersistsAndSyncs() throws {
    store.setReview(fightClub, "  Una obra maestra sobre dejar de fingir.  ")
    XCTAssertEqual(store.review(for: fightClub.key), "Una obra maestra sobre dejar de fingir.", "recorta espacios")
    XCTAssertEqual(store.pendingChanges, 1, "la reseña viaja por el sync existente")
    let stamp = try XCTUnwrap(store.ratings[fightClub.key])
    XCTAssertEqual(stamp.review, "Una obra maestra sobre dejar de fingir.")
    XCTAssertEqual(stamp.score, 0, "reseña sin nota: score 0")
    XCTAssertFalse(stamp.deleted)
  }

  func testRateKeepsReview() {
    store.rate(fightClub, score: 9)
    store.setReview(fightClub, "Imposible verla una sola vez.")
    store.rate(fightClub, score: nil) // quita la nota
    XCTAssertEqual(store.review(for: fightClub.key), "Imposible verla una sola vez.", "la reseña sobrevive sin nota")
    XCTAssertNil(store.rating(for: fightClub.key))
    let stamp = try! XCTUnwrap(store.ratings[fightClub.key])
    XCTAssertFalse(stamp.deleted, "con reseña no se marca borrada")
    XCTAssertEqual(stamp.score, 0)
  }

  func testEmptyReviewDeletesWhenNoScore() {
    store.setReview(fightClub, "x")
    store.setReview(fightClub, "   ")
    let stamp = try! XCTUnwrap(store.ratings[fightClub.key])
    XCTAssertTrue(stamp.deleted, "reseña vacía y sin nota ⇒ fila borrada")
    XCTAssertNil(store.review(for: fightClub.key))
  }

  // MARK: Dirección / creador

  private func detailJSON(createdBy: String, crew: String) -> Data {
    """
    {"id":1,"created_by":\(createdBy),"credits":{"cast":[],"crew":\(crew)}}
    """.data(using: .utf8)!
  }

  func testMovieShowsDirectorsDeduped() throws {
    let d = try TMDBClient.decoder.decode(TMDBFullDetail.self, from: detailJSON(
      createdBy: "[]",
      crew: #"[{"id":1,"name":"Denis Villeneuve","job":"Director"},{"id":1,"name":"Denis Villeneuve","job":"Director"},{"id":2,"name":"Jon Spaihts","job":"Screenplay"}]"#
    ))
    let headline = DetailLoader.creditHeadline(for: d, kind: .movie)
    XCTAssertEqual(headline?.label, String(localized: "Dirección"))
    XCTAssertEqual(headline?.names, "Denis Villeneuve", "dedupe del mismo director repetido en el crew")
  }

  func testShowShowsCreatorsNotCrew() throws {
    let d = try TMDBClient.decoder.decode(TMDBFullDetail.self, from: detailJSON(
      createdBy: #"[{"id":1,"name":"David Benioff"},{"id":2,"name":"D. B. Weiss"}]"#,
      crew: #"[{"id":3,"name":"Alguien","job":"Director"}]"#
    ))
    let headline = DetailLoader.creditHeadline(for: d, kind: .tv)
    XCTAssertEqual(headline?.label, String(localized: "Creado por"))
    XCTAssertEqual(headline?.names, "David Benioff, D. B. Weiss")
  }

  func testNoCreditsNoHeadline() throws {
    let d = try TMDBClient.decoder.decode(TMDBFullDetail.self, from: detailJSON(createdBy: "[]", crew: "[]"))
    XCTAssertNil(DetailLoader.creditHeadline(for: d, kind: .movie))
    XCTAssertNil(DetailLoader.creditHeadline(for: d, kind: .tv))
  }

  // MARK: Orden de explorar

  func testDiscoverSortDatesDifferByKind() {
    XCTAssertEqual(DiscoverSort.newest.sortBy(.movie), "primary_release_date.desc")
    XCTAssertEqual(DiscoverSort.newest.sortBy(.tv), "first_air_date.desc")
    XCTAssertEqual(DiscoverSort.rating.sortBy(.movie), DiscoverSort.rating.sortBy(.tv))
    XCTAssertEqual(DiscoverSort.rating.voteFloor, 150)
    XCTAssertEqual(DiscoverSort.newest.voteFloor, 10)
  }

  func testGenreSourceCarriesFilters() {
    let plain = MediaListSource.genre(kind: .movie, genreId: 878)
    let filtered = MediaListSource.genre(kind: .movie, genreId: 878, year: 2024, sort: .rating)
    XCTAssertNotEqual(plain, filtered, "el filtro debe reconstruir la lista (.id)")
    XCTAssertEqual(filtered.kind, .movie)
  }
}
