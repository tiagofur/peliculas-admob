import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/offline_cache_manager.dart';
import '../../../domain/datasources/local_storage_datasource.dart';
import '../../../domain/repositories/movies_repository.dart';
import '../../../infrastructure/datasources/general_movies_hive_datasource.dart';
import '../../../infrastructure/datasources/isar_datasource.dart';
import '../../../infrastructure/datasources/moviedb_datasource.dart';
import '../../../infrastructure/repositories/cached_movie_repository_impl.dart';

/// Provider for LocalStorageDatasource for general movie caching
final localStorageDatasourceProvider = Provider<LocalStorageDatasource>((ref) {
  if (kIsWeb) {
    return GeneralMoviesHiveDatasource();
  } else {
    return HiveDatasource();
  }
});

/// Provider for the cached movie repository with offline support
final cachedMovieRepositoryProvider = Provider<MoviesRepository>((ref) {
  final networkDatasource = MoviedbDatasource();
  final localDatasource = ref.watch(localStorageDatasourceProvider);

  return CachedMovieRepositoryImpl(
    networkDatasource: networkDatasource,
    localDatasource: localDatasource,
  );
});

/// Provider for offline cache manager
final offlineCacheManagerProvider = Provider<OfflineCacheManager>((ref) {
  final localDatasource = ref.watch(localStorageDatasourceProvider);

  return OfflineCacheManager(
    datasource: localDatasource,
  );
});

/// Provider to initialize cache manager
final cacheManagerInitProvider = FutureProvider<void>((ref) async {
  final cacheManager = ref.watch(offlineCacheManagerProvider);
  await cacheManager.initialize();
});
