import Foundation

/// Error del backend Go: `{"error": "<código>"}` + estado HTTP.
struct APIError: LocalizedError, Equatable {
  let status: Int
  let code: String

  static let offline = APIError(status: 0, code: "offline")
  static let notSignedIn = APIError(status: 401, code: "missing_token")

  var errorDescription: String? {
    switch code {
    case "offline": return String(localized: "Sin conexión. Revisa tu red e inténtalo de nuevo.")
    case "invalid_email": return String(localized: "Ese correo no parece válido.")
    case "weak_password": return String(localized: "La contraseña necesita al menos 8 caracteres.")
    case "email_taken": return String(localized: "Ya existe una cuenta con ese correo. Inicia sesión.")
    case "invalid_credentials": return String(localized: "Correo o contraseña incorrectos.")
    case "invalid_token", "missing_token": return String(localized: "Tu sesión caducó. Vuelve a iniciar sesión.")
    case "invalid_nonce": return String(localized: "No se pudo verificar el inicio de sesión. Inténtalo de nuevo.")
    case "provider_not_configured": return String(localized: "Este método de acceso aún no está disponible.")
    case "rate_limited": return String(localized: "Demasiados intentos. Espera unos segundos.")
    case "invalid_reset_code": return String(localized: "El código no es válido o caducó. Pide uno nuevo.")
    case "mail_not_configured": return String(localized: "No podemos enviar correos ahora mismo. Inténtalo más tarde.")
    case "purchase_owned_by_other_account": return String(localized: "Esta compra ya está vinculada a otra cuenta.")
    case "storekit_disabled": return String(localized: "Las compras no están disponibles ahora mismo.")
    case "auth_disabled": return String(localized: "El servidor no tiene cuentas activadas.")
    default:
      let detail = status == 0 ? code : String(status)
      return String(localized: "Algo salió mal (\(detail)). Inténtalo más tarde.")
    }
  }
}

/// Cliente HTTP del backend. Sin dependencias.
/// - Rutas con sesión: añade el Bearer y, si el servidor responde 401, renueva
///   el token una vez y repite la petición.
enum APIClient {
  static let session: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 20
    config.waitsForConnectivity = false
    config.requestCachePolicy = .useProtocolCachePolicy
    config.urlCache = URLCache(memoryCapacity: 20 << 20, diskCapacity: 100 << 20)
    return URLSession(configuration: config)
  }()

  static let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .custom { decoder in
      let c = try decoder.singleValueContainer()
      let s = try c.decode(String.self)
      if let date = ISO8601.parse(s) { return date }
      throw DecodingError.dataCorruptedError(in: c, debugDescription: "fecha inválida \(s)")
    }
    return d
  }()

  static let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .custom { date, encoder in
      var c = encoder.singleValueContainer()
      try c.encode(ISO8601.format(date))
    }
    return e
  }()

  static func url(_ path: String, query: [String: String] = [:]) -> URL {
    var components = URLComponents(url: AppConfig.apiBaseURL, resolvingAgainstBaseURL: false)!
    components.path = (components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path) + path
    if !query.isEmpty {
      components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
    return components.url!
  }

  /// Petición sin sesión (login, registro, refresh).
  static func send<Body: Encodable & Sendable>(_ method: String, _ path: String, body: Body?) async throws -> Data {
    var req = URLRequest(url: url(path))
    req.httpMethod = method
    if let body {
      req.setValue("application/json", forHTTPHeaderField: "Content-Type")
      req.httpBody = try encoder.encode(body)
    }
    return try await perform(req)
  }

  /// Petición con sesión. Renueva el token una vez si caducó.
  @MainActor
  static func authed<Body: Encodable & Sendable>(_ method: String, _ path: String, query: [String: String] = [:], body: Body? = Optional<Empty>.none) async throws -> Data {
    let auth = SessionStore.shared
    var req = URLRequest(url: url(path, query: query))
    req.httpMethod = method
    req.cachePolicy = .reloadIgnoringLocalCacheData
    if let body {
      req.setValue("application/json", forHTTPHeaderField: "Content-Type")
      req.httpBody = try encoder.encode(body)
    }
    req.setValue("Bearer \(try await auth.validAccessToken())", forHTTPHeaderField: "Authorization")
    do {
      return try await perform(req)
    } catch let error as APIError where error.status == 401 {
      req.setValue("Bearer \(try await auth.validAccessToken(forceRefresh: true))", forHTTPHeaderField: "Authorization")
      return try await perform(req)
    }
  }

  static func perform(_ req: URLRequest) async throws -> Data {
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: req)
    } catch {
      throw APIError.offline
    }
    guard let http = response as? HTTPURLResponse else { throw APIError.offline }
    guard (200...299).contains(http.statusCode) else {
      let code = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "http_\(http.statusCode)"
      throw APIError(status: http.statusCode, code: code)
    }
    return data
  }

  struct Empty: Codable {}
  private struct ErrorBody: Decodable { let error: String }
}

/// RFC 3339 con y sin fracciones de segundo (Go envía nanosegundos).
enum ISO8601 {
  nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  private static let lock = NSLock()

  static func parse(_ s: String) -> Date? {
    lock.lock(); defer { lock.unlock() }
    if let d = fractional.date(from: s) ?? plain.date(from: s) { return d }
    // Go puede mandar 9 decimales: recorta a 3 para el formateador.
    if let dot = s.firstIndex(of: "."), let end = s[dot...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) {
      let digits = s[s.index(after: dot)..<end].prefix(3)
      return fractional.date(from: String(s[..<dot]) + "." + digits + String(s[end...]))
    }
    return nil
  }

  static func format(_ d: Date) -> String {
    lock.lock(); defer { lock.unlock() }
    return fractional.string(from: d)
  }
}
