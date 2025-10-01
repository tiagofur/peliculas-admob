import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_movie_rating.dart';
import '../../services/unified_rating_service.dart';

/// Estado del sistema de ratings unificado
class UnifiedRatingsState {
  const UnifiedRatingsState({
    this.ratings = const {},
    this.isLoading = false,
    this.error,
    this.stats,
  });

  final Map<int, SyncableMovieRating> ratings;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? stats;

  UnifiedRatingsState copyWith({
    Map<int, SyncableMovieRating>? ratings,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? stats,
    bool clearError = false,
  }) {
    return UnifiedRatingsState(
      ratings: ratings ?? this.ratings,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      stats: stats ?? this.stats,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedRatingsState &&
        other.ratings == ratings &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.stats == stats;
  }

  @override
  int get hashCode => Object.hash(ratings, isLoading, error, stats);
}

/// Provider unificado de ratings
///
/// Reemplaza:
/// - DirectRatingsProvider
/// - MovieRatingsProvider
/// - UserMovieRatingsProvider
///
/// Ventajas:
/// - ✅ Una sola fuente de verdad
/// - ✅ Real-time sync automático
/// - ✅ Código más simple y mantenible
/// - ✅ Sin dependencias circulares
class UnifiedRatingsNotifier extends Notifier<UnifiedRatingsState> {
  final _service = UnifiedRatingService.instance;
  StreamSubscription<Map<int, SyncableMovieRating>>? _ratingsSubscription;

  @override
  UnifiedRatingsState build() {
    // Set up disposal callback
    ref.onDispose(() {
      _ratingsSubscription?.cancel();
    });

    // Ensure state is initialized before any async work runs
    state = const UnifiedRatingsState();

    // Kick off initialization without blocking the initial build
    Future.microtask(_initialize);

    return state;
  }

  Future<void> _initialize() async {
    try {
      state = state.copyWith(isLoading: true);

      // Inicializar servicio
      await _service.initialize();

      // Suscribirse a cambios del servicio
      _ratingsSubscription = _service.ratingsStream.listen(
        (ratings) {
          final stats = _service.getStats();
          state = state.copyWith(
            ratings: ratings,
            isLoading: false,
            stats: stats,
            clearError: true,
          );
          LoggerFactory.debug('✅ State updated: ${ratings.length} ratings');
        },
        onError: (error) {
          LoggerFactory.error('❌ Stream error: $error');
          state = state.copyWith(
            isLoading: false,
            error: error.toString(),
          );
        },
      );

      // Cargar estado inicial
      final initialRatings = _service.currentRatings;
      final initialStats = _service.getStats();

      state = state.copyWith(
        ratings: initialRatings,
        stats: initialStats,
        isLoading: false,
        clearError: true,
      );

      LoggerFactory.info(
          '✅ UnifiedRatingsProvider initialized with ${initialRatings.length} ratings');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Failed to initialize UnifiedRatingsProvider: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Califica una película
  Future<void> rateMovie({
    required Movie movie,
    required double rating,
    String? review,
    bool isPublic = false,
    List<String> tags = const [],
  }) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      await _service.rateMovie(
        movie: movie,
        rating: rating,
        review: review,
        isPublic: isPublic,
        tags: tags,
      );

      // El stream actualizará el estado automáticamente
      LoggerFactory.info('✅ Movie rated successfully: ${movie.title}');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Error rating movie: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Error al calificar: $e',
      );
      rethrow;
    }
  }

  /// Actualiza una calificación existente
  Future<void> updateRating({
    required int movieId,
    required double rating,
    String? review,
    bool? isPublic,
    List<String>? tags,
  }) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      await _service.updateRating(
        movieId: movieId,
        rating: rating,
        review: review,
        isPublic: isPublic,
        tags: tags,
      );

      LoggerFactory.info('✅ Rating updated successfully');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Error updating rating: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Error al actualizar: $e',
      );
      rethrow;
    }
  }

  /// Elimina una calificación
  Future<void> deleteRating(int movieId) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      await _service.deleteRating(movieId);

      LoggerFactory.info('✅ Rating deleted successfully');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Error deleting rating: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Error al eliminar: $e',
      );
      rethrow;
    }
  }

  /// Obtiene rating de una película
  SyncableMovieRating? getRating(int movieId) {
    return state.ratings[movieId];
  }

  /// Verifica si una película está calificada
  bool isMovieRated(int movieId) {
    return state.ratings.containsKey(movieId);
  }

  /// Obtiene todas las calificaciones
  List<SyncableMovieRating> getAllRatings() {
    return state.ratings.values.toList();
  }

  /// Recarga ratings desde Supabase
  Future<void> refresh() async {
    await _service.initialize();
  }

  /// Limpia el error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider principal de ratings unificado
final unifiedRatingsProvider =
    NotifierProvider<UnifiedRatingsNotifier, UnifiedRatingsState>(() {
  return UnifiedRatingsNotifier();
});

/// Provider para obtener calificaciones recientes ordenadas por fecha
final recentRatingsProvider = Provider<List<SyncableMovieRating>>((ref) {
  final state = ref.watch(unifiedRatingsProvider);
  final allRatings = state.ratings.values.toList();
  allRatings.sort((a, b) => b.ratedAt.compareTo(a.ratedAt));
  return allRatings;
});

/// Provider para verificar si una película está calificada
final isMovieRatedProvider = Provider.family<bool, int>((ref, movieId) {
  final ratingsState = ref.watch(unifiedRatingsProvider);
  return ratingsState.ratings.containsKey(movieId);
});

/// Provider para obtener el rating de una película
final movieRatingProvider =
    Provider.family<SyncableMovieRating?, int>((ref, movieId) {
  final ratingsState = ref.watch(unifiedRatingsProvider);
  return ratingsState.ratings[movieId];
});

/// Provider para el conteo de ratings
final ratingsCountProvider = Provider<int>((ref) {
  final ratingsState = ref.watch(unifiedRatingsProvider);
  return ratingsState.ratings.length;
});

/// Provider para las estadísticas de ratings
final ratingsStatsProvider = Provider<Map<String, dynamic>?>((ref) {
  final ratingsState = ref.watch(unifiedRatingsProvider);
  return ratingsState.stats;
});

/// Provider para todas las calificaciones como lista
final allRatingsListProvider = Provider<List<SyncableMovieRating>>((ref) {
  final ratingsState = ref.watch(unifiedRatingsProvider);
  return ratingsState.ratings.values.toList();
});
