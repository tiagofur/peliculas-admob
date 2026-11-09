import Foundation

/// Valores que vienen del build (Info.plist ← xcconfig). Nada secreto vive aquí:
/// la key de TMDB está en el backend, no en la app.
enum AppConfig {
  static func string(_ key: String) -> String {
    let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    return raw.hasPrefix("$(") ? "" : raw.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Backend Go (`/v1/...`). Debug: docker local; Release: tu dominio.
  static var apiBaseURL: URL {
    URL(string: string("API_BASE_URL")) ?? URL(string: "http://127.0.0.1:8787")!
  }

  /// `false` mientras la URL de producción siga siendo el ejemplo.
  static var isAPIConfigured: Bool {
    !(apiBaseURL.host ?? "").contains("example.com")
  }

  static var privacyURL: URL? { URL(string: string("PRIVACY_URL")) }
  static var termsURL: URL? { URL(string: string("TERMS_URL")) }
  static var supportURL: URL? { URL(string: string("SUPPORT_URL")) }

  /// Contrato estándar de Apple para suscripciones (válido si no publicas uno propio).
  static let appleEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

  static var appVersion: String {
    let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "\(v) (\(b))"
  }

  /// Productos Pro: mismos IDs que `PRO_PRODUCT_IDS` del backend y App Store Connect.
  enum Pro {
    static let monthly = "peliculas_pro_monthly"
    static let yearly = "peliculas_pro_yearly"
    static let lifetime = "peliculas_pro_lifetime"
    static let all = [yearly, monthly, lifetime]
    static let freeListLimit = 3
    /// Venta de Pro. Mientras sea `false` no se vende nada (uso no comercial de
    /// TMDB) y Pro no existe para el usuario: sin paywall, sin sección Pro en
    /// Cuenta y sin funciones Pro visibles; el límite de listas avisa sin
    /// mencionar Pro. Cómo reactivarlo: `docs/PRO.md`.
    static let salesEnabled = false
  }
}
