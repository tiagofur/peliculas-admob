import Foundation
import SwiftUI

/// Carga paginada con infinite scroll para cualquier `MediaListSource`
/// ("Ver todo", explorar por género). Deduplica títulos y se detiene al
/// agotar las páginas de TMDB (`total_pages`) o al llegar al tope defensivo.
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
  private let fetch: (MediaListSource, Int) async throws -> TMDBPagedMovies

  /// `seed`: la página 1 ya vino cargada (el rail del Inicio la trae);
  /// el scroll sigue desde la 2 sin repetir títulos.
  init(source: MediaListSource, seed: [MediaItem] = [], maxPages: Int = 10,
       fetch: @escaping (MediaListSource, Int) async throws -> TMDBPagedMovies = TMDBClient.pagedList) {
    self.source = source
    self.maxPages = maxPages
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
    page += 1
    do {
      let result = try await fetch(source, page)
      if result.results.isEmpty || page >= min(maxPages, max(1, result.totalPages)) { done = true }
      let existing = Set(items.map(\.key))
      items += result.results.map { MediaItem(tmdb: $0, kind: source.kind) }.filter { !existing.contains($0.key) }
    } catch {
      page -= 1
      if items.isEmpty { failed = true } else { loadMoreFailed = true }
    }
  }
}

/// Pie de infinite scroll: spinner al cargar, "Reintentar" si el load-more falló.
struct LoadMoreFooter: View {
  @ObservedObject var loader: PagedListLoader

  var body: some View {
    Group {
      if loader.done {
        EmptyView()
      } else if loader.loadMoreFailed {
        Button("Reintentar") { Task { await loader.loadMore() } }
          .font(.subheadline.weight(.medium))
          .padding()
      } else {
        ProgressView()
          .opacity(loader.loading ? 1 : 0)
          .padding()
          .onAppear { Task { await loader.loadMore() } }
      }
    }
    .frame(maxWidth: .infinity)
  }
}
