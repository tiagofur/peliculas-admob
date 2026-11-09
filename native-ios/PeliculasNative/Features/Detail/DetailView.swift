import SwiftUI
import UIKit

struct DetailView: View {
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var pro: ProStore
  @StateObject private var loader = DetailLoader()
  @State private var showingTrailer = false
  @State private var showingNewList = false
  @State private var newListName = ""
  @State private var overviewExpanded = false
  @State private var editingReview = false
  @State private var reviewDraft = ""
  let item: MediaItem

  private var current: MediaItem { loader.item ?? item }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        StretchyHeader(path: current.backdropPath.isEmpty ? current.posterPath : current.backdropPath, height: 460)
          .overlay(alignment: .bottomLeading) { titleBlock }

        VStack(alignment: .leading, spacing: 28) {
          actionBar
          if let credit = loader.creditHeadline {
            HStack(spacing: 6) {
              Text(verbatim: credit.label).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
              Text(verbatim: credit.names).font(.subheadline)
            }
            .accessibilityElement(children: .combine)
          }
          ratingRow
          reviewSection
          overview
          if current.kind == .tv, !loader.seasons.isEmpty { seasonsSection }
          if let key = loader.trailerKey { trailerSection(key) }
          if !loader.providers.isEmpty { providersSection }
          if !loader.cast.isEmpty { castSection }
          if !loader.similar.isEmpty {
            PosterRail(items: loader.similar) {
              SectionHeader(String(localized: "Te puede gustar"))
            }
            .padding(.horizontal, -20)
          }
          if loader.failed {
            VStack(spacing: 10) {
              Label("No se pudo cargar toda la información.", systemImage: "wifi.exclamationmark")
                .font(.footnote).foregroundStyle(.secondary)
              Button("Reintentar") { Task { await loader.load(item) } }
                .font(.footnote.weight(.semibold))
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 32)
      }
    }
    .coordinateSpace(name: "detailScroll")
    .ignoresSafeArea(edges: .top)
    .refreshable { await loader.load(item) }
    .background(Color(.systemBackground))
    .navigationTitle(current.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) { Text(verbatim: "") }
    }
    .task {
      library.touchRecent(item)
      await loader.load(item)
      if let full = loader.item { library.remember(full) }
    }
    .fullScreenCover(isPresented: $showingTrailer) {
      TrailerFullscreenView(key: loader.trailerKey ?? "")
    }
    .alert("Nueva lista", isPresented: $showingNewList) {
      TextField("Nombre", text: $newListName)
      Button("Crear y añadir") {
        guard !newListName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let id = library.createList(named: newListName)
        library.toggle(current, inList: id)
        newListName = ""
      }
      Button("Cancelar", role: .cancel) { newListName = "" }
    }
  }

  // MARK: Cabecera

  private var titleBlock: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        (current.kind == .tv ? Text("SERIE") : Text("PELÍCULA"))
          .font(.caption2.weight(.bold))
          .tracking(1.2)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .glassCapsule()
        if let status = loader.statusText {
          Text(status.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
        }
      }
      Text(current.title.isEmpty ? " " : current.title)
        .font(.system(size: 34, weight: .heavy))
        .lineLimit(3)
        .minimumScaleFactor(0.7)
        .accessibilityAddTraits(.isHeader)
      if let tagline = loader.detail?.tagline, !tagline.isEmpty {
        Text(tagline).font(.subheadline.italic()).foregroundStyle(.secondary).lineLimit(2)
      }
      HStack(spacing: 6) {
        if current.rating > 0 {
          Label(String(format: "%.1f", current.rating), systemImage: "star.fill")
            .foregroundStyle(.yellow)
        }
        Text(loader.meta.joined(separator: " · "))
          .foregroundStyle(.secondary)
      }
      .font(.subheadline.weight(.medium))
      .lineLimit(1)
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 12)
  }

  // MARK: Acciones

  private var actionBar: some View {
    GlassGroup(spacing: 10) {
      HStack(spacing: 10) {
        Button {
          library.toggle(current, in: .watchlist)
        } label: {
          Label {
            library.isInWatchlist(current) ? Text("Guardada") : Text("Watchlist")
          } icon: {
            Image(systemName: library.isInWatchlist(current) ? "checkmark" : "plus")
          }
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .glassProminentButtonStyle()
        .controlSize(.large)

        circleButton(library.isFavorite(current) ? "heart.fill" : "heart",
                     label: library.isFavorite(current) ? "Quitar de favoritos" : "Favorito",
                     tint: library.isFavorite(current) ? .pink : nil) {
          library.toggle(current, in: .favorite)
        }
        circleButton(library.isWatched(current) ? "eye.fill" : "eye",
                     label: library.isWatched(current) ? "Marcar como no vista" : "Marcar como vista",
                     tint: library.isWatched(current) ? .green : nil) {
          library.toggle(current, in: .watched)
        }
        Menu {
          ForEach(library.visibleLists) { list in
            Button {
              library.toggle(current, inList: list.id)
            } label: {
              if library.list(list.id, contains: current.key) {
                Label(list.name, systemImage: "checkmark")
              } else {
                Text(list.name)
              }
            }
          }
          Divider()
          Button {
            if pro.isPro || library.visibleLists.count < AppConfig.Pro.freeListLimit {
              showingNewList = true
            } else {
              pro.presentListLimit(reason: String(localized: "Con Pro creas todas las listas que quieras."))
            }
          } label: {
            Label("Nueva lista…", systemImage: "plus")
          }
          ShareLinkButton(item: current)
        } label: {
          Image(systemName: "ellipsis")
            .font(.headline)
            .frame(width: 28, height: 28)
        }
        .glassButtonStyle()
        .controlSize(.large)
        .accessibilityLabel("Más opciones")
      }
    }
  }

  private func circleButton(_ icon: String, label: LocalizedStringKey, tint: Color?, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.headline)
        .foregroundStyle(tint ?? .primary)
        .frame(width: 28, height: 28)
    }
    .glassButtonStyle()
    .controlSize(.large)
    .accessibilityLabel(label)
  }

  // MARK: Nota

  private var ratingRow: some View {
    HStack(spacing: 4) {
      Text("Tu nota")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
      Spacer()
      let mine = library.rating(for: current.key) ?? 0
      ForEach(1...5, id: \.self) { i in
        Button {
          let score = Double(i * 2)
          library.rate(current, score: mine == score ? nil : score)
        } label: {
          Image(systemName: mine >= Double(i * 2) ? "star.fill" : (mine >= Double(i * 2 - 1) ? "star.leadinghalf.filled" : "star"))
            .font(.title3)
            .foregroundStyle(mine >= Double(i * 2 - 1) ? Color.yellow : Color.secondary.opacity(0.5))
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(i) de 5 estrellas")
        .accessibilityAddTraits(mine >= Double(i * 2) ? .isSelected : [])
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 4)
    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: Reseña personal

  private var reviewSection: some View {
    let review = library.review(for: current.key) ?? ""
    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Tu reseña")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        if !editingReview {
          Button {
            reviewDraft = review
            editingReview = true
          } label: {
            Label(review.isEmpty ? "Escribir" : "Editar", systemImage: "square.and.pencil")
              .font(.footnote.weight(.semibold))
          }
        }
      }
      if editingReview {
        VStack(alignment: .leading, spacing: 8) {
          TextField("¿Qué te pareció?", text: $reviewDraft, axis: .vertical)
            .lineLimit(3...6)
            .textFieldStyle(.plain)
          HStack {
            Spacer()
            Button("Cancelar") { editingReview = false }
            Button("Guardar") {
              library.setReview(current, reviewDraft)
              editingReview = false
            }
            .font(.subheadline.weight(.semibold))
          }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      } else if !review.isEmpty {
        Text(review)
          .font(.subheadline)
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
    }
  }

  // MARK: Sinopsis

  @ViewBuilder
  private var overview: some View {
    if !current.overview.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        Text(current.overview)
          .font(.body)
          .lineLimit(overviewExpanded ? nil : 4)
          .fixedSize(horizontal: false, vertical: true)
        if current.overview.count > 220 {
          Button(overviewExpanded ? LocalizedStringKey("Menos") : LocalizedStringKey("Más")) {
            withAnimation(.easeInOut(duration: 0.25)) { overviewExpanded.toggle() }
          }
          .font(.subheadline.weight(.semibold))
        }
      }
    }
  }

  // MARK: Temporadas

  private var seasonsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Episodios").font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
        Spacer()
        let aired = loader.episodes.filter(\.hasAired).map(\.number)
        if !aired.isEmpty {
          let watched = library.seasonWatchedCount(tvId: current.id, season: loader.selectedSeason)
          Text(verbatim: "\(min(watched, aired.count))/\(aired.count)")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
          Button(watched >= aired.count ? LocalizedStringKey("Desmarcar") : LocalizedStringKey("Marcar todo")) {
            library.toggleSeason(tvId: current.id, season: loader.selectedSeason, episodeNumbers: aired)
          }
          .font(.subheadline.weight(.semibold))
        }
      }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(loader.seasons, id: \.seasonNumber) { s in
            let selected = s.seasonNumber == loader.selectedSeason
            Button {
              loader.selectedSeason = s.seasonNumber
              Task { await loader.loadEpisodes() }
            } label: {
              Text(s.name ?? String(localized: "Temporada \(s.seasonNumber)"))
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color(.systemBackground) : .primary)
                .background(selected ? Color.primary : Color(.secondarySystemFill), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
          }
        }
      }
      if loader.loadingEpisodes && loader.episodes.isEmpty {
        ProgressView().frame(maxWidth: .infinity)
      }
      VStack(spacing: 14) {
        ForEach(loader.episodes) { ep in
          EpisodeCell(show: current, season: loader.selectedSeason, episode: ep)
        }
      }
    }
  }

  // MARK: Tráiler

  private func trailerSection(_ key: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Tráiler").font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
      TrailerCard(key: key) { showingTrailer = true }
    }
  }

  // MARK: Dónde verla

  private var providersSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Dónde verla").font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 14) {
          ForEach(loader.providers) { ProviderBadge(provider: $0, title: current.title) }
        }
      }
      Text("Disponibilidad en \(Locale.current.localizedString(forRegionCode: TMDBClient.userRegion) ?? TMDBClient.userRegion) con datos de JustWatch.")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: Reparto

  private var castSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Reparto").font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 16) {
          ForEach(loader.cast) { person in
            NavigationLink(destination: ActorView(personId: person.id, personName: person.name)) {
              VStack(spacing: 6) {
                RemoteImage(url: TMDBImage.url(path: person.profilePath, size: "w185"), placeholderIcon: "person.fill")
                  .frame(width: 84, height: 84)
                  .clipShape(Circle())
                Text(person.name)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.primary)
                  .lineLimit(2)
                  .multilineTextAlignment(.center)
                if !person.character.isEmpty {
                  Text(person.character)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
              }
              .frame(width: 88)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(person.name), \(person.character)")
            .accessibilityHint("Abre su perfil")
          }
        }
        .padding(.horizontal, 20)
      }
      .padding(.horizontal, -20)
    }
  }
}

/// Imagen de cabecera que se estira al tirar hacia abajo (como Apple TV y Música).
private struct StretchyHeader: View {
  let path: String
  let height: CGFloat

  var body: some View {
    GeometryReader { geo in
      let minY = geo.frame(in: .named("detailScroll")).minY
      let stretch = max(0, minY)
      RemoteImage(url: TMDBImage.url(path: path, size: "w1280"))
        .frame(width: geo.size.width, height: height + stretch)
        .clipped()
        .overlay(
          LinearGradient(stops: [
            .init(color: .black.opacity(0.45), location: 0),
            .init(color: .clear, location: 0.25),
            .init(color: .clear, location: 0.45),
            .init(color: Color(.systemBackground).opacity(0.9), location: 0.85),
            .init(color: Color(.systemBackground), location: 1),
          ], startPoint: .top, endPoint: .bottom)
        )
        .offset(y: -stretch)
    }
    .frame(height: height)
    .accessibilityHidden(true)
  }
}

private struct EpisodeCell: View {
  @EnvironmentObject private var library: LibraryStore
  let show: MediaItem
  let season: Int
  let episode: EpisodeItem

  private var watched: Bool { library.isEpisodeWatched(tvId: show.id, season: season, episode: episode.number) }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      RemoteImage(url: TMDBImage.url(path: episode.stillPath, size: "w300"), placeholderIcon: "tv")
        .frame(width: 128, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(episode.hasAired ? 1 : 0.5)
      VStack(alignment: .leading, spacing: 3) {
        Text(verbatim: "\(episode.number). \(episode.title)")
          .font(.subheadline.weight(.semibold))
          .lineLimit(2)
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
        if !episode.overview.isEmpty {
          Text(episode.overview)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      Spacer(minLength: 0)
      if episode.hasAired {
        Button {
          library.toggleEpisode(tvId: show.id, season: season, episode: episode.number)
        } label: {
          Image(systemName: watched ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(watched ? Color.accentColor : Color.secondary.opacity(0.6))
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(watched ? Text("Episodio \(episode.number) visto. Desmarcar") : Text("Marcar episodio \(episode.number) como visto"))
      }
    }
    .accessibilityElement(children: .contain)
  }

  private var subtitle: String {
    var parts: [String] = []
    if let date = UpNextStore.parseDay(episode.airDate) {
      parts.append(episode.hasAired
        ? date.formatted(.dateTime.day().month(.abbreviated).year())
        : String(localized: "Se estrena el \(date.formatted(.dateTime.day().month(.wide)))"))
    }
    if let r = episode.runtime, r > 0 { parts.append(String(localized: "\(r) min")) }
    return parts.joined(separator: " · ")
  }
}

/// Logo del proveedor. Tap: su app si está instalada → su ficha del App Store → su web.
private struct ProviderBadge: View {
  let provider: TMDBProvider
  let title: String

  var body: some View {
    Button(action: open) {
      VStack(spacing: 6) {
        RemoteImage(url: TMDBImage.url(path: provider.logoPath, size: "w154"), placeholderIcon: "play.tv")
          .frame(width: 56, height: 56)
          .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        Text(provider.providerName)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .frame(width: 72)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Ver en \(provider.providerName)")
  }

  private func open() {
    let app = ProviderLinks.appURL(for: provider, title: title)
    let application = UIApplication.shared
    if let app, application.canOpenURL(app) {
      application.open(app)
    } else if let store = ProviderLinks.appStoreURL(for: provider) {
      application.open(store)
    } else if let web = ProviderLinks.webURL(for: provider, title: title, region: TMDBClient.userRegion) {
      application.open(web)
    }
  }
}
