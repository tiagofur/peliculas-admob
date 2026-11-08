import StoreKitTest
import XCTest
@testable import PeliculasNative

/// Compras con el archivo `Products.storekit` (sin App Store real).
@MainActor
final class ProStoreTests: XCTestCase {
  private var session: SKTestSession!

  override func setUp() async throws {
    let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
    session = try SKTestSession(contentsOf: url)
    session.resetToDefaultState()
    // Revoca lo que dejaron pruebas anteriores y empieza limpio.
    for t in session.allTransactions() { try? session.refundTransaction(identifier: t.identifier) }
    session.clearTransactions()
    session.disableDialogs = true
    // Las transacciones de pruebas anteriores tardan un instante en limpiarse.
    for _ in 0..<20 {
      await ProStore.shared.refresh()
      if !ProStore.shared.isPro { break }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
  }

  func testProductIDsMatchBackendAndLoadInOrder() async throws {
    let products = try await Product.products(for: AppConfig.Pro.all)
    XCTAssertEqual(Set(products.map(\.id)), Set(AppConfig.Pro.all), "IDs = PRO_PRODUCT_IDS del backend")
    let yearly = try XCTUnwrap(products.first { $0.id == AppConfig.Pro.yearly })
    XCTAssertEqual(yearly.subscription?.introductoryOffer?.paymentMode, .freeTrial)
  }

  func testBuyingYearlyUnlocksPro() async throws {
    XCTAssertFalse(ProStore.shared.isPro)
    let found = try await Product.products(for: [AppConfig.Pro.yearly])
    let yearly = try XCTUnwrap(found.first)
    await ProStore.shared.purchase(yearly)
    XCTAssertTrue(ProStore.shared.isPro)
    XCTAssertEqual(ProStore.shared.activeProductID, AppConfig.Pro.yearly)

    // Reembolso → deja de ser Pro.
    let transaction = try XCTUnwrap(session.allTransactions().first)
    try session.refundTransaction(identifier: transaction.identifier)
    for _ in 0..<30 {
      await ProStore.shared.refresh()
      if !ProStore.shared.isPro { break }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    XCTAssertFalse(ProStore.shared.isPro)
  }

  func testLifetimeIsProWithoutExpiry() async throws {
    let found = try await Product.products(for: [AppConfig.Pro.lifetime])
    let lifetime = try XCTUnwrap(found.first)
    await ProStore.shared.purchase(lifetime)
    XCTAssertTrue(ProStore.shared.isPro)
    XCTAssertNil(ProStore.shared.expiresAt)
  }
}
