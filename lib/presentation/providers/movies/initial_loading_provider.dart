import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import 'movies_providers.dart';

// TEMPORAL: Variable global para el timestamp inicial
DateTime? _appStartTime;

final initialLoadingProvider = Provider<bool>((ref) {
  final nowPlayingState = ref.watch(nowPlayingMoviesProvider);
  final popularState = ref.watch(popularMoviesProvider);
  final upcomingState = ref.watch(upcomingMoviesProvider);

  // Inicializar timestamp si no existe
  _appStartTime ??= DateTime.now();

  LoggerFactory.debug('InitialLoadingProvider CON TIMEOUT:');
  LoggerFactory.debug(
      '  - nowPlaying: ${nowPlayingState.movies.length} movies, estado: ${nowPlayingState.state}');
  LoggerFactory.debug(
      '  - popular: ${popularState.movies.length} movies, estado: ${popularState.state}');
  LoggerFactory.debug(
      '  - upcoming: ${upcomingState.movies.length} movies, estado: ${upcomingState.state}');

  // Timeout de 5 segundos - después de eso, mostrar la app independientemente del estado
  final timeoutReached =
      DateTime.now().difference(_appStartTime!).inSeconds > 5;

  // Si al menos uno tiene películas cargadas, no mostrar loading
  final hasAnyMovies = nowPlayingState.movies.isNotEmpty ||
      popularState.movies.isNotEmpty ||
      upcomingState.movies.isNotEmpty;

  // Si todos están en estado de error, no mostrar loading
  final allError = nowPlayingState.state == MoviesState.error &&
      popularState.state == MoviesState.error &&
      upcomingState.state == MoviesState.error;

  // Lógica: mostrar loading SOLO si no hay películas Y no se ha alcanzado el timeout Y no todos están en error
  final result = !hasAnyMovies && !timeoutReached && !allError;

  LoggerFactory.debug(
      'InitialLoadingProvider RESULTADO: $result (hasAnyMovies: $hasAnyMovies, timeoutReached: $timeoutReached, allError: $allError)');

  return result;
});
