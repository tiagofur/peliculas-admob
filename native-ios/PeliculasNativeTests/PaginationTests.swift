import XCTest
@testable import PeliculasNative

/// Infinite scroll: decodificación paginada y lógica del `PagedListLoader` sin red.
final class PaginationTests: XCTestCase {
  private func pagedJSON(page: Int, totalPages: Int, ids: [Int]) -> Data {
    let results = ids.map {
      #"{"id":\#($0),"title":"Título \#($0)","poster_path":"/p\#($0).jpg","vote_average":7.1}"#
    }.joined(separator: ",")
    return """
    {"page":\(page),"total_pages":\(totalPages),"results":[\(results)]}
    """.data(using: .utf8)!
  }

  private func item(_ id: Int) -> MediaItem {
    MediaItem(id: id, title: "Seed \(id)", overview: "", posterPath: "", backdropPath: "", rating: 0)
  }

  func testPagedMoviesDecodeTotalPages() throws {
    let page = try TMDBClient.decoder.decode(TMDBPagedMovies.self, from: pagedJSON(page: 2, totalPages: 87, ids: [1, 2, 3]))
    XCTAssertEqual(page.page, 2)
    XCTAssertEqual(page.totalPages, 87)
    XCTAssertEqual(page.results.count, 3)
  }

  func testListSourceKindMatchesContent() {
    XCTAssertEqual(MediaListSource.trending(kind: .tv, window: "week").kind, .tv)
    XCTAssertEqual(MediaListSource.topRated(kind: .tv).kind, .tv)
    XCTAssertEqual(MediaListSource.genre(kind: .tv, genreId: 18).kind, .tv)
    XCTAssertEqual(MediaListSource.search(query: "x", kind: .tv).kind, .tv)
    XCTAssertEqual(MediaListSource.nowPlaying.kind, .movie)
    XCTAssertEqual(MediaListSource.upcoming.kind, .movie)
  }

  @MainActor
  func testLoaderSeedsFirstPageAndContinuesFromSecond() async {
    var requestedPages: [Int] = []
    let loader = PagedListLoader(source: .trending(kind: .movie, window: "week"), seed: [item(1)]) { _, page in
      requestedPages.append(page)
      return try TMDBClient.decoder.decode(TMDBPagedMovies.self, from: self.pagedJSON(page: page, totalPages: 3, ids: [100 + page]))
    }
    await loader.loadMore()
    XCTAssertEqual(requestedPages, [2])
    XCTAssertEqual(loader.items.map(\.id), [1, 102])
    XCTAssertFalse(loader.done)

    await loader.loadMore()
    XCTAssertEqual(requestedPages, [2, 3])
    XCTAssertEqual(loader.items.map(\.id), [1, 102, 103])
    XCTAssertTrue(loader.done, "totalPages 3 alcanzado: no debe pedir más")

    await loader.loadMore()
    XCTAssertEqual(requestedPages, [2, 3], "done corta el load-more")
  }

  @MainActor
  func testLoaderDedupesRepeatedTitles() async {
    let loader = PagedListLoader(source: .nowPlaying, seed: [item(1)]) { _, _ in
      try TMDBClient.decoder.decode(TMDBPagedMovies.self, from: self.pagedJSON(page: 2, totalPages: 99, ids: [1, 2]))
    }
    await loader.loadMore()
    XCTAssertEqual(loader.items.map(\.id), [1, 2])
    XCTAssertFalse(loader.loadMoreFailed)
  }

  @MainActor
  func testLoaderStopsAtMaxPages() async {
    var calls = 0
    let loader = PagedListLoader(source: .topRated(kind: .movie), maxPages: 3) { _, _ in
      calls += 1
      return try TMDBClient.decoder.decode(TMDBPagedMovies.self, from: self.pagedJSON(page: calls, totalPages: 500, ids: [calls]))
    }
    for _ in 0..<5 { await loader.loadMore() }
    XCTAssertEqual(calls, 3)
    XCTAssertTrue(loader.done)
  }

  @MainActor
  func testFirstPageFailureSetsFailedAndRetriesSamePage() async {
    var calls = 0
    let loader = PagedListLoader(source: .nowPlaying) { _, _ in
      calls += 1
      if calls == 1 { throw URLError(.notConnectedToInternet) }
      return try TMDBClient.decoder.decode(TMDBPagedMovies.self, from: self.pagedJSON(page: 1, totalPages: 1, ids: [7]))
    }
    await loader.loadMore()
    XCTAssertTrue(loader.failed)
    XCTAssertTrue(loader.items.isEmpty)
    XCTAssertEqual(calls, 1)

    await loader.loadMore()
    XCTAssertFalse(loader.failed)
    XCTAssertEqual(loader.items.map(\.id), [7])
    XCTAssertTrue(loader.done)
  }

  @MainActor
  func testLoadMoreFailureKeepsItemsAndOffersRetry() async {
    var calls = 0
    let loader = PagedListLoader(source: .nowPlaying, seed: [item(1)], maxPages: 2) { _, page in
      calls += 1
      if calls == 1 { throw URLError(.notConnectedToInternet) }
      return try TMDBClient.decoder.decode(TMDBPagedMovies.self, from: self.pagedJSON(page: page, totalPages: 9, ids: [100 + page]))
    }
    await loader.loadMore()
    XCTAssertTrue(loader.loadMoreFailed)
    XCTAssertEqual(loader.items.map(\.id), [1])
    XCTAssertFalse(loader.failed, "con contenido no se muestra el error de pantalla completa")
    XCTAssertFalse(loader.done)

    await loader.loadMore()
    XCTAssertFalse(loader.loadMoreFailed)
    XCTAssertEqual(loader.items.map(\.id), [1, 102], "reintenta la misma página")
    XCTAssertTrue(loader.done, "maxPages 2 alcanzado en la segunda carga")
  }

  @MainActor
  func testEmptyResultsMarkDoneWithoutError() async {
    let loader = PagedListLoader(source: .upcoming) { _, _ in
      try TMDBClient.decoder.decode(TMDBPagedMovies.self, from: self.pagedJSON(page: 1, totalPages: 40, ids: []))
    }
    await loader.loadMore()
    XCTAssertTrue(loader.done)
    XCTAssertTrue(loader.items.isEmpty)
    XCTAssertFalse(loader.failed)
  }
}
