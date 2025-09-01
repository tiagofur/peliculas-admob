import 'package:flutter_riverpod/flutter_riverpod.dart';

// Rollback temporal a TMDB mientras se resuelve API key de Trakt
import '../../../infrastructure/datasources/moviedb_datasource.dart';
import '../../../infrastructure/repositories/movie_repository_impl.dart';

// TEMPORALMENTE USANDO TMDB - CAMBIAR A TRAKT CUANDO SE TENGA API KEY VÁLIDA
final movieRepositoryProvider = Provider((ref) {
  return MovieRepositoryImpl(MoviedbDatasource());
});

// PARA TRAKT (cuando se tenga API key válida):
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
