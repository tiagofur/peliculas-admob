import Foundation

/// Datos de Inicio desde la caché TMDB del backend. Carga todo en paralelo;
/// si una fila falla, las demás se muestran igual.
@MainActor
final class HomeLoader: ObservableObject {
  @Published private(set) var featured: [MediaItem] = []
  @Published private(set) var trending: [MediaItem] = []
  @Published private(set) var trendingShows: [MediaItem] = []
  @Published private(set) var nowPlaying: [MediaItem] = []
  @Published private(set) var upcoming: [MediaItem] = []
  @Published private(set) var topRated: [MediaItem] = []
  @Published private(set) var personal: [MediaItem] = []
  @Published private(set) var personalTitle: String?
  @Published private(set) var loading = false
  @Published private(set) var failed = false

  var isEmpty: Bool { featured.isEmpty && trending.isEmpty }

  func load() async {
    loading = true
    defer { loading = false }
    async let all = try? TMDBClient.trending(.movie, window: "day")
    async let movies = try? TMDBClient.trending(.movie)
    async let shows = try? TMDBClient.trending(.tv)
    async let cinema = try? TMDBClient.nowPlaying()
    async let soon = try? TMDBClient.upcoming()
    async let rated = try? TMDBClient.topRated(.movie)

    let (a, m, s, c, u, r) = await (all, movies, shows, cinema, soon, rated)
    let dayMovies = (a ?? []).map { MediaItem(tmdb: $0, kind: .movie) }
    let dayShows = (s ?? []).prefix(4).map { MediaItem(tmdb: $0, kind: .tv) }
    // Héroe: mezcla de películas y series del día con fondo disponible.
    let mixed = zip(dayMovies.prefix(4), dayShows).flatMap { [$0, $1] } + dayMovies.dropFirst(4)
    let heroes = mixed.filter { !$0.backdropPath.isEmpty }.prefix(6)
    if !heroes.isEmpty { featured = Array(heroes) }
    if let m, !m.isEmpty { trending = m.map { MediaItem(tmdb: $0, kind: .movie) } }
    if let s, !s.isEmpty { trendingShows = s.map { MediaItem(tmdb: $0, kind: .tv) } }
    if let c, !c.isEmpty { nowPlaying = c.map { MediaItem(tmdb: $0, kind: .movie) } }
    if let u, !u.isEmpty {
      let today = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
      upcoming = u.filter { ($0.releaseDate ?? "") >= today }.map { MediaItem(tmdb: $0, kind: .movie) }
    }
    if let r, !r.isEmpty { topRated = r.map { MediaItem(tmdb: $0, kind: .movie) } }
    failed = isEmpty
  }

  /// "Porque te gustó X": recomendaciones de tu favorito más reciente.
  func loadPersonal(from favorites: [MediaItem]) async {
    guard let seed = favorites.first(where: { !$0.title.isEmpty }) else {
      personal = []; personalTitle = nil
      return
    }
    guard let recs = try? await TMDBClient.recommendations(kind: seed.kind, id: seed.id), !recs.isEmpty else { return }
    personal = recs.prefix(15).map { MediaItem(tmdb: $0, kind: seed.kind) }
    personalTitle = String(localized: "Porque te gustó \(seed.title)")
  }
}
