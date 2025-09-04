import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/sync_operation.dart';
import '../logging/logger_factory.dart';

/// Resultado de una operación en lote
class BatchOperationResult {
  const BatchOperationResult({
    required this.operationId,
    required this.success,
    this.error,
    this.data,
  });
  final String operationId;
  final bool success;
  final String? error;
  final Map<String, dynamic>? data;

  @override
  String toString() {
    return 'BatchOperationResult(id: $operationId, success: $success, error: $error)';
  }
}

/// Resultado de un lote completo
class BatchResult {
  BatchResult({
    required this.results,
    required this.processingTime,
  })  : allSuccessful = results.every((r) => r.success),
        successCount = results.where((r) => r.success).length,
        failureCount = results.where((r) => !r.success).length;
  final List<BatchOperationResult> results;
  final bool allSuccessful;
  final int successCount;
  final int failureCount;
  final Duration processingTime;

  @override
  String toString() {
    return 'BatchResult(total: ${results.length}, successful: $successCount, failed: $failureCount, time: ${processingTime.inMilliseconds}ms)';
  }
}

/// Agrupa operaciones por tipo para procesamiento en lote
class OperationBatch {
  OperationBatch({
    required this.type,
    required this.operations,
    required this.batchId,
  }) : createdAt = DateTime.now();
  final SyncOperationType type;
  final List<SyncOperation> operations;
  final String batchId;
  final DateTime createdAt;

  int get size => operations.length;
  bool get isEmpty => operations.isEmpty;
  bool get isNotEmpty => operations.isNotEmpty;

  @override
  String toString() {
    return 'OperationBatch(type: $type, size: $size, id: $batchId)';
  }
}

/// Gestor de operaciones en lote para optimizar requests a Supabase
class BatchOperationsManager {
  BatchOperationsManager(this._supabaseClient);

  final SupabaseClient _supabaseClient;

  // Timers para procesamiento automático de lotes
  final Map<SyncOperationType, Timer> _batchTimers = {};

  // Lotes pendientes por tipo de operación
  final Map<SyncOperationType, List<SyncOperation>> _pendingBatches = {};

  /// Procesa una lista de operaciones agrupándolas por tipo
  Future<BatchResult> processBatch(List<SyncOperation> operations) async {
    if (operations.isEmpty) {
      return BatchResult(
        results: [],
        processingTime: Duration.zero,
      );
    }

    final stopwatch = Stopwatch()..start();
    final results = <BatchOperationResult>[];

    try {
      LoggerFactory.info('Procesando lote de ${operations.length} operaciones');

      // Agrupar operaciones por tipo
      final groupedOperations = _groupOperationsByType(operations);

      // Procesar cada grupo
      for (final entry in groupedOperations.entries) {
        final type = entry.key;
        final typeOperations = entry.value;

        LoggerFactory.debug(
            'Procesando ${typeOperations.length} operaciones de tipo $type');

        final typeResults =
            await _processOperationsByType(type, typeOperations);
        results.addAll(typeResults);
      }
    } catch (e, stackTrace) {
      LoggerFactory.error('Error procesando lote',
          data: {'error': e}, stackTrace: stackTrace);

      // Crear resultados de error para todas las operaciones
      for (final operation in operations) {
        if (!results.any((r) => r.operationId == operation.id)) {
          results.add(BatchOperationResult(
            operationId: operation.id,
            success: false,
            error: e.toString(),
          ));
        }
      }
    } finally {
      stopwatch.stop();
    }

    final result = BatchResult(
      results: results,
      processingTime: stopwatch.elapsed,
    );

    LoggerFactory.info('Lote procesado: $result');
    return result;
  }

  /// Agrupa operaciones por tipo
  Map<SyncOperationType, List<SyncOperation>> _groupOperationsByType(
    List<SyncOperation> operations,
  ) {
    final grouped = <SyncOperationType, List<SyncOperation>>{};

    for (final operation in operations) {
      grouped.putIfAbsent(operation.type, () => []).add(operation);
    }

    return grouped;
  }

  /// Procesa operaciones de un tipo específico
  Future<List<BatchOperationResult>> _processOperationsByType(
    SyncOperationType type,
    List<SyncOperation> operations,
  ) async {
    switch (type) {
      case SyncOperationType.addFavorite:
        return await _processFavoriteBatch(operations, isAdd: true);
      case SyncOperationType.removeFavorite:
        return await _processFavoriteBatch(operations, isAdd: false);
      case SyncOperationType.markWatched:
        return await _processWatchedBatch(operations, isWatched: true);
      case SyncOperationType.unmarkWatched:
        return await _processWatchedBatch(operations, isWatched: false);
      case SyncOperationType.createCustomList:
        return await _processCustomListCreationBatch(operations);
      case SyncOperationType.updateCustomList:
        return await _processCustomListUpdateBatch(operations);
      case SyncOperationType.deleteCustomList:
        return await _processCustomListDeletionBatch(operations);
      case SyncOperationType.addMovieToList:
        return await _processListMovieBatch(operations, isAdd: true);
      case SyncOperationType.removeMovieFromList:
        return await _processListMovieBatch(operations, isAdd: false);
      case SyncOperationType.addToWatchlist:
        return await _processWatchlistBatch(operations, isAdd: true);
      case SyncOperationType.removeFromWatchlist:
        return await _processWatchlistBatch(operations, isAdd: false);
      case SyncOperationType.updateWatchlistPriority:
        return await _processWatchlistPriorityBatch(operations);
      case SyncOperationType.tokenRefresh:
        return await _processTokenRefreshBatch(operations);
    }
  }

  /// Procesa lote de operaciones de favoritos
  Future<List<BatchOperationResult>> _processFavoriteBatch(
      List<SyncOperation> operations,
      {required bool isAdd}) async {
    final results = <BatchOperationResult>[];

    try {
      if (isAdd) {
        // Preparar datos para inserción en lote
        final insertData = operations
            .map((op) => {
                  'user_id': op.data['userId'],
                  'movie_id': op.data['movieId'],
                  'created_at': op.data['timestamp'],
                  'updated_at': op.data['timestamp'],
                })
            .toList();

        await _supabaseClient
            .from('user_favorites')
            .upsert(insertData, onConflict: 'user_id,movie_id');

        // Todas las operaciones fueron exitosas
        for (final operation in operations) {
          results.add(BatchOperationResult(
            operationId: operation.id,
            success: true,
          ));
        }
      } else {
        // Para eliminación, procesar individualmente debido a limitaciones de Supabase
        for (final operation in operations) {
          try {
            await _supabaseClient
                .from('user_favorites')
                .delete()
                .eq('user_id', operation.data['userId'])
                .eq('movie_id', operation.data['movieId']);

            results.add(BatchOperationResult(
              operationId: operation.id,
              success: true,
            ));
          } catch (e) {
            results.add(BatchOperationResult(
              operationId: operation.id,
              success: false,
              error: e.toString(),
            ));
          }
        }
      }
    } catch (e) {
      LoggerFactory.error('Error en lote de favoritos', data: e != null ? {'error': e} : null);

      // Marcar todas como fallidas
      for (final operation in operations) {
        results.add(BatchOperationResult(
          operationId: operation.id,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Procesa lote de operaciones de películas vistas
  Future<List<BatchOperationResult>> _processWatchedBatch(
      List<SyncOperation> operations,
      {required bool isWatched}) async {
    final results = <BatchOperationResult>[];

    try {
      if (isWatched) {
        // Preparar datos para inserción en lote
        final insertData = operations
            .map((op) => {
                  'user_id': op.data['userId'],
                  'movie_id': op.data['movieId'],
                  'watched_at': op.data['watchedAt'],
                  'created_at': op.data['timestamp'],
                  'updated_at': op.data['timestamp'],
                })
            .toList();

        await _supabaseClient
            .from('user_watched_movies')
            .upsert(insertData, onConflict: 'user_id,movie_id');

        // Todas las operaciones fueron exitosas
        for (final operation in operations) {
          results.add(BatchOperationResult(
            operationId: operation.id,
            success: true,
          ));
        }
      } else {
        // Para eliminación, procesar individualmente
        for (final operation in operations) {
          try {
            await _supabaseClient
                .from('user_watched_movies')
                .delete()
                .eq('user_id', operation.data['userId'])
                .eq('movie_id', operation.data['movieId']);

            results.add(BatchOperationResult(
              operationId: operation.id,
              success: true,
            ));
          } catch (e) {
            results.add(BatchOperationResult(
              operationId: operation.id,
              success: false,
              error: e.toString(),
            ));
          }
        }
      }
    } catch (e) {
      LoggerFactory.error('Error en lote de películas vistas',
          data: e != null ? {'error': e} : null);

      // Marcar todas como fallidas
      for (final operation in operations) {
        results.add(BatchOperationResult(
          operationId: operation.id,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Procesa lote de creación de listas personalizadas
  Future<List<BatchOperationResult>> _processCustomListCreationBatch(
    List<SyncOperation> operations,
  ) async {
    final results = <BatchOperationResult>[];

    // Las listas personalizadas se procesan individualmente debido a la necesidad de obtener IDs
    for (final operation in operations) {
      try {
        final response = await _supabaseClient
            .from('user_custom_lists')
            .insert({
              'user_id': operation.data['userId'],
              'name': operation.data['name'],
              'description': operation.data['description'],
              'created_at': operation.data['timestamp'],
              'updated_at': operation.data['timestamp'],
            })
            .select('id')
            .single();

        results.add(BatchOperationResult(
          operationId: operation.id,
          success: true,
          data: {'listId': response['id']},
        ));
      } catch (e) {
        results.add(BatchOperationResult(
          operationId: operation.id,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Procesa lote de actualización de listas personalizadas
  Future<List<BatchOperationResult>> _processCustomListUpdateBatch(
    List<SyncOperation> operations,
  ) async {
    final results = <BatchOperationResult>[];

    for (final operation in operations) {
      try {
        await _supabaseClient
            .from('user_custom_lists')
            .update({
              'name': operation.data['name'],
              'description': operation.data['description'],
              'updated_at': operation.data['timestamp'],
            })
            .eq('id', operation.data['listId'])
            .eq('user_id', operation.data['userId']);

        results.add(BatchOperationResult(
          operationId: operation.id,
          success: true,
        ));
      } catch (e) {
        results.add(BatchOperationResult(
          operationId: operation.id,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Procesa lote de eliminación de listas personalizadas
  Future<List<BatchOperationResult>> _processCustomListDeletionBatch(
    List<SyncOperation> operations,
  ) async {
    final results = <BatchOperationResult>[];

    for (final operation in operations) {
      try {
        await _supabaseClient
            .from('user_custom_lists')
            .delete()
            .eq('id', operation.data['listId'])
            .eq('user_id', operation.data['userId']);

        results.add(BatchOperationResult(
          operationId: operation.id,
          success: true,
        ));
      } catch (e) {
        results.add(BatchOperationResult(
          operationId: operation.id,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Procesa lote de operaciones de películas en listas
  Future<List<BatchOperationResult>> _processListMovieBatch(
      List<SyncOperation> operations,
      {required bool isAdd}) async {
    final results = <BatchOperationResult>[];

    try {
      if (isAdd) {
        // Preparar datos para inserción en lote
        final insertData = operations
            .map((op) => {
                  'list_id': op.data['listId'],
                  'movie_id': op.data['movieId'],
                  'user_id': op.data['userId'],
                  'created_at': op.data['timestamp'],
                })
            .toList();

        await _supabaseClient
            .from('custom_list_movies')
            .upsert(insertData, onConflict: 'list_id,movie_id');

        // Todas las operaciones fueron exitosas
        for (final operation in operations) {
          results.add(BatchOperationResult(
            operationId: operation.id,
            success: true,
          ));
        }
      } else {
        // Para eliminación, procesar individualmente
        for (final operation in operations) {
          try {
            await _supabaseClient
                .from('custom_list_movies')
                .delete()
                .eq('list_id', operation.data['listId'])
                .eq('movie_id', operation.data['movieId'])
                .eq('user_id', operation.data['userId']);

            results.add(BatchOperationResult(
              operationId: operation.id,
              success: true,
            ));
          } catch (e) {
            results.add(BatchOperationResult(
              operationId: operation.id,
              success: false,
              error: e.toString(),
            ));
          }
        }
      }
    } catch (e) {
      LoggerFactory.error('Error en lote de películas en listas',
          data: e != null ? {'error': e} : null);

      // Marcar todas como fallidas
      for (final operation in operations) {
        results.add(BatchOperationResult(
          operationId: operation.id,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Optimiza el orden de las operaciones para mejor rendimiento
  List<SyncOperation> optimizeOperationOrder(List<SyncOperation> operations) {
    // Crear una copia para no modificar la lista original
    final optimized = List<SyncOperation>.from(operations);

    // Ordenar por:
    // 1. Prioridad (mayor primero)
    // 2. Tipo de operación (agrupando tipos similares)
    // 3. Fecha de creación (más antigua primero)
    optimized.sort((a, b) {
      // Prioridad
      final priorityComparison = b.priority.compareTo(a.priority);
      if (priorityComparison != 0) return priorityComparison;

      // Tipo de operación (agrupar tipos similares)
      final typeComparison = a.type.index.compareTo(b.type.index);
      if (typeComparison != 0) return typeComparison;

      // Fecha de creación
      return a.createdAt.compareTo(b.createdAt);
    });

    return optimized;
  }

  /// Estima el tiempo de procesamiento para un lote
  Duration estimateProcessingTime(List<SyncOperation> operations) {
    if (operations.isEmpty) return Duration.zero;

    // Tiempo base por operación según el tipo
    const baseTimePerOperation = {
      SyncOperationType.addFavorite: Duration(milliseconds: 50),
      SyncOperationType.removeFavorite: Duration(milliseconds: 75),
      SyncOperationType.markWatched: Duration(milliseconds: 50),
      SyncOperationType.unmarkWatched: Duration(milliseconds: 75),
      SyncOperationType.createCustomList: Duration(milliseconds: 200),
      SyncOperationType.updateCustomList: Duration(milliseconds: 100),
      SyncOperationType.deleteCustomList: Duration(milliseconds: 150),
      SyncOperationType.addMovieToList: Duration(milliseconds: 75),
      SyncOperationType.removeMovieFromList: Duration(milliseconds: 100),
      SyncOperationType.addToWatchlist: Duration(milliseconds: 60),
      SyncOperationType.removeFromWatchlist: Duration(milliseconds: 80),
      SyncOperationType.updateWatchlistPriority: Duration(milliseconds: 40),
      SyncOperationType.tokenRefresh: Duration(milliseconds: 30),
    };

    var totalTime = Duration.zero;

    for (final operation in operations) {
      final baseTime = baseTimePerOperation[operation.type] ??
          const Duration(milliseconds: 100);
      totalTime += baseTime;
    }

    // Agregar overhead de red y procesamiento
    final overhead =
        Duration(milliseconds: (operations.length * 10).clamp(50, 500));

    return totalTime + overhead;
  }

  /// Procesa lote de operaciones de watchlist
  Future<List<BatchOperationResult>> _processWatchlistBatch(
      List<SyncOperation> operations,
      {required bool isAdd}) async {
    final results = <BatchOperationResult>[];

    try {
      if (isAdd) {
        // Preparar datos para inserción en lote
        final insertData = operations
            .map((op) => {
                  'user_id': op.data['userId'],
                  'movie_id': op.data['movieId'],
                  'priority': op.data['priority'] ?? 'medium',
                  'created_at': op.data['timestamp'],
                  'updated_at': op.data['timestamp'],
                })
            .toList();

        await _supabaseClient
            .from('user_watchlist')
            .upsert(insertData, onConflict: 'user_id,movie_id');

        // Todas las operaciones fueron exitosas
        for (final operation in operations) {
          results.add(BatchOperationResult(
            operationId: operation.id,
            success: true,
          ));
        }
      } else {
        // Para eliminación, procesar individualmente
        for (final operation in operations) {
          try {
            await _supabaseClient
                .from('user_watchlist')
                .delete()
                .eq('user_id', operation.data['userId'])
                .eq('movie_id', operation.data['movieId']);

            results.add(BatchOperationResult(
              operationId: operation.id,
              success: true,
            ));
          } catch (e) {
            results.add(BatchOperationResult(
              operationId: operation.id,
              success: false,
              error: e.toString(),
            ));
          }
        }
      }
    } catch (e) {
      LoggerFactory.error('Error en lote de watchlist', data: e != null ? {'error': e} : null);

      // Marcar todas como fallidas
      for (final operation in operations) {
        results.add(BatchOperationResult(
          operationId: operation.id,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Procesa lote de actualizaciones de prioridad de watchlist
  Future<List<BatchOperationResult>> _processWatchlistPriorityBatch(
    List<SyncOperation> operations,
  ) async {
    final results = <BatchOperationResult>[];

    for (final operation in operations) {
      try {
        await _supabaseClient
            .from('user_watchlist')
            .update({
              'priority': operation.data['priority'],
              'updated_at': operation.data['timestamp'],
            })
            .eq('user_id', operation.data['userId'])
            .eq('movie_id', operation.data['movieId']);

        results.add(BatchOperationResult(
          operationId: operation.id,
          success: true,
        ));
      } catch (e) {
        results.add(BatchOperationResult(
          operationId: operation.id,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Procesa lote de operaciones de actualización de token
  Future<List<BatchOperationResult>> _processTokenRefreshBatch(
    List<SyncOperation> operations,
  ) async {
    final results = <BatchOperationResult>[];

    // Las operaciones de token refresh se procesan individualmente
    // ya que requieren lógica específica de autenticación
    for (final operation in operations) {
      try {
        // Para operaciones de token refresh, simplemente marcamos como completadas
        // ya que el token refresh real se maneja en el TokenRefreshService
        results.add(BatchOperationResult(
          operationId: operation.id,
          success: true,
        ));
      } catch (e) {
        results.add(BatchOperationResult(
          operationId: operation.id,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Libera recursos
  void dispose() {
    for (final timer in _batchTimers.values) {
      timer.cancel();
    }
    _batchTimers.clear();
    _pendingBatches.clear();

    LoggerFactory.info('BatchOperationsManager disposed');
  }
}
