import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'movies_providers.dart';

final initialLoadingProvider = Provider<bool>((ref) {
  final nowPlayingState = ref.watch(nowPlayingMoviesProvider);
  final popularState = ref.watch(popularMoviesProvider);
  final topRatedState = ref.watch(topRatedMoviesProvider);
  final upcomingState = ref.watch(upcomingMoviesProvider);

  if (kDebugMode) {
    print('🔄 InitialLoadingProvider - Checking states:');
    print('   nowPlaying: ${nowPlayingState.movies.length} movies, state: ${nowPlayingState.state}');
    print('   popular: ${popularState.movies.length} movies, state: ${popularState.state}');
    print('   topRated: ${topRatedState.movies.length} movies, state: ${topRatedState.state}');
    print('   upcoming: ${upcomingState.movies.length} movies, state: ${upcomingState.state}');
  }

  // Si algún provider está cargando o en estado inicial
  final isAnyLoadingOrInitial = nowPlayingState.state == MoviesState.loading ||
      popularState.state == MoviesState.loading ||
      topRatedState.state == MoviesState.loading ||
      upcomingState.state == MoviesState.loading ||
      nowPlayingState.state == MoviesState.initial ||
      popularState.state == MoviesState.initial ||
      topRatedState.state == MoviesState.initial ||
      upcomingState.state == MoviesState.initial;

  // Si todas las listas están vacías
  final allEmpty = nowPlayingState.movies.isEmpty &&
      popularState.movies.isEmpty &&
      topRatedState.movies.isEmpty &&
      upcomingState.movies.isEmpty;

  // Solo mostrar loading si están en estado inicial/loading O si están vacías pero no en error
  final hasErrors = nowPlayingState.state == MoviesState.error ||
      popularState.state == MoviesState.error ||
      topRatedState.state == MoviesState.error ||
      upcomingState.state == MoviesState.error;

  final result = (isAnyLoadingOrInitial || allEmpty) && !hasErrors;
  
  if (kDebugMode) {
    print('🔄 InitialLoadingProvider - isAnyLoadingOrInitial: $isAnyLoadingOrInitial, allEmpty: $allEmpty, hasErrors: $hasErrors, result: $result');
  }
  
  return result;
});