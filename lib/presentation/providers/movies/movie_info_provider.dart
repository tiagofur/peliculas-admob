import 'package:flutter_riverpod/legacy.dart';

import '../../../domain/entities/movie.dart';
import 'movies_repository_provider.dart';

// Provider optimizado con AutoDispose para liberación automática
final movieInfoProvider =
    StateNotifierProvider.autoDispose<MovieMapNotifier, Map<String, Movie>>(
        (ref) {
  final movieRepository = ref.watch(movieRepositoryProvider);
  return MovieMapNotifier(getMovie: movieRepository.getMovieById);
});

/*
  {
    '505642': Movie(),
    '505643': Movie(),
    '505645': Movie(),
    '501231': Movie(),
  }
*/

typedef GetMovieCallback = Future<Movie> Function(String movieId);

class MovieMapNotifier extends StateNotifier<Map<String, Movie>> {
  MovieMapNotifier({
    required this.getMovie,
  }) : super({});

  final GetMovieCallback getMovie;

  Future<void> loadMovie(String movieId) async {
    // Validar que el movieId sea válido
    if (movieId == 'no-id' || movieId.isEmpty) {
      throw Exception('ID de película inválido: $movieId');
    }

    // Verificar que el movieId sea un número válido
    final numericId = int.tryParse(movieId);
    if (numericId == null || numericId <= 0) {
      throw Exception(
          'ID de película debe ser un número válido mayor a 0: $movieId');
    }

    final movie = await getMovie(movieId);
    state = {...state, movieId: movie};
  }

  // Note: StateNotifier doesn't have a dispose method to override
  // Resources are automatically cleaned up when the provider is disposed
}
