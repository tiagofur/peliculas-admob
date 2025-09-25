import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/user_movie_rating.dart';

/// Estado para las calificaciones (minimalista)
class DirectRatingsState {
  const DirectRatingsState({
    this.ratings = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.isInitialized = false,
  });

  final List<UserMovieRating> ratings;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final bool isInitialized;

  DirectRatingsState copyWith({
    List<UserMovieRating>? ratings,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    bool? isInitialized,
  }) {
    return DirectRatingsState(
      ratings: ratings ?? this.ratings,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  /// Helpers for compatibility
  bool isMovieRated(int movieId) => ratings.any((r) => r.movieId == movieId);

  UserMovieRating? getRating(int movieId) {
    try {
      return ratings.firstWhere((r) => r.movieId == movieId);
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() =>
      'DirectRatingsState(ratings: ${ratings.length}, isLoading: $isLoading)';
}

/// Service minimalista para ratings
class DirectRatingsNotifier extends Notifier<DirectRatingsState> {
  @override
  DirectRatingsState build() {
    LoggerFactory.info('DirectRatings: Inicializando notifier minimalista');
    return const DirectRatingsState(isInitialized: true);
  }

  /// Método stub para compatibilidad
  Future<void> refresh() async {
    LoggerFactory.info('DirectRatings: refresh() - No implementado');
  }

  /// Método stub para compatibilidad
  Future<void> updateRating(UserMovieRating rating) async {
    LoggerFactory.info('DirectRatings: updateRating() - No implementado');
  }

  /// Método stub para compatibilidad
  Future<void> deleteRating(int movieId) async {
    LoggerFactory.info('DirectRatings: deleteRating() - No implementado');
  }
}

/// Service minimalista para ratings (usando Provider simple)
class DirectRatingsService {
  const DirectRatingsService();

  /// Método stub para compatibilidad
  Future<void> refresh() async {
    LoggerFactory.info('DirectRatings: refresh() - No implementado');
  }

  /// Método stub para compatibilidad
  Future<void> updateRating(UserMovieRating rating) async {
    LoggerFactory.info('DirectRatings: updateRating() - No implementado');
  }

  /// Método stub para compatibilidad
  Future<void> deleteRating(int movieId) async {
    LoggerFactory.info('DirectRatings: deleteRating() - No implementado');
  }
}

/// Provider minimalista para ratings
final directRatingsProvider =
    NotifierProvider.autoDispose<DirectRatingsNotifier, DirectRatingsState>(
  () => DirectRatingsNotifier(),
);

/// Provider para el servicio (compatibility)
final directRatingsServiceProvider =
    Provider.autoDispose<DirectRatingsService>((ref) {
  return const DirectRatingsService();
});
