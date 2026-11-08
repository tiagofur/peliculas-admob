import Combine
import Foundation

/// Biblioteca local-first: favoritos, watchlist, vistas, notas, listas propias
/// y episodios vistos. Funciona sin cuenta; con sesión se sincroniza con el
/// backend Go (last-write-wins por fila, borrados como tombstones).
///
/// Cada cambio guarda su hora (`updatedAt`) y deja una op en la cola. La cola
/// sube unos segundos después, al abrir la app y al volver a primer plano.
@MainActor
final class LibraryStore: ObservableObject {
  // Estado sincronizado
  @Published private(set) var marks: [LibraryKind: [MediaKey: Stamp]] = [:]
  @Published private(set) var ratings: [MediaKey: RatingStamp] = [:]
  @Published private(set) var lists: [String: ListStamp] = [:]
  @Published private(set) var listItems: [String: ListItemStamp] = [:]
  @Published private(set) var episodes: [String: EpisodeStamp] = [:]
  // Solo en este dispositivo
  @Published private(set) var recent: [MediaKey] = []
  @Published private(set) var syncing = false
  @Published private(set) var lastSync: Date?
  @Published private(set) var lastSyncError: String?

  private var items: [MediaKey: MediaItem] = [:]
  private var outbox: [SyncOp] = []
  private var cursor: String?
  private var saveTask: Task<Void, Never>?
  private var syncTask: Task<Void, Never>?
  private let fileURL: URL
  /// `false` en tests: sin red ni disco.
  private let persistent: Bool

  init(fileURL: URL? = nil, persistent: Bool = true) {
    self.persistent = persistent
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    self.fileURL = fileURL ?? dir.appendingPathComponent("library.v2.json")
    if persistent {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      load()
      migrateV1IfNeeded()
    }
  }

  // MARK: Lectura

  func item(for key: MediaKey) -> MediaItem? { items[key] }

  func contains(_ key: MediaKey, in kind: LibraryKind) -> Bool {
    marks[kind]?[key]?.deleted == false
  }

  func isFavorite(_ item: MediaItem) -> Bool { contains(item.key, in: .favorite) }
  func isInWatchlist(_ item: MediaItem) -> Bool { contains(item.key, in: .watchlist) }
  func isWatched(_ item: MediaItem) -> Bool { contains(item.key, in: .watched) }

  /// Títulos de una sección, lo último añadido primero.
  func items(in kind: LibraryKind) -> [MediaItem] {
    (marks[kind] ?? [:])
      .filter { !$0.value.deleted }
      .sorted { $0.value.updatedAt > $1.value.updatedAt }
      .compactMap { items[$0.key] }
  }

  func count(_ kind: LibraryKind) -> Int { (marks[kind] ?? [:]).values.filter { !$0.deleted }.count }

  /// Reseña personal de un título (`nil` si no hay texto).
  func review(for key: MediaKey) -> String? {
    guard ratings[key]?.deleted != true else { return nil }
    let text = ratings[key]?.review ?? ""
    return text.isEmpty ? nil : text
  }

  func rating(for key: MediaKey) -> Double? {
    guard let r = ratings[key], !r.deleted, r.score > 0 else { return nil }
    return r.score
  }

  /// Lo visto ordenado de más a menos reciente (para el historial).
  func watchedLog() -> [(item: MediaItem, date: Date)] {
    (marks[.watched] ?? [:]).filter { !$0.value.deleted }
      .sorted { $0.value.updatedAt > $1.value.updatedAt }
      .compactMap { key, mark in item(for: key).map { ($0, mark.updatedAt) } }
  }

  /// Estadísticas locales (actividad, épocas, notas) para la pantalla de Stats.
  var stats: LibraryStats {
    LibraryStats.build(watched: marks[.watched] ?? [:], ratings: ratings,
                       episodeCount: watchedEpisodeCount, items: items)
  }

  func ratedItems() -> [MediaItem] {
    ratings.filter { !$0.value.deleted }
      .sorted { $0.value.updatedAt > $1.value.updatedAt }
      .compactMap { items[$0.key] }
  }

  var ratedCount: Int { ratings.values.filter { !$0.deleted }.count }

  func recentItems() -> [MediaItem] { recent.compactMap { items[$0] } }

  /// Listas visibles, en su orden.
  var visibleLists: [CustomMediaList] {
    lists.values.filter { !$0.deleted }
      .sorted { ($0.position, $0.updatedAt) < ($1.position, $1.updatedAt) }
      .map { list in
        CustomMediaList(id: list.id, name: list.name, items: itemsOfList(list.id))
      }
  }

  func itemsOfList(_ listId: String) -> [MediaItem] {
    listItems.values
      .filter { $0.listId == listId && !$0.deleted }
      .sorted { ($0.position, $0.updatedAt) < ($1.position, $1.updatedAt) }
      .compactMap { items[$0.key] }
  }

  func list(_ id: String, contains key: MediaKey) -> Bool {
    listItems[Self.listItemKey(id, key)]?.deleted == false
  }

  // Episodios

  func isEpisodeWatched(tvId: Int, season: Int, episode: Int) -> Bool {
    episodes[Self.episodeKey(tvId, season, episode)]?.deleted == false
  }

  func watchedEpisodes(tvId: Int) -> [EpisodeStamp] {
    episodes.values.filter { $0.tvId == tvId && !$0.deleted }
  }

  func seasonWatchedCount(tvId: Int, season: Int) -> Int {
    episodes.values.filter { $0.tvId == tvId && $0.season == season && !$0.deleted }.count
  }

  var watchedEpisodeCount: Int { episodes.values.filter { !$0.deleted }.count }

  /// Series que sigues: en tu biblioteca o con algún episodio visto.
  var followedShows: [MediaItem] {
    var keys = Set<MediaKey>()
    for kind in [LibraryKind.watchlist, .favorite] {
      for (key, stamp) in marks[kind] ?? [:] where key.kind == .tv && !stamp.deleted { keys.insert(key) }
    }
    for ep in episodes.values where !ep.deleted { keys.insert(MediaKey(kind: .tv, id: ep.tvId)) }
    return keys.compactMap { items[$0] ?? MediaItem(key: $0, title: "", posterPath: "", year: "") }
  }

  // MARK: Cambios

  func toggle(_ item: MediaItem, in kind: LibraryKind) {
    set(item, in: kind, on: !contains(item.key, in: kind))
  }

  func set(_ item: MediaItem, in kind: LibraryKind, on: Bool) {
    remember(item)
    let now = Date()
    marks[kind, default: [:]][item.key] = Stamp(updatedAt: now, deleted: !on)
    enqueue(.library(LibraryRow(kind: kind, mediaType: item.kind, tmdbId: item.id, title: item.title,
                                posterPath: item.posterPath, year: item.year, updatedAt: now, deleted: !on)))
    // Marcar vista quita de la watchlist (patrón de Apple TV y Letterboxd).
    if kind == .watched, on, contains(item.key, in: .watchlist) {
      set(item, in: .watchlist, on: false)
    }
    Haptics.toggle(on)
  }

  /// Nota 1–10 en pasos de 0.5. `nil` la borra (si hay reseña escrita, esta se conserva).
  func rate(_ item: MediaItem, score: Double?) {
    remember(item)
    let now = Date()
    let value = score.map { min(10, max(1, ($0 * 2).rounded() / 2)) }
    let previous = ratings[item.key]
    let review = previous?.review ?? ""
    let deleted = value == nil && review.isEmpty
    ratings[item.key] = RatingStamp(score: value ?? 0, review: review,
                                    updatedAt: now, deleted: deleted)
    enqueue(.rating(RatingRow(mediaType: item.kind, tmdbId: item.id, score: value ?? 0,
                              review: review, title: item.title,
                              posterPath: item.posterPath, updatedAt: now, deleted: deleted)))
    Haptics.selection()
  }

  /// Reseña personal (viaja en el sync junto a la nota). Vacía la borra si
  /// tampoco hay nota.
  func setReview(_ item: MediaItem, _ text: String) {
    remember(item)
    let now = Date()
    let review = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let previous = ratings[item.key]
    let score = previous?.score ?? 0
    let deleted = review.isEmpty && score == 0
    ratings[item.key] = RatingStamp(score: score, review: review, updatedAt: now, deleted: deleted)
    enqueue(.rating(RatingRow(mediaType: item.kind, tmdbId: item.id, score: score,
                              review: review, title: item.title,
                              posterPath: item.posterPath, updatedAt: now, deleted: deleted)))
    Haptics.selection()
  }

  @discardableResult
  func createList(named name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let id = UUID().uuidString.lowercased()
    let now = Date()
    let position = (lists.values.map(\.position).max() ?? -1) + 1
    lists[id] = ListStamp(id: id, name: trimmed, position: position, updatedAt: now, deleted: false)
    enqueue(.list(ListRow(id: id, name: trimmed, description: "", position: position, updatedAt: now, deleted: false)))
    Haptics.success()
    return id
  }

  func renameList(_ id: String, to name: String) {
    guard var list = lists[id] else { return }
    list.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    list.updatedAt = Date()
    lists[id] = list
    enqueue(.list(ListRow(id: id, name: list.name, description: "", position: list.position, updatedAt: list.updatedAt, deleted: false)))
  }

  func deleteList(_ id: String) {
    guard var list = lists[id] else { return }
    list.deleted = true
    list.updatedAt = Date()
    lists[id] = list
    enqueue(.list(ListRow(id: id, name: list.name, description: "", position: list.position, updatedAt: list.updatedAt, deleted: true)))
  }

  func toggle(_ item: MediaItem, inList listId: String) {
    remember(item)
    let k = Self.listItemKey(listId, item.key)
    let on = !(listItems[k]?.deleted == false)
    let now = Date()
    let position = on ? (listItems.values.filter { $0.listId == listId }.map(\.position).max() ?? -1) + 1 : (listItems[k]?.position ?? 0)
    listItems[k] = ListItemStamp(listId: listId, key: item.key, position: position, updatedAt: now, deleted: !on)
    enqueue(.listItem(ListItemRow(listId: listId, mediaType: item.kind, tmdbId: item.id, title: item.title,
                                  posterPath: item.posterPath, year: item.year, position: position,
                                  updatedAt: now, deleted: !on)))
    Haptics.toggle(on)
  }

  func setEpisode(tvId: Int, season: Int, episode: Int, watched: Bool, at date: Date = Date()) {
    let k = Self.episodeKey(tvId, season, episode)
    if isEpisodeWatched(tvId: tvId, season: season, episode: episode) == watched { return }
    episodes[k] = EpisodeStamp(tvId: tvId, season: season, episode: episode, updatedAt: date, deleted: !watched)
    enqueue(.episode(EpisodeRow(tvId: tvId, season: season, episode: episode,
                                watchedAt: watched ? date : nil, updatedAt: date, deleted: !watched)))
  }

  func toggleEpisode(tvId: Int, season: Int, episode: Int) {
    let on = !isEpisodeWatched(tvId: tvId, season: season, episode: episode)
    setEpisode(tvId: tvId, season: season, episode: episode, watched: on)
    Haptics.toggle(on)
  }

  /// Marca o desmarca una temporada entera según su estado actual.
  func toggleSeason(tvId: Int, season: Int, episodeNumbers: [Int]) {
    let allWatched = !episodeNumbers.isEmpty && episodeNumbers.allSatisfy { isEpisodeWatched(tvId: tvId, season: season, episode: $0) }
    let now = Date()
    for n in episodeNumbers { setEpisode(tvId: tvId, season: season, episode: n, watched: !allWatched, at: now) }
    Haptics.toggle(!allWatched)
  }

  func touchRecent(_ item: MediaItem) {
    remember(item)
    recent.removeAll { $0 == item.key }
    recent.insert(item.key, at: 0)
    recent = Array(recent.prefix(15))
    scheduleSave()
  }

  /// Guarda la foto más rica del título (para pintar la biblioteca sin red).
  func remember(_ item: MediaItem) {
    items[item.key] = items[item.key].map { $0.merged(with: item) } ?? item
  }

  // MARK: Sync

  /// Sube la cola y baja lo nuevo. Sin sesión no hace nada.
  func sync() async {
    guard persistent, SessionStore.shared.isSignedIn else { return }
    if let running = syncTask { await running.value; return }
    let task = Task { await runSync() }
    syncTask = task
    await task.value
    syncTask = nil
  }

  /// Primera vez con cuenta: sube todo lo local y baja todo lo del servidor.
  func mergeAfterSignIn() async {
    cursor = nil
    outbox = fullSnapshotOps()
    scheduleSave()
    await sync()
  }

  /// Al cerrar sesión o borrar la cuenta: la biblioteca pertenece a la cuenta.
  func resetForSignOut() {
    marks = [:]; ratings = [:]; lists = [:]; listItems = [:]; episodes = [:]
    outbox = []; cursor = nil; lastSync = nil; lastSyncError = nil
    scheduleSave()
  }

  private func runSync() async {
    syncing = true
    defer { syncing = false }
    do {
      try await pushOutbox()
      var more = true
      var pages = 0
      while more, pages < 50 {
        let data = try await APIClient.authed("GET", "/v1/sync", query: cursor.map { ["cursor": $0] } ?? [:])
        let page = try APIClient.decoder.decode(SyncPull.self, from: data)
        apply(page)
        cursor = page.cursor
        more = page.hasMore
        pages += 1
      }
      lastSync = Date()
      lastSyncError = nil
      scheduleSave()
    } catch let error as APIError where error.code == "invalid_cursor" {
      cursor = nil
      lastSyncError = nil
    } catch {
      lastSyncError = (error as? LocalizedError)?.errorDescription ?? String(localized: "No se pudo sincronizar.")
    }
  }

  private func pushOutbox() async throws {
    while !outbox.isEmpty {
      let batch = Array(outbox.sorted { $0.order < $1.order }.prefix(500))
      let data = try await APIClient.authed("POST", "/v1/sync", body: PushBody(ops: batch))
      let result = try APIClient.decoder.decode(SyncPushResult.self, from: data)
      // applied / stale / invalid: en los tres casos la op ya no debe reintentarse.
      let sent = Set(result.results.map { batch[$0.index].key })
      outbox.removeAll { op in sent.contains(op.key) && batch.contains { $0.key == op.key && $0.updatedAt == op.updatedAt } }
      scheduleSave()
      if result.results.count < batch.count { break }
    }
  }

  /// Aplica una página del servidor: gana el `updated_at` más reciente.
  func apply(_ page: SyncPull) {
    for row in page.library ?? [] {
      let key = MediaKey(kind: row.mediaType, id: row.tmdbId)
      if newer(row.updatedAt, than: marks[row.kind]?[key]?.updatedAt) {
        marks[row.kind, default: [:]][key] = Stamp(updatedAt: row.updatedAt, deleted: row.deleted)
      }
      rememberMinimal(key, title: row.title, poster: row.posterPath, year: row.year)
    }
    for row in page.lists ?? [] {
      let id = row.id.lowercased()
      if newer(row.updatedAt, than: lists[id]?.updatedAt) {
        lists[id] = ListStamp(id: id, name: row.name, position: row.position, updatedAt: row.updatedAt, deleted: row.deleted)
      }
    }
    for row in page.listItems ?? [] {
      let key = MediaKey(kind: row.mediaType, id: row.tmdbId)
      let listId = row.listId.lowercased()
      let k = Self.listItemKey(listId, key)
      if newer(row.updatedAt, than: listItems[k]?.updatedAt) {
        listItems[k] = ListItemStamp(listId: listId, key: key, position: row.position, updatedAt: row.updatedAt, deleted: row.deleted)
      }
      rememberMinimal(key, title: row.title, poster: row.posterPath, year: row.year)
    }
    for row in page.ratings ?? [] {
      let key = MediaKey(kind: row.mediaType, id: row.tmdbId)
      if newer(row.updatedAt, than: ratings[key]?.updatedAt) {
        ratings[key] = RatingStamp(score: row.score, review: row.review, updatedAt: row.updatedAt, deleted: row.deleted)
      }
      rememberMinimal(key, title: row.title, poster: row.posterPath, year: "")
    }
    for row in page.episodes ?? [] {
      let k = Self.episodeKey(row.tvId, row.season, row.episode)
      if newer(row.updatedAt, than: episodes[k]?.updatedAt) {
        episodes[k] = EpisodeStamp(tvId: row.tvId, season: row.season, episode: row.episode, updatedAt: row.updatedAt, deleted: row.deleted)
      }
    }
  }

  private func newer(_ remote: Date, than local: Date?) -> Bool {
    guard let local else { return true }
    return remote >= local
  }

  private func rememberMinimal(_ key: MediaKey, title: String, poster: String, year: String) {
    guard !title.isEmpty || !poster.isEmpty else { return }
    remember(MediaItem(key: key, title: title, posterPath: poster, year: year))
  }

  private func enqueue(_ op: SyncOp) {
    outbox.removeAll { $0.key == op.key }
    outbox.append(op)
    scheduleSave()
    scheduleSync()
  }

  private func scheduleSync() {
    guard persistent else { return }
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: 3_000_000_000)
      await self?.sync()
    }
  }

  private func fullSnapshotOps() -> [SyncOp] {
    var ops: [SyncOp] = []
    for (id, l) in lists {
      ops.append(.list(ListRow(id: id, name: l.name, description: "", position: l.position, updatedAt: l.updatedAt, deleted: l.deleted)))
    }
    for (kind, dict) in marks {
      for (key, s) in dict {
        let it = items[key]
        ops.append(.library(LibraryRow(kind: kind, mediaType: key.kind, tmdbId: key.id, title: it?.title ?? "",
                                       posterPath: it?.posterPath ?? "", year: it?.year ?? "", updatedAt: s.updatedAt, deleted: s.deleted)))
      }
    }
    for (key, r) in ratings {
      let it = items[key]
      ops.append(.rating(RatingRow(mediaType: key.kind, tmdbId: key.id, score: r.deleted ? 0 : r.score, review: r.review,
                                   title: it?.title ?? "", posterPath: it?.posterPath ?? "", updatedAt: r.updatedAt, deleted: r.deleted)))
    }
    for li in listItems.values {
      let it = items[li.key]
      ops.append(.listItem(ListItemRow(listId: li.listId, mediaType: li.key.kind, tmdbId: li.key.id, title: it?.title ?? "",
                                       posterPath: it?.posterPath ?? "", year: it?.year ?? "", position: li.position,
                                       updatedAt: li.updatedAt, deleted: li.deleted)))
    }
    for e in episodes.values {
      ops.append(.episode(EpisodeRow(tvId: e.tvId, season: e.season, episode: e.episode,
                                     watchedAt: e.deleted ? nil : e.updatedAt, updatedAt: e.updatedAt, deleted: e.deleted)))
    }
    return ops
  }

  var pendingChanges: Int { outbox.count }

  // MARK: Disco

  private func scheduleSave() {
    guard persistent else { return }
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 400_000_000)
      guard !Task.isCancelled else { return }
      self?.saveNow()
    }
  }

  func saveNow() {
    guard persistent else { return }
    let snapshot = Snapshot(marks: marks.mapValues { $0.mapKeys(\.description) }, ratings: ratings.mapKeys(\.description),
                            lists: lists, listItems: listItems, episodes: episodes,
                            recent: recent.map(\.description), items: items.mapKeys(\.description),
                            outbox: outbox, cursor: cursor, lastSync: lastSync)
    if let data = try? APIClient.encoder.encode(snapshot) {
      try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let s = try? APIClient.decoder.decode(Snapshot.self, from: data) else { return }
    marks = s.marks.mapValues { $0.compactMapKeys(MediaKey.init) }
    ratings = s.ratings.compactMapKeys(MediaKey.init)
    lists = s.lists
    listItems = s.listItems
    episodes = s.episodes
    recent = s.recent.compactMap(MediaKey.init)
    items = s.items.compactMapKeys(MediaKey.init)
    outbox = s.outbox
    cursor = s.cursor
    lastSync = s.lastSync
  }

  /// La versión anterior guardaba todo en UserDefaults con IDs sin tipo.
  private func migrateV1IfNeeded() {
    let v1Key = "peliculas.library.v1"
    guard let raw = UserDefaults.standard.data(forKey: v1Key),
          let old = try? JSONDecoder().decode(LibraryV1.self, from: raw) else { return }
    let now = Date()
    func key(_ id: Int) -> MediaKey { MediaKey(kind: old.items[id]?.kind ?? .movie, id: id) }
    for (id, item) in old.items { items[key(id)] = item }
    for id in old.favorites { marks[.favorite, default: [:]][key(id)] = Stamp(updatedAt: now, deleted: false) }
    for id in old.watchlist { marks[.watchlist, default: [:]][key(id)] = Stamp(updatedAt: now, deleted: false) }
    for id in old.watched { marks[.watched, default: [:]][key(id)] = Stamp(updatedAt: now, deleted: false) }
    for (id, stars) in old.ratings ?? [:] { ratings[key(id)] = RatingStamp(score: Double(stars), review: "", updatedAt: now, deleted: false) }
    for (i, list) in old.lists.enumerated() {
      let lid = list.id.uuidString.lowercased()
      lists[lid] = ListStamp(id: lid, name: list.name, position: i, updatedAt: now, deleted: false)
      for (p, id) in list.ids.enumerated() {
        listItems[Self.listItemKey(lid, key(id))] = ListItemStamp(listId: lid, key: key(id), position: p, updatedAt: now, deleted: false)
      }
    }
    for s in old.watchedEp ?? [] {
      let p = s.split(separator: ":").compactMap { Int($0) }
      if p.count == 3 { episodes[Self.episodeKey(p[0], p[1], p[2])] = EpisodeStamp(tvId: p[0], season: p[1], episode: p[2], updatedAt: now, deleted: false) }
    }
    recent = (old.recent ?? []).map(key)
    UserDefaults.standard.removeObject(forKey: v1Key)
    saveNow()
  }

  static func listItemKey(_ listId: String, _ key: MediaKey) -> String { "\(listId)|\(key)" }
  static func episodeKey(_ tv: Int, _ s: Int, _ e: Int) -> String { "\(tv):\(s):\(e)" }
}

// MARK: - Tipos

struct Stamp: Codable, Hashable, Sendable {
  var updatedAt: Date
  var deleted: Bool
}

struct RatingStamp: Codable, Hashable, Sendable {
  var score: Double
  var review: String
  var updatedAt: Date
  var deleted: Bool
}

struct ListStamp: Codable, Hashable, Sendable {
  let id: String
  var name: String
  var position: Int
  var updatedAt: Date
  var deleted: Bool
}

struct ListItemStamp: Codable, Hashable, Sendable {
  let listId: String
  let key: MediaKey
  var position: Int
  var updatedAt: Date
  var deleted: Bool
}

struct EpisodeStamp: Codable, Hashable, Sendable {
  let tvId: Int
  let season: Int
  let episode: Int
  var updatedAt: Date
  var deleted: Bool
}

struct CustomMediaList: Identifiable, Hashable {
  let id: String
  let name: String
  let items: [MediaItem]
}

private struct PushBody: Encodable { let ops: [SyncOp] }

private extension SyncOp {
  var updatedAt: Date {
    switch self {
    case .library(let r): return r.updatedAt
    case .list(let r): return r.updatedAt
    case .listItem(let r): return r.updatedAt
    case .rating(let r): return r.updatedAt
    case .episode(let r): return r.updatedAt
    }
  }
}

private struct Snapshot: Codable {
  let marks: [LibraryKind: [String: Stamp]]
  let ratings: [String: RatingStamp]
  let lists: [String: ListStamp]
  let listItems: [String: ListItemStamp]
  let episodes: [String: EpisodeStamp]
  let recent: [String]
  let items: [String: MediaItem]
  let outbox: [SyncOp]
  let cursor: String?
  let lastSync: Date?
}

private struct LibraryV1: Decodable {
  struct OldList: Decodable { let id: UUID; let name: String; let ids: [Int] }
  let favorites: [Int]
  let watchlist: [Int]
  let watched: [Int]
  let lists: [OldList]
  let items: [Int: MediaItem]
  let ratings: [Int: Int]?
  let recent: [Int]?
  let watchedEp: [String]?
}

extension Dictionary {
  func mapKeys<K: Hashable>(_ transform: (Key) -> K) -> [K: Value] {
    Dictionary<K, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
  }

  func compactMapKeys<K: Hashable>(_ transform: (Key) -> K?) -> [K: Value] {
    var out: [K: Value] = [:]
    for (k, v) in self { if let nk = transform(k) { out[nk] = v } }
    return out
  }
}
