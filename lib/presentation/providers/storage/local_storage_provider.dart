import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../infrastructure/datasources/favorite_movies_hive_datasource.dart';
import '../../../infrastructure/datasources/isar_datasource.dart';
import '../../../infrastructure/repositories/local_storage_repository_impl.dart';

final localStorageRepositoryProvider = Provider((ref) {
  // Usar SharedPreferences en web, Hive en otras plataformas
  if (kIsWeb) {
    return LocalStorageRepositoryImpl(FavoriteMoviesHiveDatasource());
  } else {
    return LocalStorageRepositoryImpl(HiveDatasource());
  }
});