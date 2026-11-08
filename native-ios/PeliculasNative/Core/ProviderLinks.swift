import Foundation

/// Tap en proveedor abre LA APP del proveedor, no la página de TMDB.
/// Espejo de Flutter (`deep_link_service.dart` + `tmdb_provider_mapper.dart`):
/// primero el esquema de la app (abre directo si está instalada), y si iOS
/// no la puede abrir, la búsqueda web del título en el dominio propio del
/// proveedor (el universal link abre la app; sin ella, Safari la muestra).
/// El `link` de TMDB apunta a `themoviedb.org/.../watch` y nunca se usa.
///
/// IDs verificados contra `GET /watch/providers/movie` y respuestas en vivo
/// (Max migró de 384/425 a 1899; Prime tiene 9/119/2100/10; etc.).
enum ProviderLinks {
  /// Esquema de la app (`nil` = sin esquema conocido: ir directo a `webURL`).
  /// Apple TV usa su universal link (`tv.apple.com`, verificado en device).
  static func appURL(for provider: TMDBProvider, title: String) -> URL? {
    let encoded = title.trimmingCharacters(in: .whitespacesAndNewlines)
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    switch provider.providerId {
    case 8, 1796: return URL(string: "netflix://search?q=\(encoded)")
    case 9, 119, 2100, 10: return URL(string: "aiv://aiv/search?phrase=\(encoded)")
    case 337: return URL(string: "disneyplus://search?q=\(encoded)")
    case 1899, 1825, 384, 425: return URL(string: "hbomax://search?q=\(encoded)")
    case 15: return URL(string: "hulu://search?q=\(encoded)")
    case 531, 582, 2303: return URL(string: "paramountplus://search?q=\(encoded)")
    default:
      let name = provider.providerName.lowercased()
      if name.contains("netflix") { return URL(string: "netflix://search?q=\(encoded)") }
      else if name.contains("prime") || name == "amazon video" { return URL(string: "aiv://aiv/search?phrase=\(encoded)") }
      else if name.contains("disney") { return URL(string: "disneyplus://search?q=\(encoded)") }
      else if name.contains("max") || name.contains("hbo") { return URL(string: "hbomax://search?q=\(encoded)") }
      else if name.contains("hulu") { return URL(string: "hulu://search?q=\(encoded)") }
      else if name.contains("paramount") { return URL(string: "paramountplus://search?q=\(encoded)") }
      return nil
    }
  }

  /// Búsqueda web del título en el dominio propio del proveedor.
  /// Desconocido → JustWatch regional (su trabajo es enlazar a la app).
  static func webURL(for provider: TMDBProvider, title: String, region: String) -> URL? {
    let encoded = title.trimmingCharacters(in: .whitespacesAndNewlines)
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let name = provider.providerName.lowercased()
    let template: String
    switch provider.providerId {
    case 8, 1796: template = "https://www.netflix.com/search?q=\(encoded)"
    case 9, 119, 2100, 10: template = "https://www.primevideo.com/search/ref=atv_nb_sr?phrase=\(encoded)"
    case 337: template = "https://www.disneyplus.com/search?q=\(encoded)"
    case 2, 350: template = "https://tv.apple.com/search?term=\(encoded)"
    case 1899, 1825, 384, 425: template = "https://play.max.com/search?q=\(encoded)"
    case 531, 582, 2303, 1853: template = "https://www.paramountplus.com/search?q=\(encoded)"
    case 386, 387: template = "https://www.peacocktv.com/search?q=\(encoded)"
    case 7: template = "https://www.vudu.com/content/movies/search?query=\(encoded)"
    case 3: template = "https://play.google.com/store/search?q=\(encoded)&c=movies"
    default:
      if name.contains("netflix") { template = "https://www.netflix.com/search?q=\(encoded)" }
      else if name.contains("prime") || name == "amazon video" { template = "https://www.primevideo.com/search/ref=atv_nb_sr?phrase=\(encoded)" }
      else if name.contains("disney") { template = "https://www.disneyplus.com/search?q=\(encoded)" }
      else if name.contains("apple") { template = "https://tv.apple.com/search?term=\(encoded)" }
      else if name.contains("max") || name.contains("hbo") { template = "https://play.max.com/search?q=\(encoded)" }
      else if name.contains("paramount") { template = "https://www.paramountplus.com/search?q=\(encoded)" }
      else if name.contains("peacock") { template = "https://www.peacocktv.com/search?q=\(encoded)" }
      else {
        let locale = region.lowercased()
        template = "https://www.justwatch.com/\(locale)/search?q=\(encoded)"
      }
    }
    return URL(string: template)
  }

  /// Ficha de la app en el App Store (`nil` = sin ficha conocida: ir a `webURL`).
  /// IDs espejo de Flutter (`DeepLinkService._getIOSAppStoreLink`).
  static func appStoreURL(for provider: TMDBProvider) -> URL? {
    let string: String?
    switch provider.providerId {
    case 8, 1796: string = "https://apps.apple.com/app/netflix/id363590051"
    case 9, 119, 2100, 10: string = "https://apps.apple.com/app/amazon-prime-video/id545519333"
    case 337: string = "https://apps.apple.com/app/disney/id1446075923"
    case 1899, 1825, 384, 425: string = "https://apps.apple.com/app/hbo-max/id971265422"
    case 2, 350: string = "https://apps.apple.com/app/apple-tv/id1174078549"
    case 15: string = "https://apps.apple.com/app/hulu/id376510438"
    case 531, 582, 2303, 1853: string = "https://apps.apple.com/app/paramount/id1320318421"
    default:
      let name = provider.providerName.lowercased()
      if name.contains("netflix") { string = "https://apps.apple.com/app/netflix/id363590051" }
      else if name.contains("prime") || name == "amazon video" { string = "https://apps.apple.com/app/amazon-prime-video/id545519333" }
      else if name.contains("disney") { string = "https://apps.apple.com/app/disney/id1446075923" }
      else if name.contains("max") || name.contains("hbo") { string = "https://apps.apple.com/app/hbo-max/id971265422" }
      else if name.contains("apple") { string = "https://apps.apple.com/app/apple-tv/id1174078549" }
      else if name.contains("hulu") { string = "https://apps.apple.com/app/hulu/id376510438" }
      else if name.contains("paramount") { string = "https://apps.apple.com/app/paramount/id1320318421" }
      else { string = nil }
    }
    return string.flatMap(URL.init(string:))
  }

  /// Destino principal del tap (compat: lo que `Link` abría antes).
  static func url(for provider: TMDBProvider, title: String, region: String) -> URL? {
    webURL(for: provider, title: title, region: region)
  }
}
