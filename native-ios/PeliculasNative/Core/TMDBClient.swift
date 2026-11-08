import Foundation

/// TMDB a través de la caché del backend Go (`GET /v1/tmdb/{ruta}`).
/// Mismo JSON que `api.themoviedb.org/3`, pero la key vive en el servidor
/// y las respuestas salen de memoria/Postgres. Las imágenes siguen en el CDN
/// de TMDB (`image.tmdb.org`).
enum TMDBClient {
  /// Idioma del contenido según el teléfono (es / pt / en).
  static var language: String {
    let preferred = Locale.preferredLanguages.first?.lowercased() ?? "es"
    if preferred.hasPrefix("pt") { return "pt-BR" }
    if preferred.hasPrefix("en") { return "en-US" }
    if preferred.hasPrefix("es-es") { return "es-ES" }
    return "es-MX"
  }

  /// Región del teléfono para "Dónde verla" (fallback US).
  static var userRegion: String {
    if #available(iOS 16, *) {
      Locale.current.region?.identifier ?? "US"
    } else {
      Locale.current.regionCode ?? "US"
    }
  }

  static let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
  }()

  static func get<T: Decodable>(_ path: String, query: [String: String] = [:], localized: Bool = true) async throws -> T {
    var q = query
    if localized { q["language"] = language }
    var req = URLRequest(url: APIClient.url("/v1/tmdb" + path, query: q))
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    let data = try await APIClient.perform(req)
    return try decoder.decode(T.self, from: data)
  }

  private static func list(_ path: String, _ query: [String: String] = [:]) async throws -> [TMDBMovie] {
    let r: TMDBResponse = try await get(path, query: query)
    return r.results
  }

  // MARK: Listas

  static func trending(_ kind: MediaKind = .movie, window: String = "week") async throws -> [TMDBMovie] {
    try await list("/trending/\(kind.rawValue)/\(window)")
  }
  static func topRated(_ kind: MediaKind = .movie) async throws -> [TMDBMovie] { try await list("/\(kind.rawValue)/top_rated") }
  static func popular(_ kind: MediaKind = .movie) async throws -> [TMDBMovie] { try await list("/\(kind.rawValue)/popular") }
  static func nowPlaying() async throws -> [TMDBMovie] { try await list("/movie/now_playing", ["region": userRegion]) }
  static func upcoming() async throws -> [TMDBMovie] { try await list("/movie/upcoming", ["region": userRegion]) }
  static func onTheAir() async throws -> [TMDBMovie] { try await list("/tv/on_the_air") }

  static func search(_ query: String, kind: MediaKind) async throws -> [TMDBMovie] {
    try await list("/search/\(kind.rawValue)", ["query": query, "include_adult": "false"])
  }

  static func discover(kind: MediaKind, genreId: Int?, year: Int?, page: Int = 1) async throws -> [TMDBMovie] {
    var q = ["sort_by": "popularity.desc", "include_adult": "false", "page": "\(page)", "vote_count.gte": "50"]
    if let genreId { q["with_genres"] = "\(genreId)" }
    if let year { q[kind == .movie ? "primary_release_year" : "first_air_date_year"] = "\(year)" }
    return try await list("/discover/\(kind.rawValue)", q)
  }

  static func genres(kind: MediaKind) async throws -> [TMDBGenre] {
    let r: TMDBGenreList = try await get("/genre/\(kind.rawValue)/list")
    return r.genres
  }

  static func recommendations(kind: MediaKind, id: Int) async throws -> [TMDBMovie] {
    try await list("/\(kind.rawValue)/\(id)/recommendations")
  }

  // MARK: Detalle

  /// Todo el detalle en una sola petición (cacheada por el backend).
  static func detail(kind: MediaKind, id: Int) async throws -> TMDBFullDetail {
    try await get("/\(kind.rawValue)/\(id)", query: ["append_to_response": "videos,credits,recommendations,similar,watch/providers"])
  }

  /// Detalle ligero de una serie (para "Siguiente"): temporadas y episodios al aire.
  static func show(id: Int) async throws -> TMDBFullDetail {
    try await get("/tv/\(id)")
  }

  static func season(tvId: Int, season: Int) async throws -> [TMDBEpisode] {
    let s: TMDBSeason = try await get("/tv/\(tvId)/season/\(season)")
    return s.episodes
  }

  /// Tráiler: primero en el idioma del teléfono; si no hay, cualquiera (suele ser inglés).
  static func trailerKey(from videos: TMDBVideos?, kind: MediaKind, id: Int) async -> String? {
    if let key = bestTrailer(videos?.results ?? []) { return key }
    guard let all: TMDBVideos = try? await get("/\(kind.rawValue)/\(id)/videos", localized: false) else { return nil }
    return bestTrailer(all.results)
  }

  static func bestTrailer(_ videos: [TMDBVideo]) -> String? {
    let yt = videos.filter { $0.site == "YouTube" }
    return yt.first { $0.type == "Trailer" && $0.official == true }?.key
      ?? yt.first { $0.type == "Trailer" }?.key
      ?? yt.first { $0.type == "Teaser" }?.key
      ?? yt.first?.key
  }

  static func person(id: Int) async throws -> TMDBPersonDetail { try await get("/person/\(id)") }

  static func personCredits(id: Int) async throws -> [TMDBMovie] {
    let r: TMDBMovieCredits = try await get("/person/\(id)/combined_credits")
    return r.cast
  }

  /// "Dónde verla" desde el JSON ya descargado, en la región del teléfono.
  /// Junta suscripción + renta + compra (muchos títulos no tienen plana).
  static func providers(from response: TMDBWatchResponse?, region: String = userRegion) -> (link: String?, providers: [TMDBProvider]) {
    let local = response?.results[region] ?? response?.results["US"]
    var seen: Set<Int> = []
    let all = (local?.flatrate ?? []) + (local?.rent ?? []) + (local?.buy ?? [])
    return (local?.link, all.filter { seen.insert($0.providerId).inserted })
  }

  /// Decode puro (testeable sin red) del `/watch/providers`.
  static func decodeWatchProviders(_ data: Data, region: String) throws -> (link: String?, flatrate: [TMDBProvider]) {
    let decoded = try decoder.decode(TMDBWatchResponse.self, from: data)
    let r = providers(from: decoded, region: region)
    return (r.link, r.providers)
  }
}

// MARK: - Modelos TMDB

struct TMDBResponse: Decodable { let results: [TMDBMovie] }

struct TMDBMovie: Decodable {
  let id: Int
  let title: String?
  let name: String?
  let overview: String?
  let posterPath: String?
  let backdropPath: String?
  let voteAverage: Double?
  let releaseDate: String?
  let firstAirDate: String?
  /// Solo en tendencias "all" y créditos combinados.
  let mediaType: String?
  let genreIds: [Int]?
}

struct TMDBVideos: Decodable { let results: [TMDBVideo] }

struct TMDBVideo: Decodable {
  let key: String
  let site: String
  let type: String?
  let official: Bool?
}

struct TMDBGenre: Decodable, Hashable, Identifiable {
  let id: Int
  let name: String
}

struct TMDBGenreList: Decodable { let genres: [TMDBGenre] }

struct TMDBCredits: Decodable { let cast: [TMDBPerson] }

struct TMDBPerson: Decodable {
  let id: Int
  let name: String?
  let character: String?
  let profilePath: String?
}

struct TMDBWatchResponse: Decodable { let results: [String: TMDBWatchCountry] }

struct TMDBWatchCountry: Decodable {
  let link: String?
  let flatrate: [TMDBProvider]?
  let rent: [TMDBProvider]?
  let buy: [TMDBProvider]?
}

struct TMDBProvider: Decodable, Identifiable, Hashable {
  let providerId: Int
  let providerName: String
  let logoPath: String?
  var id: Int { providerId }
}

struct TMDBPersonDetail: Decodable {
  let id: Int
  let name: String?
  let biography: String?
  let birthday: String?
  let placeOfBirth: String?
  let profilePath: String?
  let knownForDepartment: String?
}

struct TMDBMovieCredits: Decodable { let cast: [TMDBMovie] }

struct TMDBSeason: Decodable { let episodes: [TMDBEpisode] }

struct TMDBEpisode: Decodable {
  let id: Int
  let episodeNumber: Int
  let seasonNumber: Int?
  let name: String?
  let overview: String?
  let stillPath: String?
  let runtime: Int?
  let voteAverage: Double?
  let airDate: String?
}

struct TMDBSeasonSummary: Decodable, Hashable {
  let seasonNumber: Int
  let episodeCount: Int?
  let name: String?
  let airDate: String?
  let posterPath: String?
}

struct TMDBEpisodeRef: Decodable, Hashable {
  let seasonNumber: Int
  let episodeNumber: Int
  let name: String?
  let overview: String?
  let airDate: String?
  let stillPath: String?
  let runtime: Int?
}

/// Detalle de película o serie (con `append_to_response` opcional).
struct TMDBFullDetail: Decodable {
  let id: Int
  let title: String?
  let name: String?
  let overview: String?
  let tagline: String?
  let posterPath: String?
  let backdropPath: String?
  let voteAverage: Double?
  let releaseDate: String?
  let firstAirDate: String?
  let runtime: Int?
  let episodeRunTime: [Int]?
  let numberOfSeasons: Int?
  let numberOfEpisodes: Int?
  let status: String?
  let genres: [TMDBGenre]?
  let seasons: [TMDBSeasonSummary]?
  let nextEpisodeToAir: TMDBEpisodeRef?
  let lastEpisodeToAir: TMDBEpisodeRef?
  let videos: TMDBVideos?
  let credits: TMDBCredits?
  let similar: TMDBResponse?
  let recommendations: TMDBResponse?
  let watchProviders: TMDBWatchResponse?

  enum CodingKeys: String, CodingKey {
    case id, title, name, overview, tagline, posterPath, backdropPath, voteAverage
    case releaseDate, firstAirDate, runtime, episodeRunTime, numberOfSeasons, numberOfEpisodes
    case status, genres, seasons, nextEpisodeToAir, lastEpisodeToAir, videos, credits, similar, recommendations
    case watchProviders = "watch/providers"
  }
}

/// CDN de imágenes de TMDB (gemelo de `tmdb_image_utils.dart`).
enum TMDBImage {
  static func url(path: String?, size: String = "w500") -> URL? {
    guard let path, !path.isEmpty else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
  }
}
