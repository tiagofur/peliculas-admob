import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/movie.dart';
import '../../domain/entities/movie_rating.dart';
import '../../services/social_sharing_service.dart';

/// Provider para el servicio de compartir en redes sociales
final socialSharingServiceProvider = Provider<SocialSharingService>((ref) {
  return SocialSharingService.instance;
});

/// Provider para el estado de compartir
final shareStateProvider = NotifierProvider<ShareStateNotifier, ShareState>(() {
  return ShareStateNotifier();
});

/// Notificador para el estado de compartir
class ShareStateNotifier extends Notifier<ShareState> {
  ShareStateNotifier();

  @override
  ShareState build() {
    return const ShareState.idle();
  }

  SocialSharingService get _sharingService =>
      ref.read(socialSharingServiceProvider);

  /// Comparte una película
  Future<void> shareMovie({
    required Movie movie,
    String? customMessage,
    ShareContext context = ShareContext.general,
  }) async {
    state = const ShareState.loading();

    try {
      await _sharingService.shareMovie(
        movie: movie,
        customMessage: customMessage,
        context: context,
      );

      state = const ShareState.success('Película compartida exitosamente');
    } catch (e) {
      state = ShareState.error('Error al compartir película: $e');
    }
  }

  /// Comparte una reseña
  Future<void> shareReview({
    required Movie movie,
    required MovieRating rating,
    String? customMessage,
  }) async {
    state = const ShareState.loading();

    try {
      await _sharingService.shareReview(
        movie: movie,
        rating: rating,
        customMessage: customMessage,
      );

      state = const ShareState.success('Reseña compartida exitosamente');
    } catch (e) {
      state = ShareState.error('Error al compartir reseña: $e');
    }
  }

  /// Comparte una lista de películas
  Future<void> shareMovieList({
    required List<Movie> movies,
    required String listName,
    String? customMessage,
  }) async {
    state = const ShareState.loading();

    try {
      await _sharingService.shareMovieList(
        movies: movies,
        listName: listName,
        customMessage: customMessage,
      );

      state = const ShareState.success('Lista compartida exitosamente');
    } catch (e) {
      state = ShareState.error('Error al compartir lista: $e');
    }
  }

  /// Comparte estadísticas del usuario
  Future<void> shareUserStats({
    required Map<String, dynamic> stats,
    String? customMessage,
  }) async {
    state = const ShareState.loading();

    try {
      await _sharingService.shareUserStats(
        stats: stats,
        customMessage: customMessage,
      );

      state = const ShareState.success('Estadísticas compartidas exitosamente');
    } catch (e) {
      state = ShareState.error('Error al compartir estadísticas: $e');
    }
  }

  /// Copia contenido al portapapeles
  Future<void> copyToClipboard(String content) async {
    try {
      await _sharingService.copyToClipboard(content: content);
      state = const ShareState.success('Copiado al portapapeles');
    } catch (e) {
      state = ShareState.error('Error al copiar: $e');
    }
  }

  /// Genera deep link para una película
  String generateMovieDeepLink(Movie movie) {
    return _sharingService.generateMovieDeepLink(movie);
  }

  /// Resetea el estado
  void reset() {
    state = const ShareState.idle();
  }
}

/// Estados posibles del proceso de compartir
sealed class ShareState {
  const ShareState();

  const factory ShareState.idle() = ShareStateIdle;
  const factory ShareState.loading() = ShareStateLoading;
  const factory ShareState.success(String message) = ShareStateSuccess;
  const factory ShareState.error(String message) = ShareStateError;
}

class ShareStateIdle extends ShareState {
  const ShareStateIdle();
}

class ShareStateLoading extends ShareState {
  const ShareStateLoading();
}

class ShareStateSuccess extends ShareState {
  const ShareStateSuccess(this.message);
  final String message;
}

class ShareStateError extends ShareState {
  const ShareStateError(this.message);
  final String message;
}

/// Provider para obtener opciones de compartir según el contexto
final shareOptionsProvider =
    Provider.family<List<ShareOption>, ShareOptionsContext>((ref, context) {
  return _getShareOptionsForContext(context);
});

/// Opciones de compartir disponibles
class ShareOption {
  const ShareOption({
    required this.title,
    required this.iconPath,
    required this.context,
    this.onTap,
  });
  final String title;
  final String iconPath;
  final ShareContext context;
  final VoidCallback? onTap;
}

/// Contexto para opciones de compartir
class ShareOptionsContext {
  const ShareOptionsContext({
    required this.contentType,
    this.content,
  });
  final ShareContentType contentType;
  final dynamic content;
}

/// Tipos de contenido compartible
enum ShareContentType {
  movie,
  review,
  list,
  profile,
  stats,
}

/// Obtiene las opciones de compartir según el contexto
List<ShareOption> _getShareOptionsForContext(ShareOptionsContext context) {
  switch (context.contentType) {
    case ShareContentType.movie:
      return [
        const ShareOption(
          title: 'Recomendar',
          iconPath: 'assets/icons/recommend.png',
          context: ShareContext.recommendation,
        ),
        const ShareOption(
          title: 'Añadir a lista',
          iconPath: 'assets/icons/add_to_list.png',
          context: ShareContext.watchlist,
        ),
        const ShareOption(
          title: 'Favorita',
          iconPath: 'assets/icons/favorite.png',
          context: ShareContext.favorite,
        ),
        const ShareOption(
          title: 'Compartir general',
          iconPath: 'assets/icons/share.png',
          context: ShareContext.general,
        ),
      ];

    case ShareContentType.review:
      return [
        const ShareOption(
          title: 'Compartir reseña',
          iconPath: 'assets/icons/share_review.png',
          context: ShareContext.general,
        ),
        const ShareOption(
          title: 'Copiar enlace',
          iconPath: 'assets/icons/copy_link.png',
          context: ShareContext.general,
        ),
      ];

    case ShareContentType.list:
      return [
        const ShareOption(
          title: 'Compartir lista',
          iconPath: 'assets/icons/share_list.png',
          context: ShareContext.general,
        ),
        const ShareOption(
          title: 'Invitar amigos',
          iconPath: 'assets/icons/invite.png',
          context: ShareContext.general,
        ),
      ];

    case ShareContentType.profile:
      return [
        const ShareOption(
          title: 'Compartir perfil',
          iconPath: 'assets/icons/share_profile.png',
          context: ShareContext.general,
        ),
        const ShareOption(
          title: 'Invitar a seguir',
          iconPath: 'assets/icons/follow.png',
          context: ShareContext.general,
        ),
      ];

    case ShareContentType.stats:
      return [
        const ShareOption(
          title: 'Compartir estadísticas',
          iconPath: 'assets/icons/share_stats.png',
          context: ShareContext.general,
        ),
        const ShareOption(
          title: 'Comparar con amigos',
          iconPath: 'assets/icons/compare.png',
          context: ShareContext.general,
        ),
      ];
  }
}
