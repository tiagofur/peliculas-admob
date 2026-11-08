import SwiftUI

/// Logros y nivel (desde Cuenta).
struct AchievementsView: View {
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var achievements: AchievementStore

  var body: some View {
    let items = achievements.all(LibraryCounts(library))
    List {
      Section {
        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .firstTextBaseline) {
            Text(verbatim: "\(achievements.totalPoints)")
              .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
            Text("puntos").font(.headline).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "trophy.fill").font(.largeTitle).foregroundStyle(.yellow)
          }
          Text("Nivel \(achievements.level.level) · \(achievements.level.name)")
            .font(.subheadline.weight(.semibold))
          if let missing = achievements.pointsToNextLevel {
            ProgressView(value: achievements.levelProgress)
            Text("Te faltan \(missing) puntos para el siguiente nivel").font(.caption).foregroundStyle(.secondary)
          } else {
            Text("Nivel máximo. ¡Eres una leyenda!").font(.caption).foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
      }
      Section("Desbloqueados") {
        ForEach(items.filter(\.isUnlocked)) { AchievementRow(item: $0) }
      }
      Section("Por conseguir") {
        ForEach(items.filter { !$0.isUnlocked }) { AchievementRow(item: $0) }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Logros")
  }
}

private struct AchievementRow: View {
  let item: Achievement

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: item.icon)
        .font(.title3)
        .foregroundStyle(item.isUnlocked ? Color.yellow : Color.secondary)
        .frame(width: 40, height: 40)
        .background(Circle().fill(item.isUnlocked ? Color.yellow.opacity(0.15) : Color(.tertiarySystemFill)))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.name).font(.subheadline.weight(.semibold))
        Text(item.description).font(.caption).foregroundStyle(.secondary)
        if !item.isUnlocked {
          ProgressView(value: Double(item.progress), total: Double(item.target))
        }
      }
      Spacer()
      Text(verbatim: item.isUnlocked ? "+\(item.points)" : "\(item.progress)/\(item.target)")
        .font(.caption.weight(.bold).monospacedDigit())
        .foregroundStyle(item.isUnlocked ? .green : .secondary)
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(item.isUnlocked
      ? Text("\(item.name). \(item.description). Desbloqueado")
      : Text("\(item.name). \(item.description). \(item.progress) de \(item.target)"))
  }
}
