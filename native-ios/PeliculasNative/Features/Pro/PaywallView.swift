import StoreKit
import SwiftUI

/// Paywall Pro. Cumple la guía 3.1.2: precio y periodo claros, renovación
/// automática explicada, restaurar compras, términos y privacidad enlazados.
struct PaywallView: View {
  @EnvironmentObject private var pro: ProStore
  @Environment(\.dismiss) private var dismiss
  @State private var selected: String = AppConfig.Pro.yearly
  @State private var introEligible = true

  var body: some View {
    ZStack {
      background
      ScrollView {
        VStack(spacing: 24) {
          header
          features
          plans
          cta
          footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 56)
        .padding(.bottom, 32)
      }
    }
    .overlay(alignment: .topTrailing) {
      Button { dismiss() } label: {
        Image(systemName: "xmark")
          .font(.subheadline.weight(.bold))
          .foregroundStyle(.white)
          .frame(width: 34, height: 34)
          .glassCircle()
      }
      .padding(16)
      .accessibilityLabel("Cerrar")
    }
    .preferredColorScheme(.dark)
    .task {
      await pro.loadProducts()
      if let p = pro.products.first(where: { $0.id == AppConfig.Pro.yearly }), let sub = p.subscription {
        introEligible = await sub.isEligibleForIntroOffer
      }
    }
    .alert(pro.message ?? "", isPresented: Binding(get: { pro.message != nil }, set: { if !$0 { pro.message = nil } })) {
      Button("OK", role: .cancel) {}
    }
  }

  private var background: some View {
    ZStack {
      Color.black
      RadialGradient(colors: [Color(red: 1, green: 0.45, blue: 0.25).opacity(0.55), .clear],
                     center: .top, startRadius: 0, endRadius: 520)
      RadialGradient(colors: [Color(red: 0.55, green: 0.2, blue: 0.9).opacity(0.35), .clear],
                     center: .bottomLeading, startRadius: 0, endRadius: 500)
    }
    .ignoresSafeArea()
  }

  private var header: some View {
    VStack(spacing: 12) {
      Image(systemName: "sparkles.tv.fill")
        .font(.system(size: 54))
        .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
      Text("Películas Pro")
        .font(.system(size: 36, weight: .heavy))
        .foregroundStyle(.white)
      Text(pro.paywallReason ?? "Lo mejor de la app, sin anuncios y con avisos de tus series.")
        .font(.body)
        .foregroundStyle(.white.opacity(0.75))
        .multilineTextAlignment(.center)
    }
  }

  private var features: some View {
    VStack(alignment: .leading, spacing: 14) {
      feature("bell.badge.fill", .orange, "Avisos de episodios nuevos", "El día del estreno, a las 18:00 de tu hora.")
      feature("nosign", .pink, "Sin anuncios", "Ni banners ni interrupciones.")
      feature("list.star", .purple, "Listas ilimitadas", "La versión gratis incluye \(AppConfig.Pro.freeListLimit).")
      feature("heart.text.square.fill", .red, "Apoyas a un desarrollador independiente", "Cada suscripción mantiene la app viva.")
    }
    .padding(20)
    .glassCard(cornerRadius: 24)
  }

  private func feature(_ icon: String, _ color: Color, _ title: String, _ subtitle: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(color)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
        Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.65))
      }
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var plans: some View {
    if pro.products.isEmpty {
      VStack(spacing: 8) {
        if pro.loadingProducts {
          ProgressView().tint(.white)
        } else {
          Text("Los planes no están disponibles ahora mismo.").font(.footnote).foregroundStyle(.white.opacity(0.7))
          Button("Reintentar") { Task { await pro.loadProducts() } }.glassButtonStyle()
        }
      }
      .frame(minHeight: 120)
    } else {
      VStack(spacing: 10) {
        ForEach(pro.products, id: \.id) { product in
          PlanRow(product: product, selected: selected == product.id, badge: badge(for: product), introEligible: introEligible) {
            selected = product.id
            Haptics.selection()
          }
        }
      }
    }
  }

  private func badge(for product: Product) -> String? {
    guard product.id == AppConfig.Pro.yearly,
          let monthly = pro.products.first(where: { $0.id == AppConfig.Pro.monthly }) else { return nil }
    let yearlyCost = NSDecimalNumber(decimal: product.price).doubleValue
    let monthlyCost = NSDecimalNumber(decimal: monthly.price).doubleValue * 12
    guard monthlyCost > 0, yearlyCost < monthlyCost else { return "Mejor precio" }
    return "Ahorra \(Int(((1 - yearlyCost / monthlyCost) * 100).rounded()))%"
  }

  private var selectedProduct: Product? { pro.products.first { $0.id == selected } }

  private var cta: some View {
    VStack(spacing: 10) {
      Button {
        guard let p = selectedProduct else { return }
        Task { await pro.purchase(p) }
      } label: {
        Group {
          if pro.purchasing != nil {
            ProgressView().tint(.white)
          } else {
            Text(ctaTitle)
          }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
      }
      .glassProminentButtonStyle()
      .controlSize(.large)
      .disabled(selectedProduct == nil || pro.purchasing != nil)

      if let p = selectedProduct {
        Text(renewalText(p))
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.6))
          .multilineTextAlignment(.center)
      }
    }
  }

  private var ctaTitle: String {
    guard let p = selectedProduct else { return "Continuar" }
    if p.subscription?.introductoryOffer?.paymentMode == .freeTrial, introEligible { return "Probar gratis" }
    return p.type == .nonConsumable ? "Comprar por \(p.displayPrice)" : "Suscribirme"
  }

  private func renewalText(_ p: Product) -> String {
    guard let sub = p.subscription else { return "Pago único. Tuyo para siempre, compartible con En Familia." }
    let period = sub.subscriptionPeriod.unit == .year ? "año" : "mes"
    var text = "\(p.displayPrice) al \(period). "
    if let intro = sub.introductoryOffer, intro.paymentMode == .freeTrial, introEligible {
      text = "Gratis \(intro.period.debugDescriptionES), luego " + text
    }
    return text + "Se renueva automáticamente salvo que la canceles al menos 24 h antes del final del periodo, desde Ajustes › Apple ID › Suscripciones."
  }

  private var footer: some View {
    VStack(spacing: 10) {
      Button("Restaurar compras") { Task { await pro.restore() } }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
      HStack(spacing: 18) {
        if let t = AppConfig.termsURL { Link("Términos", destination: t) }
        Link("EULA", destination: AppConfig.appleEULA)
        if let p = AppConfig.privacyURL { Link("Privacidad", destination: p) }
      }
      .font(.caption)
      .foregroundStyle(.white.opacity(0.6))
    }
  }
}

private struct PlanRow: View {
  let product: Product
  let selected: Bool
  let badge: String?
  let introEligible: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
          .font(.title2)
          .foregroundStyle(selected ? Color.orange : .white.opacity(0.4))
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 8) {
            Text(product.displayName).font(.headline).foregroundStyle(.white)
            if let badge {
              Text(badge)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange, in: Capsule())
                .foregroundStyle(.black)
            }
          }
          Text(detail).font(.caption).foregroundStyle(.white.opacity(0.65))
        }
        Spacer()
        Text(product.displayPrice).font(.headline.monospacedDigit()).foregroundStyle(.white)
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(Color.white.opacity(selected ? 0.14 : 0.06))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(selected ? Color.orange : Color.white.opacity(0.12), lineWidth: selected ? 2 : 1)
      )
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var detail: String {
    guard let sub = product.subscription else { return "Un solo pago" }
    var s = sub.subscriptionPeriod.unit == .year ? "Facturado cada año" : "Facturado cada mes"
    if sub.subscriptionPeriod.unit == .year {
      let perMonth = (product.price / 12) as NSDecimalNumber
      s = "Equivale a \(product.priceFormatStyle.format(perMonth.decimalValue))/mes"
    }
    if let intro = sub.introductoryOffer, intro.paymentMode == .freeTrial, introEligible {
      s += " · \(intro.period.debugDescriptionES) gratis"
    }
    return s
  }
}

extension Product.SubscriptionPeriod {
  /// "1 semana", "1 mes"… en español.
  var debugDescriptionES: String {
    let n = value
    switch unit {
    case .day: return n == 7 ? "1 semana" : (n == 1 ? "1 día" : "\(n) días")
    case .week: return n == 1 ? "1 semana" : "\(n) semanas"
    case .month: return n == 1 ? "1 mes" : "\(n) meses"
    case .year: return n == 1 ? "1 año" : "\(n) años"
    @unknown default: return "\(n)"
    }
  }
}
