import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/repositories/series_repository.dart';
import '../../../infrastructure/datasources/series_moviedb_datasource.dart';
import '../../../infrastructure/repositories/series_repository_impl.dart';

final seriesRepositoryProvider = Provider<SeriesRepository>((ref) {
  return SeriesRepositoryImpl(SeriesMoviedbDatasource());
});
