import Foundation

@MainActor
final class DetailLoader: ObservableObject {
  @Published private(set) var item: MediaItem?
  @Published private(set) var detail: TMDBFullDetail?
  @Published private(set) var trailerKey: String?
  @Published private(set) var cast: [CastItem] = []
  @Published private(set) var similar: [MediaItem] = []
  @Published private(set) var providers: [TMDBProvider] = []
  @Published private(set) var seasons: [TMDBSeasonSummary] = []
  @Published private(set) var episodes: [EpisodeItem] = []
  @Published private(set) var loadingEpisodes = false
  @Published private(set) var failed = false
  @Published var selectedSeason = 1

  private var loadedFor: MediaKey?

  func load(_ base: MediaItem) async {
    guard loadedFor != base.key else { return }
    loadedFor = base.key
    item = base
    failed = false
    do {
      let d = try await TMDBClient.detail(kind: base.kind, id: base.id)
      detail = d
      item = base.merged(with: MediaItem(detail: d, kind: base.kind))
      cast = (d.credits?.cast ?? []).prefix(15).map(CastItem.init(person:))
      // `recommendations` de TMDB es mucho más fiable que `similar`.
      let recs = d.recommendations?.results ?? []
      similar = (recs.isEmpty ? (d.similar?.results ?? []) : recs)
        .filter { $0.posterPath != nil }
        .prefix(15).map { MediaItem(tmdb: $0, kind: base.kind) }
      providers = Array(TMDBClient.providers(from: d.watchProviders).providers.prefix(10))
      if base.kind == .tv {
        seasons = (d.seasons ?? []).filter { $0.seasonNumber > 0 && ($0.episodeCount ?? 0) > 0 }
        selectedSeason = defaultSeason(d)
        await loadEpisodes()
      }
      trailerKey = await TMDBClient.trailerKey(from: d.videos, kind: base.kind, id: base.id)
    } catch {
      failed = detail == nil
      loadedFor = nil
    }
  }

  func loadEpisodes() async {
    guard let item, item.kind == .tv else { return }
    loadingEpisodes = true
    defer { loadingEpisodes = false }
    let season = selectedSeason
    do {
      let eps = try await TMDBClient.season(tvId: item.id, season: season)
      guard season == selectedSeason else { return }
      episodes = eps.map(EpisodeItem.init(tmdb:))
    } catch {
      // Falló la carga: no dejar colgados los episodios de la temporada anterior.
      guard season == selectedSeason else { return }
      episodes = []
    }
  }

  /// Abre en la última temporada emitida que tenga algo.
  private func defaultSeason(_ d: TMDBFullDetail) -> Int {
    seasons.first?.seasonNumber ?? 1
  }

  var meta: [String] {
    guard let d = detail, let item else { return [] }
    var parts: [String] = []
    if !item.year.isEmpty { parts.append(item.year) }
    if item.kind == .movie, let r = d.runtime, r > 0 {
      parts.append(r >= 60 ? String(localized: "\(r / 60) h \(r % 60) min") : String(localized: "\(r) min"))
    }
    if item.kind == .tv, let s = d.numberOfSeasons, s > 0 {
      parts.append(String(localized: "\(s) temporadas"))
    }
    if let g = d.genres?.prefix(2).map(\.name), !g.isEmpty { parts.append(g.joined(separator: ", ")) }
    return parts
  }

  var statusText: String? {
    switch detail?.status {
    case "Returning Series": return String(localized: "En emisión")
    case "Ended": return String(localized: "Finalizada")
    case "Canceled": return String(localized: "Cancelada")
    case "In Production": return String(localized: "En producción")
    case "Released": return nil
    case "Post Production", "Planned": return String(localized: "Próximamente")
    default: return nil
    }
  }

  /// "Dirección" (películas, del `crew`) o "Creado por" (series, `created_by`).
  var creditHeadline: (label: String, names: String)? {
    guard let d = detail, let kind = item?.kind else { return nil }
    return Self.creditHeadline(for: d, kind: kind)
  }

  static func creditHeadline(for d: TMDBFullDetail, kind: MediaKind) -> (label: String, names: String)? {
    if kind == .tv {
      let creators = (d.createdBy ?? []).compactMap(\.name).filter { !$0.isEmpty }.prefix(2)
      guard !creators.isEmpty else { return nil }
      return (String(localized: "Creado por"), creators.joined(separator: ", "))
    }
    var seen = Set<String>()
    let directors = (d.credits?.crew ?? []).filter { $0.job == "Director" }
      .compactMap(\.name).filter { !$0.isEmpty && seen.insert($0).inserted }
      .prefix(2)
    guard !directors.isEmpty else { return nil }
    return (String(localized: "Dirección"), directors.joined(separator: ", "))
  }
}

struct CastItem: Identifiable, Hashable {
  let id: Int
  let name: String
  let character: String
  let profilePath: String

  init(person: TMDBPerson) {
    id = person.id
    name = person.name ?? "—"
    character = person.character ?? ""
    profilePath = person.profilePath ?? ""
  }
}

struct EpisodeItem: Identifiable, Hashable {
  let id: Int
  let number: Int
  let title: String
  let overview: String
  let stillPath: String
  let runtime: Int?
  let airDate: String

  init(tmdb: TMDBEpisode) {
    id = tmdb.id
    number = tmdb.episodeNumber
    title = tmdb.name ?? String(localized: "Episodio \(tmdb.episodeNumber)")
    overview = tmdb.overview ?? ""
    stillPath = tmdb.stillPath ?? ""
    runtime = tmdb.runtime
    airDate = tmdb.airDate ?? ""
  }

  var hasAired: Bool {
    guard let d = UpNextStore.parseDay(airDate) else { return false }
    return d <= Date()
  }
}
