import Foundation

enum AppTab: Hashable {
  case home, upNext, library, search
}

/// Navegación global: pestaña activa, hojas y deep links.
///   peliculas://trending · search · library · upnext · account · pro
///   peliculas://movie/{id} · peliculas://serie/{id}   (avisos de episodios)
///   https://peliculas.creapolis.dev/movie/{id} · /serie/{id} · /trending  (universal links)
@MainActor
final class DeepLinkRouter: ObservableObject {
  static let shared = DeepLinkRouter()

  /// Dominio de los universal links (AASA servida aquí; la web es la Flutter).
  static let webDomain = "peliculas.creapolis.dev"

  @Published var tab: AppTab = .home
  @Published var presented: MediaItem?
  @Published var showingAccount = false
  @Published var showingSignIn = false

  func open(_ url: URL) {
    if url.scheme == "https", url.host == Self.webDomain {
      openWebPath(url.pathComponents.filter { $0 != "/" })
      return
    }
    guard url.scheme == "peliculas" else { return }
    let parts = url.pathComponents.filter { $0 != "/" }
    switch url.host {
    case "trending", "home": tab = .home
    case "search": tab = .search
    case "library": tab = .library
    case "upnext", "siguiente": tab = .upNext
    case "account": showingAccount = true
    case "pro": ProStore.shared.presentPaywall()
    case "serie", "tv":
      if let id = parts.first.flatMap(Int.init) { present(MediaKey(kind: .tv, id: id)) }
    case "movie", "pelicula":
      if let id = parts.first.flatMap(Int.init) { present(MediaKey(kind: .movie, id: id)) }
    default: tab = .home
    }
  }

  private func openWebPath(_ parts: [String]) {
    switch parts.first {
    case "movie", "pelicula":
      if let id = parts.dropFirst().first.flatMap(Int.init) { present(MediaKey(kind: .movie, id: id)) }
    case "serie", "tv":
      if let id = parts.dropFirst().first.flatMap(Int.init) { present(MediaKey(kind: .tv, id: id)) }
    default: tab = .home
    }
  }

  private func present(_ key: MediaKey) {
    showingAccount = false
    presented = MediaItem(key: key, title: "", posterPath: "", year: "")
  }
}
