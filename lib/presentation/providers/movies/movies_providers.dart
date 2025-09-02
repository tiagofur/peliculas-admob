import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/movie.dart';
import '../error_reporting_provider.dart';
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

class MoviesNotifier extends StateNotifier<MoviesStateData> with ErrorReportingMixin<MoviesStateData> {
  MoviesNotifier({
    required this.fetchMoreMovies,
  }) : super(const MoviesStateData());

  int currentPage = 0;
  final MovieCallback fetchMoreMovies;
  static const int maxRetries = 3;

  Future<void> loadNextPage({int retryCount = 0}) async {
    if (state.state == MoviesState.loading) return;

    // Si es la primera página, mostrar estado de carga
    if (currentPage == 0) {
      state = state.copyWith(state: MoviesState.loading);
    }

    try {
      await runWithErrorReporting(
        () async {
          currentPage++;
          final List<Movie> movies = await fetchMoreMovies(page: currentPage);
          
          // Simular delay solo en desarrollo
          await Future.delayed(const Duration(milliseconds: 300));
          
          final updatedMovies = [...state.movies, ...movies];
          state = state.copyWith(
            movies: updatedMovies,
            state: MoviesState.loaded,
            errorMessage: null,
            hasReachedMax: movies.isEmpty,
          );
        },
        operationName: 'loadNextPage',
        customData: {
          'page': currentPage + 1,
          'retry_count': retryCount,
          'current_movies_count': state.movies.length,
        },
      );
    } catch (e, stackTrace) {
      // Report error with context
      await reportError(
        e,
        stackTrace,
        context: 'loadNextPage',
        data: {
          'page': currentPage + 1,
          'retry_count': retryCount,
          'max_retries': maxRetries,
          'current_movies_count': state.movies.length,
        },
        fatal: false,
      );

      // Implementar reintentos automáticos
      if (retryCount < maxRetries) {
        await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
        currentPage--; // Revertir el incremento de página
        return loadNextPage(retryCount: retryCount + 1);
      }
      
      // Si fallan todos los reintentos, mostrar error
      currentPage--; // Revertir el incremento de página
      state = state.copyWith(
        state: MoviesState.error,
        errorMessage: 'Error al cargar películas: ${e.toString()}',
      );
    }
  }

  Future<void> refresh() async {
    await runWithErrorReporting(
      () async {
        currentPage = 0;
        state = const MoviesStateData();
        await loadNextPage();
      },
      operationName: 'refresh',
      customData: {
        'previous_movies_count': state.movies.length,
      },
    );
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
