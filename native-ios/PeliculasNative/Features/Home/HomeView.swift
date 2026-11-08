import SwiftUI

/// Inicio estilo Apple TV: el contenido manda (héroe a sangre completa),
/// el chrome flota en vidrio encima.
struct HomeView: View {
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var upNext: UpNextStore
  @StateObject private var loader = HomeLoader()

  var body: some View {
    AppNavigation {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 32) {
          if loader.featured.isEmpty {
            HeroPlaceholder(loading: loader.loading, failed: loader.failed) {
              Task { await loader.load() }
            }
          } else {
            HeroCarousel(items: loader.featured)
          }

          if !upNext.entries.isEmpty {
            ContinueWatchingRail(entries: Array(upNext.entries.prefix(10)))
          }
          if !library.recentItems().isEmpty {
            PosterRail(items: library.recentItems()) { SectionHeader("Visto recientemente") }
          }
          if let title = loader.personalTitle, !loader.personal.isEmpty {
            PosterRail(items: loader.personal) { SectionHeader(title, subtitle: "Recomendaciones para ti") }
          }
          if !loader.trending.isEmpty {
            Top10Rail(items: Array(loader.trending.prefix(10)))
          }
          rail("Series en tendencia", loader.trendingShows)
          rail("En cines", loader.nowPlaying)
          rail("Próximos estrenos", loader.upcoming)
          rail("Aclamadas por la crítica", loader.topRated)

          TMDBAttribution()
            .padding(.horizontal, 20)
          AdBannerView()
        }
        .padding(.bottom, 24)
      }
      .ignoresSafeArea(edges: .top)
      .background(Color(.systemBackground))
      .refreshable {
        await loader.load()
        await library.sync()
      }
      .navigationTitle("Inicio")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        // Título oculto sobre el héroe (sigue sirviendo para el botón Atrás).
        ToolbarItem(placement: .principal) { Text("") }
      }
      .accountToolbar()
    }
    .task {
      if loader.isEmpty { await loader.load() }
      await loader.loadPersonal(from: library.items(in: .favorite))
      if !upNext.loadedOnce { await upNext.load(library: library) }
    }
  }

  @ViewBuilder
  private func rail(_ title: String, _ items: [MediaItem]) -> some View {
    if !items.isEmpty {
      PosterRail(items: items) {
        SectionHeader(title) { SeeAllView(title: title, items: items) }
      }
    }
  }
}

// MARK: - Héroe

private struct HeroCarousel: View {
  let items: [MediaItem]
  @State private var index = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let height: CGFloat = 600

  var body: some View {
    ZStack(alignment: .bottom) {
      TabView(selection: $index) {
        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
          HeroPage(item: item, height: height).tag(i)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(height: height)

      HStack(spacing: 6) {
        ForEach(items.indices, id: \.self) { i in
          Capsule()
            .fill(i == index ? Color.primary : Color.primary.opacity(0.3))
            .frame(width: i == index ? 18 : 6, height: 6)
        }
      }
      .animation(.spring(response: 0.35), value: index)
      .padding(.bottom, 4)
      .accessibilityHidden(true)
    }
    .task(id: index) {
      // Avanza solo, salvo con "Reducir movimiento".
      guard !reduceMotion, items.count > 1 else { return }
      try? await Task.sleep(nanoseconds: 7_000_000_000)
      guard !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 0.6)) { index = (index + 1) % items.count }
    }
  }
}

private struct HeroPage: View {
  @EnvironmentObject private var library: LibraryStore
  let item: MediaItem
  let height: CGFloat

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      NavigationLink(destination: DetailView(item: item)) {
        RemoteImage(url: TMDBImage.url(path: item.backdropPath, size: "w1280"))
          .frame(height: height)
          .frame(maxWidth: .infinity)
          .clipped()
          .overlay(
            LinearGradient(stops: [
              .init(color: .black.opacity(0.35), location: 0),
              .init(color: .clear, location: 0.22),
              .init(color: .clear, location: 0.45),
              .init(color: Color(.systemBackground).opacity(0.85), location: 0.82),
              .init(color: Color(.systemBackground), location: 1),
            ], startPoint: .top, endPoint: .bottom)
          )
      }
      .buttonStyle(.plain)
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 10) {
        Text(item.kind == .tv ? "SERIE" : "PELÍCULA")
          .font(.caption2.weight(.bold))
          .tracking(1.2)
          .foregroundStyle(.secondary)
        Text(item.title)
          .font(.system(size: 36, weight: .heavy, design: .default))
          .lineLimit(2)
          .minimumScaleFactor(0.7)
        HStack(spacing: 8) {
          if !item.year.isEmpty { Text(item.year) }
          if item.rating > 0 {
            Label(String(format: "%.1f", item.rating), systemImage: "star.fill")
              .labelStyle(.titleAndIcon)
          }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        if !item.overview.isEmpty {
          Text(item.overview)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        GlassGroup(spacing: 10) {
          HStack(spacing: 10) {
            NavigationLink(destination: DetailView(item: item)) {
              Label("Ver ficha", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: 200)
                .padding(.vertical, 4)
            }
            .glassProminentButtonStyle()
            .controlSize(.large)
            Button { library.toggle(item, in: .watchlist) } label: {
              Image(systemName: library.isInWatchlist(item) ? "checkmark" : "plus")
                .font(.headline)
                .frame(width: 28, height: 28)
            }
            .glassButtonStyle()
            .controlSize(.large)
            .accessibilityLabel(library.isInWatchlist(item) ? "Quitar de Watchlist" : "Añadir a Watchlist")
          }
        }
        .padding(.top, 4)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 28)
    }
    .frame(height: height)
  }
}

private struct HeroPlaceholder: View {
  let loading: Bool
  let failed: Bool
  let retry: () -> Void

  var body: some View {
    ZStack {
      LinearGradient(colors: [Color(.secondarySystemBackground), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
      if loading {
        ProgressView().controlSize(.large)
      } else if failed {
        VStack(spacing: 12) {
          Image(systemName: "wifi.exclamationmark").font(.system(size: 44)).foregroundStyle(.secondary)
          Text("No pudimos cargar el contenido").font(.headline)
          Text(AppConfig.isAPIConfigured || isDebug ? "Revisa tu conexión e inténtalo de nuevo." : "Falta configurar la URL del servidor.")
            .font(.subheadline).foregroundStyle(.secondary)
          Button("Reintentar", action: retry).glassProminentButtonStyle()
        }
        .padding(.top, 80)
      }
    }
    .frame(height: 460)
  }

  private var isDebug: Bool {
    #if DEBUG
    true
    #else
    false
    #endif
  }
}

// MARK: - Continuar viendo

private struct ContinueWatchingRail: View {
  let entries: [UpNextEntry]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionHeader("Continuar viendo")
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 14) {
          ForEach(entries) { UpNextCard(entry: $0, width: 280) }
        }
        .padding(.horizontal, 20)
      }
    }
  }
}

/// Tarjeta horizontal de episodio (fotograma + progreso), como "A continuación" de TV.
struct UpNextCard: View {
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var upNext: UpNextStore
  let entry: UpNextEntry
  var width: CGFloat = 300

  var body: some View {
    NavigationLink(destination: DetailView(item: entry.show)) {
      VStack(alignment: .leading, spacing: 8) {
        ZStack(alignment: .bottomLeading) {
          RemoteImage(url: TMDBImage.url(path: entry.stillPath.isEmpty ? entry.show.backdropPath : entry.stillPath, size: "w780"),
                      placeholderIcon: "tv")
            .frame(width: width, height: width * 9 / 16)
            .clipped()
          LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
          VStack(alignment: .leading, spacing: 6) {
            Text(entry.next.label)
              .font(.caption.weight(.bold))
              .foregroundStyle(.white.opacity(0.85))
            if entry.airedCount > 0 {
              ProgressView(value: entry.progress)
                .tint(.white)
                .frame(width: width * 0.4)
            }
          }
          .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topTrailing) {
          Button {
            Task { await upNext.markWatched(entry, library: library) }
          } label: {
            Image(systemName: "checkmark")
              .font(.subheadline.weight(.bold))
              .foregroundStyle(.white)
              .frame(width: 34, height: 34)
              .glassCircle()
          }
          .padding(8)
          .accessibilityLabel("Marcar \(entry.next.label) como visto")
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(entry.show.title).font(.subheadline.weight(.semibold)).lineLimit(1)
          Text(entry.episodeTitle.isEmpty ? (entry.started ? "Siguiente episodio" : "Empieza la serie") : entry.episodeTitle)
            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      .frame(width: width, alignment: .leading)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .contain)
  }
}

// MARK: - Top 10

private struct Top10Rail: View {
  let items: [MediaItem]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionHeader("Top 10 de la semana", subtitle: "Películas") { SeeAllView(title: "Tendencias de la semana", items: items) }
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 6) {
          ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
            NavigationLink(destination: DetailView(item: item)) {
              HStack(alignment: .bottom, spacing: -18) {
                Text("\(i + 1)")
                  .font(.system(size: 96, weight: .black, design: .rounded))
                  .foregroundStyle(
                    LinearGradient(colors: [.primary.opacity(0.9), .primary.opacity(0.25)], startPoint: .top, endPoint: .bottom)
                  )
                  .frame(minWidth: 56)
                  .offset(y: 14)
                  .accessibilityHidden(true)
                PosterImage(path: item.posterPath, width: 112)
                  .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
              }
            }
            .buttonStyle(.plain)
            .mediaContextMenu(item)
            .accessibilityLabel("Número \(i + 1): \(item.title)")
          }
        }
        .padding(.horizontal, 20)
      }
    }
  }
}

/// Crédito obligatorio de TMDB (sus términos de uso de la API).
struct TMDBAttribution: View {
  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text("TMDB")
        .font(.caption2.weight(.black))
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(LinearGradient(colors: [Color(red: 0.56, green: 0.81, blue: 0.64), Color(red: 0.0, green: 0.71, blue: 0.89)],
                                   startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 4))
      Text("Datos e imágenes de The Movie Database (TMDB). Esta app usa la API de TMDB pero no está respaldada ni certificada por TMDB.")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}
