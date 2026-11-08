import SwiftUI

/// Imagen remota de TMDB con placeholder y fundido al cargar.
struct RemoteImage: View {
  let url: URL?
  var placeholderIcon: String = "film"

  /// `Color.clear` toma el tamaño propuesto y la imagen lo rellena encima:
  /// así `scaledToFill` nunca agranda el contenedor (el héroe no se desborda).
  var body: some View {
    Color.clear
      .overlay(content)
      .clipped()
  }

  @ViewBuilder
  private var content: some View {
    if let url {
      AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
        switch phase {
        case .success(let image):
          image.resizable().scaledToFill()
        case .failure:
          placeholder
        default:
          placeholder.overlay(ProgressView().opacity(0.5))
        }
      }
    } else {
      placeholder
    }
  }

  private var placeholder: some View {
    Rectangle()
      .fill(Color(.secondarySystemFill))
      .overlay(Image(systemName: placeholderIcon).font(.title2).foregroundStyle(.tertiary))
  }
}

/// Póster 2:3 con esquinas continuas y borde sutil (como el App Store).
struct PosterImage: View {
  let path: String
  var width: CGFloat = 120

  var body: some View {
    RemoteImage(url: TMDBImage.url(path: path, size: width > 160 ? "w500" : "w342"), placeholderIcon: "popcorn")
      .frame(width: width, height: width * 1.5)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
      )
  }
}

/// Póster con título debajo, enlace al detalle y menú contextual.
struct PosterCard: View {
  let item: MediaItem
  var width: CGFloat = 120
  var showTitle = true
  var badge: String? = nil

  var body: some View {
    NavigationLink(destination: DetailView(item: item)) {
      VStack(alignment: .leading, spacing: 6) {
        PosterImage(path: item.posterPath, width: width)
          .overlay(alignment: .topTrailing) {
            if let badge {
              Text(badge)
                .font(.caption2.weight(.bold).monospacedDigit())
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(6)
            }
          }
        if showTitle {
          Text(item.title)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
          if !item.year.isEmpty {
            Text(item.year).font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      .frame(width: width, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .mediaContextMenu(item)
    .accessibilityElement(children: .combine)
    .accessibilityLabel([item.title, item.year, item.kind.label].filter { !$0.isEmpty }.joined(separator: ", "))
    .accessibilityHint("Abre la ficha. Mantén pulsado para más opciones.")
  }
}

/// Fila horizontal de pósters.
struct PosterRail<Header: View>: View {
  let items: [MediaItem]
  var width: CGFloat = 120
  @ViewBuilder var header: Header

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 14) {
          ForEach(items) { PosterCard(item: $0, width: width) }
        }
        .padding(.horizontal, 20)
      }
    }
  }
}

/// Acciones rápidas al mantener pulsado un título.
struct MediaContextMenu: ViewModifier {
  @EnvironmentObject private var library: LibraryStore
  let item: MediaItem

  func body(content: Content) -> some View {
    content.contextMenu {
      Button {
        library.toggle(item, in: .watchlist)
      } label: {
        library.isInWatchlist(item)
          ? Label("Quitar de Watchlist", systemImage: "bookmark.slash")
          : Label("Añadir a Watchlist", systemImage: "bookmark")
      }
      Button {
        library.toggle(item, in: .favorite)
      } label: {
        library.isFavorite(item)
          ? Label("Quitar de favoritos", systemImage: "heart.slash")
          : Label("Favorito", systemImage: "heart")
      }
      Button {
        library.toggle(item, in: .watched)
      } label: {
        library.isWatched(item)
          ? Label("Marcar como no vista", systemImage: "eye.slash")
          : Label("Marcar como vista", systemImage: "checkmark.circle")
      }
      if !library.visibleLists.isEmpty {
        Menu {
          ForEach(library.visibleLists) { list in
            Button {
              library.toggle(item, inList: list.id)
            } label: {
              if library.list(list.id, contains: item.key) {
                Label(list.name, systemImage: "checkmark")
              } else {
                Text(list.name)
              }
            }
          }
        } label: {
          Label("Añadir a lista", systemImage: "text.badge.plus")
        }
      }
      ShareLinkButton(item: item)
    }
  }
}

extension View {
  func mediaContextMenu(_ item: MediaItem) -> some View { modifier(MediaContextMenu(item: item)) }
}

/// Compartir: `ShareLink` en iOS 16+, hoja del sistema en iOS 15.
struct ShareLinkButton: View {
  let item: MediaItem

  var body: some View {
    if #available(iOS 16, *) {
      ShareLink(item: item.shareURL, subject: Text(item.title), message: Text(item.shareText)) {
        Label("Compartir", systemImage: "square.and.arrow.up")
      }
    } else {
      Button {
        ShareSheet.present(items: [item.shareText, item.shareURL])
      } label: {
        Label("Compartir", systemImage: "square.and.arrow.up")
      }
    }
  }
}

enum ShareSheet {
  @MainActor static func present(items: [Any]) {
    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
    AdsManager.rootViewController()?.present(vc, animated: true)
  }
}

extension MediaItem {
  var shareURL: URL {
    URL(string: "https://www.themoviedb.org/\(kind == .movie ? "movie" : "tv")/\(id)")!
  }

  var shareText: String { "Mira «\(title)» — la encontré en Películas" }
}
