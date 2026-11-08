import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/logging/logger_factory.dart';
import '../domain/entities/movie.dart';
import '../domain/entities/movie_rating.dart';

/// Servicio para compartir contenido en redes sociales y otras plataformas
class SocialSharingService {
  SocialSharingService._();

  static final SocialSharingService _instance = SocialSharingService._();
  static SocialSharingService get instance => _instance;

  /// Comparte información de una película
  Future<void> shareMovie({
    required Movie movie,
    String? customMessage,
    ShareContext context = ShareContext.general,
  }) async {
    try {
      LoggerFactory.info('📤 Sharing movie: ${movie.title}');

      final message = _buildMovieShareMessage(movie, customMessage, context);
      final subject = 'Te recomiendo esta película: ${movie.title}';

      await SharePlus.instance.share(ShareParams(
        text: message,
        subject: subject,
      ));

      LoggerFactory.info('✅ Movie shared successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to share movie: $e');
      rethrow;
    }
  }

  /// Comparte una reseña de película
  Future<void> shareReview({
    required Movie movie,
    required MovieRating rating,
    String? customMessage,
  }) async {
    try {
      LoggerFactory.info('📤 Sharing review for: ${movie.title}');

      final message = _buildReviewShareMessage(movie, rating, customMessage);
      final subject = 'Mi reseña de ${movie.title}';

      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: subject,
        ),
      );

      LoggerFactory.info('✅ Review shared successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to share review: $e');
      rethrow;
    }
  }

  /// Comparte una lista de películas (watchlist, favoritos, etc.)
  Future<void> shareMovieList({
    required List<Movie> movies,
    required String listName,
    String? customMessage,
    int maxMoviesInShare = 5,
  }) async {
    try {
      LoggerFactory.info(
          '📤 Sharing movie list: $listName (${movies.length} movies)');

      final message = _buildMovieListShareMessage(
        movies,
        listName,
        customMessage,
        maxMoviesInShare,
      );
      final subject = 'Mi lista: $listName';

      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: subject,
        ),
      );

      LoggerFactory.info('✅ Movie list shared successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to share movie list: $e');
      rethrow;
    }
  }

  /// Comparte con una imagen (película poster)
  Future<void> shareMovieWithImage({
    required Movie movie,
    required Uint8List imageBytes,
    String? customMessage,
  }) async {
    try {
      LoggerFactory.info('📤 Sharing movie with image: ${movie.title}');

      final message =
          _buildMovieShareMessage(movie, customMessage, ShareContext.withImage);

      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Te recomiendo esta película: ${movie.title}',
          files: [
            XFile.fromData(imageBytes,
                mimeType: 'image/png', name: '${movie.title}_poster.png')
          ],
        ),
      );

      LoggerFactory.info('✅ Movie with image shared successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to share movie with image: $e');
      rethrow;
    }
  }

  /// Genera deep link para una película
  String generateMovieDeepLink(Movie movie) {
    // En un app real, esto sería tu dominio personalizado
    const baseUrl = 'https://peliculasapp.com';
    final deepLink =
        '$baseUrl/movie/${movie.id}?title=${Uri.encodeComponent(movie.title)}';

    LoggerFactory.info('🔗 Generated deep link for ${movie.title}: $deepLink');
    return deepLink;
  }

  /// Genera deep link para una reseña
  String generateReviewDeepLink(Movie movie, MovieRating rating) {
    const baseUrl = 'https://peliculasapp.com';
    final deepLink = '$baseUrl/movie/${movie.id}/review/${rating.id}';

    LoggerFactory.info('🔗 Generated review deep link: $deepLink');
    return deepLink;
  }

  /// Comparte con deep link incluido
  Future<void> shareMovieWithDeepLink({
    required Movie movie,
    String? customMessage,
    bool includeAppInvitation = true,
  }) async {
    try {
      LoggerFactory.info('📤 Sharing movie with deep link: ${movie.title}');

      final deepLink = generateMovieDeepLink(movie);
      final message = _buildMovieShareMessageWithDeepLink(
        movie,
        deepLink,
        customMessage,
        includeAppInvitation,
      );

      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: '🎬 Te recomiendo esta película',
        ),
      );

      LoggerFactory.info('✅ Movie with deep link shared successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to share movie with deep link: $e');
      rethrow;
    }
  }

  /// Copia contenido al portapapeles
  Future<void> copyToClipboard({
    required String content,
    String? successMessage,
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      LoggerFactory.info('📋 Content copied to clipboard');
    } catch (e) {
      LoggerFactory.error('❌ Failed to copy to clipboard: $e');
      rethrow;
    }
  }

  /// Comparte estadísticas del usuario
  Future<void> shareUserStats({
    required Map<String, dynamic> stats,
    String? customMessage,
  }) async {
    try {
      LoggerFactory.info('📤 Sharing user stats');

      final message = _buildUserStatsShareMessage(stats, customMessage);

      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: '🎬 Mis estadísticas de películas',
        ),
      );

      LoggerFactory.info('✅ User stats shared successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to share user stats: $e');
      rethrow;
    }
  }

  /// Construye el mensaje para compartir una película
  String _buildMovieShareMessage(
      Movie movie, String? customMessage, ShareContext context) {
    final buffer = StringBuffer();

    if (customMessage != null && customMessage.isNotEmpty) {
      buffer.writeln(customMessage);
      buffer.writeln();
    }

    buffer.writeln('🎬 ${movie.title}');

    if (movie.releaseDate.year > 1900) {
      buffer.writeln('📅 ${movie.releaseDate.year}');
    }

    if (movie.voteAverage > 0) {
      buffer.writeln('⭐ ${movie.voteAverage.toStringAsFixed(1)}/10');
    }

    if (movie.overview.isNotEmpty) {
      final shortOverview = movie.overview.length > 150
          ? '${movie.overview.substring(0, 150)}...'
          : movie.overview;
      buffer.writeln();
      buffer.writeln(shortOverview);
    }

    switch (context) {
      case ShareContext.recommendation:
        buffer.writeln();
        buffer.writeln('¡Te la recomiendo! 👍');
        break;
      case ShareContext.watchlist:
        buffer.writeln();
        buffer.writeln('La tengo en mi lista para ver 📝');
        break;
      case ShareContext.favorite:
        buffer.writeln();
        buffer.writeln('¡Es una de mis favoritas! ❤️');
        break;
      default:
        break;
    }

    buffer.writeln();
    buffer.writeln('#PeliculasApp #Cine #Recomendaciones');

    return buffer.toString();
  }

  /// Construye el mensaje para compartir una reseña
  String _buildReviewShareMessage(
      Movie movie, MovieRating rating, String? customMessage) {
    final buffer = StringBuffer();

    if (customMessage != null && customMessage.isNotEmpty) {
      buffer.writeln(customMessage);
      buffer.writeln();
    }

    buffer.writeln('🎬 Mi reseña de "${movie.title}"');
    buffer.writeln();

    // Rating con estrellas visuales
    final stars = '⭐' * rating.rating.round();
    buffer.writeln('$stars ${rating.rating.toStringAsFixed(1)}/5');
    buffer.writeln();

    if (rating.hasReview) {
      if (rating.containsSpoilers) {
        buffer.writeln('⚠️ CONTIENE SPOILERS ⚠️');
        buffer.writeln();
      }

      buffer.writeln(rating.review);
      buffer.writeln();
    }

    buffer.writeln('Película: ${movie.title} (${movie.releaseDate.year})');
    buffer.writeln();
    buffer.writeln('#PeliculasApp #Reseña #${movie.title.replaceAll(' ', '')}');

    return buffer.toString();
  }

  /// Construye el mensaje para compartir una lista de películas
  String _buildMovieListShareMessage(
    List<Movie> movies,
    String listName,
    String? customMessage,
    int maxMoviesInShare,
  ) {
    final buffer = StringBuffer();

    if (customMessage != null && customMessage.isNotEmpty) {
      buffer.writeln(customMessage);
      buffer.writeln();
    }

    buffer.writeln('🎬 Mi lista: $listName');
    buffer.writeln('📝 ${movies.length} películas');
    buffer.writeln();

    final moviesToShow = movies.take(maxMoviesInShare).toList();

    for (int i = 0; i < moviesToShow.length; i++) {
      final movie = moviesToShow[i];
      buffer.writeln(
          '${i + 1}. ${movie.title} (${movie.releaseDate.year}) ⭐${movie.voteAverage.toStringAsFixed(1)}');
    }

    if (movies.length > maxMoviesInShare) {
      buffer.writeln('... y ${movies.length - maxMoviesInShare} más');
    }

    buffer.writeln();
    buffer.writeln('#PeliculasApp #ListaPeliculas #Cine');

    return buffer.toString();
  }

  /// Construye el mensaje con deep link
  String _buildMovieShareMessageWithDeepLink(
    Movie movie,
    String deepLink,
    String? customMessage,
    bool includeAppInvitation,
  ) {
    final buffer = StringBuffer();

    if (customMessage != null && customMessage.isNotEmpty) {
      buffer.writeln(customMessage);
      buffer.writeln();
    }

    buffer.writeln('🎬 Te recomiendo "${movie.title}"');

    if (movie.releaseDate.year > 1900) {
      buffer.writeln('📅 ${movie.releaseDate.year}');
    }

    if (movie.voteAverage > 0) {
      buffer.writeln('⭐ ${movie.voteAverage.toStringAsFixed(1)}/10');
    }

    if (movie.overview.isNotEmpty) {
      final shortOverview = movie.overview.length > 100
          ? '${movie.overview.substring(0, 100)}...'
          : movie.overview;
      buffer.writeln();
      buffer.writeln(shortOverview);
    }

    buffer.writeln();
    buffer.writeln('👀 Ver más detalles: $deepLink');

    if (includeAppInvitation) {
      buffer.writeln();
      buffer.writeln(
          '📱 ¡Descarga PeliculasApp para descubrir más películas increíbles!');
    }

    return buffer.toString();
  }

  /// Construye el mensaje para compartir estadísticas del usuario
  String _buildUserStatsShareMessage(
      Map<String, dynamic> stats, String? customMessage) {
    final buffer = StringBuffer();

    if (customMessage != null && customMessage.isNotEmpty) {
      buffer.writeln(customMessage);
      buffer.writeln();
    }

    buffer.writeln('🎬 Mis estadísticas de películas');
    buffer.writeln();

    if (stats['totalMoviesRated'] != null) {
      buffer.writeln('🌟 Películas calificadas: ${stats['totalMoviesRated']}');
    }

    if (stats['averageRating'] != null) {
      final avgRating = (stats['averageRating'] as num).toDouble();
      buffer.writeln(
          '📊 Calificación promedio: ${avgRating.toStringAsFixed(1)}/5');
    }

    if (stats['favoriteGenre'] != null) {
      buffer.writeln('🎭 Género favorito: ${stats['favoriteGenre']}');
    }

    if (stats['totalWatchTime'] != null) {
      final hours = (stats['totalWatchTime'] as num) / 60;
      buffer
          .writeln('⏱️ Tiempo total visto: ${hours.toStringAsFixed(0)} horas');
    }

    if (stats['watchlistSize'] != null) {
      buffer.writeln('📝 Películas en lista: ${stats['watchlistSize']}');
    }

    buffer.writeln();
    buffer.writeln('📱 Únete a PeliculasApp y comparte tu pasión por el cine');
    buffer.writeln('#PeliculasApp #Cine #Estadísticas');

    return buffer.toString();
  }

  /// Obtiene información del usuario para invitaciones
  ShareableUserProfile createShareableProfile({
    required String userName,
    required Map<String, dynamic> stats,
    List<Movie>? favoriteMovies,
  }) {
    return ShareableUserProfile(
      userName: userName,
      stats: stats,
      favoriteMovies: favoriteMovies ?? [],
      profileDeepLink:
          'https://peliculasapp.com/user/${Uri.encodeComponent(userName)}',
    );
  }

  /// Comparte perfil de usuario
  Future<void> shareUserProfile(ShareableUserProfile profile) async {
    try {
      LoggerFactory.info('📤 Sharing user profile: ${profile.userName}');

      final message = _buildUserProfileShareMessage(profile);

      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: '👤 Perfil de ${profile.userName} en PeliculasApp',
        ),
      );

      LoggerFactory.info('✅ User profile shared successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to share user profile: $e');
      rethrow;
    }
  }

  /// Construye el mensaje del perfil de usuario
  String _buildUserProfileShareMessage(ShareableUserProfile profile) {
    final buffer = StringBuffer();

    buffer.writeln('👤 Perfil de ${profile.userName}');
    buffer.writeln();

    if (profile.stats['totalMoviesRated'] != null &&
        profile.stats['totalMoviesRated'] > 0) {
      buffer.writeln(
          '🎬 ${profile.stats['totalMoviesRated']} películas calificadas');
    }

    if (profile.favoriteMovies.isNotEmpty) {
      buffer.writeln('⭐ Películas favoritas:');
      for (int i = 0; i < profile.favoriteMovies.take(3).length; i++) {
        final movie = profile.favoriteMovies[i];
        buffer.writeln('  ${i + 1}. ${movie.title}');
      }
    }

    buffer.writeln();
    buffer.writeln('🔗 Ver perfil completo: ${profile.profileDeepLink}');
    buffer.writeln();
    buffer.writeln('📱 Únete a PeliculasApp y descubre películas increíbles');

    return buffer.toString();
  }
}

/// Contexto de compartir para personalizar mensajes
enum ShareContext {
  general,
  recommendation,
  watchlist,
  favorite,
  withImage,
}

/// Perfil de usuario compartible
class ShareableUserProfile {
  const ShareableUserProfile({
    required this.userName,
    required this.stats,
    required this.favoriteMovies,
    required this.profileDeepLink,
  });
  final String userName;
  final Map<String, dynamic> stats;
  final List<Movie> favoriteMovies;
  final String profileDeepLink;
}

/// Resultado de operación de compartir
class ShareResult {
  const ShareResult({
    required this.success,
    this.errorMessage,
    this.method,
  });

  factory ShareResult.success(ShareMethod method) {
    return ShareResult(success: true, method: method);
  }

  factory ShareResult.failure(String error) {
    return ShareResult(success: false, errorMessage: error);
  }
  final bool success;
  final String? errorMessage;
  final ShareMethod? method;
}

/// Métodos de compartir disponibles
enum ShareMethod {
  native,
  clipboard,
  whatsapp,
  facebook,
  twitter,
  instagram,
  email,
  sms,
}
