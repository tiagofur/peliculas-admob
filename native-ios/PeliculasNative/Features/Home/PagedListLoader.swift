import Foundation
import SwiftUI

/// Carga paginada con infinite scroll para cualquier `MediaListSource`
/// ("Ver todo", explorar por género). Deduplica títulos y se detiene al
/// agotar las páginas de TMDB (`total_pages`) o al llegar al tope defensivo.
/// Las filas del Inicio y su "Ver todo" comparten la misma instancia.
@MainActor
final class PagedListLoader: ObservableObject {
  @Published private(set) var items: [MediaItem] = []
  @Published private(set) var loading = false
  /// Una primera página fallida deja la pantalla vacía: se muestra error con reintentar.
  @Published private(set) var failed = false
  /// Un load-more fallido es recuperable en el pie de la lista (`LoadMoreFooter`).
  @Published private(set) var loadMoreFailed = false
  private(set) var done = false

  private let source: MediaListSource
  private let maxPages: Int
  private var page = 0
  private let keep: (TMDBMovie) -> Bool
  private let fetch: (MediaListSource, Int) async throws -> TMDBPagedMovies

  /// `seed`: la página 1 ya vino cargada (el rail del Inicio la trae);
  /// el scroll sigue desde la 2 sin repetir títulos.
  /// `keep`: filtra resultados crudos (p. ej. estrenos ya pasados en "Próximos").
  init(source: MediaListSource, seed: [MediaItem] = [], maxPages: Int = 10,
       fetch: @escaping (MediaListSource, Int) async throws -> TMDBPagedMovies = TMDBClient.pagedList,
       keep: @escaping (TMDBMovie) -> Bool = { _ in true }) {
    self.source = source
    self.maxPages = maxPages
    self.keep = keep
    self.fetch = fetch
    if !seed.isEmpty {
      items = seed
      page = 1
    }
  }

  func loadMore() async {
    guard !loading, !done else { return }
    loading = true
    failed = false
    loadMoreFailed = false
    defer { loading = false }
    do {
      // Una página sin títulos nuevos (repetidos o filtrados) no deja la lista
      // atascada con el pie visible: se pide la siguiente, hasta el tope.
      while true {
        let next = page + 1
        let result = try await fetch(source, next)
        page = next
        if result.results.isEmpty || next >= min(maxPages, max(1, result.totalPages)) { done = true }
        var seen = Set(items.map(\.key))
        let fresh = result.results.filter(keep).map { MediaItem(tmdb: $0, kind: source.kind) }
          .filter { seen.insert($0.key).inserted }
        items += fresh
        if !fresh.isEmpty || done { break }
      }
    } catch {
      if items.isEmpty { failed = true } else { loadMoreFailed = true }
    }
  }
}

/// Pie de infinite scroll: spinner al cargar, "Reintentar" si el load-more falló.
/// `compact`: versión para filas horizontales (icono en vez de botón con texto).
struct LoadMoreFooter: View {
  @ObservedObject var loader: PagedListLoader
  var compact = false

  var body: some View {
    Group {
      if loader.done {
        EmptyView()
      } else if loader.loadMoreFailed && compact {
        Button { Task { await loader.loadMore() } } label: {
          Image(systemName: "arrow.clockwise").font(.headline)
        }
        .accessibilityLabel("Reintentar")
      } else if loader.loadMoreFailed {
        Button("Reintentar") { Task { await loader.loadMore() } }
          .font(.subheadline.weight(.medium))
          .padding()
      } else {
        ProgressView()
          .opacity(loader.loading ? 1 : 0)
          .padding(compact ? 0 : 16)
          .onAppear { Task { await loader.loadMore() } }
      }
    }
    .frame(maxWidth: .infinity)
  }
}
