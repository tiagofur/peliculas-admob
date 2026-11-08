import XCTest
@testable import PeliculasNative

/// Sync con el backend Go: formato de las ops y reglas last-write-wins.
@MainActor
final class SyncTests: XCTestCase {
  private func store() -> LibraryStore { LibraryStore(persistent: false) }
  private let movie = MediaItem(id: 550, title: "El club de la pelea", overview: "", posterPath: "/p.jpg", backdropPath: "", rating: 8.4, kind: .movie, year: "1999")
  private let show = MediaItem(id: 550, title: "Otra cosa", overview: "", posterPath: "/s.jpg", backdropPath: "", rating: 7, kind: .tv, year: "2020")

  func testMovieAndShowWithSameIdDoNotCollide() {
    let s = store()
    s.toggle(movie, in: .favorite)
    XCTAssertTrue(s.isFavorite(movie))
    XCTAssertFalse(s.isFavorite(show))
  }

  func testOpEncodesBackendShape() throws {
    let op = SyncOp.library(LibraryRow(kind: .watchlist, mediaType: .movie, tmdbId: 550, title: "T", posterPath: "/p.jpg",
                                       year: "1999", updatedAt: Date(timeIntervalSince1970: 0), deleted: false))
    let json = try JSONSerialization.jsonObject(with: APIClient.encoder.encode(op)) as! [String: Any]
    XCTAssertEqual(json["entity"] as? String, "library")
    let data = json["data"] as! [String: Any]
    XCTAssertEqual(data["kind"] as? String, "watchlist")
    XCTAssertEqual(data["media_type"] as? String, "movie")
    XCTAssertEqual(data["tmdb_id"] as? Int, 550)
    XCTAssertEqual(data["poster_path"] as? String, "/p.jpg")
    XCTAssertEqual(data["updated_at"] as? String, "1970-01-01T00:00:00.000Z")
  }

  func testNewerRemoteWinsOlderRemoteLoses() throws {
    let s = store()
    s.toggle(movie, in: .watchlist) // local: ahora, en la watchlist
    let old = SyncPull(cursor: "1", hasMore: false,
                       library: [LibraryRow(kind: .watchlist, mediaType: .movie, tmdbId: 550, title: "T", posterPath: "", year: "",
                                            updatedAt: Date(timeIntervalSinceNow: -3600), deleted: true)],
                       lists: nil, listItems: nil, ratings: nil, episodes: nil)
    s.apply(old)
    XCTAssertTrue(s.isInWatchlist(movie), "un borrado más viejo no pisa el cambio local")

    let newer = SyncPull(cursor: "2", hasMore: false,
                         library: [LibraryRow(kind: .watchlist, mediaType: .movie, tmdbId: 550, title: "T", posterPath: "", year: "",
                                              updatedAt: Date(timeIntervalSinceNow: 60), deleted: true)],
                         lists: nil, listItems: nil, ratings: nil, episodes: nil)
    s.apply(newer)
    XCTAssertFalse(s.isInWatchlist(movie))
  }

  func testPullDecodesServerPayload() throws {
    let json = """
    {"cursor":"778","has_more":false,
     "library":[{"kind":"favorite","media_type":"tv","tmdb_id":1399,"title":"GoT","poster_path":"/g.jpg","year":"2011","updated_at":"2026-11-07T12:00:00.123456789Z","deleted":false}],
     "lists":[{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","name":"Clásicos","description":"","position":0,"updated_at":"2026-11-07T12:00:00Z","deleted":false}],
     "list_items":[],"ratings":[{"media_type":"movie","tmdb_id":550,"score":8.5,"review":"","title":"","poster_path":"","updated_at":"2026-11-07T12:00:00Z","deleted":false}],
     "episodes":[{"tv_id":1399,"season":1,"episode":1,"watched_at":"2026-11-07T12:00:00Z","updated_at":"2026-11-07T12:00:00Z","deleted":false}]}
    """.data(using: .utf8)!
    let page = try APIClient.decoder.decode(SyncPull.self, from: json)
    let s = store()
    s.apply(page)
    XCTAssertTrue(s.contains(MediaKey(kind: .tv, id: 1399), in: .favorite))
    XCTAssertEqual(s.item(for: MediaKey(kind: .tv, id: 1399))?.title, "GoT")
    XCTAssertEqual(s.visibleLists.first?.id, "6f9619ff-8b86-d011-b42d-00cf4fc964ff", "IDs de lista en minúsculas como Postgres")
    XCTAssertEqual(s.rating(for: MediaKey(kind: .movie, id: 550)), 8.5)
    XCTAssertTrue(s.isEpisodeWatched(tvId: 1399, season: 1, episode: 1))
  }

  func testRatingRoundsToHalfPoints() {
    let s = store()
    s.rate(movie, score: 7.3)
    XCTAssertEqual(s.rating(for: movie.key), 7.5)
    s.rate(movie, score: nil)
    XCTAssertNil(s.rating(for: movie.key))
  }

  func testMarkingWatchedRemovesFromWatchlist() {
    let s = store()
    s.set(movie, in: .watchlist, on: true)
    s.set(movie, in: .watched, on: true)
    XCTAssertFalse(s.isInWatchlist(movie))
    XCTAssertTrue(s.isWatched(movie))
  }

  func testListsUseLowercaseIdsAndKeepOrder() {
    let s = store()
    let id = s.createList(named: "  Para ver en pareja ")
    XCTAssertEqual(id, id.lowercased())
    s.toggle(movie, inList: id)
    s.toggle(show, inList: id)
    XCTAssertEqual(s.visibleLists.first?.name, "Para ver en pareja")
    XCTAssertEqual(s.itemsOfList(id).map(\.key), [movie.key, show.key])
    s.deleteList(id)
    XCTAssertTrue(s.visibleLists.isEmpty)
  }

  func testSeasonToggleMarksAndUnmarks() {
    let s = store()
    s.toggleSeason(tvId: 1, season: 1, episodeNumbers: [1, 2, 3])
    XCTAssertEqual(s.seasonWatchedCount(tvId: 1, season: 1), 3)
    s.toggleSeason(tvId: 1, season: 1, episodeNumbers: [1, 2, 3])
    XCTAssertEqual(s.seasonWatchedCount(tvId: 1, season: 1), 0)
  }
}
