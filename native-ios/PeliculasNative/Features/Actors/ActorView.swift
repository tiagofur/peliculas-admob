import SwiftUI

/// Perfil del actor: foto, biografía, datos y filmografía navegable.
/// Espejo de `ActorScreen` de Flutter (`/person/:id`, skeleton→contenido, error→reintentar).
struct ActorView: View {
  @StateObject private var loader = ActorLoader()
  let personId: Int
  let personName: String

  var body: some View {
    Group {
      if loader.loading {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if loader.failed {
        VStack(spacing: 12) {
          Image(systemName: "person.crop.circle.badge.exclamationmark")
            .font(.system(size: 64))
            .foregroundStyle(.secondary)
          Text("No pudimos cargar el perfil")
            .font(.headline)
          Text("Verifica tu conexión e intenta de nuevo.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Button("Reintentar") { Task { await loader.load(id: personId) } }
            .glassProminentIfAvailable()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            ActorHeader(path: loader.profilePath, name: loader.name, department: loader.department)
            if !loader.facts.isEmpty {
              ActorFacts(facts: loader.facts)
            }
            if !loader.biography.isEmpty {
              VStack(alignment: .leading, spacing: 8) {
                Text("Biografía")
                  .font(.title2.bold())
                  .accessibilityAddTraits(.isHeader)
                Text(loader.biography)
                  .font(.body)
              }
              .padding(.horizontal)
            }
            if !loader.films.isEmpty {
              VStack(alignment: .leading, spacing: 12) {
                Text("Filmografía")
                  .font(.title2.bold())
                  .accessibilityAddTraits(.isHeader)
                  .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                  LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(loader.films) { PosterCard(item: $0, width: 110) }
                  }
                  .padding(.horizontal)
                }
              }
            }
          }
          .padding(.vertical)
        }
      }
    }
    .background(Color(.systemBackground))
    .navigationTitle(personName)
    .navigationBarTitleDisplayMode(.inline)
    .task { await loader.load(id: personId) }
  }
}

@MainActor
final class ActorLoader: ObservableObject {
  @Published private(set) var loading = true
  @Published private(set) var failed = false
  @Published private(set) var name = ""
  @Published private(set) var department = ""
  @Published private(set) var profilePath = ""
  @Published private(set) var biography = ""
  @Published private(set) var facts: [(String, String)] = []
  @Published private(set) var films: [MediaItem] = []

  func load(id: Int) async {
    loading = true
    failed = false
    defer { loading = false }
    guard let detail = try? await TMDBClient.person(id: id) else {
      failed = true
      return
    }
    name = detail.name ?? ""
    department = Self.department(detail.knownForDepartment ?? "")
    profilePath = detail.profilePath ?? ""
    biography = detail.biography ?? ""
    var f: [(String, String)] = []
    if let b = detail.birthday, !b.isEmpty {
      let shown = UpNextStore.parseDay(b)?.formatted(.dateTime.day().month(.wide).year()) ?? b
      f.append((String(localized: "Nacimiento"), shown))
    }
    if let p = detail.placeOfBirth, !p.isEmpty { f.append((String(localized: "Lugar"), p)) }
    facts = f
    if let credits = try? await TMDBClient.personCredits(id: id) {
      // Lo más conocido primero, sin duplicados (un actor puede salir dos veces en una serie).
      var seen = Set<MediaKey>()
      films = credits
        .map { MediaItem(tmdb: $0, kind: $0.mediaType == "tv" ? .tv : .movie) }
        .filter { !$0.posterPath.isEmpty && seen.insert($0.key).inserted }
        .sorted { $0.rating > $1.rating }
        .prefix(30).map { $0 }
    }
  }

  /// TMDB manda el departamento siempre en inglés.
  private static func department(_ raw: String) -> String {
    switch raw {
    case "Acting": return String(localized: "Actuación")
    case "Directing": return String(localized: "Dirección")
    case "Writing": return String(localized: "Guion")
    case "Production": return String(localized: "Producción")
    case "Creator": return String(localized: "Creación")
    case "Sound": return String(localized: "Sonido")
    case "Camera": return String(localized: "Fotografía")
    case "Editing": return String(localized: "Montaje")
    case "Art": return String(localized: "Dirección de arte")
    case "Visual Effects": return String(localized: "Efectos visuales")
    case "Costume & Make-Up": return String(localized: "Vestuario y maquillaje")
    case "Crew": return String(localized: "Equipo técnico")
    default: return raw
    }
  }
}

private struct ActorHeader: View {
  let path: String
  let name: String
  let department: String

  var body: some View {
    HStack(spacing: 16) {
      Group {
        if let url = TMDBImage.url(path: path, size: "w185") {
          AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
              image.resizable().scaledToFill()
            default:
              Color.secondary.opacity(0.25)
            }
          }
        } else {
          Color.secondary.opacity(0.25)
        }
      }
      .frame(width: 110, height: 110)
      .clipShape(Circle())
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(name.isEmpty ? "—" : name)
          .font(.title.bold())
        if !department.isEmpty {
          Text(department)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.horizontal)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(name)
  }
}

private struct ActorFacts: View {
  let facts: [(String, String)]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(facts, id: \.0) { label, value in
        HStack {
          Text(label)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(width: 90, alignment: .leading)
          Text(value)
            .font(.subheadline)
        }
      }
    }
    .padding(.horizontal)
  }
}
