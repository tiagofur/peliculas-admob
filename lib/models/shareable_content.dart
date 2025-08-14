/// Model for shareable content that can be shared across different platforms
class ShareableContent {
  final String title;
  final String description;
  final String url;
  final String? imageUrl;
  final ShareableContentType type;
  final Map<String, dynamic>? metadata;

  const ShareableContent({
    required this.title,
    required this.description,
    required this.url,
    this.imageUrl,
    required this.type,
    this.metadata,
  });

  /// Creates a shareable content for a movie
  factory ShareableContent.movie({
    required String movieTitle,
    required String movieDescription,
    required int movieId,
    String? posterUrl,
    Map<String, dynamic>? additionalData,
  }) {
    return ShareableContent(
      title: '🎬 $movieTitle',
      description: movieDescription.length > 100 
          ? '${movieDescription.substring(0, 100)}...'
          : movieDescription,
      url: 'https://peliculas.creapolis.dev/movie/$movieId/share',
      imageUrl: posterUrl,
      type: ShareableContentType.movie,
      metadata: {
        'movieId': movieId,
        'movieTitle': movieTitle,
        ...?additionalData,
      },
    );
  }

  /// Creates a shareable content for a movie list
  factory ShareableContent.movieList({
    required String listName,
    required String listDescription,
    required String listId,
    required int movieCount,
    String? coverImageUrl,
    Map<String, dynamic>? additionalData,
  }) {
    return ShareableContent(
      title: '📋 $listName',
      description: '$listDescription\n\n🎬 $movieCount películas en esta lista',
      url: 'https://peliculas.creapolis.dev/list/$listId/share',
      imageUrl: coverImageUrl,
      type: ShareableContentType.movieList,
      metadata: {
        'listId': listId,
        'listName': listName,
        'movieCount': movieCount,
        ...?additionalData,
      },
    );
  }

  /// Creates a shareable content for recommendations
  factory ShareableContent.recommendation({
    required String recommendationType,
    required String recommendationId,
    required String title,
    required String description,
    String? imageUrl,
    Map<String, dynamic>? additionalData,
  }) {
    return ShareableContent(
      title: '⭐ $title',
      description: description,
      url: 'https://peliculas.creapolis.dev/recommendations/$recommendationType/$recommendationId/share',
      imageUrl: imageUrl,
      type: ShareableContentType.recommendation,
      metadata: {
        'recommendationType': recommendationType,
        'recommendationId': recommendationId,
        ...?additionalData,
      },
    );
  }

  /// Generates the text content for sharing
  String get shareText {
    final buffer = StringBuffer();
    buffer.writeln(title);
    buffer.writeln();
    buffer.writeln(description);
    buffer.writeln();
    buffer.writeln('🔗 Ver más: $url');
    buffer.writeln();
    buffer.writeln('📱 Descarga la app Películas para más contenido:');
    buffer.writeln('https://peliculas.creapolis.dev');
    
    return buffer.toString();
  }

  /// Generates the text content for sharing with custom call to action
  String shareTextWithCustomCTA(String callToAction) {
    final buffer = StringBuffer();
    buffer.writeln(title);
    buffer.writeln();
    buffer.writeln(description);
    buffer.writeln();
    buffer.writeln('🔗 $callToAction: $url');
    buffer.writeln();
    buffer.writeln('📱 Descarga la app Películas:');
    buffer.writeln('https://peliculas.creapolis.dev');
    
    return buffer.toString();
  }

  @override
  String toString() {
    return 'ShareableContent(title: $title, type: $type, url: $url)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShareableContent &&
        other.title == title &&
        other.description == description &&
        other.url == url &&
        other.imageUrl == imageUrl &&
        other.type == type;
  }

  @override
  int get hashCode {
    return Object.hash(title, description, url, imageUrl, type);
  }
}

/// Types of shareable content
enum ShareableContentType {
  movie,
  movieList,
  recommendation,
}

/// Extension to get display names for ShareableContentType
extension ShareableContentTypeExtension on ShareableContentType {
  String get displayName {
    switch (this) {
      case ShareableContentType.movie:
        return 'Película';
      case ShareableContentType.movieList:
        return 'Lista de Películas';
      case ShareableContentType.recommendation:
        return 'Recomendación';
    }
  }

  String get emoji {
    switch (this) {
      case ShareableContentType.movie:
        return '🎬';
      case ShareableContentType.movieList:
        return '📋';
      case ShareableContentType.recommendation:
        return '⭐';
    }
  }
}