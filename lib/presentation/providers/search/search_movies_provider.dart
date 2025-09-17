import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../domain/entities/movie.dart';
import '../movies/movies_repository_provider.dart';

// Provider para el query de búsqueda
final searchQueryProvider = StateProvider<String>((ref) => '');

// Provider para los resultados de búsqueda
final searchedMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  // FIXED: Eliminar validación incorrecta de 3 caracteres mínimo
  if (query.isEmpty || query.trim().isEmpty) {
    return [];
  }

  final movieRepository = ref.read(movieRepositoryProvider);
  return await movieRepository.searchMovies(query);
});

// Legacy support - mantener callback para compatibilidad
typedef SearchMoviesCallback = Future<List<Movie>> Function(String query);
