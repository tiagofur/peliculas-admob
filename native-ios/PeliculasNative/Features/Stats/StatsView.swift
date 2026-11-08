import SwiftUI
import Charts

/// Cálculo puro (testeable sin red ni store) de estadísticas de biblioteca.
struct LibraryStats {
  let watchedTotal: Int
  let watchedMovies: Int
  let watchedShows: Int
  /// Media de notas 1–10 (0 si no hay).
  let averageScore: Double
  let episodeCount: Int
  /// Últimos 12 meses naturales: títulos marcados como vistos por mes.
  let byMonth: [ActivityMonth]
  /// Décadas de estreno de lo visto (ordenadas asc).
  let byDecade: [DecadeCount]

  struct ActivityMonth: Identifiable, Hashable {
    let id: String // "2026-11"
    let label: String // "nov"
    let count: Int
  }

  struct DecadeCount: Identifiable, Hashable {
    let id: String // "1990"
    let label: String // "90s"
    let count: Int
  }

  static func build(watched: [MediaKey: Stamp], ratings: [MediaKey: RatingStamp],
                    episodeCount: Int, items: [MediaKey: MediaItem],
                    now: Date = Date(), calendar: Calendar = .current) -> LibraryStats {
    let live = watched.filter { !$0.value.deleted }
    let scores = ratings.values.filter { !$0.deleted && $0.score > 0 }.map(\.score)
    let average = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

    // Actividad: ventana fija de 12 meses, con ceros donde no hubo marcas.
    let stamp = DateFormatter()
    stamp.dateFormat = "yyyy-MM"
    let name = DateFormatter()
    name.setLocalizedDateFormatFromTemplate("MMM")
    var window: [(id: String, label: String)] = []
    var counts: [String: Int] = [:]
    for back in (0..<12).reversed() {
      let month = calendar.date(byAdding: .month, value: -back, to: calendar.startOfDay(for: now))!
      let id = stamp.string(from: month)
      window.append((id, name.string(from: month).capitalized))
    }
    for (_, mark) in live {
      let id = stamp.string(from: mark.updatedAt)
      if window.contains(where: { $0.id == id }) { counts[id, default: 0] += 1 }
    }
    let byMonth = window.map { ActivityMonth(id: $0.id, label: $0.label, count: counts[$0.id] ?? 0) }

    // Épocas: año de estreno de lo visto (la foto mínima guarda `year`).
    var perDecade: [String: Int] = [:]
    for (key, _) in live {
      guard let year = Int(items[key]?.year.prefix(4) ?? ""), year >= 1920 else { continue }
      perDecade[String(year - year % 10), default: 0] += 1
    }
    let byDecade = perDecade.sorted { $0.key < $1.key }
      .map { DecadeCount(id: $0.key, label: "\(String($0.key.suffix(2)))s", count: $0.value) }

    return LibraryStats(
      watchedTotal: live.count,
      watchedMovies: live.filter { $0.key.kind == .movie }.count,
      watchedShows: live.filter { $0.key.kind == .tv }.count,
      averageScore: average,
      episodeCount: episodeCount,
      byMonth: byMonth,
      byDecade: byDecade
    )
  }
}

/// "Estadísticas": qué y cuánto ves, con gráficas nativas. 100% local.
struct StatsView: View {
  @EnvironmentObject private var library: LibraryStore

  private var stats: LibraryStats { library.stats }

  var body: some View {
    let stats = stats
    Group {
      if stats.watchedTotal == 0 && stats.episodeCount == 0 {
        EmptyState(icon: "chart.bar", title: "Sin estadísticas todavía",
                   message: "Marca títulos como vistos y aquí verás tu actividad, tus épocas favoritas y tu nota media.")
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            tiles(stats)
            if stats.byMonth.contains(where: { $0.count > 0 }) {
              activityChart(stats)
            }
            if !stats.byDecade.isEmpty {
              decadeChart(stats)
            }
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
      }
    }
    .navigationTitle("Estadísticas")
    .navigationBarTitleDisplayMode(.large)
  }

  private func tiles(_ stats: LibraryStats) -> some View {
    let fmt = NumberFormatter()
    fmt.maximumFractionDigits = 1
    return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
      tile("Vistos", value: "\(stats.watchedTotal)", icon: "eye.fill", color: .green,
           detail: String(localized: "\(stats.watchedMovies) películas · \(stats.watchedShows) series"))
      tile("Episodios", value: "\(stats.episodeCount)", icon: "tv.fill", color: .indigo,
           detail: String(localized: "De tus series seguidas"))
      tile("Nota media", value: stats.averageScore > 0 ? String(format: "%.1f", stats.averageScore) : "—",
           icon: "star.fill", color: .yellow,
           detail: String(localized: "Sobre 10"))
      tile("Por ver", value: "\(library.count(.watchlist))", icon: "bookmark.fill", color: .orange,
           detail: String(localized: "En tu watchlist"))
    }
  }

  private func tile(_ title: LocalizedStringKey, value: String, icon: String, color: Color, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(title, systemImage: icon)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
      Text(verbatim: value)
        .font(.system(.title, design: .rounded).weight(.heavy))
        .monospacedDigit()
      Text(verbatim: detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  private func activityChart(_ stats: LibraryStats) -> some View {
    chartCard(title: "Actividad", subtitle: "Vistos por mes") {
      Chart(stats.byMonth) { month in
        BarMark(
          x: .value("Mes", month.label),
          y: .value("Vistos", month.count)
        )
        .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.9), .pink.opacity(0.7)], startPoint: .top, endPoint: .bottom))
        .cornerRadius(3)
      }
      .chartXAxis {
        AxisMarks(values: .automatic(desiredCount: 4))
      }
    }
  }

  private func decadeChart(_ stats: LibraryStats) -> some View {
    chartCard(title: "Tus épocas", subtitle: "Década de estreno") {
      Chart(stats.byDecade) { decade in
        BarMark(
          x: .value("Vistos", decade.count),
          y: .value("Década", decade.label)
        )
        .foregroundStyle(LinearGradient(colors: [.indigo.opacity(0.9), .blue.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
        .cornerRadius(3)
      }
    }
  }

  private func chartCard<Chart: View>(title: LocalizedStringKey, subtitle: LocalizedStringKey, @ViewBuilder chart: () -> Chart) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.headline)
        Text(subtitle).font(.caption).foregroundStyle(.secondary)
      }
      chart()
        .frame(height: 150)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .accessibilityElement(children: .combine)
  }
}
