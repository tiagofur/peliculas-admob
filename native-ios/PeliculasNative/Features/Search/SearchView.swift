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
            VStack(alignment: .leading, spacing: 16) {
              if !loader.people.isEmpty {
                peopleSection
              }
              PosterGrid(items: loader.results) { $0.kind == .tv && loader.scope == .all ? String(localized: "SERIE") : nil }
              if !loader.done {
                ProgressView()
                  .opacity(loader.loadingMore ? 1 : 0)
                  .padding()
                  .onAppear { Task { await loader.loadMore() } }
              }
            }
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

  /// Actores/directores encontrados en "Todo": fila compacta hacia la ficha de persona.
  private var peopleSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Personas")
        .font(.title3.weight(.bold))
        .padding(.horizontal, 20)
        .accessibilityAddTraits(.isHeader)
      ForEach(loader.people, id: \.id) { person in
        NavigationLink(destination: ActorView(personId: person.id, personName: person.name ?? "")) {
          HStack(spacing: 12) {
            InitialsAvatar(initials: Self.initials(of: person.name ?? ""))
            VStack(alignment: .leading, spacing: 1) {
              Text(person.name ?? "").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
              Text("Ver filmografía").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 8)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
      }
    }
  }

  private static func initials(of name: String) -> String {
    name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
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
      moodGrid
      genreGrid(title: "Explorar películas", genres: loader.movieGenres, kind: .movie)
      genreGrid(title: "Explorar series", genres: loader.tvGenres, kind: .tv)
    }
    .padding(.vertical, 12)
  }

  /// "Descubrir": moods curados con filtros fijos de discover.
  private var moodGrid: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Descubrir").font(.title3.weight(.bold)).padding(.horizontal, 20).accessibilityAddTraits(.isHeader)
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
        ForEach(Mood.allCases) { mood in
          NavigationLink(destination: PagedResultsView(title: String(localized: mood.title), source: mood.source)) {
            MoodTile(mood: mood)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 20)
    }
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
  @State private var year: Int?
  @State private var sort: DiscoverSort = .popularity

  private var source: MediaListSource {
    .genre(kind: kind, genreId: genre.id, year: year, sort: sort)
  }

  var body: some View {
    PagedResultsView(title: genre.name, source: source, emptyMessage: "No hay títulos en este género ahora mismo.")
      .id(source) // cambiar filtro ⇒ lista nueva desde la página 1
      .toolbar { filterMenu }
  }

  private var filterMenu: some ToolbarContent {
    ToolbarItem {
      Menu {
        Picker("Orden", selection: $sort) {
          Label("Populares", systemImage: "flame").tag(DiscoverSort.popularity)
          Label("Mejor valoradas", systemImage: "star.fill").tag(DiscoverSort.rating)
          Label("Más recientes", systemImage: "calendar").tag(DiscoverSort.newest)
        }
        Picker("Año", selection: Binding(get: { year ?? 0 }, set: { year = $0 == 0 ? nil : $0 })) {
          Text("Todos").tag(0)
          ForEach(Self.years, id: \.self) { y in
            Text(verbatim: "\(y)").tag(y)
          }
        }
      } label: {
        Image(systemName: year != nil || sort != .popularity
              ? "line.3.horizontal.decrease.circle.fill"
              : "line.3.horizontal.decrease.circle")
      }
      .accessibilityLabel("Filtrar")
    }
  }

  private static let years: [Int] = {
    let current = Calendar.current.component(.year, from: Date())
    return (current - 25...current).reversed()
  }()
}

/// Grid paginado con infinite scroll para un `MediaListSource` cualquiera
/// (género, mood…). Estados: cargando, error con reintentar, vacío.
struct PagedResultsView: View {
  let title: String
  let source: MediaListSource
  let emptyMessage: LocalizedStringKey
  @StateObject private var loader: PagedListLoader

  init(title: String, source: MediaListSource, emptyMessage: LocalizedStringKey = "Nada por aquí") {
    self.title = title
    self.source = source
    self.emptyMessage = emptyMessage
    _loader = StateObject(wrappedValue: PagedListLoader(source: source))
  }

  var body: some View {
    Group {
      if loader.items.isEmpty && loader.failed {
        EmptyState(icon: "wifi.exclamationmark",
                   title: "Sin conexión",
                   message: "Revisa tu red e inténtalo de nuevo.") {
          Button("Reintentar") { Task { await loader.loadMore() } }
            .glassProminentButtonStyle()
        }
      } else if loader.items.isEmpty && loader.loading {
        ProgressView()
      } else if loader.items.isEmpty {
        EmptyState(icon: "film",
                   title: "Nada por aquí",
                   message: emptyMessage)
      } else {
        ScrollView {
          PosterGrid(items: loader.items)
            .padding(.vertical, 12)
          LoadMoreFooter(loader: loader)
        }
      }
    }
    .navigationTitle(Text(verbatim: title))
    .task { if loader.items.isEmpty { await loader.loadMore() } }
  }
}
