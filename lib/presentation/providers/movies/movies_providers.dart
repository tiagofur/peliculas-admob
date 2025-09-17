import 'package:flutter_riverpod/legacy.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/entities.dart';
import 'movies_repository_provider.dart';

enum MoviesState {
  initial,
  loading,
  loaded,
  error,
}

class MoviesStateData {
  const MoviesStateData({
    this.movies = const [],
    this.state = MoviesState.initial,
    this.errorMessage,
    this.hasReachedMax = false,
  });

  final List<Movie> movies;
  final MoviesState state;
  final String? errorMessage;
  final bool hasReachedMax;

  MoviesStateData copyWith({
    List<Movie>? movies,
    MoviesState? state,
    String? errorMessage,
    bool? hasReachedMax,
  }) {
    return MoviesStateData(
      movies: movies ?? this.movies,
      state: state ?? this.state,
      errorMessage: errorMessage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }
}

// TODO: Fix legacy compatibility for StateNotifierProvider
final nowPlayingMoviesProvider =
    StateNotifierProvider<MoviesNotifier, MoviesStateData>((ref) {
  final fetchMoreMovies = ref.watch(movieRepositoryProvider).getNowPlaying;
  return MoviesNotifier(fetchMoreMovies: fetchMoreMovies);
});

final popularMoviesProvider =
    StateNotifierProvider<MoviesNotifier, MoviesStateData>((ref) {
  final fetchMoreMovies = ref.watch(movieRepositoryProvider).getPopular;
  return MoviesNotifier(fetchMoreMovies: fetchMoreMovies);
});

final upcomingMoviesProvider =
    StateNotifierProvider<MoviesNotifier, MoviesStateData>((ref) {
  final fetchMoreMovies = ref.watch(movieRepositoryProvider).getUpcoming;
  return MoviesNotifier(fetchMoreMovies: fetchMoreMovies);
});

final topRatedMoviesProvider =
    StateNotifierProvider<MoviesNotifier, MoviesStateData>((ref) {
  final fetchMoreMovies = ref.watch(movieRepositoryProvider).getTopRated;
  return MoviesNotifier(fetchMoreMovies: fetchMoreMovies);
});

typedef MovieCallback = Future<List<Movie>> Function({int page});

class MoviesNotifier extends StateNotifier<MoviesStateData> {
  MoviesNotifier({
    required this.fetchMoreMovies,
  }) : super(const MoviesStateData()) {
    LoggerFactory.debug('MoviesNotifier: MoviesNotifier creado');
  }

  int currentPage = 0;
  final MovieCallback fetchMoreMovies;
  static const int maxRetries = 3;

  Future<void> loadNextPage() async {
    LoggerFactory.debug(
        'MoviesNotifier: loadNextPage() llamado - Estado actual: ${state.state}, página: $currentPage');

    if (state.state == MoviesState.loading || state.hasReachedMax) {
      LoggerFactory.debug(
          'MoviesNotifier: Saltando loadNextPage - loading: ${state.state == MoviesState.loading}, hasReachedMax: ${state.hasReachedMax}');
      return;
    }

    LoggerFactory.debug('MoviesNotifier: Cambiando estado a loading');

    state = state.copyWith(state: MoviesState.loading);

    try {
      LoggerFactory.debug(
          'MoviesNotifier: Llamando fetchMoreMovies con página: ${currentPage + 1}');
      final movies = await fetchMoreMovies(page: currentPage + 1);

      LoggerFactory.debug(
          'MoviesNotifier: Recibidas ${movies.length} películas de la API');

      currentPage++;

      if (movies.isEmpty) {
        LoggerFactory.debug(
            'MoviesNotifier: No hay más películas - estableciendo hasReachedMax');
        state = state.copyWith(
          state: MoviesState.loaded,
          hasReachedMax: true,
        );
        return;
      }

      state = state.copyWith(
        hasReachedMax: false,
        state: MoviesState.loaded,
        movies: [...state.movies, ...movies],
      );

      LoggerFactory.debug(
          'MoviesNotifier: Estado actualizado - Total películas: ${state.movies.length}, Estado: ${state.state}');
    } catch (e) {
      LoggerFactory.error('MoviesNotifier: Error al cargar películas: $e');
      state = state.copyWith(
        state: MoviesState.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    try {
      currentPage = 0;
      state = state.copyWith(
        state: MoviesState.loading,
        movies: [],
        hasReachedMax: false,
        errorMessage: null,
      );
      await loadNextPage();
    } catch (e) {
      LoggerFactory.error('MoviesNotifier: Error al refrescar películas: $e');
      state = state.copyWith(
        state: MoviesState.error,
        errorMessage: 'Error al refrescar películas: ${e.toString()}',
      );
    }
  }

  void clearError() {
    if (state.state == MoviesState.error) {
      state = state.copyWith(
        state: state.movies.isEmpty ? MoviesState.initial : MoviesState.loaded,
        errorMessage: null,
      );
    }
  }

  @override
  void dispose() {
    // Limpiar recursos si es necesario
    super.dispose();
  }
}
