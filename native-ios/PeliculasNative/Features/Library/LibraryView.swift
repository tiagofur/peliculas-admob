import SwiftUI

/// Biblioteca estilo Música: categorías arriba, lo añadido recientemente debajo.
struct LibraryView: View {
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var session: SessionStore
  @EnvironmentObject private var router: DeepLinkRouter

  var body: some View {
    AppNavigation {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          categories
          if !session.isSignedIn { syncBanner }
          let recentlyAdded = recentlyAddedItems
          if recentlyAdded.isEmpty {
            EmptyState(icon: "books.vertical", title: "Tu biblioteca está vacía",
                       message: "Mantén pulsado cualquier póster o usa los botones de la ficha para guardar títulos aquí.") {
              Button("Explorar") { router.tab = .home }.glassProminentButtonStyle()
            }
            .frame(minHeight: 280)
          } else {
            VStack(alignment: .leading, spacing: 12) {
              SectionHeader(String(localized: "Añadido recientemente"))
              PosterGrid(items: recentlyAdded)
            }
          }
        }
        .padding(.vertical, 8)
      }
      .refreshable { await library.sync() }
      .navigationTitle("Biblioteca")
      .accountToolbar()
    }
  }

  private var categories: some View {
    VStack(spacing: 0) {
      row("Watchlist", icon: "bookmark.fill", color: .orange, count: library.count(.watchlist)) {
        LibraryGridView(kind: .watchlist)
      }
      Divider().padding(.leading, 60)
      row("Favoritos", icon: "heart.fill", color: .pink, count: library.count(.favorite)) {
        LibraryGridView(kind: .favorite)
      }
      Divider().padding(.leading, 60)
      row("Vistas", icon: "checkmark.circle.fill", color: .green, count: library.count(.watched)) {
        LibraryGridView(kind: .watched)
      }
      Divider().padding(.leading, 60)
      row("Calificadas", icon: "star.fill", color: .yellow, count: library.ratedCount) {
        RatedGridView()
      }
      Divider().padding(.leading, 60)
      row("Listas", icon: "list.star", color: .indigo, count: library.visibleLists.count) {
        ListsView()
      }
    }
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .padding(.horizontal, 20)
  }

  private func row<D: View>(_ title: LocalizedStringKey, icon: String, color: Color, count: Int, @ViewBuilder destination: () -> D) -> some View {
    NavigationLink(destination: destination()) {
      HStack(spacing: 14) {
        Image(systemName: icon)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 30, height: 30)
          .background(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        Text(title).font(.body)
        Spacer()
        if count > 0 {
          Text(verbatim: "\(count)").font(.body.monospacedDigit()).foregroundStyle(.secondary)
        }
        Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(title) + Text(verbatim: ", \(count)"))
  }

  private var syncBanner: some View {
    HStack(spacing: 14) {
      Image(systemName: "icloud.and.arrow.up")
        .font(.title2)
        .foregroundStyle(.tint)
      VStack(alignment: .leading, spacing: 2) {
        Text("Lleva tu biblioteca contigo").font(.subheadline.weight(.semibold))
        Text("Inicia sesión para sincronizarla entre tus dispositivos.").font(.caption).foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
      Button("Entrar") { router.showingSignIn = true }
        .glassButtonStyle()
        .controlSize(.small)
    }
    .padding(16)
    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .padding(.horizontal, 20)
  }

  private var recentlyAddedItems: [MediaItem] {
    var seen = Set<MediaKey>()
    let all = LibraryKind.allCases.flatMap { kind in
      (library.marks[kind] ?? [:]).filter { !$0.value.deleted }.map { ($0.key, $0.value.updatedAt) }
    }
    return all.sorted { $0.1 > $1.1 }
      .compactMap { key, _ in seen.insert(key).inserted ? library.item(for: key) : nil }
      .prefix(24).map { $0 }
  }
}

/// Cuadrícula de una sección, con filtro Películas/Series.
struct LibraryGridView: View {
  @EnvironmentObject private var library: LibraryStore
  let kind: LibraryKind
  @State private var filter: MediaKind? = nil

  private var title: LocalizedStringKey {
    switch kind {
    case .watchlist: return "Watchlist"
    case .favorite: return "Favoritos"
    case .watched: return "Vistas"
    }
  }

  var body: some View {
    let items = library.items(in: kind).filter { filter == nil || $0.kind == filter }
    ScrollView {
      VStack(spacing: 16) {
        Picker("Tipo", selection: $filter) {
          Text("Todo").tag(MediaKind?.none)
          Text("Películas").tag(MediaKind?.some(.movie))
          Text("Series").tag(MediaKind?.some(.tv))
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        if items.isEmpty {
          EmptyState(icon: icon, title: "Nada por aquí", message: emptyMessage)
            .frame(minHeight: 320)
        } else {
          PosterGrid(items: items)
        }
      }
      .padding(.vertical, 8)
    }
    .refreshable { await library.sync() }
    .navigationTitle(title)
  }

  private var icon: String {
    switch kind {
    case .watchlist: return "bookmark"
    case .favorite: return "heart"
    case .watched: return "checkmark.circle"
    }
  }

  private var emptyMessage: LocalizedStringKey {
    switch kind {
    case .watchlist: return "Guarda lo que quieras ver más tarde con el botón Watchlist."
    case .favorite: return "Toca el corazón en la ficha de lo que más te guste."
    case .watched: return "Marca lo que ya viste con el ojo de la ficha."
    }
  }
}

private struct RatedGridView: View {
  @EnvironmentObject private var library: LibraryStore

  var body: some View {
    let items = library.ratedItems()
    ScrollView {
      if items.isEmpty {
        EmptyState(icon: "star", title: "Aún no calificas nada", message: "Toca las estrellas en la ficha de un título.")
          .frame(minHeight: 360)
      } else {
        PosterGrid(items: items) { item in
          library.rating(for: item.key).map { String(format: $0.truncatingRemainder(dividingBy: 1) == 0 ? "★ %.0f" : "★ %.1f", $0) }
        }
        .padding(.vertical)
      }
    }
    .navigationTitle("Calificadas")
  }
}

/// Listas propias: crear, renombrar y borrar (gratis hasta 3, ilimitadas con Pro).
struct ListsView: View {
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var pro: ProStore
  @State private var creating = false
  @State private var renaming: CustomMediaList?
  @State private var name = ""

  var body: some View {
    List {
      if library.visibleLists.isEmpty {
        Section {
          EmptyState(icon: "list.star", title: "Crea tu primera lista", message: "Agrupa títulos como quieras: \"Para ver en pareja\", \"Clásicos\"…")
            .listRowBackground(Color.clear)
        }
      }
      ForEach(library.visibleLists) { list in
        NavigationLink(destination: ListDetailView(listId: list.id)) {
          HStack(spacing: 14) {
            ListCover(items: list.items)
            VStack(alignment: .leading, spacing: 2) {
              Text(list.name).font(.body.weight(.medium))
              Text("\(list.items.count) títulos")
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          .padding(.vertical, 4)
        }
        .swipeActions {
          Button(role: .destructive) { library.deleteList(list.id) } label: { Label("Borrar", systemImage: "trash") }
          Button { name = list.name; renaming = list } label: { Label("Renombrar", systemImage: "pencil") }
        }
        .contextMenu {
          Button { name = list.name; renaming = list } label: { Label("Renombrar", systemImage: "pencil") }
          Button(role: .destructive) { library.deleteList(list.id) } label: { Label("Borrar lista", systemImage: "trash") }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Listas")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          if pro.isPro || library.visibleLists.count < AppConfig.Pro.freeListLimit {
            name = ""
            creating = true
          } else {
            pro.presentPaywall(reason: String(localized: "La versión gratis incluye \(AppConfig.Pro.freeListLimit) listas. Con Pro, ilimitadas."))
          }
        } label: {
          Image(systemName: "plus")
        }
        .accessibilityLabel("Nueva lista")
      }
    }
    .alert("Nueva lista", isPresented: $creating) {
      TextField("Nombre", text: $name)
      Button("Crear") {
        if !name.trimmingCharacters(in: .whitespaces).isEmpty { library.createList(named: name) }
      }
      Button("Cancelar", role: .cancel) {}
    }
    .alert("Renombrar lista", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
      TextField("Nombre", text: $name)
      Button("Guardar") {
        if let list = renaming, !name.trimmingCharacters(in: .whitespaces).isEmpty { library.renameList(list.id, to: name) }
        renaming = nil
      }
      Button("Cancelar", role: .cancel) { renaming = nil }
    }
  }
}

/// Collage 2×2 de pósters como portada de la lista.
private struct ListCover: View {
  let items: [MediaItem]

  var body: some View {
    let paths = items.prefix(4).map(\.posterPath)
    LazyVGrid(columns: [GridItem(.fixed(26), spacing: 2), GridItem(.fixed(26), spacing: 2)], spacing: 2) {
      ForEach(0..<4, id: \.self) { i in
        RemoteImage(url: i < paths.count ? TMDBImage.url(path: paths[i], size: "w92") : nil, placeholderIcon: "film")
          .frame(width: 26, height: 26)
          .clipped()
      }
    }
    .frame(width: 54, height: 54)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .accessibilityHidden(true)
  }
}

private struct ListDetailView: View {
  @EnvironmentObject private var library: LibraryStore
  let listId: String

  var body: some View {
    let items = library.itemsOfList(listId)
    let name = library.lists[listId]?.name ?? String(localized: "Lista")
    ScrollView {
      if items.isEmpty {
        EmptyState(icon: "text.badge.plus", title: "Lista vacía",
                   message: "Añade títulos desde su ficha (botón ⋯) o manteniendo pulsado un póster.")
          .frame(minHeight: 360)
      } else {
        PosterGrid(items: items).padding(.vertical)
      }
    }
    .navigationTitle(name)
  }
}
