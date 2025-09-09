import 'package:flutter_riverpod/flutter_riverpod.dart';

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


    if (state.state == MoviesState.loading || state.hasReachedMax) return;



    state = state.copyWith(state: MoviesState.loading);

    try {
      final movies = await fetchMoreMovies(page: currentPage + 1);



      currentPage++;

      if (movies.isEmpty) {

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


    } catch (e) {
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
