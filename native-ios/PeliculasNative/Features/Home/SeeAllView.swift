import SwiftUI

/// Cuadrícula completa de una fila ("Ver todo") con infinite scroll.
/// Si le llega `seed` (la página ya cargada en el rail), sigue desde la 2.
struct SeeAllView: View {
  let title: String
  private let seed: [MediaItem]
  @StateObject private var loader: PagedListLoader

  init(title: String, source: MediaListSource, seed: [MediaItem] = []) {
    self.title = title
    self.seed = seed
    _loader = StateObject(wrappedValue: PagedListLoader(source: source, seed: seed))
  }

  /// Desde una fila del Inicio: la misma lista paginada, sigue donde va la fila.
  init(title: String, loader: PagedListLoader) {
    self.title = title
    self.seed = loader.items
    _loader = StateObject(wrappedValue: loader)
  }

  var body: some View {
    Group {
      if loader.items.isEmpty && loader.failed {
        EmptyState(icon: "wifi.exclamationmark",
                   title: "Sin conexión",
                   message: "Revisa tu red e inténtalo de nuevo.") {
          Button("Reintentar") { Task { await loadFirstPage() } }
            .glassProminentButtonStyle()
        }
      } else if loader.items.isEmpty && loader.loading {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if loader.items.isEmpty {
        EmptyState(icon: "film",
                   title: "Nada por aquí",
                   message: "No hay títulos en esta lista ahora mismo.")
      } else {
        grid
      }
    }
    .background(Color(.systemBackground))
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.large)
    .task { if seed.isEmpty { await loadFirstPage() } }
  }

  private var grid: some View {
    ScrollView {
      PosterGrid(items: loader.items)
        .padding(.vertical)
      LoadMoreFooter(loader: loader)
    }
  }

  private func loadFirstPage() async {
    guard loader.items.isEmpty else { return }
    await loader.loadMore()
  }
}

/// Cuadrícula adaptable de pósters con título.
struct PosterGrid: View {
  let items: [MediaItem]
  var badge: ((MediaItem) -> String?)? = nil

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 140), spacing: 14, alignment: .top)], spacing: 20) {
      ForEach(items) { item in
        PosterCard(item: item, width: 104, badge: badge?(item))
      }
    }
    .padding(.horizontal, 20)
  }
}
