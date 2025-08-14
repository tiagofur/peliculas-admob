import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'movies_providers.dart';

final initialLoadingProvider = Provider<bool>((ref) {
  final nowPlayingMovies = ref.watch(nowPlayingMoviesProvider).movies;
  final popularMovies = ref.watch(popularMoviesProvider).movies;
  final topRatedMovies = ref.watch(topRatedMoviesProvider).movies;
  final upcomingMovies = ref.watch(upcomingMoviesProvider).movies;

  // Si todas las listas de películas siguen vacías, estamos en el estado de carga inicial.
  if (nowPlayingMovies.isEmpty &&
      popularMovies.isEmpty &&
      topRatedMovies.isEmpty &&
      upcomingMovies.isEmpty) {
    return true;
  }

  // De lo contrario, tenemos algunos datos y la carga inicial ha finalizado.
  return false;
});