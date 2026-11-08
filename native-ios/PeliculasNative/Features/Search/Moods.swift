import SwiftUI

/// Descubrimiento curado ("¿qué vemos hoy?"): cada mood es `discover` con
/// filtros fijos, como las categorías de la app Flutter.
enum Mood: String, CaseIterable, Identifiable {
  case romantic, hiddenGems, adrenaline, cry, family, mindBending, comfort, scaryNight

  var id: String { rawValue }

  var title: String.LocalizationValue {
    switch self {
    case .romantic: return "Noche romántica"
    case .hiddenGems: return "Joyas ocultas"
    case .adrenaline: return "Adrenalina pura"
    case .cry: return "Para llorar"
    case .family: return "Plan familiar"
    case .mindBending: return "Mente viajada"
    case .comfort: return "Comedia ligera"
    case .scaryNight: return "Noche de sustos"
    }
  }

  var icon: String {
    switch self {
    case .romantic: return "heart.fill"
    case .hiddenGems: return "gem.fill" // fallback manual: ver MoodTile
    case .adrenaline: return "bolt.fill"
    case .cry: return "drop.fill"
    case .family: return "person.3.fill"
    case .mindBending: return "brain.head.profile"
    case .comfort: return "face.smiling.inverse"
    case .scaryNight: return "moon.stars.fill"
    }
  }

  var colors: (Color, Color) {
    switch self {
    case .romantic: return (.pink, .red)
    case .hiddenGems: return (.teal, .mint)
    case .adrenaline: return (.orange, .red)
    case .cry: return (.indigo, .blue)
    case .family: return (.yellow, .orange)
    case .mindBending: return (.purple, .indigo)
    case .comfort: return (.green, .mint)
    case .scaryNight: return (.black.opacity(0.8), .purple)
    }
  }

  /// Filtros de discover: géneros TMDB + piso de votos (+ nota mínima si aplica).
  var source: MediaListSource {
    switch self {
    case .romantic: return .discover(kind: .movie, genreIds: "10749", voteFloor: 200)
    case .hiddenGems: return .discover(kind: .movie, genreIds: "18", voteFloor: 300, minRating: 7.2, order: "vote_count.desc")
    case .adrenaline: return .discover(kind: .movie, genreIds: "28", voteFloor: 200)
    case .cry: return .discover(kind: .movie, genreIds: "18", voteFloor: 300, minRating: 7)
    case .family: return .discover(kind: .movie, genreIds: "10751", voteFloor: 150)
    case .mindBending: return .discover(kind: .movie, genreIds: "878,9648", voteFloor: 300, minRating: 7)
    case .comfort: return .discover(kind: .movie, genreIds: "35", voteFloor: 200)
    case .scaryNight: return .discover(kind: .movie, genreIds: "27", voteFloor: 150)
    }
  }
}

/// Mosaico de mood con gradiente e icono (hermana de `GenreTile`).
struct MoodTile: View {
  let mood: Mood

  var body: some View {
    let colors = mood.colors
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: mood.icon == "gem.fill" ? "sparkles" : mood.icon)
        .font(.title3)
      Text(String(localized: mood.title))
        .font(.headline)
        .multilineTextAlignment(.leading)
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, minHeight: 84, alignment: .bottomLeading)
    .padding(14)
    .background(LinearGradient(colors: [colors.0, colors.1], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .shadow(color: colors.1.opacity(0.25), radius: 6, y: 3)
  }
}
