import SwiftUI

struct RootView: View {
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var achievements: AchievementStore
  @EnvironmentObject private var router: DeepLinkRouter
  @EnvironmentObject private var pro: ProStore
  @AppStorage("peliculas.onboarded.v2") private var onboarded = false

  var body: some View {
    tabs
      .overlay(alignment: .top) { AchievementToast() }
      .onChange(of: LibraryCounts(library)) { _, counts in achievements.check(counts) }
      .modalHost(.root)
      .sheet(isPresented: $router.showingAccount) { AccountView().modalHost(.account) }
      .sheet(item: $router.presented) { item in
        AppNavigation {
          DetailView(item: item)
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { router.presented = nil }
              }
            }
        }
        .modalHost(.detail)
      }
      .fullScreenCover(isPresented: Binding(get: { !onboarded }, set: { onboarded = !$0 })) {
        OnboardingView { onboarded = true }
      }
  }

  @ViewBuilder
  private var tabs: some View {
    if #available(iOS 18, *) {
      TabView(selection: $router.tab) {
        Tab("Inicio", systemImage: "play.house.fill", value: AppTab.home) { HomeView() }
        Tab("Siguiente", systemImage: "play.square.stack.fill", value: AppTab.upNext) { UpNextView() }
        Tab("Biblioteca", systemImage: "books.vertical.fill", value: AppTab.library) { LibraryView() }
        Tab(value: AppTab.search, role: .search) { SearchView() }
      }
      .minimizingTabBar()
    } else {
      TabView(selection: $router.tab) {
        HomeView()
          .tabItem { Label("Inicio", systemImage: "play.house.fill") }
          .tag(AppTab.home)
        UpNextView()
          .tabItem { Label("Siguiente", systemImage: "play.square.stack.fill") }
          .tag(AppTab.upNext)
        LibraryView()
          .tabItem { Label("Biblioteca", systemImage: "books.vertical.fill") }
          .tag(AppTab.library)
        SearchView()
          .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
          .tag(AppTab.search)
      }
    }
  }
}

/// Botón de cuenta arriba a la derecha (patrón de App Store, Música y TV).
struct AccountButton: View {
  @EnvironmentObject private var session: SessionStore
  @EnvironmentObject private var router: DeepLinkRouter

  var body: some View {
    Button { router.showingAccount = true } label: {
      if let user = session.user {
        InitialsAvatar(initials: user.initials, size: 32)
      } else {
        Image(systemName: "person.crop.circle")
          .font(.title3)
      }
    }
    .accessibilityLabel("Cuenta y ajustes")
  }
}

extension View {
  /// Añade el botón de cuenta al toolbar de una pantalla raíz.
  func accountToolbar() -> some View {
    toolbar {
      ToolbarItem(placement: .navigationBarTrailing) { AccountButton() }
    }
  }
}

/// Aviso de logro: cápsula de vidrio que baja y se va sola (no bloquea como una alerta).
struct AchievementToast: View {
  @EnvironmentObject private var achievements: AchievementStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      if let item = achievements.toast {
        HStack(spacing: 12) {
          Image(systemName: item.icon)
            .font(.title3)
            .foregroundStyle(.yellow)
            .frame(width: 36, height: 36)
          VStack(alignment: .leading, spacing: 1) {
            Text("Logro desbloqueado").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(item.name).font(.subheadline.weight(.bold))
          }
          Text(verbatim: "+\(item.points)")
            .font(.subheadline.weight(.heavy).monospacedDigit())
            .foregroundStyle(.tint)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassCapsule()
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .padding(.top, 6)
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Logro desbloqueado: \(item.name), más \(item.points) puntos")
        .onTapGesture { achievements.toast = nil }
        .task(id: item.id) {
          try? await Task.sleep(nanoseconds: 3_500_000_000)
          withAnimation { achievements.toast = nil }
        }
      }
    }
    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: achievements.toast)
  }
}

/// SwiftUI solo presenta una hoja por nivel. El login y el paywall se abren
/// desde la capa visible: la raíz, la hoja de Cuenta o un detalle abierto por enlace.
enum ModalLevel { case root, account, detail }

private struct ModalHost: ViewModifier {
  @EnvironmentObject private var router: DeepLinkRouter
  @EnvironmentObject private var pro: ProStore
  let level: ModalLevel

  private var active: Bool {
    switch level {
    case .root: return !router.showingAccount && router.presented == nil
    case .account: return router.showingAccount
    case .detail: return router.presented != nil && !router.showingAccount
    }
  }

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: Binding(get: { active && pro.showingPaywall }, set: { if !$0 { pro.showingPaywall = false } })) {
        PaywallView()
      }
      .sheet(isPresented: Binding(get: { active && router.showingSignIn }, set: { if !$0 { router.showingSignIn = false } })) {
        SignInView()
      }
  }
}

extension View {
  func modalHost(_ level: ModalLevel) -> some View { modifier(ModalHost(level: level)) }
}
