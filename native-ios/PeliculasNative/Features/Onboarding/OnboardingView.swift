import SwiftUI

/// Bienvenida de primer uso ("What's New" de Apple): qué hace la app y entrar.
struct OnboardingView: View {
  @EnvironmentObject private var router: DeepLinkRouter
  let done: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 36) {
          VStack(spacing: 14) {
            Image(systemName: "movieclapper.fill")
              .font(.system(size: 64))
              .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.77, blue: 0.36), Color(red: 1, green: 0.44, blue: 0.26), Color(red: 0.91, green: 0.24, blue: 0.36)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
              .accessibilityHidden(true)
            Text("Bienvenido a\nPelículas")
              .font(.system(size: 38, weight: .heavy))
              .multilineTextAlignment(.center)
          }
          .padding(.top, 64)

          VStack(alignment: .leading, spacing: 26) {
            row("play.square.stack.fill", .orange, "Sigue tus series",
                "Marca episodios y mira en Siguiente qué toca ver hoy.")
            row("sparkles.tv.fill", .pink, "Descubre qué ver",
                "Tendencias, estrenos y recomendaciones según lo que te gusta.")
            row("play.tv.fill", .blue, "Dónde verla",
                "Netflix, Prime Video, Disney+ y más: abre la app correcta con un toque.")
            row("icloud.fill", .indigo, "En todos tus dispositivos",
                "Con tu cuenta, tu biblioteca se sincroniza sola.")
          }
          .padding(.horizontal, 32)
        }
      }

      VStack(spacing: 12) {
        Button(action: done) {
          Text("Continuar")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .glassProminentButtonStyle()
        .controlSize(.large)
        Button("Ya tengo cuenta") {
          done()
          router.showingSignIn = true
        }
        .font(.subheadline.weight(.semibold))
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 20)
    }
    .interactiveDismissDisabled()
  }

  private func row(_ icon: String, _ color: Color, _ title: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 18) {
      Image(systemName: icon)
        .font(.system(size: 30))
        .foregroundStyle(color)
        .frame(width: 40)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.headline)
        Text(text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
