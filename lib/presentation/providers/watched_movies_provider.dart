import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../../infrastructure/repositories/hybrid_watched_repository.dart';
import 'achievements/achievements_provider.dart';
import 'hybrid_repositories_provider.dart';

// Provider para verificar si una película está vista
final isMovieWatchedProvider =
    FutureProvider.family<bool, int>((ref, movieId) async {
  final repository = ref.watch(hybridWatchedRepositoryProvider);
  return repository.isMovieWatched(movieId);
});

// Provider para la lista de películas vistas
final watchedMoviesProvider =
    StateNotifierProvider<WatchedMoviesNotifier, WatchedMoviesState>((ref) {
  final repository = ref.watch(hybridWatchedRepositoryProvider);
  return WatchedMoviesNotifier(
    repository: repository,
    onMovieWatched: (Movie movie) async {
      // Manejar el callback aquí, dentro del provider
      await ref.read(achievementsProvider.notifier).trackMovieWatched(movie);
    },
  );
});

// Estado para las películas vistas
class WatchedMoviesState {
  const WatchedMoviesState({
    this.movies = const [],
    this.isLoading = false,
    this.isLastPage = false,
    this.currentPage = 0,
  });

  final List<SyncableWatchedMovie> movies;
  final bool isLoading;
  final bool isLastPage;
  final int currentPage;

  WatchedMoviesState copyWith({
    List<SyncableWatchedMovie>? movies,
    bool? isLoading,
    bool? isLastPage,
    int? currentPage,
  }) {
    return WatchedMoviesState(
      movies: movies ?? this.movies,
      isLoading: isLoading ?? this.isLoading,
      isLastPage: isLastPage ?? this.isLastPage,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

// Notifier para gestionar las películas vistas
class WatchedMoviesNotifier extends StateNotifier<WatchedMoviesState> {
  WatchedMoviesNotifier({
    required this.repository,
    required this.onMovieWatched,
  }) : super(const WatchedMoviesState()) {
    loadNextPage();
  }

  final HybridWatchedRepository repository;
  final Future<void> Function(Movie) onMovieWatched;
  static const int _limit = 20;

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLastPage) return;

    state = state.copyWith(isLoading: true);

    try {
      // Use hybrid repository to get watched movies with pagination
      final allWatchedMovies = await repository.getWatchedMoviesSorted();
      
      // Simulate pagination by slicing the sorted list
      final startIndex = state.currentPage * _limit;
      final endIndex = startIndex + _limit;
      
      if (startIndex >= allWatchedMovies.length) {
        state = state.copyWith(
          isLoading: false,
          isLastPage: true,
        );
        return;
      }
      
      final pageMovies = allWatchedMovies.skip(startIndex).take(_limit).toList();

      if (pageMovies.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          isLastPage: true,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        movies: [...state.movies, ...pageMovies],
        currentPage: state.currentPage + 1,
        isLastPage: pageMovies.length < _limit || endIndex >= allWatchedMovies.length,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading watched movies: $e');
      }
      state = state.copyWith(
        isLoading: false,
        isLastPage: true,
      );
    }
  }

  Future<void> markAsWatched(Movie movie) async {
    try {
      // Use hybrid repository for offline-first approach
      // This will automatically queue the operation for sync when online
      await repository.markAsWatched(
        movieId: movie.id,
        watchedAt: DateTime.now(),
      );
      
      // Trigger sync with Supabase (will handle offline queue)
      await repository.syncWithSupabase();

      // Track logros usando callback
      await onMovieWatched(movie);

      // Recargar la lista
      await _reloadMovies();
      
      if (kDebugMode) {
        print('✅ Película marcada como vista: ${movie.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marcando película como vista: $e');
      }
      rethrow;
    }
  }

  Future<void> removeFromWatched(int movieId) async {
    try {
      // Use hybrid repository for offline-first approach
      await repository.unmarkAsWatched(movieId);
      
      // Trigger sync with Supabase (will handle offline queue)
      await repository.syncWithSupabase();
      
      // Recargar la lista
      await _reloadMovies();
      
      if (kDebugMode) {
        print('✅ Película removida de vistas: $movieId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removiendo película de vistas: $e');
      }
      rethrow;
    }
  }

  Future<void> _reloadMovies() async {
    state = const WatchedMoviesState();
    await loadNextPage();
  }

  Future<void> refresh() async {
    await _reloadMovies();
  }

  @override
  void dispose() {
    // Limpiar recursos si es necesario
    super.dispose();
  }
}
