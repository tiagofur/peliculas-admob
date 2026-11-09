import SwiftUI

/// Continúa el launch screen (mismo fondo y logo) hasta que la app pinta su primera
/// pantalla, para que no se vea la ventana en blanco entre uno y otra.
struct SplashOverlay: View {
  var body: some View {
    ZStack {
      Color("LaunchBackground").ignoresSafeArea()
      Image("LaunchLogo")
    }
    .accessibilityHidden(true)
  }
}
