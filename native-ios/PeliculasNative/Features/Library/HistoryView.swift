import SwiftUI

/// Historial completo de lo visto, agrupado por mes (solo 15 caben en "recientes").
struct HistoryView: View {
  @EnvironmentObject private var library: LibraryStore

  private var grouped: [(month: String, entries: [(item: MediaItem, date: Date)])] {
    let fmt = DateFormatter()
    fmt.setLocalizedDateFormatFromTemplate("MMMM yyyy")
    var order: [String] = []
    var buckets: [String: [(item: MediaItem, date: Date)]] = [:]
    for entry in library.watchedLog() {
      let key = fmt.string(from: entry.date).capitalized
      if buckets[key] == nil { order.append(key) }
      buckets[key, default: []].append(entry)
    }
    return order.map { ($0, buckets[$0] ?? []) }
  }

  var body: some View {
    Group {
      if grouped.isEmpty {
        EmptyState(icon: "clock.arrow.circlepath", title: "Nada visto aún",
                   message: "Los títulos que marques como vistos aparecerán aquí por mes.")
      } else {
        List {
          ForEach(grouped, id: \.month) { month in
            Section(month.month) {
              ForEach(month.entries, id: \.item.key) { entry in
                NavigationLink(destination: DetailView(item: entry.item)) {
                  HistoryRow(entry: entry)
                }
              }
            }
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle("Historial")
    .navigationBarTitleDisplayMode(.large)
  }
}

private struct HistoryRow: View {
  let entry: (item: MediaItem, date: Date)

  private var day: String {
    let fmt = DateFormatter()
    fmt.setLocalizedDateFormatFromTemplate("d MMM")
    return fmt.string(from: entry.date)
  }

  var body: some View {
    HStack(spacing: 12) {
      PosterImage(path: entry.item.posterPath, width: 44)
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.item.title).font(.subheadline.weight(.semibold)).lineLimit(1)
        HStack(spacing: 6) {
          if !entry.item.year.isEmpty {
            Text(entry.item.year)
          }
          Text(entry.item.kind == .tv ? "SERIE" : "PELÍCULA")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Spacer()
      Text(verbatim: day)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }
}
