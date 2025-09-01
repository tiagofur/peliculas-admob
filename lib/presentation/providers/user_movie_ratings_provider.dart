import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user_movie_rating.dart';
import '../../domain/repositories/user_movie_ratings_repository.dart';
import '../../infrastructure/repositories/user_movie_ratings_repository_impl.dart';

// Provider del repositorio
final userMovieRatingsRepositoryProvider = Provider<UserMovieRatingsRepository>((ref) {
  return UserMovieRatingsRepositoryImpl();
});

// Provider para obtener la valoración de una película específica
final movieRatingProvider = FutureProvider.family<UserMovieRating?, int>((ref, movieId) async {
  final repository = ref.watch(userMovieRatingsRepositoryProvider);
  return repository.getUserRating(movieId);
});

// Provider para las valoraciones del usuario
final userRatingsProvider = StateNotifierProvider<UserRatingsNotifier, UserRatingsState>((ref) {
  final repository = ref.watch(userMovieRatingsRepositoryProvider);
  return UserRatingsNotifier(repository);
});

// Provider para estadísticas de valoraciones
final userRatingStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(userMovieRatingsRepositoryProvider);
  return repository.getRatingStats();
});

// Provider para las mejores películas valoradas
final topRatedMoviesProvider = FutureProvider.family<List<UserMovieRating>, int>((ref, limit) async {
  final repository = ref.watch(userMovieRatingsRepositoryProvider);
  return repository.getTopRatedMovies(limit: limit);
});

// Provider para las valoraciones más recientes
final recentRatingsProvider = FutureProvider.family<List<UserMovieRating>, int>((ref, limit) async {
  final repository = ref.watch(userMovieRatingsRepositoryProvider);
  return repository.getRecentRatings(limit: limit);
});

// Estado para las valoraciones del usuario
class UserRatingsState {
  const UserRatingsState({
    this.ratings = const [],
    this.isLoading = false,
    this.isLastPage = false,
    this.currentPage = 0,
    this.error,
  });

  final List<UserMovieRating> ratings;
  final bool isLoading;
  final bool isLastPage;
  final int currentPage;
  final String? error;

  UserRatingsState copyWith({
    List<UserMovieRating>? ratings,
    bool? isLoading,
    bool? isLastPage,
    int? currentPage,
    String? error,
  }) {
    return UserRatingsState(
      ratings: ratings ?? this.ratings,
      isLoading: isLoading ?? this.isLoading,
      isLastPage: isLastPage ?? this.isLastPage,
      currentPage: currentPage ?? this.currentPage,
      error: error ?? this.error,
    );
  }
}

// Notifier para manejar las valoraciones del usuario
class UserRatingsNotifier extends StateNotifier<UserRatingsState> {
  UserRatingsNotifier(this._repository) : super(const UserRatingsState());

  final UserMovieRatingsRepository _repository;
  static const int _pageSize = 20;

  /// Carga las valoraciones del usuario
  Future<void> loadRatings({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = const UserRatingsState(isLoading: true);
    } else {
      if (state.isLastPage) return;
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final offset = refresh ? 0 : state.ratings.length;
      final newRatings = await _repository.getUserRatings(
        limit: _pageSize,
        offset: offset,
        orderBy: 'created_at',
        ascending: false,
      );

      if (refresh) {
        state = state.copyWith(
          ratings: newRatings,
          isLoading: false,
          isLastPage: newRatings.length < _pageSize,
          currentPage: 1,
        );
      } else {
        state = state.copyWith(
          ratings: [...state.ratings, ...newRatings],
          isLoading: false,
          isLastPage: newRatings.length < _pageSize,
          currentPage: state.currentPage + 1,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Guarda o actualiza una valoración
  Future<UserMovieRating> saveRating(UserMovieRating rating) async {
    try {
      final savedRating = await _repository.saveRating(rating);
      
      // Actualizar la lista local
      final updatedRatings = List<UserMovieRating>.from(state.ratings);
      final existingIndex = updatedRatings.indexWhere(
        (r) => r.movieId == savedRating.movieId,
      );
      
      if (existingIndex >= 0) {
        updatedRatings[existingIndex] = savedRating;
      } else {
        updatedRatings.insert(0, savedRating);
      }
      
      state = state.copyWith(ratings: updatedRatings);
      return savedRating;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Elimina una valoración
  Future<void> deleteRating(int movieId) async {
    try {
      await _repository.deleteRating(movieId);
      
      // Actualizar la lista local
      final updatedRatings = state.ratings
          .where((rating) => rating.movieId != movieId)
          .toList();
      
      state = state.copyWith(ratings: updatedRatings);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Busca valoraciones por título
  Future<void> searchRatings(String query) async {
    if (query.isEmpty) {
      await loadRatings(refresh: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final searchResults = await _repository.searchRatingsByTitle(query);
      state = state.copyWith(
        ratings: searchResults,
        isLoading: false,
        isLastPage: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Limpia el estado de error
  void clearError() {
    state = state.copyWith(error: null);
  }
}