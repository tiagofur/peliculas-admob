import Foundation

@MainActor
final class SearchLoader: ObservableObject {
  enum Scope: String, CaseIterable, Hashable {
    case all = "Todo"
    case movies = "Películas"
    case series = "Series"
  }

  @Published var query = "" { didSet { if oldValue != query { schedule() } } }
  @Published var scope: Scope = .all { didSet { if oldValue != scope { schedule(immediate: true) } } }
  @Published private(set) var results: [MediaItem] = []
  @Published private(set) var searching = false
  @Published private(set) var failed = false
  @Published private(set) var history: [String] = []
  @Published private(set) var movieGenres: [TMDBGenre] = []
  @Published private(set) var tvGenres: [TMDBGenre] = []

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
      let found: [MediaItem]
      switch scope {
      case .movies: found = try await TMDBClient.search(q, kind: .movie).map { MediaItem(tmdb: $0, kind: .movie) }
      case .series: found = try await TMDBClient.search(q, kind: .tv).map { MediaItem(tmdb: $0, kind: .tv) }
      case .all:
        async let m = TMDBClient.search(q, kind: .movie)
        async let t = TMDBClient.search(q, kind: .tv)
        let (movies, shows) = try await (m, t)
        // Intercala por popularidad aproximada (nota × presencia de póster).
        let all = movies.map { MediaItem(tmdb: $0, kind: .movie) } + shows.map { MediaItem(tmdb: $0, kind: .tv) }
        found = all.sorted { score($0, q) > score($1, q) }
      }
      guard !Task.isCancelled, q == trimmed else { return }
      results = found
      failed = false
      if !found.isEmpty { addHistory(q) }
    } catch {
      guard !Task.isCancelled else { return }
      results = []
      failed = true
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

/// Resultados de "Explorar por género" con paginación infinita.
@MainActor
final class GenreLoader: ObservableObject {
  @Published private(set) var items: [MediaItem] = []
  @Published private(set) var loading = false
  private var page = 0
  private var done = false

  func loadMore(kind: MediaKind, genre: Int) async {
    guard !loading, !done else { return }
    loading = true
    defer { loading = false }
    page += 1
    guard let found = try? await TMDBClient.discover(kind: kind, genreId: genre, year: nil, page: page) else {
      page -= 1
      return
    }
    if found.isEmpty || page >= 10 { done = true }
    let existing = Set(items.map(\.key))
    items += found.map { MediaItem(tmdb: $0, kind: kind) }.filter { !existing.contains($0.key) }
  }
}
