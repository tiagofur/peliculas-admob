import SwiftUI

/// Cuadrícula completa de una fila ("Ver todo").
struct SeeAllView: View {
  let title: String
  let items: [MediaItem]

  var body: some View {
    ScrollView {
      PosterGrid(items: items)
        .padding(.vertical)
    }
    .background(Color(.systemBackground))
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.large)
  }
}

/// Cuadrícula adaptable de pósters con título.
struct PosterGrid: View {
  let items: [MediaItem]
  var badge: ((MediaItem) -> String?)? = nil

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 140), spacing: 14, alignment: .top)], spacing: 20) {
      ForEach(items) { item in
        PosterCard(item: item, width: 104, badge: badge?(item))
      }
    }
    .padding(.horizontal, 20)
  }
}
