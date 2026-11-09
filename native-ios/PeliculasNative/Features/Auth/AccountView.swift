import StoreKit
import SwiftUI

/// Cuenta y ajustes (hoja desde el avatar, como App Store y Música).
struct AccountView: View {
  @EnvironmentObject private var session: SessionStore
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var pro: ProStore
  @EnvironmentObject private var achievements: AchievementStore
  @EnvironmentObject private var reminders: ReminderManager
  @EnvironmentObject private var router: DeepLinkRouter
  @ObservedObject private var push = PushManager.shared
  @Environment(\.dismiss) private var dismiss

  @State private var confirmSignOut = false
  @State private var confirmDelete = false
  @State private var managingSubscription = false
  @State private var errorMessage: String?

  var body: some View {
    AppNavigation {
      List {
        profileSection
        // Oculto mientras Pro no se vende, salvo para quien ya lo compró (docs/PRO.md).
        if AppConfig.Pro.salesEnabled || pro.isPro { proSection }
        activitySection
        notificationsSection
        if session.isSignedIn { syncSection }
        privacySection
        aboutSection
        if session.isSignedIn { accountSection }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Cuenta")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
      }
      .manageSubscriptionsSheet(isPresented: $managingSubscription)
      .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmSignOut, titleVisibility: .visible) {
        Button("Cerrar sesión", role: .destructive) { Task { await session.signOut() } }
      } message: {
        Text("Tu biblioteca queda guardada en tu cuenta y se quita de este iPhone.")
      }
      .confirmationDialog("¿Borrar tu cuenta?", isPresented: $confirmDelete, titleVisibility: .visible) {
        Button("Borrar cuenta y datos", role: .destructive) {
          Task {
            do { try await session.deleteAccount() } catch {
              errorMessage = (error as? LocalizedError)?.errorDescription
            }
          }
        }
      } message: {
        Text("Se borran para siempre tu cuenta, biblioteca, listas, notas y progreso. Las suscripciones se cancelan aparte en Ajustes › Apple ID.")
      }
      .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
        Button("OK", role: .cancel) {}
      }
    }
    .task { await push.refreshStatus() }
  }

  // MARK: Secciones

  private var profileSection: some View {
    Section {
      if let user = session.user {
        HStack(spacing: 14) {
          InitialsAvatar(initials: user.initials, size: 56)
          VStack(alignment: .leading, spacing: 2) {
            Text(user.shownName).font(.title3.weight(.semibold))
            Text(user.email).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
          }
        }
        .padding(.vertical, 6)
      } else {
        Button { router.showingSignIn = true } label: {
          HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
              .font(.system(size: 48))
              .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
              Text("Inicia sesión").font(.title3.weight(.semibold)).foregroundStyle(.primary)
              Text("Sincroniza tu biblioteca y tus series en todos tus dispositivos.")
                .font(.subheadline).foregroundStyle(.secondary)
            }
          }
          .padding(.vertical, 6)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var proSection: some View {
    Section {
      if pro.isPro {
        HStack {
          Label(pro.planName, systemImage: "sparkles")
            .foregroundStyle(.primary)
          Spacer()
          if let exp = pro.expiresAt {
            Text("Hasta el \(exp.formatted(.dateTime.day().month(.abbreviated).year()))")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        if pro.activeProductID != AppConfig.Pro.lifetime {
          Button("Gestionar suscripción") { managingSubscription = true }
        }
      } else {
        Button { pro.presentPaywall() } label: {
          HStack(spacing: 14) {
            Image(systemName: "sparkles.tv.fill")
              .font(.title2)
              .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 2) {
              Text("Películas Pro").font(.headline).foregroundStyle(.primary)
              Text("Avisos de episodios y listas ilimitadas.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      Button("Restaurar compras") { Task { await pro.restore() } }
    }
  }

  private var activitySection: some View {
    Section("Tu actividad") {
      HStack {
        stat(library.count(.watched), "Vistas")
        stat(library.watchedEpisodeCount, "Episodios")
        stat(library.ratedCount, "Notas")
        stat(achievements.totalPoints, "Puntos")
      }
      .padding(.vertical, 4)
      NavigationLink(destination: AchievementsView()) {
        HStack {
          Label("Logros", systemImage: "trophy.fill")
          Spacer()
          Text(verbatim: "\(achievements.unlockedCount)/\(achievements.totalCount)").foregroundStyle(.secondary)
        }
      }
    }
  }

  private func stat(_ value: Int, _ label: LocalizedStringKey) -> some View {
    VStack(spacing: 2) {
      Text(verbatim: "\(value)").font(.title3.weight(.bold).monospacedDigit())
      Text(label).font(.caption2).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
  }

  private var notificationsSection: some View {
    Section {
      // Avisos de episodios: función Pro, oculta mientras Pro no se vende (docs/PRO.md).
      if showsEpisodeAlerts {
        Toggle(isOn: Binding(get: { push.status == .authorized && push.registered },
                             set: { on in Task { await setEpisodeAlerts(on) } })) {
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Text("Episodios nuevos")
              if !pro.isPro { ProBadge() }
            }
            Text("Te avisamos el día del estreno de tus series.").font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      Toggle(isOn: Binding(get: { reminders.enabled },
                           set: { on in Task { await reminders.setEnabled(on, watchlistCount: library.count(.watchlist)) } })) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Recordatorios semanales")
          Text("Tendencias del viernes y tu watchlist del domingo.").font(.caption).foregroundStyle(.secondary)
        }
      }
      if push.status == .denied {
        Button("Activar notificaciones en Ajustes") {
          if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }
      }
      #if DEBUG
      if session.isSignedIn {
        Button("Enviar aviso de prueba") { Task { await push.sendTest() } }
        if let m = push.lastMessage { Text(m).font(.caption).foregroundStyle(.secondary) }
      }
      #endif
    } header: {
      Text("Avisos")
    } footer: {
      if showsEpisodeAlerts && !session.isSignedIn { Text("Los avisos de episodios necesitan una cuenta.") }
    }
  }

  private var showsEpisodeAlerts: Bool { AppConfig.Pro.salesEnabled || pro.isPro }

  private func setEpisodeAlerts(_ on: Bool) async {
    guard session.isSignedIn else { router.showingSignIn = true; return }
    if on {
      guard pro.isPro else { pro.presentPaywall(reason: String(localized: "Los avisos de episodios nuevos son parte de Pro.")); return }
      if await push.requestPermission() { await push.upload() }
    } else {
      await push.unregister()
    }
  }

  private var syncSection: some View {
    Section {
      HStack {
        Label("Sincronización", systemImage: "arrow.triangle.2.circlepath")
        Spacer()
        if library.syncing {
          ProgressView()
        } else if let error = library.lastSyncError {
          Text(error).font(.caption).foregroundStyle(.orange).lineLimit(2)
        } else if let date = library.lastSync {
          Text(date.formatted(.relative(presentation: .named))).font(.caption).foregroundStyle(.secondary)
        }
      }
      Button("Sincronizar ahora") { Task { await library.sync() } }
        .disabled(library.syncing)
    } footer: {
      if library.pendingChanges > 0 {
        Text("\(library.pendingChanges) cambios pendientes de subir.")
      }
    }
  }

  private var privacySection: some View {
    Section("Privacidad y ayuda") {
      if let url = AppConfig.privacyURL { Link(destination: url) { Label("Política de privacidad", systemImage: "hand.raised") } }
      if let url = AppConfig.termsURL { Link(destination: url) { Label("Términos de uso", systemImage: "doc.text") } }
      if let url = AppConfig.supportURL { Link(destination: url) { Label("Ayuda y contacto", systemImage: "questionmark.circle") } }
      Button { router.showingAccount = false; UserDefaults.standard.set(false, forKey: "peliculas.onboarded.v2") } label: {
        Label("Ver la bienvenida otra vez", systemImage: "sparkles")
      }
    }
  }

  private var aboutSection: some View {
    Section {
      HStack {
        Text("Versión")
        Spacer()
        Text(AppConfig.appVersion).foregroundStyle(.secondary)
      }
      TMDBAttribution().padding(.vertical, 4)
    }
  }

  private var accountSection: some View {
    Section {
      Button("Cerrar sesión") { confirmSignOut = true }
      Button("Borrar cuenta", role: .destructive) { confirmDelete = true }
        .disabled(session.busy)
    }
  }
}

struct ProBadge: View {
  var body: some View {
    Text("PRO")
      .font(.caption2.weight(.heavy))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .foregroundStyle(.white)
      .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing), in: Capsule())
      .accessibilityLabel("Función Pro")
  }
}
