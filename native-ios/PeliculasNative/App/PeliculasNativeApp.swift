import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    UNUserNotificationCenter.current().delegate = PushManager.shared
    // Caché de imágenes de TMDB (AsyncImage usa la sesión compartida).
    URLCache.shared.memoryCapacity = 60 << 20
    URLCache.shared.diskCapacity = 300 << 20
    return true
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Task { @MainActor in PushManager.shared.didRegister(deviceToken: deviceToken) }
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}
}

@main
struct PeliculasNativeApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @Environment(\.scenePhase) private var scenePhase

  @StateObject private var library = LibraryStore()
  @StateObject private var achievements = AchievementStore()
  @StateObject private var reminders = ReminderManager()
  @StateObject private var upNext = UpNextStore()
  @ObservedObject private var session = SessionStore.shared
  @ObservedObject private var pro = ProStore.shared
  @ObservedObject private var router = DeepLinkRouter.shared

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(library)
        .environmentObject(achievements)
        .environmentObject(reminders)
        .environmentObject(upNext)
        .environmentObject(session)
        .environmentObject(pro)
        .environmentObject(router)
        .onOpenURL { router.open($0) }
        .task { wireUp() }
        .onChange(of: scenePhase) { _, phase in
          switch phase {
          case .active:
            Task {
              await library.sync()
              await pro.refresh()
              await PushManager.shared.refreshStatus()
              reminders.reschedule(watchlistCount: library.count(.watchlist))
            }
          case .background:
            library.saveNow()
          default:
            break
          }
        }
    }
  }

  /// Conecta la sesión con el resto: al entrar se sube la biblioteca local y se
  /// reclaman las compras; al salir se quita el dispositivo y se vacía lo local.
  private func wireUp() {
    let library = library
    session.didSignIn = [
      { await library.mergeAfterSignIn() },
      { await ProStore.shared.claimAll() },
      { await PushManager.shared.upload() },
      { await SessionStore.shared.refreshProfile() },
    ]
    session.willSignOut = [
      { await PushManager.shared.unregister() },
      { library.resetForSignOut() },
    ]
    AdsManager.shared.start()
    achievements.check(LibraryCounts(library))
  }
}
