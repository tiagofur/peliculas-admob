import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/movie.dart';
import '../movies/movies_repository_provider.dart';

// Provider para el query de búsqueda
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  () => SearchQueryNotifier(),
);

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

// Compatibilidad con código existente
typedef SearchMoviesCallback = Future<List<Movie>> Function(String query);
