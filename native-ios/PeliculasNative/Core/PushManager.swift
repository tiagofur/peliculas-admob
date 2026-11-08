import Foundation
import UIKit
import UserNotifications

/// Avisos de episodios nuevos por APNs (los envía el backend Go cada hora).
/// El token se registra en `POST /v1/devices` solo con sesión y permiso.
@MainActor
final class PushManager: NSObject, ObservableObject {
  static let shared = PushManager()

  @Published private(set) var status: UNAuthorizationStatus = .notDetermined
  @Published private(set) var registered = false
  @Published var lastMessage: String?

  private var token: String? {
    get { UserDefaults.standard.string(forKey: "peliculas.apns.token") }
    set { UserDefaults.standard.set(newValue, forKey: "peliculas.apns.token") }
  }

  /// Builds de Xcode → APNs sandbox; TestFlight/App Store → producción.
  private var environment: String {
    #if DEBUG
    "sandbox"
    #else
    "production"
    #endif
  }

  func refreshStatus() async {
    status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    if status == .authorized || status == .provisional {
      UIApplication.shared.registerForRemoteNotifications()
    }
  }

  /// Pide permiso en contexto (al activar los avisos), nunca al abrir la app.
  @discardableResult
  func requestPermission() async -> Bool {
    let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    await refreshStatus()
    if granted { UIApplication.shared.registerForRemoteNotifications() }
    return granted
  }

  func didRegister(deviceToken: Data) {
    token = deviceToken.map { String(format: "%02x", $0) }.joined()
    Task { await upload() }
  }

  func upload() async {
    guard let token, SessionStore.shared.isSignedIn else { return }
    let body = DeviceBody(
      token: token, environment: environment, platform: "ios",
      locale: TMDBClient.language, timezone: TimeZone.current.identifier,
      appVersion: AppConfig.appVersion
    )
    registered = (try? await APIClient.authed("POST", "/v1/devices", body: body)) != nil
  }

  func unregister() async {
    guard let token, SessionStore.shared.isSignedIn else { return }
    _ = try? await APIClient.authed("DELETE", "/v1/devices/\(token)")
    registered = false
  }

  func sendTest() async {
    do {
      let data = try await APIClient.authed("POST", "/v1/devices/test")
      let sent = (try? JSONDecoder().decode([String: Int].self, from: data))?["sent"] ?? 0
      lastMessage = sent > 0 ? String(localized: "Aviso de prueba enviado.") : String(localized: "No hay dispositivos que puedan recibirlo.")
    } catch let error as APIError where error.code == "push_not_configured" {
      lastMessage = String(localized: "El servidor aún no tiene la clave de APNs.")
    } catch {
      lastMessage = (error as? LocalizedError)?.errorDescription
    }
  }
}

extension PushManager: UNUserNotificationCenterDelegate {
  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    let info = response.notification.request.content.userInfo
    let link = (info["url"] as? String).flatMap(URL.init(string:))
      ?? (info["tv_id"] as? Int).flatMap { URL(string: "peliculas://serie/\($0)") }
    guard let link else { return }
    await MainActor.run { DeepLinkRouter.shared.open(link) }
  }
}

private struct DeviceBody: Encodable {
  let token: String
  let environment: String
  let platform: String
  let locale: String
  let timezone: String
  let appVersion: String

  enum CodingKeys: String, CodingKey {
    case token, environment, platform, locale, timezone, appVersion = "app_version"
  }
}
