import SwiftUI
import UIKit
import WidgetKit

/// Widget "Tendencias": top del día desde la caché TMDB del backend, con pósters.
struct TrendItem: Hashable {
  let id: Int
  let title: String
  let rating: Double
  let poster: UIImage?
}

struct TrendEntry: TimelineEntry {
  let date: Date
  let items: [TrendItem]
}

struct TrendProvider: TimelineProvider {
  func placeholder(in context: Context) -> TrendEntry {
    TrendEntry(date: Date(), items: Self.sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (TrendEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : TrendEntry(date: Date(), items: Self.fetch()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TrendEntry>) -> Void) {
    let items = Self.fetch()
    // Sin datos (red/servidor caído): estado vacío honesto y reintento en 1 h.
    // Nunca datos de muestra: parecerían tendencias reales.
    let next = Calendar.current.date(byAdding: .hour, value: items.isEmpty ? 1 : 4, to: Date()) ?? Date()
    completion(Timeline(entries: [TrendEntry(date: Date(), items: items)], policy: .after(next)))
  }

  /// Descarga síncrona clásica de widgets (corre fuera del hilo principal),
  /// con límite de tiempo para no quedarnos colgados sin red.
  private static func fetchData(_ url: URL, timeout: TimeInterval = 10) -> Data? {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = timeout
    config.timeoutIntervalForResource = timeout + 5
    let semaphore = DispatchSemaphore(value: 0)
    var box: Data?
    URLSession(configuration: config).dataTask(with: url) { data, _, _ in
      box = data
      semaphore.signal()
    }.resume()
    _ = semaphore.wait(timeout: .now() + timeout + 5)
    return box
  }

  private static func fetch() -> [TrendItem] {
    let base = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String) ?? ""
    let lang = Locale.preferredLanguages.first?.hasPrefix("pt") == true ? "pt-BR"
      : (Locale.preferredLanguages.first?.hasPrefix("en") == true ? "en-US" : "es-MX")
    guard !base.isEmpty, let url = URL(string: "\(base)/v1/tmdb/trending/movie/day?language=\(lang)"),
          let data = fetchData(url),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let results = json["results"] as? [[String: Any]] else { return [] }
    return results.prefix(3).compactMap { r in
      guard let id = r["id"] as? Int, let title = r["title"] as? String else { return nil }
      let poster = (r["poster_path"] as? String)
        .flatMap { URL(string: "https://image.tmdb.org/t/p/w185\($0)") }
        .flatMap { fetchData($0, timeout: 8) }
        .flatMap(UIImage.init(data:))
      return TrendItem(id: id, title: title, rating: r["vote_average"] as? Double ?? 0, poster: poster)
    }
  }

  static let sample = [
    TrendItem(id: 0, title: String(localized: "Dune: Parte Dos"), rating: 8.2, poster: nil),
    TrendItem(id: 1, title: "Oppenheimer", rating: 8.1, poster: nil),
    TrendItem(id: 2, title: String(localized: "Pobres criaturas"), rating: 7.8, poster: nil),
  ]
}

private struct Poster: View {
  let item: TrendItem

  var body: some View {
    Group {
      if let img = item.poster {
        Image(uiImage: img).resizable().scaledToFill()
      } else {
        LinearGradient(colors: [.orange.opacity(0.6), .pink.opacity(0.5)], startPoint: .top, endPoint: .bottom)
          .overlay(Image(systemName: "film").foregroundStyle(.white.opacity(0.8)))
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

struct TrendSmallView: View {
  let entry: TrendEntry

  var body: some View {
    Group {
      if let first = entry.items.first {
        VStack(alignment: .leading, spacing: 6) {
          Label("Tendencia hoy", systemImage: "flame.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.orange)
          Poster(item: first).frame(width: 44, height: 66)
          Spacer(minLength: 0)
          Text(first.title).font(.subheadline.weight(.bold)).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(first.id > 0 ? URL(string: "peliculas://movie/\(first.id)") : URL(string: "peliculas://trending"))
      } else {
        EmptyTrendView(compact: true)
          .widgetURL(URL(string: "peliculas://trending"))
      }
    }
  }
}

struct TrendMediumView: View {
  let entry: TrendEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Tendencias de hoy", systemImage: "flame.fill")
        .font(.caption.weight(.bold))
        .foregroundStyle(.orange)
      if entry.items.isEmpty {
        EmptyTrendView(compact: false)
      } else {
        HStack(alignment: .top, spacing: 10) {
          ForEach(Array(entry.items.prefix(3).enumerated()), id: \.offset) { i, item in
            Link(destination: URL(string: item.id > 0 ? "peliculas://movie/\(item.id)" : "peliculas://trending") ?? URL(string: "peliculas://trending")!) {
              VStack(alignment: .leading, spacing: 4) {
                Poster(item: item).frame(height: 84)
                Text(verbatim: "\(i + 1). \(item.title)").font(.caption2.weight(.semibold)).lineLimit(1)
              }
            }
          }
        }
      }
    }
  }
}

/// Sin red o sin respuesta del servidor: no fingir datos.
private struct EmptyTrendView: View {
  let compact: Bool

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "wifi.exclamationmark")
        .font(compact ? .title3 : .title2)
        .foregroundStyle(.secondary)
      Text("Sin conexión")
        .font(.caption.weight(.semibold))
      if !compact {
        Text("Toca para reintentar más tarde o abre la app.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }
}

struct TrendEntryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: TrendEntry

  var body: some View {
    Group {
      switch family {
      case .systemSmall: TrendSmallView(entry: entry)
      default: TrendMediumView(entry: entry)
      }
    }
    .widgetBackground()
  }
}

private extension View {
  @ViewBuilder
  func widgetBackground() -> some View {
    if #available(iOS 17, *) {
      containerBackground(for: .widget) { Color(.systemBackground) }
    } else {
      padding().background(Color(.systemBackground))
    }
  }
}

struct TrendingWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "mx.creapolis.peliculas.trending", provider: TrendProvider()) { entry in
      TrendEntryView(entry: entry)
    }
    .configurationDisplayName("Tendencias")
    .description("Las películas más vistas de hoy.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct PeliculasWidgets: WidgetBundle {
  var body: some Widget {
    TrendingWidget()
  }
}
