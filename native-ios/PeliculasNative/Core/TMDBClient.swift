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

  static func searchPage(_ query: String, kind: MediaKind, page: Int) async throws -> TMDBPagedMovies {
    try await get("/search/\(kind.rawValue)", query: ["query": query, "include_adult": "false", "page": "\(page)"])
  }

  /// Actores/directores por nombre (solo primera página: 3 resultados en UI).
  static func searchPeople(_ query: String) async throws -> [TMDBPerson] {
    let r: TMDBPersonsResponse = try await get("/search/person", query: ["query": query, "include_adult": "false", "page": "1"])
    return r.results
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

  // MARK: Listas paginadas

  /// Lista completa paginada ("Ver todo", explorar, búsqueda). El backend ya
  /// deja pasar `page` (`internal/tmdb/policy.go`) y TMDB devuelve `total_pages`.
  static func pagedList(_ source: MediaListSource, page: Int) async throws -> TMDBPagedMovies {
    switch source {
    case .trending(let kind, let window):
      return try await get("/trending/\(kind.rawValue)/\(window)", query: ["page": "\(page)"])
    case .topRated(let kind):
      return try await get("/\(kind.rawValue)/top_rated", query: ["page": "\(page)"])
    case .nowPlaying:
      return try await get("/movie/now_playing", query: ["page": "\(page)", "region": userRegion])
    case .upcoming:
      return try await get("/movie/upcoming", query: ["page": "\(page)", "region": userRegion])
    case .genre(let kind, let genreId, let year, let sort):
      var q = ["sort_by": sort.sortBy(kind), "include_adult": "false",
               "page": "\(page)", "vote_count.gte": "\(sort.voteFloor)", "with_genres": "\(genreId)"]
      if let year { q[kind == .movie ? "primary_release_year" : "first_air_date_year"] = "\(year)" }
      if sort == .newest {
        // "Más recientes": sin esto entran estrenos futuros sin votos.
        let today = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        q[kind == .movie ? "primary_release_date.lte" : "first_air_date.lte"] = today
      }
      return try await get("/discover/\(kind.rawValue)", query: q)
    case .discover(let kind, let genreIds, let voteFloor, let minRating, let order):
      var q: [String: String] = ["sort_by": order, "include_adult": "false", "page": "\(page)",
                                 "vote_count.gte": "\(voteFloor)", "with_genres": genreIds]
      if let minRating { q["vote_average.gte"] = "\(minRating)" }
      return try await get("/discover/\(kind.rawValue)", query: q)
    case .search(let query, let kind):
      return try await searchPage(query, kind: kind, page: page)
    }
  }
}

/// De dónde sale una lista paginada. Cada caso es un endpoint TMDB de una sola
/// clase de contenido, así que `kind` es conocido.
enum MediaListSource: Hashable {
  case trending(kind: MediaKind, window: String)
  case topRated(kind: MediaKind)
  case nowPlaying
  case upcoming
  case genre(kind: MediaKind, genreId: Int, year: Int? = nil, sort: DiscoverSort = .popularity)
  case discover(kind: MediaKind, genreIds: String, voteFloor: Int, minRating: Double? = nil, order: String = "popularity.desc")
  case search(query: String, kind: MediaKind)

  var kind: MediaKind {
    switch self {
    case .trending(let kind, _), .topRated(let kind), .genre(let kind, _, _, _),
         .discover(let kind, _, _, _, _), .search(_, let kind):
      return kind
    case .nowPlaying, .upcoming:
      return .movie
    }
  }
}

/// Orden de "Explorar por género" (TMDB `sort_by` de discover).
enum DiscoverSort: Hashable {
  case popularity, rating, newest

  /// TMDB usa campos de fecha distintos para película y serie.
  func sortBy(_ kind: MediaKind) -> String {
    switch self {
    case .popularity: return "popularity.desc"
    case .rating: return "vote_average.desc"
    case .newest: return kind == .movie ? "primary_release_date.desc" : "first_air_date.desc"
    }
  }

  /// Piso de votos para no llenar la lista de títulos desconocidos.
  var voteFloor: Int {
    switch self {
    case .popularity: return 50
    case .rating: return 150
    case .newest: return 10
    }
  }
}

// MARK: - Modelos TMDB

struct TMDBResponse: Decodable { let results: [TMDBMovie] }

struct TMDBPersonsResponse: Decodable { let results: [TMDBPerson] }

/// Respuesta paginada de TMDB (`page`, `results`, `total_pages`).
struct TMDBPagedMovies: Decodable {
  let page: Int
  let results: [TMDBMovie]
  let totalPages: Int
}

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

struct TMDBCredits: Decodable { let cast: [TMDBPerson]; let crew: [TMDBPerson]? }

struct TMDBPerson: Decodable {
  let id: Int
  let name: String?
  let character: String?
  /// Solo en el `crew` (Director, Screenplay…).
  let job: String?
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
  let createdBy: [TMDBPerson]?
  let similar: TMDBResponse?
  let recommendations: TMDBResponse?
  let watchProviders: TMDBWatchResponse?

  enum CodingKeys: String, CodingKey {
    case id, title, name, overview, tagline, posterPath, backdropPath, voteAverage
    case releaseDate, firstAirDate, runtime, episodeRunTime, numberOfSeasons, numberOfEpisodes
    case status, genres, seasons, nextEpisodeToAir, lastEpisodeToAir, videos, credits, similar, recommendations
    // Con convertFromSnakeCase la clave explícita va en forma convertida.
    case createdBy
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
