import Foundation

enum MediaKind: String, Codable, Sendable {
  case movie
  case tv

  var label: String { self == .movie ? "Película" : "Serie" }
}

/// Identidad de un título. TMDB reutiliza números entre películas y series
/// (la película 1399 no es la serie 1399), así que la clave lleva el tipo.
struct MediaKey: Hashable, Codable, Sendable, CustomStringConvertible {
  let kind: MediaKind
  let id: Int

  var description: String { "\(kind.rawValue):\(id)" }

  init(kind: MediaKind, id: Int) {
    self.kind = kind
    self.id = id
  }

  init?(_ string: String) {
    let parts = string.split(separator: ":")
    guard parts.count == 2, let kind = MediaKind(rawValue: String(parts[0])), let id = Int(parts[1]) else { return nil }
    self.init(kind: kind, id: id)
  }
}

/// Modelo de título en la app. Codable para guardar la biblioteca sin red.
struct MediaItem: Identifiable, Hashable, Codable, Sendable {
  let id: Int
  let title: String
  let overview: String
  let posterPath: String
  let backdropPath: String
  let rating: Double
  let kind: MediaKind
  let year: String

  var key: MediaKey { MediaKey(kind: kind, id: id) }

  init(id: Int, title: String, overview: String, posterPath: String, backdropPath: String,
       rating: Double, kind: MediaKind = .movie, year: String = "") {
    self.id = id
    self.title = title
    self.overview = overview
    self.posterPath = posterPath
    self.backdropPath = backdropPath
    self.rating = rating
    self.kind = kind
    self.year = year
  }

  init(tmdb: TMDBMovie, kind: MediaKind) {
    self.init(
      id: tmdb.id,
      title: tmdb.title ?? tmdb.name ?? "Sin título",
      overview: tmdb.overview ?? "",
      posterPath: tmdb.posterPath ?? "",
      backdropPath: tmdb.backdropPath ?? "",
      rating: tmdb.voteAverage ?? 0,
      kind: kind,
      year: String((tmdb.releaseDate ?? tmdb.firstAirDate ?? "").prefix(4))
    )
  }

  init(detail: TMDBFullDetail, kind: MediaKind) {
    self.init(
      id: detail.id,
      title: detail.title ?? detail.name ?? "Sin título",
      overview: detail.overview ?? "",
      posterPath: detail.posterPath ?? "",
      backdropPath: detail.backdropPath ?? "",
      rating: detail.voteAverage ?? 0,
      kind: kind,
      year: String((detail.releaseDate ?? detail.firstAirDate ?? "").prefix(4))
    )
  }

  /// Título "mínimo" guardado en el servidor (sin sinopsis ni fondo).
  init(key: MediaKey, title: String, posterPath: String, year: String) {
    self.init(id: key.id, title: title, overview: "", posterPath: posterPath,
              backdropPath: "", rating: 0, kind: key.kind, year: year)
  }

  /// Cachés viejas sin `kind`/`year` siguen abriendo.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(Int.self, forKey: .id)
    title = try c.decode(String.self, forKey: .title)
    overview = try c.decodeIfPresent(String.self, forKey: .overview) ?? ""
    posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath) ?? ""
    backdropPath = try c.decodeIfPresent(String.self, forKey: .backdropPath) ?? ""
    rating = try c.decodeIfPresent(Double.self, forKey: .rating) ?? 0
    kind = try c.decodeIfPresent(MediaKind.self, forKey: .kind) ?? .movie
    year = try c.decodeIfPresent(String.self, forKey: .year) ?? ""
  }

  /// Une dos fotos del mismo título quedándose con los campos más ricos.
  func merged(with other: MediaItem) -> MediaItem {
    MediaItem(
      id: id,
      title: other.title.isEmpty ? title : other.title,
      overview: other.overview.isEmpty ? overview : other.overview,
      posterPath: other.posterPath.isEmpty ? posterPath : other.posterPath,
      backdropPath: other.backdropPath.isEmpty ? backdropPath : other.backdropPath,
      rating: other.rating == 0 ? rating : other.rating,
      kind: kind,
      year: other.year.isEmpty ? year : other.year
    )
  }
}
