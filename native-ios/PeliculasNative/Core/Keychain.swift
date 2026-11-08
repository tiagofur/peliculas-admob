import Foundation
import Security

/// Guarda datos sensibles (tokens de sesión) en el Llavero, no en UserDefaults.
/// `AfterFirstUnlock`: el widget y las tareas en segundo plano pueden leerlo
/// tras el primer desbloqueo; no viaja a otros dispositivos ni a backups.
enum Keychain {
  private static let service = "mx.creapolis.peliculas.session"

  static func save<T: Encodable>(_ value: T, account: String) {
    guard let data = try? JSONEncoder().encode(value) else { return }
    let base: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(base as CFDictionary)
    var add = base
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(add as CFDictionary, nil)
  }

  static func load<T: Decodable>(_ type: T.Type, account: String) -> T? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var out: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
          let data = out as? Data else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }

  static func delete(account: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
  }
}
