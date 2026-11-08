import Foundation

/// Episodio en una serie, ordenable (T1E10 < T2E1).
struct EpisodeRef: Hashable, Comparable, Sendable {
  let season: Int
  let episode: Int

  static func < (a: EpisodeRef, b: EpisodeRef) -> Bool {
    (a.season, a.episode) < (b.season, b.episode)
  }

  var label: String { String(localized: "T\(season) · E\(episode)") }
}

/// Lógica pura de "qué toca ver ahora" (testeable sin red).
enum UpNextCalculator {
  /// Primer episodio ya emitido que no has visto, en orden.
  /// `seasons`: (número, nº de episodios). La temporada 0 (especiales) no cuenta.
  static func next(seasons: [(number: Int, count: Int)], lastAired: EpisodeRef?, watched: Set<EpisodeRef>) -> EpisodeRef? {
    guard let lastAired else { return nil }
    for s in seasons.filter({ $0.number > 0 }).sorted(by: { $0.number < $1.number }) {
      guard s.count > 0 else { continue }
      for e in 1...s.count {
        let ref = EpisodeRef(season: s.number, episode: e)
        if ref > lastAired { return nil }
        if !watched.contains(ref) { return ref }
      }
    }
    return nil
  }

  /// Episodios emitidos hasta `lastAired` (para la barra de progreso).
  static func airedCount(seasons: [(number: Int, count: Int)], lastAired: EpisodeRef?) -> Int {
    guard let lastAired else { return 0 }
    return seasons.filter { $0.number > 0 && $0.number <= lastAired.season }
      .reduce(0) { $0 + ($1.number == lastAired.season ? min($1.count, lastAired.episode) : $1.count) }
  }
}

struct UpNextEntry: Identifiable, Hashable {
  let show: MediaItem
  let next: EpisodeRef
  let episodeTitle: String
  let stillPath: String
  let overview: String
  let runtime: Int?
  let watchedCount: Int
  let airedCount: Int
  let started: Bool

  var id: Int { show.id }
  var progress: Double { airedCount > 0 ? Double(watchedCount) / Double(airedCount) : 0 }
  var remaining: Int { max(0, airedCount - watchedCount) }
}

struct UpcomingEntry: Identifiable, Hashable {
  let show: MediaItem
  let episode: EpisodeRef
  let name: String
  let airDate: Date

  var id: Int { show.id }
}

/// Pestaña "Siguiente": el próximo episodio de cada serie que sigues y los
/// estrenos que vienen. Todo sale de la caché TMDB del backend.
@MainActor
final class UpNextStore: ObservableObject {
  @Published private(set) var entries: [UpNextEntry] = []
  @Published private(set) var upcoming: [UpcomingEntry] = []
  @Published private(set) var loading = false
  @Published private(set) var loadedOnce = false

  private var shows: [Int: TMDBFullDetail] = [:]

  func load(library: LibraryStore, force: Bool = false) async {
    let followed = library.followedShows
    guard !followed.isEmpty else {
      entries = []; upcoming = []; loadedOnce = true
      return
    }
    loading = true
    defer { loading = false; loadedOnce = true }

    let missing = followed.map(\.id).filter { force || shows[$0] == nil }
    await withTaskGroup(of: (Int, TMDBFullDetail?).self) { group in
      for id in missing.prefix(60) {
        group.addTask { (id, try? await TMDBClient.show(id: id)) }
      }
      for await (id, detail) in group { if let detail { shows[id] = detail } }
    }

    var newEntries: [UpNextEntry] = []
    var newUpcoming: [UpcomingEntry] = []
    for base in followed {
      guard let d = shows[base.id] else { continue }
      let show = base.merged(with: MediaItem(detail: d, kind: .tv))
      library.remember(show)
      let seasons = (d.seasons ?? []).map { (number: $0.seasonNumber, count: $0.episodeCount ?? 0) }
      let last = d.lastEpisodeToAir.map { EpisodeRef(season: $0.seasonNumber, episode: $0.episodeNumber) }
      let watched = Set(library.watchedEpisodes(tvId: d.id).map { EpisodeRef(season: $0.season, episode: $0.episode) })
      let aired = UpNextCalculator.airedCount(seasons: seasons, lastAired: last)
      if let next = UpNextCalculator.next(seasons: seasons, lastAired: last, watched: watched) {
        newEntries.append(UpNextEntry(show: show, next: next, episodeTitle: "", stillPath: "", overview: "",
                                      runtime: nil, watchedCount: min(watched.count, aired), airedCount: aired,
                                      started: !watched.isEmpty))
      }
      if let n = d.nextEpisodeToAir, let date = n.airDate.flatMap(Self.parseDay), date >= Calendar.current.startOfDay(for: Date()) {
        newUpcoming.append(UpcomingEntry(show: show, episode: EpisodeRef(season: n.seasonNumber, episode: n.episodeNumber),
                                         name: n.name ?? "", airDate: date))
      }
    }

    // Primero lo que ya empezaste (más avanzado arriba), luego lo pendiente de empezar.
    newEntries.sort { a, b in
      if a.started != b.started { return a.started }
      return a.progress > b.progress
    }
    entries = newEntries
    upcoming = newUpcoming.sorted { $0.airDate < $1.airDate }
    await enrich()
  }

  /// Título e imagen de cada siguiente episodio (una temporada por serie).
  private func enrich() async {
    let current = entries
    let details = await withTaskGroup(of: (Int, TMDBEpisode?).self) { group -> [Int: TMDBEpisode] in
      for e in current.prefix(30) {
        group.addTask {
          let eps = try? await TMDBClient.season(tvId: e.show.id, season: e.next.season)
          return (e.show.id, eps?.first { $0.episodeNumber == e.next.episode })
        }
      }
      var out: [Int: TMDBEpisode] = [:]
      for await (id, ep) in group { if let ep { out[id] = ep } }
      return out
    }
    entries = entries.map { e in
      guard let ep = details[e.show.id] else { return e }
      return UpNextEntry(show: e.show, next: e.next, episodeTitle: ep.name ?? "", stillPath: ep.stillPath ?? "",
                         overview: ep.overview ?? "", runtime: ep.runtime, watchedCount: e.watchedCount,
                         airedCount: e.airedCount, started: e.started)
    }
  }

  /// Marca visto y pasa al siguiente sin recargar todo.
  func markWatched(_ entry: UpNextEntry, library: LibraryStore) async {
    library.setEpisode(tvId: entry.show.id, season: entry.next.season, episode: entry.next.episode, watched: true)
    Haptics.success()
    await load(library: library)
  }

  nonisolated static func parseDay(_ s: String) -> Date? {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: s)
  }
}
