import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/logging/logger_factory.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_movie_rating.dart';
import '../../domain/repositories/movie_ratings_repository.dart';
import '../../infrastructure/repositories/hybrid_movie_ratings_repository.dart';
import 'auth_provider.dart';

/// Estado para el sistema de calificaciones
@immutable
class MovieRatingsState {
  const MovieRatingsState({
    this.userRatings = const [],
    this.isLoading = false,
    this.error,
    this.stats,
    this.currentMovieRating,
  });

  final List<SyncableMovieRating> userRatings;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? stats;
  final SyncableMovieRating? currentMovieRating;

  MovieRatingsState copyWith({
    List<SyncableMovieRating>? userRatings,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? stats,
    SyncableMovieRating? currentMovieRating,
    bool clearCurrentRating = false,
  }) {
    return MovieRatingsState(
      userRatings: userRatings ?? this.userRatings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      stats: stats ?? this.stats,
      currentMovieRating: clearCurrentRating
          ? null
          : (currentMovieRating ?? this.currentMovieRating),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MovieRatingsState &&
        listEquals(other.userRatings, userRatings) &&
        other.isLoading == isLoading &&
        other.error == error &&
        mapEquals(other.stats, stats) &&
        other.currentMovieRating == currentMovieRating;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(userRatings),
      isLoading,
      error,
      stats.hashCode,
      currentMovieRating,
    );
  }
}

/// Notifier para el sistema de calificaciones
class MovieRatingsNotifier extends StateNotifier<MovieRatingsState> {
  MovieRatingsNotifier(this._repository) : super(const MovieRatingsState()) {
    _initialize();
  }

  final MovieRatingsRepository _repository;
  StreamSubscription<List<SyncableMovieRating>>? _ratingsSubscription;

  /// Inicializa el provider
  Future<void> _initialize() async {
    try {
      state = state.copyWith(isLoading: true);

      // Cargar calificaciones iniciales
      await loadUserRatings();

      // Cargar estadísticas
      await loadUserStats();

      // Configurar listener de tiempo real
      _setupRealtimeListener();

      state = state.copyWith(isLoading: false);
      LoggerFactory.info('✅ MovieRatingsProvider initialized');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize MovieRatingsProvider: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize ratings: $e',
      );
    }
  }

  /// Configura el listener de tiempo real
  void _setupRealtimeListener() {
    try {
      _ratingsSubscription?.cancel();
      _ratingsSubscription = _repository.watchUserRatings().listen(
        (ratings) {
          LoggerFactory.debug(
              '🔄 Real-time ratings update: ${ratings.length} ratings');
          state = state.copyWith(userRatings: ratings);

          // Actualizar estadísticas cuando cambian las calificaciones
          loadUserStats();
        },
        onError: (error) {
          LoggerFactory.error('❌ Real-time ratings error: $error');
          state = state.copyWith(error: 'Real-time sync error: $error');
        },
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to setup realtime listener: $e');
    }
  }

  /// Carga las calificaciones del usuario
  Future<void> loadUserRatings({
    bool refresh = false,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      if (!refresh && state.userRatings.isNotEmpty) return;

      state = state.copyWith(isLoading: true);

      final ratings = await _repository.getUserRatingsSorted(
        ascending: false,
        limit: limit,
        offset: offset,
      );

      state = state.copyWith(
        userRatings: offset == 0 ? ratings : [...state.userRatings, ...ratings],
        isLoading: false,
        error: null,
      );

      LoggerFactory.debug('📊 Loaded ${ratings.length} user ratings');
    } catch (e) {
      LoggerFactory.error('❌ Failed to load user ratings: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load ratings: $e',
      );
    }
  }

  /// Carga estadísticas del usuario
  Future<void> loadUserStats() async {
    try {
      final stats = await _repository.getUserRatingStats();
      state = state.copyWith(stats: stats);
      LoggerFactory.debug('📈 Loaded user rating stats');
    } catch (e) {
      LoggerFactory.error('❌ Failed to load user stats: $e');
    }
  }

  /// Califica una película
  Future<bool> rateMovie({
    required Movie movie,
    required double rating,
    String? review,
    bool isPublic = false,
    List<String> tags = const [],
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      await _repository.rateMovie(
        movie: movie,
        rating: rating,
        review: review,
        isPublic: isPublic,
        tags: tags,
      );

      // Recargar calificaciones y estadísticas
      await Future.wait([
        loadUserRatings(refresh: true),
        loadUserStats(),
      ]);

      state = state.copyWith(isLoading: false, error: null);
      LoggerFactory.info('⭐ Successfully rated movie: ${movie.id}');
      return true;
    } catch (e) {
      LoggerFactory.error('❌ Failed to rate movie: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to rate movie: $e',
      );
      return false;
    }
  }

  /// Actualiza una calificación existente
  Future<bool> updateRating({
    required int movieId,
    required double rating,
    String? review,
    bool? isPublic,
    List<String>? tags,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      await _repository.updateRating(
        movieId: movieId,
        rating: rating,
        review: review,
        isPublic: isPublic,
        tags: tags,
      );

      // Recargar calificaciones y estadísticas
      await Future.wait([
        loadUserRatings(refresh: true),
        loadUserStats(),
      ]);

      state = state.copyWith(isLoading: false, error: null);
      LoggerFactory.info('📝 Successfully updated rating: $movieId');
      return true;
    } catch (e) {
      LoggerFactory.error('❌ Failed to update rating: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update rating: $e',
      );
      return false;
    }
  }

  /// Elimina una calificación
  Future<bool> removeRating(int movieId) async {
    try {
      state = state.copyWith(isLoading: true);

      await _repository.removeRating(movieId);

      // Recargar calificaciones y estadísticas
      await Future.wait([
        loadUserRatings(refresh: true),
        loadUserStats(),
      ]);

      state = state.copyWith(
        isLoading: false,
        error: null,
        clearCurrentRating: true,
      );
      LoggerFactory.info('🗑️ Successfully removed rating: $movieId');
      return true;
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove rating: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to remove rating: $e',
      );
      return false;
    }
  }

  /// Obtiene la calificación del usuario para una película específica
  Future<SyncableMovieRating?> getUserRating(int movieId) async {
    try {
      // Primero buscar en el estado actual
      final existingRating =
          state.userRatings.where((r) => r.movieId == movieId).firstOrNull;

      if (existingRating != null) {
        state = state.copyWith(currentMovieRating: existingRating);
        return existingRating;
      }

      // Si no está en el estado, buscar en el repositorio
      final rating = await _repository.getUserRating(movieId);
      state = state.copyWith(currentMovieRating: rating);
      return rating;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user rating: $e');
      return null;
    }
  }

  /// Verifica si el usuario ya calificó una película
  Future<bool> hasUserRatedMovie(int movieId) async {
    try {
      // Verificar en el estado actual primero
      final hasRating = state.userRatings.any((r) => r.movieId == movieId);
      if (hasRating) return true;

      // Verificar en el repositorio
      return await _repository.hasUserRatedMovie(movieId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to check if user rated movie: $e');
      return false;
    }
  }

  /// Busca calificaciones por texto
  Future<List<SyncableMovieRating>> searchRatings(String query) async {
    try {
      if (query.trim().isEmpty) return state.userRatings;

      return await _repository.searchRatingsByReviewText(
        query: query,
        limit: 50,
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to search ratings: $e');
      return [];
    }
  }

  /// Obtiene calificaciones filtradas por rating
  Future<List<SyncableMovieRating>> getRatingsByRating({
    double? minRating,
    double? maxRating,
  }) async {
    try {
      return await _repository.getUserRatingsByRating(
        minRating: minRating,
        maxRating: maxRating,
        limit: 100,
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to get ratings by rating: $e');
      return [];
    }
  }

  /// Obtiene calificaciones con reseña
  Future<List<SyncableMovieRating>> getRatingsWithReviews() async {
    try {
      return await _repository.getUserRatingsWithReviews(limit: 100);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get ratings with reviews: $e');
      return [];
    }
  }

  /// Obtiene calificaciones recientes
  Future<List<SyncableMovieRating>> getRecentRatings({int days = 30}) async {
    try {
      return await _repository.getRecentRatings(days: days);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get recent ratings: $e');
      return [];
    }
  }

  /// Obtiene resumen de calificación para una película
  Future<Map<String, dynamic>?> getMovieRatingSummary(int movieId) async {
    try {
      return await _repository.getMovieRatingSummary(movieId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get movie rating summary: $e');
      return null;
    }
  }

  /// Stream para una calificación específica
  Stream<SyncableMovieRating?> watchMovieRating(int movieId) {
    try {
      return _repository.watchUserRating(movieId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to watch movie rating: $e');
      return Stream.value(null);
    }
  }

  /// Limpia el error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Limpia la calificación actual
  void clearCurrentRating() {
    state = state.copyWith(clearCurrentRating: true);
  }

  @override
  void dispose() {
    _ratingsSubscription?.cancel();
    super.dispose();
  }
}

/// Provider para el repositorio de calificaciones
final movieRatingsRepositoryProvider = Provider<MovieRatingsRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  final userId = user?.id ?? 'anonymous';

  return HybridMovieRatingsRepository(userId: userId);
});

/// Provider principal para el estado de calificaciones
final movieRatingsProvider =
    StateNotifierProvider<MovieRatingsNotifier, MovieRatingsState>((ref) {
  final repository = ref.watch(movieRatingsRepositoryProvider);
  return MovieRatingsNotifier(repository);
});

/// Provider para obtener una calificación específica
final movieRatingProvider =
    FutureProvider.family<SyncableMovieRating?, int>((ref, movieId) async {
  final notifier = ref.watch(movieRatingsProvider.notifier);
  return await notifier.getUserRating(movieId);
});

/// Provider para verificar si una película está calificada
final isMovieRatedProvider =
    FutureProvider.family<bool, int>((ref, movieId) async {
  final notifier = ref.watch(movieRatingsProvider.notifier);
  return await notifier.hasUserRatedMovie(movieId);
});

/// Provider para las estadísticas de calificaciones
final userRatingStatsProvider = Provider<Map<String, dynamic>?>((ref) {
  final state = ref.watch(movieRatingsProvider);
  return state.stats;
});

/// Provider para calificaciones recientes
final recentRatingsProvider =
    FutureProvider<List<SyncableMovieRating>>((ref) async {
  final notifier = ref.watch(movieRatingsProvider.notifier);
  return await notifier.getRecentRatings(days: 30);
});

/// Provider para calificaciones con reseña
final ratingsWithReviewsProvider =
    FutureProvider<List<SyncableMovieRating>>((ref) async {
  final notifier = ref.watch(movieRatingsProvider.notifier);
  return await notifier.getRatingsWithReviews();
});

/// Provider para obtener resumen de calificaciones de una película
final movieRatingSummaryProvider =
    FutureProvider.family<Map<String, dynamic>?, int>((ref, movieId) async {
  final notifier = ref.watch(movieRatingsProvider.notifier);
  return await notifier.getMovieRatingSummary(movieId);
});
