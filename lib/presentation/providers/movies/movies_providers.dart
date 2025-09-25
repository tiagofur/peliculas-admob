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
    NotifierProvider<NowPlayingMoviesNotifier, MoviesStateData>(
        NowPlayingMoviesNotifier.new);

final popularMoviesProvider =
    NotifierProvider<PopularMoviesNotifier, MoviesStateData>(
        PopularMoviesNotifier.new);

final upcomingMoviesProvider =
    NotifierProvider<UpcomingMoviesNotifier, MoviesStateData>(
        UpcomingMoviesNotifier.new);

final topRatedMoviesProvider =
    NotifierProvider<TopRatedMoviesNotifier, MoviesStateData>(
        TopRatedMoviesNotifier.new);

typedef MovieCallback = Future<List<Movie>> Function({int page});

abstract class MoviesNotifier extends Notifier<MoviesStateData> {
  int currentPage = 0;
  MovieCallback? fetchMoreMovies;
  static const int maxRetries = 3;

  Future<void> loadNextPage() async {
    LoggerFactory.debug(
        'MoviesNotifier: loadNextPage() llamado - Estado actual: ${state.state}, página: $currentPage');

    if (state.state == MoviesState.loading ||
        state.hasReachedMax ||
        fetchMoreMovies == null) {
      LoggerFactory.debug(
          'MoviesNotifier: Saltando loadNextPage - loading: ${state.state == MoviesState.loading}, hasReachedMax: ${state.hasReachedMax}');
      return;
    }

    LoggerFactory.debug('MoviesNotifier: Cambiando estado a loading');

    state = state.copyWith(state: MoviesState.loading);

    try {
      LoggerFactory.debug(
          'MoviesNotifier: Llamando fetchMoreMovies con página: ${currentPage + 1}');
      final movies = await fetchMoreMovies!(page: currentPage + 1);

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
}

// Concrete implementations for each movie category
class NowPlayingMoviesNotifier extends MoviesNotifier {
  @override
  MoviesStateData build() {
    final repository = ref.watch(movieRepositoryProvider);
    fetchMoreMovies = repository.getNowPlaying;
    LoggerFactory.debug('NowPlayingMoviesNotifier: Notifier created');
    return const MoviesStateData();
  }
}

class PopularMoviesNotifier extends MoviesNotifier {
  @override
  MoviesStateData build() {
    final repository = ref.watch(movieRepositoryProvider);
    fetchMoreMovies = repository.getPopular;
    LoggerFactory.debug('PopularMoviesNotifier: Notifier created');
    return const MoviesStateData();
  }
}

class UpcomingMoviesNotifier extends MoviesNotifier {
  @override
  MoviesStateData build() {
    final repository = ref.watch(movieRepositoryProvider);
    fetchMoreMovies = repository.getUpcoming;
    LoggerFactory.debug('UpcomingMoviesNotifier: Notifier created');
    return const MoviesStateData();
  }
}

class TopRatedMoviesNotifier extends MoviesNotifier {
  @override
  MoviesStateData build() {
    final repository = ref.watch(movieRepositoryProvider);
    fetchMoreMovies = repository.getTopRated;
    LoggerFactory.debug('TopRatedMoviesNotifier: Notifier created');
    return const MoviesStateData();
  }
}
