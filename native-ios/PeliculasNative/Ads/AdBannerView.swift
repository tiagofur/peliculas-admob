import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
import UserMessagingPlatform
#endif

/// AdMob solo como apoyo en la versión gratis: un banner discreto, nunca
/// intersticiales. Primero el consentimiento (UMP: RGPD y, si lo configuras en
/// AdMob, el mensaje de ATT), luego el SDK.
@MainActor
final class AdsManager: ObservableObject {
  static let shared = AdsManager()

  @Published private(set) var canShowAds = false
  @Published private(set) var privacyOptionsRequired = false
  private var started = false

  func start() {
    #if canImport(GoogleMobileAds)
    guard !started else { return }
    started = true
    let params = RequestParameters()
    ConsentInformation.shared.requestConsentInfoUpdate(with: params) { [weak self] _ in
      Task { @MainActor in
        guard let root = Self.rootViewController() else { self?.startSDKIfAllowed(); return }
        try? await ConsentForm.loadAndPresentIfRequired(from: root)
        self?.startSDKIfAllowed()
      }
    }
    // Si ya había consentimiento de otra sesión, no hace falta esperar.
    startSDKIfAllowed()
    #endif
  }

  /// "Privacidad de anuncios" en Ajustes (obligatorio con UMP en la UE).
  func presentPrivacyOptions() {
    #if canImport(GoogleMobileAds)
    guard let root = Self.rootViewController() else { return }
    ConsentForm.presentPrivacyOptionsForm(from: root) { _ in }
    #endif
  }

  #if canImport(GoogleMobileAds)
  private func startSDKIfAllowed() {
    privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    guard ConsentInformation.shared.canRequestAds, !canShowAds else { return }
    MobileAds.shared.start(completionHandler: nil)
    canShowAds = true
  }
  #endif

  static func rootViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
      ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

/// Banner adaptativo. Invisible para Pro y mientras no haya consentimiento.
struct AdBannerView: View {
  @ObservedObject private var ads = AdsManager.shared
  @ObservedObject private var pro = ProStore.shared

  var body: some View {
    #if canImport(GoogleMobileAds)
    if ads.canShowAds && !pro.isPro {
      GeometryReader { geo in
        BannerRepresentable(width: geo.size.width)
      }
      .frame(height: 60)
      .padding(.vertical, 8)
      .accessibilityLabel("Anuncio")
    }
    #endif
  }
}

#if canImport(GoogleMobileAds)
private struct BannerRepresentable: UIViewRepresentable {
  let width: CGFloat

  func makeUIView(context: Context) -> BannerView {
    let view = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: max(width, 320)))
    view.adUnitID = AppConfig.string("GADAdUnitID")
    view.rootViewController = AdsManager.rootViewController()
    view.load(Request())
    return view
  }

  func updateUIView(_ uiView: BannerView, context: Context) {}
}
#endif
