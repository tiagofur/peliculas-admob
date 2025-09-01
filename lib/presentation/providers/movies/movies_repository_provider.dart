import 'package:flutter_riverpod/flutter_riverpod.dart';

// Use the new cached repository with offline support
import 'cached_movies_repository_provider.dart';

// Export the cached repository as the main movie repository
final movieRepositoryProvider = Provider((ref) {
  return ref.watch(cachedMovieRepositoryProvider);
});

// LEGACY: TMDB only implementation (kept for reference)
// import '../../../infrastructure/datasources/moviedb_datasource.dart';
// import '../../../infrastructure/repositories/movie_repository_impl.dart';
// 
// final movieRepositoryProvider = Provider((ref) {
//   return MovieRepositoryImpl(MoviedbDatasource());
// });

// LEGACY: TRAKT implementation (when API key is available)
// import '../../../infrastructure/repositories/trakt_movies_repository_impl.dart';
// import '../../../infrastructure/services/trakt_api_service.dart';
//
// final traktApiServiceProvider = Provider<TraktApiService>((ref) {
//   return TraktApiService();
// });
//
// final movieRepositoryProvider = Provider((ref) {
//   final traktApiService = ref.watch(traktApiServiceProvider);
//   return TraktMoviesRepositoryImpl(traktApiService);
// });
