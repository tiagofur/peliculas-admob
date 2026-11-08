import Foundation
import SwiftUI

@MainActor
final class SearchLoader: ObservableObject {
  enum Scope: String, CaseIterable, Hashable {
    case all, movies, series

    var title: LocalizedStringKey {
      switch self {
      case .all: return "Todo"
      case .movies: return "Películas"
      case .series: return "Series"
      }
    }
  }

  @Published var query = "" { didSet { if oldValue != query { schedule() } } }
  @Published var scope: Scope = .all { didSet { if oldValue != scope { schedule(immediate: true) } } }
  @Published private(set) var results: [MediaItem] = []
  @Published private(set) var searching = false
  @Published private(set) var failed = false
  @Published private(set) var loadingMore = false
  @Published private(set) var history: [String] = []
  @Published private(set) var movieGenres: [TMDBGenre] = []
  @Published private(set) var tvGenres: [TMDBGenre] = []

  /// Infinite scroll de resultados (igual que en Flutter). Tope defensivo de 10 páginas.
  private(set) var done = false
  private var page = 1
  private let maxPages = 10
  private var task: Task<Void, Never>?
  private let historyKey = "peliculas.search.history.v1"

  init() {
    if let raw = UserDefaults.standard.data(forKey: historyKey),
       let saved = try? JSONDecoder().decode([String].self, from: raw) {
      history = saved
    }
  }

  var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

  func loadGenres() async {
    guard movieGenres.isEmpty else { return }
    async let m = try? TMDBClient.genres(kind: .movie)
    async let t = try? TMDBClient.genres(kind: .tv)
    movieGenres = await m ?? []
    tvGenres = await t ?? []
  }

  func submit() {
    schedule(immediate: true)
  }

  private func schedule(immediate: Bool = false) {
    task?.cancel()
    let q = trimmed
    guard q.count >= 2 else {
      results = []
      searching = false
      return
    }
    searching = true
    task = Task {
      if !immediate { try? await Task.sleep(nanoseconds: 350_000_000) }
      guard !Task.isCancelled else { return }
      await run(q)
    }
  }

  private func run(_ q: String) async {
    defer { searching = false }
    do {
      let page1 = try await fetchResults(q, page: 1)
      guard !Task.isCancelled, q == trimmed else { return }
      results = page1.items
      page = 1
      done = page1.items.isEmpty || 1 >= min(maxPages, max(1, page1.totalPages))
      failed = false
      if !page1.items.isEmpty { addHistory(q) }
    } catch {
      guard !Task.isCancelled else { return }
      results = []
      failed = true
      done = false
    }
  }

  private struct PageBatch {
    let items: [MediaItem]
    let totalPages: Int
  }

  /// Busca una página; en "Todo" mezcla películas y series por relevancia aproximada.
  private func fetchResults(_ q: String, page: Int) async throws -> PageBatch {
    switch scope {
    case .movies:
      let r = try await TMDBClient.searchPage(q, kind: .movie, page: page)
      return PageBatch(items: r.results.map { MediaItem(tmdb: $0, kind: .movie) }, totalPages: r.totalPages)
    case .series:
      let r = try await TMDBClient.searchPage(q, kind: .tv, page: page)
      return PageBatch(items: r.results.map { MediaItem(tmdb: $0, kind: .tv) }, totalPages: r.totalPages)
    case .all:
      async let m = TMDBClient.searchPage(q, kind: .movie, page: page)
      async let t = TMDBClient.searchPage(q, kind: .tv, page: page)
      let (movies, shows) = try await (m, t)
      // Intercala por popularidad aproximada (nota × presencia de póster).
      let all = movies.results.map { MediaItem(tmdb: $0, kind: .movie) } + shows.results.map { MediaItem(tmdb: $0, kind: .tv) }
      return PageBatch(items: all.sorted { score($0, q) > score($1, q) }, totalPages: min(movies.totalPages, shows.totalPages))
    }
  }

  /// Siguiente página para el infinite scroll de resultados. Deduplica y se
  /// detiene al agotar `total_pages` o al llegar al tope defensivo.
  func loadMore() async {
    guard !searching, !loadingMore, !done, !results.isEmpty, !trimmed.isEmpty else { return }
    loadingMore = true
    defer { loadingMore = false }
    let q = trimmed
    let next = page + 1
    do {
      let batch = try await fetchResults(q, page: next)
      guard !Task.isCancelled, q == trimmed else { return }
      page = next
      done = batch.items.isEmpty || next >= min(maxPages, max(1, batch.totalPages))
      let existing = Set(results.map(\.key))
      results += batch.items.filter { !existing.contains($0.key) }
    } catch {
      // Silencioso: al volver a aparecer el pie reintenta la misma página.
    }
  }

  private func score(_ item: MediaItem, _ q: String) -> Double {
    var s = item.rating
    if item.posterPath.isEmpty { s -= 5 }
    if item.title.localizedCaseInsensitiveCompare(q) == .orderedSame { s += 10 }
    else if item.title.lowercased().hasPrefix(q.lowercased()) { s += 3 }
    return s
  }

  func clearHistory() {
    history = []
    UserDefaults.standard.removeObject(forKey: historyKey)
  }

  private func addHistory(_ q: String) {
    history.removeAll { $0.caseInsensitiveCompare(q) == .orderedSame }
    history.insert(q, at: 0)
    history = Array(history.prefix(8))
    if let encoded = try? JSONEncoder().encode(history) {
      UserDefaults.standard.set(encoded, forKey: historyKey)
    }
  }
}

// "Explorar por género" usa el `PagedListLoader` compartido (con infinite scroll).
