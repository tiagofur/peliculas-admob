import Foundation

/// Filas del sync del backend Go. Misma forma al subir (`POST /v1/sync`)
/// y al bajar (`GET /v1/sync`). Ver backend/README.md → "Sync de la biblioteca".
enum LibraryKind: String, Codable, CaseIterable, Sendable {
  case favorite, watchlist, watched
}

struct LibraryRow: Codable, Sendable {
  var kind: LibraryKind
  var mediaType: MediaKind
  var tmdbId: Int
  var title: String
  var posterPath: String
  var year: String
  var updatedAt: Date
  var deleted: Bool

  enum CodingKeys: String, CodingKey {
    case kind, mediaType = "media_type", tmdbId = "tmdb_id", title, posterPath = "poster_path"
    case year, updatedAt = "updated_at", deleted
  }
}

struct ListRow: Codable, Sendable {
  var id: String
  var name: String
  var description: String
  var position: Int
  var updatedAt: Date
  var deleted: Bool

  enum CodingKeys: String, CodingKey {
    case id, name, description, position, updatedAt = "updated_at", deleted
  }
}

struct ListItemRow: Codable, Sendable {
  var listId: String
  var mediaType: MediaKind
  var tmdbId: Int
  var title: String
  var posterPath: String
  var year: String
  var position: Int
  var updatedAt: Date
  var deleted: Bool

  enum CodingKeys: String, CodingKey {
    case listId = "list_id", mediaType = "media_type", tmdbId = "tmdb_id", title
    case posterPath = "poster_path", year, position, updatedAt = "updated_at", deleted
  }
}

struct RatingRow: Codable, Sendable {
  var mediaType: MediaKind
  var tmdbId: Int
  var score: Double
  var review: String
  var title: String
  var posterPath: String
  var updatedAt: Date
  var deleted: Bool

  enum CodingKeys: String, CodingKey {
    case mediaType = "media_type", tmdbId = "tmdb_id", score, review, title
    case posterPath = "poster_path", updatedAt = "updated_at", deleted
  }
}

struct EpisodeRow: Codable, Sendable {
  var tvId: Int
  var season: Int
  var episode: Int
  var watchedAt: Date?
  var updatedAt: Date
  var deleted: Bool

  enum CodingKeys: String, CodingKey {
    case tvId = "tv_id", season, episode, watchedAt = "watched_at", updatedAt = "updated_at", deleted
  }
}

/// Un cambio pendiente de subir.
enum SyncOp: Codable, Sendable {
  case library(LibraryRow)
  case list(ListRow)
  case listItem(ListItemRow)
  case rating(RatingRow)
  case episode(EpisodeRow)

  /// Dos ops con la misma clave se pisan: solo sube la última.
  var key: String {
    switch self {
    case .library(let r): return "lib:\(r.kind.rawValue):\(r.mediaType.rawValue):\(r.tmdbId)"
    case .list(let r): return "list:\(r.id)"
    case .listItem(let r): return "li:\(r.listId):\(r.mediaType.rawValue):\(r.tmdbId)"
    case .rating(let r): return "rate:\(r.mediaType.rawValue):\(r.tmdbId)"
    case .episode(let r): return "ep:\(r.tvId):\(r.season):\(r.episode)"
    }
  }

  /// Las listas suben antes que sus elementos (el servidor exige que exista la lista).
  var order: Int {
    switch self {
    case .list: return 0
    case .listItem: return 2
    default: return 1
    }
  }

  private enum CodingKeys: String, CodingKey { case entity, data }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .library(let r): try c.encode("library", forKey: .entity); try c.encode(r, forKey: .data)
    case .list(let r): try c.encode("list", forKey: .entity); try c.encode(r, forKey: .data)
    case .listItem(let r): try c.encode("list_item", forKey: .entity); try c.encode(r, forKey: .data)
    case .rating(let r): try c.encode("rating", forKey: .entity); try c.encode(r, forKey: .data)
    case .episode(let r): try c.encode("episode", forKey: .entity); try c.encode(r, forKey: .data)
    }
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    switch try c.decode(String.self, forKey: .entity) {
    case "library": self = .library(try c.decode(LibraryRow.self, forKey: .data))
    case "list": self = .list(try c.decode(ListRow.self, forKey: .data))
    case "list_item": self = .listItem(try c.decode(ListItemRow.self, forKey: .data))
    case "rating": self = .rating(try c.decode(RatingRow.self, forKey: .data))
    default: self = .episode(try c.decode(EpisodeRow.self, forKey: .data))
    }
  }
}

struct SyncPull: Decodable, Sendable {
  let cursor: String
  let hasMore: Bool
  let library: [LibraryRow]?
  let lists: [ListRow]?
  let listItems: [ListItemRow]?
  let ratings: [RatingRow]?
  let episodes: [EpisodeRow]?

  enum CodingKeys: String, CodingKey {
    case cursor, hasMore = "has_more", library, lists, listItems = "list_items", ratings, episodes
  }
}

struct SyncPushResult: Decodable, Sendable {
  struct Item: Decodable, Sendable {
    let index: Int
    let status: String
    let error: String?
  }
  let results: [Item]
}
