import Foundation
import UserNotifications

/// Recordatorios locales semanales (no necesitan cuenta ni servidor):
/// tendencias del viernes y la watchlist del domingo.
@MainActor
final class ReminderManager: ObservableObject {
  @Published private(set) var enabled: Bool

  private let key = "peliculas.reminders.enabled.v1"
  private let ids = ["peliculas.trending.weekly", "peliculas.watchlist.weekly"]

  init() {
    enabled = UserDefaults.standard.bool(forKey: key)
  }

  func setEnabled(_ on: Bool, watchlistCount: Int) async {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ids)
    guard on else {
      enabled = false
      UserDefaults.standard.set(false, forKey: key)
      return
    }
    guard await PushManager.shared.requestPermission() else {
      enabled = false
      return
    }
    enabled = true
    UserDefaults.standard.set(true, forKey: key)
    schedule(watchlistCount: watchlistCount)
  }

  /// Vuelve a programar con el conteo actual (al volver a primer plano).
  func reschedule(watchlistCount: Int) {
    guard enabled else { return }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    schedule(watchlistCount: watchlistCount)
  }

  private func schedule(watchlistCount: Int) {
    let center = UNUserNotificationCenter.current()
    var friday = DateComponents()
    friday.weekday = 6
    friday.hour = 19
    let trends = UNMutableNotificationContent()
    trends.title = String(localized: "Tendencias de la semana")
    trends.body = String(localized: "Mira lo que todos están viendo este fin de semana.")
    trends.userInfo = ["url": "peliculas://trending"]
    center.add(UNNotificationRequest(identifier: ids[0], content: trends,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: friday, repeats: true)))

    guard watchlistCount > 0 else { return }
    var sunday = DateComponents()
    sunday.weekday = 1
    sunday.hour = 18
    let wl = UNMutableNotificationContent()
    wl.title = String(localized: "Tu watchlist te espera")
    wl.body = String(localized: "Tienes \(watchlistCount) títulos guardados para ver.")
    wl.userInfo = ["url": "peliculas://library"]
    center.add(UNNotificationRequest(identifier: ids[1], content: wl,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: sunday, repeats: true)))
  }
}
