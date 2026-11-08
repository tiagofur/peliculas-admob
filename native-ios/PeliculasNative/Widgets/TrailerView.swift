import SwiftUI
import WebKit

/// Tarjeta de tráiler: miniatura de YouTube con botón de play de vidrio.
/// El vídeo se abre a pantalla completa (no hay un WebView pesado en el scroll).
struct TrailerCard: View {
  let key: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        RemoteImage(url: URL(string: "https://img.youtube.com/vi/\(key)/hqdefault.jpg"), placeholderIcon: "play.rectangle")
          .frame(maxWidth: .infinity)
          .aspectRatio(16 / 9, contentMode: .fit)
          .clipped()
        LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
        Image(systemName: "play.fill")
          .font(.title.weight(.semibold))
          .foregroundStyle(.white)
          .frame(width: 64, height: 64)
          .glassCircle()
      }
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Ver tráiler")
  }
}

/// Reproductor a pantalla completa con botón de cerrar flotante.
struct TrailerFullscreenView: View {
  @Environment(\.dismiss) private var dismiss
  let key: String

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color.black.ignoresSafeArea()
      YouTubeEmbedView(key: key)
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxHeight: .infinity)
      HStack(spacing: 12) {
        if let url = URL(string: "https://www.youtube.com/watch?v=\(key)") {
          Link(destination: url) {
            Image(systemName: "arrow.up.forward.app")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(width: 44, height: 44)
              .glassCircle()
          }
          .accessibilityLabel("Abrir en YouTube")
        }
        Button { dismiss() } label: {
          Image(systemName: "xmark")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .glassCircle()
        }
        .accessibilityLabel("Cerrar")
      }
      .padding()
    }
    .preferredColorScheme(.dark)
  }
}

struct YouTubeEmbedView: UIViewRepresentable {
  let key: String

  func makeUIView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []
    let view = WKWebView(frame: .zero, configuration: config)
    view.isOpaque = false
    view.backgroundColor = .black
    view.scrollView.isScrollEnabled = false
    return view
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {
    guard uiView.url == nil else { return }
    // youtube-nocookie + origin evita el "Error 153" de embeds restringidos.
    let html = """
    <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
    <style>html,body{margin:0;background:#000;height:100%}iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style></head>
    <body><iframe src="https://www.youtube-nocookie.com/embed/\(key)?autoplay=1&playsinline=1&rel=0&modestbranding=1"
    allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe></body></html>
    """
    uiView.loadHTMLString(html, baseURL: URL(string: "https://peliculas.app"))
  }
}
