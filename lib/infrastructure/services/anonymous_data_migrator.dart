import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/syncable_custom_list.dart';
import '../../domain/entities/syncable_favorite.dart';
import '../../domain/entities/syncable_watched_movie.dart';
import '../../domain/entities/syncable_watchlist_item.dart';
import '../../presentation/providers/hybrid_repositories_provider.dart';
import '../datasources/favorite_movies_hive_datasource.dart';
import '../datasources/watched_movies_hive_datasource.dart';
import '../datasources/watchlist_hive_datasource.dart';
import '../models/favorite_model.dart';
import '../repositories/hybrid_custom_lists_repository.dart';
import '../repositories/hybrid_favorites_repository.dart';
import '../repositories/hybrid_watchlist_repository.dart';
import 'connectivity_detector.dart';

/// Resultado de la migración de datos anónimos
class MigrationResult {
  const MigrationResult({
    required this.success,
    required this.migratedData,
    required this.errors,
    required this.duration,
    required this.timestamp,
  });

  final bool success;
  final Map<String, int> migratedData; // tipo_dato -> cantidad_migrada
  final List<String> errors;
  final Duration duration;
  final DateTime timestamp;

  @override
  String toString() {
    return 'MigrationResult(success: $success, data: $migratedData, errors: ${errors.length}, duration: ${duration.inSeconds}s)';
  }
}

/// Tipos de datos que pueden ser migrados
enum DataType {
  favorites('favoritos'),
  watchedMovies('películas vistas'),
  customLists('listas personalizadas'),
  watchlist('watchlist');

  const DataType(this.displayName);
  final String displayName;
}

/// Servicio para migrar datos de usuario anónimo a usuario autenticado
class AnonymousDataMigrator {
  AnonymousDataMigrator({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Detecta si hay datos locales de usuario anónimo
  Future<Map<DataType, int>> detectAnonymousData() async {
    final Map<DataType, int> detectedData = {};

    try {
      LoggerFactory.info('🔍 Detectando datos locales anónimos...');

      // Detectar favoritos directamente del datasource
      final favoritesDatasource = FavoriteMoviesHiveDatasource();
      final favoriteMovies = await favoritesDatasource.loadMovies(limit: 10000, offset: 0);
      if (favoriteMovies.isNotEmpty) {
        detectedData[DataType.favorites] = favoriteMovies.length;
        LoggerFactory.info(
            '📱 Favoritos encontrados: ${favoriteMovies.length}');
      }

      // Detectar películas vistas directamente del datasource
      final watchedDatasource = WatchedMoviesHiveDatasource();
      final watchedMovies = await watchedDatasource.loadWatchedMovies(limit: 10000);
      if (watchedMovies.isNotEmpty) {
        detectedData[DataType.watchedMovies] = watchedMovies.length;
        LoggerFactory.info(
            '📱 Películas vistas encontradas: ${watchedMovies.length}');
      }

      // Detectar watchlist directamente del datasource
      final watchlistDatasource = WatchlistHiveDatasource();
      final watchlistMovies = await watchlistDatasource.getAllWatchlistMovies();
      if (watchlistMovies.isNotEmpty) {
        detectedData[DataType.watchlist] = watchlistMovies.length;
        LoggerFactory.info(
            '📱 Watchlist encontrada: ${watchlistMovies.length}');
      }

      // Detectar listas personalizadas
      final customListsRepo = _ref.read(customListsRepositoryProvider)
          as HybridCustomListsRepository;
      final customLists = await customListsRepo.getAll();
      // Filtrar solo listas personalizadas (no las 8 por defecto)
      final personalizedLists =
          customLists.where((list) => !_isDefaultList(list.name)).toList();
      if (personalizedLists.isNotEmpty) {
        detectedData[DataType.customLists] = personalizedLists.length;
        LoggerFactory.info(
            '📱 Listas personalizadas encontradas: ${personalizedLists.length}');
      }

      LoggerFactory.info('🔍 Detección completada: $detectedData');
      return detectedData;
    } catch (e) {
      LoggerFactory.error('❌ Error detectando datos anónimos: $e');
      return {};
    }
  }

  /// Verifica si una lista es una de las 8 listas por defecto
  bool _isDefaultList(String listName) {
    const defaultLists = {
      'Acción y Aventura',
      'Comedia',
      'Drama',
      'Terror y Suspenso',
      'Ciencia Ficción',
      'Romance',
      'Documentales',
      'Animación',
    };
    return defaultLists.contains(listName);
  }

  /// Migra todos los datos locales al usuario autenticado
  Future<MigrationResult> migrateAllData(String userId) async {
    final startTime = DateTime.now();
    final Map<String, int> migratedData = {};
    final List<String> errors = [];

    try {
      LoggerFactory.info(
          '🔄 Iniciando migración completa para usuario: $userId');

      // Verificar conectividad
      final connectivity =
          await ConnectivityDetector.instance.checkConnectivity();
      if (connectivity == ConnectivityStatus.offline) {
        throw Exception('Sin conexión a internet para migrar datos');
      }

      // Detectar datos disponibles
      final detectedData = await detectAnonymousData();
      if (detectedData.isEmpty) {
        LoggerFactory.info('ℹ️ No hay datos locales para migrar');
        return MigrationResult(
          success: true,
          migratedData: {},
          errors: [],
          duration: DateTime.now().difference(startTime),
          timestamp: startTime,
        );
      }

      // Migrar cada tipo de dato
      for (final entry in detectedData.entries) {
        final dataType = entry.key;
        // final count = entry.value; // No se usa actualmente

        try {
          LoggerFactory.info('🔄 Migrando ${dataType.displayName}...');
          final migrated = await _migrateDataType(dataType, userId);
          migratedData[dataType.displayName] = migrated;
          LoggerFactory.info('✅ ${dataType.displayName} migrados: $migrated');
        } catch (e) {
          final error = 'Error migrando ${dataType.displayName}: $e';
          errors.add(error);
          LoggerFactory.error('❌ $error');
        }
      }

      final success = errors.isEmpty;
      final duration = DateTime.now().difference(startTime);

      LoggerFactory.info(success
          ? '🎉 Migración completada exitosamente: $migratedData'
          : '⚠️ Migración completada con errores: ${errors.length}');

      return MigrationResult(
        success: success,
        migratedData: migratedData,
        errors: errors,
        duration: duration,
        timestamp: startTime,
      );
    } catch (e) {
      final error = 'Error crítico en migración: $e';
      errors.add(error);
      LoggerFactory.error('❌ $error');

      return MigrationResult(
        success: false,
        migratedData: migratedData,
        errors: errors,
        duration: DateTime.now().difference(startTime),
        timestamp: startTime,
      );
    }
  }

  /// Migra un tipo específico de dato
  Future<int> _migrateDataType(DataType dataType, String userId) async {
    switch (dataType) {
      case DataType.favorites:
        return await _migrateFavorites(userId);
      case DataType.watchedMovies:
        return await _migrateWatchedMovies(userId);
      case DataType.customLists:
        return await _migrateCustomLists(userId);
      case DataType.watchlist:
        return await _migrateWatchlist(userId);
    }
  }

  /// Migra favoritos locales a Supabase
  Future<int> _migrateFavorites(String userId) async {
    try {
      // Obtener datos directamente del datasource local
      final favoritesDatasource = FavoriteMoviesHiveDatasource();
      final localMovies = await favoritesDatasource.loadMovies(limit: 10000, offset: 0);

      if (localMovies.isEmpty) {
        LoggerFactory.info('ℹ️ No hay favoritos locales para migrar');
        return 0;
      }

      LoggerFactory.info('🔄 Migrando ${localMovies.length} favoritos locales...');

      // Convertir películas a entidades syncables con el nuevo userId
      final List<SyncableFavorite> syncableFavorites = localMovies
          .map((movie) => SyncableFavorite.fromFavoriteModel(
                FavoriteModel.fromMovie(movie, userId),
                userId,
              ))
          .toList();

      // Obtener el repositorio híbrido y subir a Supabase
      final repo = _ref.read(favoritesRepositoryProvider) as HybridFavoritesRepository;
      await repo.upload(syncableFavorites);

      LoggerFactory.info(
          '📤 ${syncableFavorites.length} favoritos migrados para usuario $userId');
      return syncableFavorites.length;
    } catch (e) {
      LoggerFactory.error('❌ Error migrando favoritos: $e');
      rethrow;
    }
  }

  /// Migra películas vistas locales a Supabase
  Future<int> _migrateWatchedMovies(String userId) async {
    try {
      // Obtener datos directamente del datasource local
      final watchedDatasource = WatchedMoviesHiveDatasource();
      final localWatchedMovies = await watchedDatasource.loadWatchedMovies(limit: 10000);

      if (localWatchedMovies.isEmpty) {
        LoggerFactory.info('ℹ️ No hay películas vistas locales para migrar');
        return 0;
      }

      LoggerFactory.info('🔄 Migrando ${localWatchedMovies.length} películas vistas locales...');

      // Convertir películas vistas a entidades syncables con el nuevo userId
      final List<SyncableWatchedMovie> syncableWatched = localWatchedMovies
          .map((watchedMovie) => SyncableWatchedMovie.fromWatchedMovie(
                userId: userId,
                watchedMovie: watchedMovie,
              ))
          .toList();

      // Obtener el repositorio híbrido y subir a Supabase
      final repo = _ref.read(hybridWatchedRepositoryProvider);
      await repo.upload(syncableWatched);

      LoggerFactory.info(
          '📤 ${syncableWatched.length} películas vistas migradas para usuario $userId');
      return syncableWatched.length;
    } catch (e) {
      LoggerFactory.error('❌ Error migrando películas vistas: $e');
      rethrow;
    }
  }

  /// Migra watchlist local a Supabase
  Future<int> _migrateWatchlist(String userId) async {
    try {
      // Obtener datos directamente del datasource local
      final watchlistDatasource = WatchlistHiveDatasource();
      final localWatchlistMovies = await watchlistDatasource.getAllWatchlistMovies();

      if (localWatchlistMovies.isEmpty) {
        LoggerFactory.info('ℹ️ No hay items en watchlist locales para migrar');
        return 0;
      }

      LoggerFactory.info('🔄 Migrando ${localWatchlistMovies.length} items de watchlist locales...');

      // Convertir WatchlistMovies a entidades syncables con el nuevo userId
      final List<SyncableWatchlistItem> syncableWatchlist = localWatchlistMovies
          .map((watchlistMovie) => SyncableWatchlistItem.fromWatchlistMovie(
                userId: userId,
                watchlistMovie: watchlistMovie,
              ))
          .toList();

      // Obtener el repositorio híbrido y subir a Supabase
      final repo = _ref.read(watchlistRepositoryProvider) as HybridWatchlistRepository;
      await repo.upload(syncableWatchlist);

      LoggerFactory.info(
          '📤 ${syncableWatchlist.length} items de watchlist migrados para usuario $userId');
      return syncableWatchlist.length;
    } catch (e) {
      LoggerFactory.error('❌ Error migrando watchlist: $e');
      rethrow;
    }
  }

  /// Migra listas personalizadas locales a Supabase
  Future<int> _migrateCustomLists(String userId) async {
    final repo =
        _ref.read(customListsRepositoryProvider) as HybridCustomListsRepository;
    final localData = await repo.getLocalData();

    if (localData.isEmpty) return 0;

    // Filtrar solo listas personalizadas (no las 8 por defecto)
    final personalizedLists =
        localData.where((list) => !_isDefaultList(list.name)).toList();

    if (personalizedLists.isEmpty) return 0;

    // Actualizar userId para cada lista personalizada
    final List<SyncableCustomList> updatedLists = personalizedLists
        .cast<SyncableCustomList>()
        .map((list) => list.copyWithData(userId: userId))
        .toList();

    // Subir a Supabase
    await repo.upload(updatedLists);

    LoggerFactory.info(
        '📤 ${updatedLists.length} listas personalizadas migradas para usuario $userId');
    return updatedLists.length;
  }

  /// Limpia datos locales después de migración exitosa
  Future<void> cleanupLocalDataAfterMigration() async {
    try {
      LoggerFactory.info('🧹 Limpiando datos locales después de migración...');

      // Nota: NO limpiar datos locales inmediatamente
      // Dejar que la sincronización normal maneje la consistencia
      // Los datos locales servirán como backup hasta la próxima sincronización exitosa

      LoggerFactory.info('✅ Cleanup completado');
    } catch (e) {
      LoggerFactory.error('❌ Error en cleanup: $e');
    }
  }

  /// Obtiene estadísticas de migración
  Future<Map<String, dynamic>> getMigrationStats() async {
    try {
      final detectedData = await detectAnonymousData();
      final totalItems =
          detectedData.values.fold(0, (sum, count) => sum + count);

      return {
        'has_local_data': detectedData.isNotEmpty,
        'total_items': totalItems,
        'by_type': detectedData
            .map((type, count) => MapEntry(type.displayName, count)),
        'migration_recommended': totalItems > 0,
        'estimated_duration_seconds': _estimateMigrationDuration(totalItems),
      };
    } catch (e) {
      LoggerFactory.error('Error obteniendo estadísticas de migración: $e');
      return {'error': e.toString()};
    }
  }

  /// Estima la duración de la migración basada en el número de items
  int _estimateMigrationDuration(int totalItems) {
    // Estimación: ~0.1 segundos por item + 2 segundos de overhead
    return (totalItems * 0.1 + 2).round();
  }
}

// Provider para el servicio de migración
final anonymousDataMigratorProvider = Provider<AnonymousDataMigrator>((ref) {
  return AnonymousDataMigrator(ref: ref);
});
