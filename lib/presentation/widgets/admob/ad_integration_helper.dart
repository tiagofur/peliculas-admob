import '../../../domain/entities/movie.dart';

/// Helper class para integrar anuncios en listas de películas
/// Calcula posiciones y maneja la lógica de inserción de anuncios
class AdIntegrationHelper {
  /// Frecuencia de anuncios en listas horizontales (cada X películas)
  static const int horizontalAdFrequency = 6;
  
  /// Frecuencia de anuncios en grids verticales (cada X películas, múltiplo de 3)
  static const int verticalAdFrequency = 15;
  
  /// Frecuencia de anuncios de línea completa en grids (cada X películas)
  static const int fullWidthAdFrequency = 9; // Múltiplo de 3 para grids de 3 columnas

  /// Calcula si debe mostrar un anuncio en la posición dada para listas horizontales
  static bool shouldShowHorizontalAd(int index) {
    return index > 0 && (index + 1) % horizontalAdFrequency == 0;
  }

  /// Calcula si debe mostrar un anuncio en grid vertical
  static bool shouldShowGridAd(int index) {
    return index > 0 && (index + 1) % verticalAdFrequency == 0;
  }

  /// Calcula si debe mostrar un anuncio de línea completa en grid
  static bool shouldShowFullWidthAd(int index) {
    return index > 0 && (index + 1) % fullWidthAdFrequency == 0;
  }

  /// Obtiene el número total de elementos incluyendo anuncios para lista horizontal
  static int getTotalHorizontalItems(int movieCount) {
    final adCount = movieCount ~/ horizontalAdFrequency;
    return movieCount + adCount;
  }

  /// Obtiene el número total de elementos incluyendo anuncios para grid vertical
  static int getTotalGridItems(int movieCount) {
    final gridAdCount = movieCount ~/ verticalAdFrequency;
    final fullWidthAdCount = movieCount ~/ fullWidthAdFrequency;
    return movieCount + gridAdCount + fullWidthAdCount;
  }

  /// Convierte índice de lista con anuncios a índice de película original
  static int getMovieIndex(int listIndex, {bool isHorizontal = true}) {
    if (isHorizontal) {
      final adsBefore = listIndex ~/ (horizontalAdFrequency + 1);
      return listIndex - adsBefore;
    } else {
      // Para grids verticales, consideramos ambos tipos de anuncios
      int movieIndex = listIndex;
      int adsCount = 0;
      
      // Contar anuncios de grid
      for (int i = 0; i <= listIndex; i++) {
        if (shouldShowGridAd(i - adsCount)) {
          adsCount++;
          movieIndex--;
        }
        if (shouldShowFullWidthAd(i - adsCount)) {
          adsCount++;
          movieIndex--;
        }
      }
      
      return movieIndex;
    }
  }

  /// Determina el tipo de elemento en una posición dada
  static AdItemType getItemType(int index, {bool isHorizontal = true}) {
    if (isHorizontal) {
      return shouldShowHorizontalAd(index) ? AdItemType.horizontalAd : AdItemType.movie;
    } else {
      final movieIndex = getMovieIndex(index, isHorizontal: false);
      
      if (shouldShowFullWidthAd(movieIndex)) {
        return AdItemType.fullWidthAd;
      } else if (shouldShowGridAd(movieIndex)) {
        return AdItemType.gridAd;
      } else {
        return AdItemType.movie;
      }
    }
  }

  /// Crea una lista mixta de películas y anuncios para listas horizontales
  static List<AdListItem> createHorizontalAdList(List<Movie> movies) {
    final List<AdListItem> items = [];
    
    for (int i = 0; i < movies.length; i++) {
      // Agregar película
      items.add(AdListItem.movie(movies[i]));
      
      // Agregar anuncio si corresponde
      if (shouldShowHorizontalAd(i)) {
        items.add(AdListItem.horizontalAd());
      }
    }
    
    return items;
  }

  /// Crea una lista mixta de películas y anuncios para grids verticales
  static List<AdListItem> createGridAdList(List<Movie> movies) {
    final List<AdListItem> items = [];
    
    for (int i = 0; i < movies.length; i++) {
      // Agregar película
      items.add(AdListItem.movie(movies[i]));
      
      // Agregar anuncio de línea completa si corresponde (prioridad)
      if (shouldShowFullWidthAd(i)) {
        items.add(AdListItem.fullWidthAd());
      }
      // Agregar anuncio de grid si corresponde
      else if (shouldShowGridAd(i)) {
        items.add(AdListItem.gridAd());
      }
    }
    
    return items;
  }
}

/// Enum para tipos de elementos en la lista
enum AdItemType {
  movie,
  horizontalAd,
  gridAd,
  fullWidthAd,
}

/// Clase que representa un elemento en la lista (película o anuncio)
class AdListItem {
  final AdItemType type;
  final Movie? movie;
  
  const AdListItem._({required this.type, this.movie});
  
  factory AdListItem.movie(Movie movie) => AdListItem._(
    type: AdItemType.movie,
    movie: movie,
  );
  
  factory AdListItem.horizontalAd() => const AdListItem._(
    type: AdItemType.horizontalAd,
  );
  
  factory AdListItem.gridAd() => const AdListItem._(
    type: AdItemType.gridAd,
  );
  
  factory AdListItem.fullWidthAd() => const AdListItem._(
    type: AdItemType.fullWidthAd,
  );
  
  bool get isMovie => type == AdItemType.movie;
  bool get isHorizontalAd => type == AdItemType.horizontalAd;
  bool get isGridAd => type == AdItemType.gridAd;
  bool get isFullWidthAd => type == AdItemType.fullWidthAd;
  bool get isAd => !isMovie;
}