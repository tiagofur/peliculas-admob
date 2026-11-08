import SwiftUI

/// "Siguiente": lo que te toca ver de cada serie y lo que se estrena pronto.
struct UpNextView: View {
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var upNext: UpNextStore
  @EnvironmentObject private var router: DeepLinkRouter
  @EnvironmentObject private var pro: ProStore

  var body: some View {
    AppNavigation {
      Group {
        if upNext.entries.isEmpty && upNext.upcoming.isEmpty {
          if upNext.loading || !upNext.loadedOnce {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            EmptyState(icon: "play.square.stack", title: "Sigue tus series",
                       message: "Añade una serie a tu Watchlist o marca un episodio visto y aquí verás qué toca después.") {
              Button("Buscar series") { router.tab = .search }.glassProminentButtonStyle()
            }
          }
        } else {
          content
        }
      }
      .navigationTitle("Siguiente")
      .accountToolbar()
    }
    .task { await upNext.load(library: library) }
    .onChange(of: library.watchedEpisodeCount) { _ in Task { await upNext.load(library: library) } }
  }

  private var content: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        let started = upNext.entries.filter(\.started)
        let notStarted = upNext.entries.filter { !$0.started }
        if !started.isEmpty {
          VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Continuar viendo")
            ForEach(started) { UpNextRow(entry: $0) }
          }
        }
        if !upNext.upcoming.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Próximos episodios")
            ForEach(upNext.upcoming) { UpcomingRow(entry: $0) }
            if !pro.isPro {
              Button {
                pro.presentPaywall(reason: "Con Pro te avisamos el día que sale cada episodio.")
              } label: {
                Label("Avísame cuando se estrenen", systemImage: "bell.badge")
                  .font(.subheadline.weight(.semibold))
              }
              .padding(.horizontal, 20)
            }
          }
        }
        if !notStarted.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Por empezar")
            ScrollView(.horizontal, showsIndicators: false) {
              LazyHStack(spacing: 14) {
                ForEach(notStarted) { PosterCard(item: $0.show, width: 112) }
              }
              .padding(.horizontal, 20)
            }
          }
        }
      }
      .padding(.vertical, 8)
    }
    .refreshable {
      await library.sync()
      await upNext.load(library: library, force: true)
    }
  }
}

private struct UpNextRow: View {
  let entry: UpNextEntry

  var body: some View {
    UpNextCard(entry: entry, width: UIScreen.main.bounds.width - 40)
      .padding(.horizontal, 20)
  }
}

private struct UpcomingRow: View {
  let entry: UpcomingEntry

  var body: some View {
    NavigationLink(destination: DetailView(item: entry.show)) {
      HStack(spacing: 14) {
        VStack(spacing: 0) {
          Text(entry.airDate.formatted(.dateTime.month(.abbreviated)).uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tint)
          Text(entry.airDate.formatted(.dateTime.day()))
            .font(.title2.weight(.bold).monospacedDigit())
        }
        .frame(width: 48)
        PosterImage(path: entry.show.posterPath, width: 44)
        VStack(alignment: .leading, spacing: 2) {
          Text(entry.show.title).font(.subheadline.weight(.semibold)).lineLimit(1)
          Text([entry.episode.label, entry.name].filter { !$0.isEmpty }.joined(separator: " · "))
            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
          Text(relative(entry.airDate)).font(.caption2).foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding(.horizontal, 20)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
  }

  private func relative(_ date: Date) -> String {
    let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: date).day ?? 0
    switch days {
    case 0: return "Hoy"
    case 1: return "Mañana"
    default: return "En \(days) días"
    }
  }
}
