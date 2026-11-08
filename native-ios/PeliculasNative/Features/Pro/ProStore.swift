import Foundation
import StoreKit

/// Pro con StoreKit 2 (iOS 15+).
/// - El estado Pro sale de `Transaction.currentEntitlements` (funciona sin cuenta
///   y sin red: StoreKit lo guarda firmado en el dispositivo).
/// - Con sesión, cada compra se reclama en el backend (`POST /v1/storekit/transactions`)
///   para que el servidor sepa quién es Pro (avisos de episodios, etc.).
@MainActor
final class ProStore: ObservableObject {
  static let shared = ProStore()

  @Published private(set) var products: [Product] = []
  @Published private(set) var isPro = false
  @Published private(set) var activeProductID: String?
  @Published private(set) var expiresAt: Date?
  @Published private(set) var purchasing: String?
  @Published private(set) var loadingProducts = false
  @Published var message: String?
  @Published var showingPaywall = false
  /// Por qué se abrió el paywall (texto del encabezado).
  @Published var paywallReason: String?

  private var updates: Task<Void, Never>?

  private init() {
    updates = Task.detached { [weak self] in
      for await result in Transaction.updates {
        await self?.handle(result, claim: true)
      }
    }
    Task { await refresh() }
  }

  func presentPaywall(reason: String? = nil) {
    paywallReason = reason
    showingPaywall = true
  }

  func loadProducts() async {
    guard products.isEmpty else { return }
    loadingProducts = true
    defer { loadingProducts = false }
    do {
      let loaded = try await Product.products(for: AppConfig.Pro.all)
      products = AppConfig.Pro.all.compactMap { id in loaded.first { $0.id == id } }
    } catch {
      message = "No se pudieron cargar los planes. Revisa tu conexión."
    }
  }

  func purchase(_ product: Product) async {
    purchasing = product.id
    defer { purchasing = nil }
    var options: Set<Product.PurchaseOption> = []
    if let id = SessionStore.shared.user?.id, let uuid = UUID(uuidString: id) {
      options.insert(.appAccountToken(uuid))
    }
    do {
      switch try await product.purchase(options: options) {
      case .success(let result):
        await handle(result, claim: true)
        if isPro {
          Haptics.success()
          showingPaywall = false
        }
      case .pending:
        message = "Tu compra está pendiente de aprobación."
      case .userCancelled:
        break
      @unknown default:
        break
      }
    } catch {
      message = "No se pudo completar la compra."
    }
  }

  /// "Restaurar compras" (obligatorio por App Review).
  func restore() async {
    do {
      try await AppStore.sync()
    } catch {
      message = "No se pudo conectar con el App Store."
    }
    await refresh()
    await claimAll()
    message = isPro ? "¡Listo! Tu Pro está activo." : "No encontramos compras de Pro en tu Apple ID."
  }

  /// Recalcula el estado con lo que StoreKit tiene firmado en el dispositivo.
  func refresh() async {
    var pro = false
    var product: String?
    var expiry: Date?
    for await result in Transaction.currentEntitlements {
      guard case .verified(let t) = result, AppConfig.Pro.all.contains(t.productID), t.revocationDate == nil else { continue }
      if let exp = t.expirationDate, exp < Date() { continue }
      pro = true
      if product == nil || t.productID == AppConfig.Pro.lifetime {
        product = t.productID
        expiry = t.expirationDate
      }
    }
    isPro = pro
    activeProductID = product
    expiresAt = expiry
  }

  /// Envía al backend todas las compras activas (al iniciar sesión).
  func claimAll() async {
    guard SessionStore.shared.isSignedIn else { return }
    for await result in Transaction.currentEntitlements {
      if case .verified(let t) = result, AppConfig.Pro.all.contains(t.productID) {
        await claim(jws: result.jwsRepresentation)
      }
    }
  }

  private func handle(_ result: VerificationResult<Transaction>, claim: Bool) async {
    guard case .verified(let transaction) = result else { return }
    if claim { await self.claim(jws: result.jwsRepresentation) }
    await transaction.finish()
    await refresh()
  }

  private func claim(jws: String) async {
    guard SessionStore.shared.isSignedIn else { return }
    do {
      _ = try await APIClient.authed("POST", "/v1/storekit/transactions", body: ["signed_transaction": jws])
    } catch let error as APIError where error.code == "purchase_owned_by_other_account" {
      message = error.errorDescription
    } catch {
      // Sin red o servidor sin StoreKit: el webhook de Apple lo completará.
    }
  }

  var planName: String {
    switch activeProductID {
    case AppConfig.Pro.lifetime: return "Pro de por vida"
    case AppConfig.Pro.yearly: return "Pro anual"
    case AppConfig.Pro.monthly: return "Pro mensual"
    default: return "Pro"
    }
  }
}
