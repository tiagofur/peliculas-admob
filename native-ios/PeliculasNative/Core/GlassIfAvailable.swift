import SwiftUI
import UIKit

// MARK: - Liquid Glass con respaldo
//
// Regla de Apple (HIG, "Materials"): el vidrio es para la capa de controles y
// navegación que flota sobre el contenido, nunca para el contenido en sí.
// iOS 26+: Liquid Glass real. iOS 15–25: materiales clásicos con la misma forma.

extension View {
  /// Vidrio en cápsula (chips, controles flotantes).
  @ViewBuilder
  func glassCapsule(interactive: Bool = false) -> some View {
    if #available(iOS 26, *) {
      self.glassEffect(interactive ? .regular.interactive() : .regular, in: .capsule)
    } else {
      self.background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
    }
  }

  /// Vidrio circular (botones de icono sobre imágenes).
  @ViewBuilder
  func glassCircle(interactive: Bool = true) -> some View {
    if #available(iOS 26, *) {
      self.glassEffect(interactive ? .regular.interactive() : .regular, in: .circle)
    } else {
      self.background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
    }
  }

  /// Vidrio en rectángulo redondeado (tarjetas flotantes, avisos).
  @ViewBuilder
  func glassCard(cornerRadius: CGFloat = 22) -> some View {
    if #available(iOS 26, *) {
      self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    } else {
      self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
  }

  /// Compatibilidad con el nombre anterior.
  func glassCapsuleIfAvailable() -> some View { glassCapsule() }
  func glassCircularIfAvailable() -> some View { glassCircle() }

  /// Botón de vidrio estándar (secundario).
  @ViewBuilder
  func glassButtonStyle() -> some View {
    if #available(iOS 26, *) {
      self.buttonStyle(.glass)
    } else {
      self.buttonStyle(.bordered)
    }
  }

  /// Botón de vidrio teñido con el color de acento (acción principal).
  @ViewBuilder
  func glassProminentButtonStyle() -> some View {
    if #available(iOS 26, *) {
      self.buttonStyle(.glassProminent)
    } else {
      self.buttonStyle(.borderedProminent)
    }
  }

  /// Compatibilidad con el nombre anterior.
  func glassProminentIfAvailable() -> some View { glassProminentButtonStyle() }

  /// La barra de pestañas se encoge al bajar (iOS 26+), como Música o TV.
  @ViewBuilder
  func minimizingTabBar() -> some View {
    if #available(iOS 26, *) {
      self.tabBarMinimizeBehavior(.onScrollDown)
    } else {
      self
    }
  }

  /// La imagen del héroe se extiende bajo la barra de estado y el toolbar.
  @ViewBuilder
  func extendsBehindChrome() -> some View {
    if #available(iOS 26, *) {
      self.backgroundExtensionEffect()
    } else {
      self
    }
  }
}

/// Agrupa vidrios cercanos para que se fundan entre sí (iOS 26+).
struct GlassGroup<Content: View>: View {
  var spacing: CGFloat = 12
  @ViewBuilder var content: Content

  var body: some View {
    if #available(iOS 26, *) {
      GlassEffectContainer(spacing: spacing) { content }
    } else {
      content
    }
  }
}

// MARK: - Navegación

/// `NavigationStack` en iOS 16+, `NavigationView` en pila en iOS 15.
struct AppNavigation<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    if #available(iOS 16, *) {
      NavigationStack { content }
    } else {
      NavigationView { content }.navigationViewStyle(.stack)
    }
  }
}

// MARK: - Hápticos

@MainActor
enum Haptics {
  static func toggle(_ on: Bool) {
    UIImpactFeedbackGenerator(style: on ? .medium : .light).impactOccurred()
  }

  static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
  static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
  static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// MARK: - Piezas comunes

/// Encabezado de sección con "Ver todo" opcional (patrón de App Store y TV).
struct SectionHeader<Destination: View>: View {
  let title: String
  var subtitle: String? = nil
  var destination: Destination?

  init(_ title: String, subtitle: String? = nil, @ViewBuilder destination: () -> Destination) {
    self.title = title
    self.subtitle = subtitle
    self.destination = destination()
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.title3.weight(.bold))
          .accessibilityAddTraits(.isHeader)
        if let subtitle {
          Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
      }
      Spacer()
      if let destination {
        NavigationLink(destination: destination) {
          HStack(spacing: 2) {
            Text("Ver todo")
            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold))
          }
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Ver todo: \(title)")
      }
    }
    .padding(.horizontal, 20)
  }
}

extension SectionHeader where Destination == EmptyView {
  init(_ title: String, subtitle: String? = nil) {
    self.title = title
    self.subtitle = subtitle
    self.destination = nil
  }
}

/// Estado vacío: `ContentUnavailableView` en iOS 17+, equivalente propio antes.
struct EmptyState<Actions: View>: View {
  let icon: String
  let title: String
  let message: String
  @ViewBuilder var actions: Actions

  var body: some View {
    if #available(iOS 17, *) {
      ContentUnavailableView {
        Label(title, systemImage: icon)
      } description: {
        Text(message)
      } actions: {
        actions
      }
    } else {
      VStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 48, weight: .regular))
          .foregroundStyle(.secondary)
        Text(title).font(.title3.weight(.semibold))
        Text(message)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        actions
      }
      .padding(32)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

extension EmptyState where Actions == EmptyView {
  init(icon: String, title: String, message: String) {
    self.init(icon: icon, title: title, message: message) { EmptyView() }
  }
}

/// Avatar con iniciales.
struct InitialsAvatar: View {
  let initials: String
  var size: CGFloat = 36

  var body: some View {
    Text(initials)
      .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(
        LinearGradient(colors: [Color(red: 1, green: 0.55, blue: 0.3), Color(red: 0.86, green: 0.25, blue: 0.4)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        in: Circle()
      )
      .accessibilityHidden(true)
  }
}
