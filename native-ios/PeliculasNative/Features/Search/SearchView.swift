import SwiftUI

struct SearchView: View {
  @StateObject private var loader = SearchLoader()

  var body: some View {
    AppNavigation {
      ScrollView {
        Group {
          if loader.trimmed.count < 2 {
            browse
          } else if loader.searching && loader.results.isEmpty {
            ProgressView().padding(.top, 80).frame(maxWidth: .infinity)
          } else if loader.results.isEmpty {
            EmptyState(icon: loader.failed ? "wifi.exclamationmark" : "magnifyingglass",
                       title: loader.failed ? "Sin conexión" : "Sin resultados",
                       message: loader.failed ? "Revisa tu red e inténtalo de nuevo." : "Prueba con otro título o revisa la ortografía.")
              .frame(minHeight: 360)
          } else {
            PosterGrid(items: loader.results) { $0.kind == .tv && loader.scope == .all ? String(localized: "SERIE") : nil }
              .padding(.vertical, 12)
          }
        }
      }
      .navigationTitle("Buscar")
      .searchable(text: $loader.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Películas, series…")
      .onSubmit(of: .search) { loader.submit() }
      .modifier(SearchScopes(loader: loader))
      .accountToolbar()
    }
    .task { await loader.loadGenres() }
  }

  private var browse: some View {
    VStack(alignment: .leading, spacing: 24) {
      if !loader.history.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Búsquedas recientes").font(.title3.weight(.bold))
            Spacer()
            Button("Borrar") { loader.clearHistory() }.font(.subheadline)
          }
          ForEach(loader.history, id: \.self) { term in
            Button { loader.query = term; loader.submit() } label: {
              HStack {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                Text(term).foregroundStyle(.primary)
                Spacer()
              }
              .padding(.vertical, 6)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 20)
      }
      genreGrid(title: "Explorar películas", genres: loader.movieGenres, kind: .movie)
      genreGrid(title: "Explorar series", genres: loader.tvGenres, kind: .tv)
    }
    .padding(.vertical, 12)
  }

  @ViewBuilder
  private func genreGrid(title: LocalizedStringKey, genres: [TMDBGenre], kind: MediaKind) -> some View {
    if !genres.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        Text(title).font(.title3.weight(.bold)).padding(.horizontal, 20).accessibilityAddTraits(.isHeader)
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
          ForEach(genres) { genre in
            NavigationLink(destination: GenreResultsView(genre: genre, kind: kind)) {
              GenreTile(genre: genre)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 20)
      }
    }
  }
}

/// Ámbitos de búsqueda: nativos en iOS 16.4+, selector segmentado antes.
private struct SearchScopes: ViewModifier {
  @ObservedObject var loader: SearchLoader

  func body(content: Content) -> some View {
    if #available(iOS 16.4, *) {
      content.searchScopes($loader.scope, activation: .onSearchPresentation) {
        ForEach(SearchLoader.Scope.allCases, id: \.self) { Text($0.title).tag($0) }
      }
    } else {
      content.safeAreaInset(edge: .top) {
        Picker("Tipo", selection: $loader.scope) {
          ForEach(SearchLoader.Scope.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .background(.bar)
      }
    }
  }
}

/// Mosaico de género con color propio (como Explorar en Música).
private struct GenreTile: View {
  let genre: TMDBGenre

  private static let palette: [(Color, Color)] = [
    (.orange, .red), (.pink, .purple), (.indigo, .blue), (.teal, .green),
    (.purple, .indigo), (.red, .pink), (.blue, .cyan), (.green, .mint),
    (.yellow, .orange), (.brown, .orange),
  ]

  var body: some View {
    let colors = Self.palette[abs(genre.id) % Self.palette.count]
    Text(genre.name)
      .font(.headline)
      .foregroundStyle(.white)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, minHeight: 72, alignment: .bottomLeading)
      .padding(14)
      .background(LinearGradient(colors: [colors.0, colors.1], startPoint: .topLeading, endPoint: .bottomTrailing),
                  in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .shadow(color: colors.1.opacity(0.25), radius: 6, y: 3)
  }
}

private struct GenreResultsView: View {
  let genre: TMDBGenre
  let kind: MediaKind
  @StateObject private var loader = GenreLoader()

  var body: some View {
    ScrollView {
      PosterGrid(items: loader.items)
        .padding(.vertical, 12)
      if !loader.items.isEmpty {
        ProgressView()
          .opacity(loader.loading ? 1 : 0)
          .padding()
          .onAppear { Task { await loader.loadMore(kind: kind, genre: genre.id) } }
      }
    }
    .overlay { if loader.items.isEmpty && loader.loading { ProgressView() } }
    .navigationTitle(genre.name)
    .task { if loader.items.isEmpty { await loader.loadMore(kind: kind, genre: genre.id) } }
  }
}
