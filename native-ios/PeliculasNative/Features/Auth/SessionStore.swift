import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct APIUser: Codable, Equatable, Sendable {
  let id: String
  let email: String
  let emailVerified: Bool?
  let displayName: String?
  let avatarUrl: String?
  let providers: [String]?

  var shownName: String {
    if let n = displayName, !n.isEmpty { return n }
    if email.hasSuffix("privaterelay.appleid.com") { return String(localized: "Usuario de Apple") }
    return email.split(separator: "@").first.map(String.init) ?? String(localized: "Tú")
  }

  var initials: String {
    let parts = shownName.split(separator: " ").prefix(2)
    let s = parts.compactMap { $0.first }.map(String.init).joined()
    return s.isEmpty ? "?" : s.uppercased()
  }
}

/// Sesión con el backend Go: access token de 15 min + refresh token rotativo.
/// Los tokens viven en el Llavero. Todo el estado de la UI de login vive aquí.
@MainActor
final class SessionStore: ObservableObject {
  static let shared = SessionStore()

  @Published private(set) var user: APIUser?
  @Published private(set) var busy = false

  var isSignedIn: Bool { stored != nil }

  /// Se ejecutan antes de borrar la sesión (con el token aún válido):
  /// quitar el dispositivo de los avisos, vaciar la biblioteca local…
  var willSignOut: [@MainActor () async -> Void] = []
  /// Tras iniciar sesión (primera sincronización, reclamar compras…).
  var didSignIn: [@MainActor () async -> Void] = []

  private var stored: StoredSession?
  private var refreshTask: Task<StoredSession, Error>?
  private var appleNonce: String?
  private static let account = "session.v2"

  private init() {
    stored = Keychain.load(StoredSession.self, account: Self.account)
    user = stored?.user
    // Restos de la app con Supabase: ya no sirven.
    UserDefaults.standard.removeObject(forKey: "peliculas.auth.v1")
  }

  // MARK: Email

  func signIn(email: String, password: String) async throws {
    try await authenticate("/v1/auth/email/login", Credentials(email: email, password: password, name: nil, device: Self.deviceName))
  }

  func signUp(email: String, password: String, name: String) async throws {
    try await authenticate("/v1/auth/email/signup", Credentials(email: email, password: password, name: name.isEmpty ? nil : name, device: Self.deviceName))
  }

  // MARK: Sign in with Apple

  /// Configura la petición de Apple con un nonce nuevo (Apple recibe su SHA-256).
  func prepare(_ request: ASAuthorizationAppleIDRequest) {
    let raw = Self.randomNonce()
    appleNonce = raw
    request.requestedScopes = [.fullName, .email]
    request.nonce = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  func complete(_ result: Result<ASAuthorization, Error>) async throws {
    switch result {
    case .failure(let error):
      if (error as? ASAuthorizationError)?.code == .canceled { return }
      throw error
    case .success(let auth):
      guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8) else {
        throw APIError(status: 0, code: "apple_no_token")
      }
      let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
      let name = [credential.fullName?.givenName, credential.fullName?.familyName]
        .compactMap { $0 }.joined(separator: " ")
      try await authenticate("/v1/auth/apple", AppleBody(
        idToken: token, nonce: appleNonce, authorizationCode: code,
        name: name.isEmpty ? nil : name, device: Self.deviceName
      ))
    }
  }

  // MARK: Sesión

  /// Token válido para llamar al backend; renueva si le queda < 1 min.
  func validAccessToken(forceRefresh: Bool = false) async throws -> String {
    guard let current = stored else { throw APIError.notSignedIn }
    if !forceRefresh, current.expiresAt.timeIntervalSinceNow > 60 { return current.accessToken }
    if let task = refreshTask { return try await task.value.accessToken }
    let refreshToken = current.refreshToken
    let task = Task { () throws -> StoredSession in
      let data = try await APIClient.send("POST", "/v1/auth/refresh", body: ["refresh_token": refreshToken])
      return try Self.decodeSession(data)
    }
    refreshTask = task
    defer { refreshTask = nil }
    do {
      let fresh = try await task.value
      save(fresh)
      return fresh.accessToken
    } catch let error as APIError where error.status == 401 {
      // Refresh revocado o caducado: la sesión ya no existe.
      clearLocal()
      throw error
    }
  }

  func refreshProfile() async {
    guard isSignedIn, let data = try? await APIClient.authed("GET", "/v1/me"),
          let fresh = try? Self.snakeDecoder.decode(APIUser.self, from: data),
          var s = stored else { return }
    s.user = fresh
    save(s)
  }

  func updateName(_ name: String) async throws {
    let data = try await APIClient.authed("PATCH", "/v1/me", body: ["display_name": name])
    if var s = stored, let fresh = try? Self.snakeDecoder.decode(APIUser.self, from: data) {
      s.user = fresh
      save(s)
    }
  }

  func signOut() async {
    guard let current = stored else { return }
    for hook in willSignOut { await hook() }
    _ = try? await APIClient.send("POST", "/v1/auth/logout", body: ["refresh_token": current.refreshToken])
    clearLocal()
  }

  /// Borra la cuenta y todos sus datos en el servidor (App Review 5.1.1(v)).
  func deleteAccount() async throws {
    busy = true
    defer { busy = false }
    for hook in willSignOut { await hook() }
    _ = try await APIClient.authed("DELETE", "/v1/me")
    clearLocal()
  }

  // MARK: Privado

  private func authenticate<Body: Encodable & Sendable>(_ path: String, _ body: Body) async throws {
    busy = true
    defer { busy = false }
    let data = try await APIClient.send("POST", path, body: body)
    save(try Self.decodeSession(data))
    for hook in didSignIn { await hook() }
  }

  private func save(_ s: StoredSession) {
    stored = s
    user = s.user
    Keychain.save(s, account: Self.account)
  }

  private func clearLocal() {
    stored = nil
    user = nil
    Keychain.delete(account: Self.account)
  }

  private static let snakeDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
  }()

  nonisolated private static func decodeSession(_ data: Data) throws -> StoredSession {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    let r = try d.decode(SessionResponse.self, from: data)
    return StoredSession(
      accessToken: r.accessToken, refreshToken: r.refreshToken,
      expiresAt: Date().addingTimeInterval(TimeInterval(r.expiresIn)), user: r.user
    )
  }

  private static var deviceName: String {
    "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
  }

  private static func randomNonce(length: Int = 32) -> String {
    let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var rng = SystemRandomNumberGenerator()
    return String((0..<length).map { _ in chars[Int(rng.next() % UInt64(chars.count))] })
  }
}

struct StoredSession: Codable, Sendable {
  let accessToken: String
  let refreshToken: String
  let expiresAt: Date
  var user: APIUser
}

private struct SessionResponse: Decodable {
  let accessToken: String
  let refreshToken: String
  let expiresIn: Int
  let user: APIUser
}

private struct Credentials: Encodable {
  let email: String
  let password: String
  let name: String?
  let device: String
}

private struct AppleBody: Encodable {
  let idToken: String
  let nonce: String?
  let authorizationCode: String?
  let name: String?
  let device: String

  enum CodingKeys: String, CodingKey {
    case idToken = "id_token", nonce, authorizationCode = "authorization_code", name, device
  }
}
