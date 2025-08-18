import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/movie.dart';
import '../movies/movies_repository_provider.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchedMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  if (query.isEmpty || query.trim().length < 3) {
    return [];
  }

  final movieRepository = ref.read(movieRepositoryProvider);
  return await movieRepository.searchMovies(query);
});

typedef SearchMoviesCallback = Future<List<Movie>> Function(String query);

class SearchedMoviesNotifier extends StateNotifier<List<Movie>> {
  SearchedMoviesNotifier({
    required this.searchMovies,
    required this.ref,
  }) : super([]);
  final SearchMoviesCallback searchMovies;
  final Ref ref;

  Future<List<Movie>> searchMoviesByQuery(String query) async {
    final List<Movie> movies = await searchMovies(query);
    state = movies;
    ref.read(searchQueryProvider.notifier).update((state) => query);

    return movies;
  }
}
