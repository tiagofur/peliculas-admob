import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/custom_list.dart';
import '../../domain/entities/movie.dart';

/// Optimizador de rendimiento para operaciones de sincronización
class SyncPerformanceOptimizer {
  SyncPerformanceOptimizer(this._supabase);
  static const int _defaultBatchSize = 50;
  static const int _maxBatchSize = 100;
  static const Duration _batchDelay = Duration(milliseconds: 100);
  static const int _maxRetries = 3;

  final SupabaseClient _supabase;
  final Map<String, DateTime> _lastSyncTimes = {};

  /// Sincronización optimizada de favoritos por lotes
  Future<SyncBatchResult> syncFavoritesBatch({
    required String userId,
    required List<Movie> localFavorites,
    int batchSize = _defaultBatchSize,
  }) async {
    final stopwatch = Stopwatch()..start();
    final results = SyncBatchResult();

    try {
      // 1. Obtener timestamp de última sincronización
      final lastSync = _lastSyncTimes['favorites_$userId'];

      // 2. Obtener favoritos remotos modificados desde última sincronización
      var remoteQuery =
          _supabase.from('user_favorites').select().eq('user_id', userId);

      if (lastSync != null) {
        remoteQuery = remoteQuery.gt('last_modified_at', lastSync.toIso8601String());
      }

      await remoteQuery;

      // 3. Procesar en lotes para evitar sobrecarga
      final batches = _createBatches(localFavorites, batchSize);

      for (int i = 0; i < batches.length; i++) {
        final batch = batches[i];
        final batchResult = await _processFavoritesBatch(
          userId: userId,
          batch: batch,
          batchIndex: i,
          totalBatches: batches.length,
        );

        results.merge(batchResult);

        // Pequeña pausa entre lotes para no saturar la red
        if (i < batches.length - 1) {
          await Future.delayed(_batchDelay);
        }
      }

      // 4. Actualizar timestamp de última sincronización
      _lastSyncTimes['favorites_$userId'] = DateTime.now();

      results.totalTime = stopwatch.elapsed;
      results.isSuccess = true;
    } catch (e) {
      results.isSuccess = false;
      results.errors.add(e.toString());
    } finally {
      stopwatch.stop();
    }

    return results;
  }

  /// Sincronización optimizada de películas vistas por lotes
  Future<SyncBatchResult> syncWatchedBatch({
    required String userId,
    required List<Movie> localWatched,
    int batchSize = _defaultBatchSize,
  }) async {
    final stopwatch = Stopwatch()..start();
    final results = SyncBatchResult();

    try {
      final lastSync = _lastSyncTimes['watched_$userId'];

      // Consulta optimizada con índices
      var remoteQuery =
          _supabase.from('user_watched_movies').select().eq('user_id', userId);

      if (lastSync != null) {
        remoteQuery = remoteQuery.gt('last_modified_at', lastSync.toIso8601String());
      }

      await remoteQuery.order('last_modified_at', ascending: false);

      // Procesar en lotes optimizados
      final batches = _createBatches(localWatched, batchSize);

      for (int i = 0; i < batches.length; i++) {
        final batch = batches[i];
        final batchResult = await _processWatchedBatch(
          userId: userId,
          batch: batch,
          batchIndex: i,
          totalBatches: batches.length,
        );

        results.merge(batchResult);

        if (i < batches.length - 1) {
          await Future.delayed(_batchDelay);
        }
      }

      _lastSyncTimes['watched_$userId'] = DateTime.now();
      results.totalTime = stopwatch.elapsed;
      results.isSuccess = true;
    } catch (e) {
      results.isSuccess = false;
      results.errors.add(e.toString());
    } finally {
      stopwatch.stop();
    }

    return results;
  }

  /// Sincronización optimizada de listas personalizadas
  Future<SyncBatchResult> syncCustomListsBatch({
    required String userId,
    required List<CustomList> localLists,
    int batchSize = _defaultBatchSize,
  }) async {
    final stopwatch = Stopwatch()..start();
    final results = SyncBatchResult();

    try {
      final lastSync = _lastSyncTimes['lists_$userId'];

      // Consulta optimizada para listas
      var listsQuery =
          _supabase.from('user_lists').select().eq('user_id', userId);

      if (lastSync != null) {
        listsQuery = listsQuery.gt('last_modified_at', lastSync.toIso8601String());
      }

      await listsQuery;

      // Procesar listas en lotes
      final listBatches = _createBatches(localLists, batchSize);

      for (int i = 0; i < listBatches.length; i++) {
        final batch = listBatches[i];
        final batchResult = await _processListsBatch(
          userId: userId,
          batch: batch,
          batchIndex: i,
          totalBatches: listBatches.length,
        );

        results.merge(batchResult);

        // Sincronizar elementos de las listas en paralelo (con límite)
        await _syncListItemsInParallel(userId, batch);

        if (i < listBatches.length - 1) {
          await Future.delayed(_batchDelay);
        }
      }

      _lastSyncTimes['lists_$userId'] = DateTime.now();
      results.totalTime = stopwatch.elapsed;
      results.isSuccess = true;
    } catch (e) {
      results.isSuccess = false;
      results.errors.add(e.toString());
    } finally {
      stopwatch.stop();
    }

    return results;
  }

  /// Operación de upsert masivo optimizada
  Future<void> bulkUpsertFavorites({
    required String userId,
    required List<Movie> movies,
  }) async {
    if (movies.isEmpty) return;

    final data = movies
        .map((movie) => {
              'user_id': userId,
              'movie_id': movie.id,
              'movie_title': movie.title,
              'movie_poster_path': movie.posterPath,
              'created_at': DateTime.now().toIso8601String(),
              'last_modified_at': DateTime.now().toIso8601String(),
            })
        .toList();

    // Usar upsert para manejar duplicados eficientemente
    await _supabase
        .from('user_favorites')
        .upsert(data, onConflict: 'user_id,movie_id');
  }

  /// Operación de eliminación masiva optimizada
  Future<void> bulkDeleteFavorites({
    required String userId,
    required List<int> movieIds,
  }) async {
    if (movieIds.isEmpty) return;

    await _supabase
        .from('user_favorites')
        .delete()
        .eq('user_id', userId)
        .inFilter('movie_id', movieIds);
  }

  /// Paginación optimizada para grandes conjuntos de datos
  Future<List<T>> paginatedQuery<T>({
    required String table,
    required String userId,
    required T Function(Map<String, dynamic>) fromJson,
    int pageSize = 100,
    String orderBy = 'created_at',
  }) async {
    final allResults = <T>[];
    int offset = 0;
    bool hasMore = true;

    while (hasMore) {
      final response = await _supabase
          .from(table)
          .select()
          .eq('user_id', userId)
          .order(orderBy)
          .range(offset, offset + pageSize - 1);

      final batch = response as List<dynamic>;

      if (batch.isEmpty) {
        hasMore = false;
      } else {
        allResults.addAll(
            batch.map((item) => fromJson(item as Map<String, dynamic>)));
        offset += pageSize;
        hasMore = batch.length == pageSize;
      }

      // Pausa pequeña entre páginas
      if (hasMore) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    return allResults;
  }

  /// Crear lotes optimizados basados en el tamaño de datos
  List<List<T>> _createBatches<T>(List<T> items, int batchSize) {
    final batches = <List<T>>[];
    final adjustedBatchSize = min(batchSize, _maxBatchSize);

    for (int i = 0; i < items.length; i += adjustedBatchSize) {
      final end = min(i + adjustedBatchSize, items.length);
      batches.add(items.sublist(i, end));
    }

    return batches;
  }

  /// Procesar lote de favoritos con reintentos
  Future<SyncBatchResult> _processFavoritesBatch({
    required String userId,
    required List<Movie> batch,
    required int batchIndex,
    required int totalBatches,
  }) async {
    final result = SyncBatchResult();
    int retries = 0;

    while (retries < _maxRetries) {
      try {
        await bulkUpsertFavorites(userId: userId, movies: batch);
        result.processedItems += batch.length;
        result.successfulBatches++;
        break;
      } catch (e) {
        retries++;
        if (retries >= _maxRetries) {
          result.failedBatches++;
          result.errors.add('Batch $batchIndex failed: $e');
        } else {
          // Espera exponencial entre reintentos
          await Future.delayed(
              Duration(milliseconds: 100 * pow(2, retries).toInt()));
        }
      }
    }

    return result;
  }

  /// Procesar lote de películas vistas
  Future<SyncBatchResult> _processWatchedBatch({
    required String userId,
    required List<Movie> batch,
    required int batchIndex,
    required int totalBatches,
  }) async {
    final result = SyncBatchResult();

    try {
      final data = batch
          .map((movie) => {
                'user_id': userId,
                'movie_id': movie.id,
                'movie_title': movie.title,
                'movie_poster_path': movie.posterPath,
                'watched_at': DateTime.now().toIso8601String(),
                'created_at': DateTime.now().toIso8601String(),
                'last_modified_at': DateTime.now().toIso8601String(),
              })
          .toList();

      await _supabase
          .from('user_watched_movies')
          .upsert(data, onConflict: 'user_id,movie_id');

      result.processedItems += batch.length;
      result.successfulBatches++;
    } catch (e) {
      result.failedBatches++;
      result.errors.add('Watched batch $batchIndex failed: $e');
    }

    return result;
  }

  /// Procesar lote de listas personalizadas
  Future<SyncBatchResult> _processListsBatch({
    required String userId,
    required List<CustomList> batch,
    required int batchIndex,
    required int totalBatches,
  }) async {
    final result = SyncBatchResult();

    try {
      final data = batch
          .map((list) => {
                'id': list.id,
                'user_id': userId,
                'name': list.name,
                'description': list.description,
                'color_hex': list.color,
                'created_at': list.createdAt.toIso8601String(),
                'last_modified_at': list.lastModifiedAt.toIso8601String(),
              })
          .toList();

      await _supabase.from('user_lists').upsert(data, onConflict: 'id');

      result.processedItems += batch.length;
      result.successfulBatches++;
    } catch (e) {
      result.failedBatches++;
      result.errors.add('Lists batch $batchIndex failed: $e');
    }

    return result;
  }

  /// Sincronizar elementos de listas en paralelo con límite de concurrencia
  Future<void> _syncListItemsInParallel(
      String userId, List<CustomList> lists) async {
    const maxConcurrency = 3;
    final semaphore = Semaphore(maxConcurrency);

    final futures = lists.map((list) async {
      await semaphore.acquire();
      try {
        await _syncListItems(userId, list);
      } finally {
        semaphore.release();
      }
    });

    await Future.wait(futures);
  }

  /// Sincronizar elementos de una lista específica
  Future<void> _syncListItems(String userId, CustomList list) async {
    if (list.movieIds.isEmpty) return;

    final data = list.movieIds
        .map((movieId) => {
              'list_id': list.id,
              'movie_id': movieId,
              'added_at': DateTime.now().toIso8601String(),
            })
        .toList();

    // Primero eliminar elementos existentes de la lista
    await _supabase
        .from('user_list_items')
        .delete()
        .match({'list_id': list.id});

    // Luego insertar los nuevos elementos
    if (data.isNotEmpty) {
      await _supabase.from('user_list_items').insert(data);
    }
  }

  /// Obtener estadísticas de rendimiento
  Map<String, dynamic> getPerformanceStats() {
    return {
      'last_sync_times': _lastSyncTimes,
      'default_batch_size': _defaultBatchSize,
      'max_batch_size': _maxBatchSize,
      'batch_delay_ms': _batchDelay.inMilliseconds,
      'max_retries': _maxRetries,
    };
  }

  /// Limpiar caché de timestamps
  void clearSyncCache() {
    _lastSyncTimes.clear();
  }
}

/// Resultado de operación de sincronización por lotes
class SyncBatchResult {
  bool isSuccess = false;
  int processedItems = 0;
  int successfulBatches = 0;
  int failedBatches = 0;
  List<String> errors = [];
  Duration totalTime = Duration.zero;

  void merge(SyncBatchResult other) {
    processedItems += other.processedItems;
    successfulBatches += other.successfulBatches;
    failedBatches += other.failedBatches;
    errors.addAll(other.errors);
  }

  Map<String, dynamic> toJson() {
    return {
      'is_success': isSuccess,
      'processed_items': processedItems,
      'successful_batches': successfulBatches,
      'failed_batches': failedBatches,
      'errors': errors,
      'total_time_ms': totalTime.inMilliseconds,
    };
  }
}

/// Semáforo para controlar concurrencia
class Semaphore {
  Semaphore(this.maxCount) : _currentCount = maxCount;
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}
