import Foundation

/// Conteos de la biblioteca que alimentan los logros.
struct LibraryCounts: Equatable {
  var favorites = 0
  var watchlist = 0
  var watched = 0
  var lists = 0
  var ratings = 0
  var episodes = 0

  @MainActor init(_ store: LibraryStore) {
    favorites = store.count(.favorite)
    watchlist = store.count(.watchlist)
    watched = store.count(.watched)
    lists = store.visibleLists.count
    ratings = store.ratedCount
    episodes = store.watchedEpisodeCount
  }

  init() {}
}

struct Achievement: Identifiable, Equatable {
  let id: String
  let name: String
  let description: String
  let icon: String
  let points: Int
  let progress: Int
  let target: Int
  let unlockedAt: Date?
  var isUnlocked: Bool { unlockedAt != nil }
}

/// Logros locales: mismos ids, nombres y puntos que `achievement_categories.dart`
/// de Flutter, más los de series y notas de la app nativa.
@MainActor
final class AchievementStore: ObservableObject {
  @Published var toast: Achievement?

  private var unlocked: [String: Date] = [:]
  private let key = "peliculas.achievements.v1"
  /// Al arrancar se evalúa en silencio: no se celebra lo que ya tenías.
  private var primed = false

  private struct Def {
    let id: String
    let name: String
    let description: String
    let icon: String
    let points: Int
    let target: Int
    let count: (LibraryCounts) -> Int
  }

  private static let defs: [Def] = [
    Def(id: "first_movie", name: String(localized: "Primera Película"), description: String(localized: "Agrega tu primer favorito"), icon: "heart.fill", points: 10, target: 1, count: { $0.favorites }),
    Def(id: "movie_enthusiast", name: String(localized: "Entusiasta del Cine"), description: String(localized: "Agrega 10 favoritos"), icon: "heart.circle.fill", points: 50, target: 10, count: { $0.favorites }),
    Def(id: "movie_collector", name: String(localized: "Coleccionista"), description: String(localized: "Agrega 50 favoritos"), icon: "square.stack.3d.up.fill", points: 150, target: 50, count: { $0.favorites }),
    Def(id: "movie_curator", name: String(localized: "Curador de Cine"), description: String(localized: "Agrega 100 favoritos"), icon: "rosette", points: 300, target: 100, count: { $0.favorites }),
    Def(id: "movie_master", name: String(localized: "Maestro del Cine"), description: String(localized: "Agrega 200 favoritos"), icon: "crown.fill", points: 500, target: 200, count: { $0.favorites }),
    Def(id: "first_watchlist", name: String(localized: "Para después"), description: String(localized: "Guarda tu primer título en la watchlist"), icon: "bookmark.fill", points: 10, target: 1, count: { $0.watchlist }),
    Def(id: "first_watched", name: String(localized: "Primera Vista"), description: String(localized: "Marca tu primer título como visto"), icon: "eye.fill", points: 10, target: 1, count: { $0.watched }),
    Def(id: "cinephile", name: String(localized: "Cinéfilo"), description: String(localized: "Marca 10 títulos como vistos"), icon: "film.stack.fill", points: 50, target: 10, count: { $0.watched }),
    Def(id: "list_creator", name: String(localized: "Creador de Listas"), description: String(localized: "Crea tu primera lista"), icon: "list.star", points: 25, target: 1, count: { $0.lists }),
    Def(id: "first_rating", name: String(localized: "Crítico Novato"), description: String(localized: "Califica tu primer título"), icon: "star.fill", points: 10, target: 1, count: { $0.ratings }),
    Def(id: "critic", name: String(localized: "Crítico"), description: String(localized: "Califica 25 títulos"), icon: "star.circle.fill", points: 75, target: 25, count: { $0.ratings }),
    Def(id: "first_episode", name: String(localized: "Piloto"), description: String(localized: "Marca tu primer episodio visto"), icon: "play.tv.fill", points: 10, target: 1, count: { $0.episodes }),
    Def(id: "binge_watcher", name: String(localized: "Maratonista"), description: String(localized: "Marca 50 episodios vistos"), icon: "flame.fill", points: 100, target: 50, count: { $0.episodes }),
    Def(id: "series_addict", name: String(localized: "Adicto a las Series"), description: String(localized: "Marca 250 episodios vistos"), icon: "sparkles.tv.fill", points: 300, target: 250, count: { $0.episodes }),
  ]

  init() {
    if let raw = UserDefaults.standard.data(forKey: key),
       let saved = try? JSONDecoder().decode([String: Date].self, from: raw) {
      unlocked = saved
    }
  }

  func check(_ counts: LibraryCounts) {
    var newest: Achievement?
    for def in Self.defs where unlocked[def.id] == nil {
      let progress = min(def.count(counts), def.target)
      guard progress >= def.target else { continue }
      let now = Date()
      unlocked[def.id] = now
      newest = Achievement(id: def.id, name: def.name, description: def.description, icon: def.icon,
                           points: def.points, progress: progress, target: def.target, unlockedAt: now)
    }
    if newest != nil { persist() }
    if primed, let newest {
      toast = newest
      Haptics.success()
    }
    primed = true
  }

  func all(_ counts: LibraryCounts) -> [Achievement] {
    Self.defs.map { def in
      Achievement(id: def.id, name: def.name, description: def.description, icon: def.icon, points: def.points,
                  progress: min(def.count(counts), def.target), target: def.target, unlockedAt: unlocked[def.id])
    }
  }

  var unlockedCount: Int { unlocked.count }
  var totalCount: Int { Self.defs.count }

  var totalPoints: Int {
    Self.defs.filter { unlocked[$0.id] != nil }.reduce(0) { $0 + $1.points }
  }

  var level: UserLevel { UserLevel.level(for: totalPoints) }
  var pointsToNextLevel: Int? { level.pointsToNext(from: totalPoints) }
  var levelProgress: Double { level.progress(from: totalPoints) }

  private func persist() {
    if let encoded = try? JSONEncoder().encode(unlocked) {
      UserDefaults.standard.set(encoded, forKey: key)
    }
  }
}

/// Nivel por puntos: mismos 7 umbrales que `Level.defaultLevels` de Flutter.
struct UserLevel {
  let level: Int
  let name: String
  let pointsRequired: Int

  private static let all: [UserLevel] = [
    UserLevel(level: 1, name: String(localized: "Novato del Cine"), pointsRequired: 0),
    UserLevel(level: 2, name: String(localized: "Explorador"), pointsRequired: 150),
    UserLevel(level: 3, name: String(localized: "Entusiasta"), pointsRequired: 400),
    UserLevel(level: 4, name: String(localized: "Conocedor"), pointsRequired: 800),
    UserLevel(level: 5, name: String(localized: "Crítico"), pointsRequired: 1500),
    UserLevel(level: 6, name: String(localized: "Maestro del Cine"), pointsRequired: 2500),
    UserLevel(level: 7, name: String(localized: "Leyenda del Cine"), pointsRequired: 4000),
  ]

  static func level(for points: Int) -> UserLevel {
    all.last(where: { points >= $0.pointsRequired }) ?? all[0]
  }

  var next: UserLevel? { Self.all.first(where: { $0.pointsRequired > pointsRequired }) }

  func pointsToNext(from points: Int) -> Int? {
    guard let next else { return nil }
    return max(0, next.pointsRequired - points)
  }

  func progress(from points: Int) -> Double {
    guard let next else { return 1 }
    let span = Double(next.pointsRequired - pointsRequired)
    guard span > 0 else { return 1 }
    return min(1, max(0, Double(points - pointsRequired) / span))
  }
}
