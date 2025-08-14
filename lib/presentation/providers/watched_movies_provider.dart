import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/watched_movies_repository.dart';
import '../../infrastructure/datasources/watched_movies_hive_datasource.dart';
import '../../infrastructure/datasources/watched_movies_shared_preferences_datasource.dart';
import '../../infrastructure/repositories/watched_movies_repository_impl.dart';
import 'achievements/achievements_provider.dart';

// Provider del repositorio
final watchedMoviesRepositoryProvider = Provider<WatchedMoviesRepository>((ref) {
  // Usar SharedPreferences en web, Hive en otras plataformas
  if (kIsWeb) {
    final datasource = WatchedMoviesSharedPreferencesDatasource();
    return WatchedMoviesRepositoryImpl(datasource);
  } else {
    final datasource = WatchedMoviesHiveDatasource();
    return WatchedMoviesRepositoryImpl(datasource);
  }
});

// Provider para verificar si una película está vista
final isMovieWatchedProvider = FutureProvider.family<bool, int>((ref, movieId) async {
  final repository = ref.watch(watchedMoviesRepositoryProvider);
  return repository.isMovieWatched(movieId);
});

// Provider para la lista de películas vistas
final watchedMoviesProvider = StateNotifierProvider<WatchedMoviesNotifier, WatchedMoviesState>((ref) {
  final repository = ref.watch(watchedMoviesRepositoryProvider);
  return WatchedMoviesNotifier(repository, ref);
});

// Estado para las películas vistas
class WatchedMoviesState {
  const WatchedMoviesState({
    this.movies = const [],
    this.isLoading = false,
    this.isLastPage = false,
    this.currentPage = 0,
  });

  final List<WatchedMovie> movies;
  final bool isLoading;
  final bool isLastPage;
  final int currentPage;

  WatchedMoviesState copyWith({
    List<WatchedMovie>? movies,
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
  WatchedMoviesNotifier(this.repository, this.ref) : super(const WatchedMoviesState()) {
    loadNextPage();
  }

  final WatchedMoviesRepository repository;
  final Ref ref;
  static const int _limit = 20;

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLastPage) return;

    state = state.copyWith(isLoading: true);

    final movies = await repository.loadWatchedMovies(
      limit: _limit,
      offset: state.currentPage * _limit,
    );

    if (movies.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        isLastPage: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      movies: [...state.movies, ...movies],
      currentPage: state.currentPage + 1,
      isLastPage: movies.length < _limit,
    );
  }

  Future<void> markAsWatched(Movie movie) async {
    await repository.markAsWatched(movie);
    
    // Track logros
    await ref.read(achievementsProvider.notifier).trackMovieWatched(movie);
    
    // Recargar la lista
    await _reloadMovies();
  }

  Future<void> removeFromWatched(int movieId) async {
    await repository.removeFromWatched(movieId);
    // Recargar la lista
    await _reloadMovies();
  }

  Future<void> _reloadMovies() async {
    state = WatchedMoviesState();
    await loadNextPage();
  }

  Future<void> refresh() async {
    await _reloadMovies();
  }
}