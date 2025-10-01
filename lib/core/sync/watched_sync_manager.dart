import 'dart:async';

import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/entities.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/entities/syncable_watched_movie.dart';
import '../../infrastructure/datasources/watched_movies_hive_datasource.dart';
import '../logging/logger_factory.dart';
import 'entity_sync_manager.dart';
import 'sync_operation.dart';

/// Implementación específica del EntitySyncManager para películas vistas
class WatchedSyncManager extends EntitySyncManager<SyncableWatchedMovie> {
  WatchedSyncManager({
    required super.userId,
    SupabaseClient? supabaseClient,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        super(entityType: 'watched_movie');
  final WatchedMoviesHiveDatasource _localDatasource =
      WatchedMoviesHiveDatasource();

  final SupabaseClient _supabase;
  static const String _tableName = 'user_watched';

  /// Getter para acceder al almacenamiento local de Hive
  Box get _localStorage => Hive.box('watched_movies');

  // =============================================
  // IMPLEMENTACIONES REQUERIDAS
  // =============================================

  @override
  Future<List<SyncableWatchedMovie>> getLocalPendingSync(
      {DateTime? since}) async {
    try {
      // Get local watched movies that need syncing from the persistent queue
      final queuedOperations = await super.processQueuedOperations();

      // For now, we'll get pending operations from the sync queue
      // In a complete implementation, this would also check local storage timestamps
      LoggerFactory.info(
          '🔍 Found ${queuedOperations.itemsProcessed} pending sync operations for watched movies');

      // Return empty list as operations are processed through the queue system
      return [];
    } catch (e) {
      LoggerFactory.error('❌ Error getting local pending sync: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableWatchedMovie>> getRemoteChanges({DateTime? since}) async {
    try {
      final response = since != null
          ? await _supabase
              .from(_tableName)
              .select()
              .eq('user_id', userId)
              .filter('last_modified_at', 'gte', since.toIso8601String())
              .order('last_modified_at', ascending: false)
          : await _supabase
              .from(_tableName)
              .select()
              .eq('user_id', userId)
              .order('last_modified_at', ascending: false);

      if (since != null) {
        LoggerFactory.info(
            '📅 Fetching remote changes since: ${since.toIso8601String()}');
      } else {
        LoggerFactory.info('📅 Fetching all remote changes (no date filter)');
      }
      final List<dynamic> data = response as List<dynamic>;

      final watchedMovies = data
          .map((item) => deserializeFromRemote(Map<String, dynamic>.from(item)))
          .toList();

      LoggerFactory.info(
          '📥 Retrieved ${watchedMovies.length} remote watched movies');
      return watchedMovies;
    } catch (e) {
      LoggerFactory.error('❌ Failed to fetch remote changes: $e');
      rethrow;
    }
  }

  @override
  Future<SyncResult> uploadChanges(List<SyncableWatchedMovie> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info('📤 Uploading ${entities.length} watched movies');

      for (final entity in entities) {
        try {
          final data = serializeForRemote(entity);

          // Usar upsert para crear o actualizar
          await _supabase.from(_tableName).upsert(data);

          successful++;
          LoggerFactory.debug('✅ Uploaded watched movie: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to upload watched movie ${entity.id}: $e';
          errors.add(error);
          LoggerFactory.error(error);
        }
      }

      final result = SyncResult(
        success: errors.isEmpty,
        itemsProcessed: entities.length,
        itemsSuccessful: successful,
        itemsFailed: entities.length - successful,
        errors: errors,
        duration: DateTime.now().difference(startTime),
      );

      LoggerFactory.info('📤 Upload completed: ${result.toString()}');
      return result;
    } catch (e) {
      LoggerFactory.error('❌ Upload batch failed: $e');
      return SyncResult.failure(
        itemsProcessed: entities.length,
        errors: ['Batch upload failed: $e'],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  @override
  Future<SyncResult> downloadChanges(
      List<SyncableWatchedMovie> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info(
          '📥 Processing ${entities.length} remote watched movies');

      for (final entity in entities) {
        try {
          // This will be handled by the hybrid repository when it processes the download
          // For now, just count as successful - the hybrid repository handles actual storage
          successful++;
          LoggerFactory.debug(
              '✅ Downloaded watched movie: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to save watched movie ${entity.id}: $e';
          errors.add(error);
          LoggerFactory.error(error);
        }
      }

      final result = SyncResult(
        success: errors.isEmpty,
        itemsProcessed: entities.length,
        itemsSuccessful: successful,
        itemsFailed: entities.length - successful,
        errors: errors,
        duration: DateTime.now().difference(startTime),
      );

      LoggerFactory.info('📥 Download completed: ${result.toString()}');
      return result;
    } catch (e) {
      LoggerFactory.error('❌ Download batch failed: $e');
      return SyncResult.failure(
        itemsProcessed: entities.length,
        errors: ['Batch download failed: $e'],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  @override
  Future<List<ConflictInfo<SyncableWatchedMovie>>> detectConflicts() async {
    try {
      final conflicts = <ConflictInfo<SyncableWatchedMovie>>[];

      // Obtener películas vistas localmente
      final localWatchedMovies = await _localDatasource.loadWatchedMovies();

      // Obtener cambios remotos para comparar
      final remoteWatchedMovies = await getRemoteChanges();

      for (final remoteMovie in remoteWatchedMovies) {
        // Buscar si existe localmente
        final localMovie = localWatchedMovies.cast<WatchedMovie?>().firstWhere(
              (movie) => movie?.movie.id == remoteMovie.movieId,
              orElse: () => null,
            );

        // Detectar conflicto si ambos existen pero tienen diferentes timestamps
        final localTimestamp = localMovie?.watchedDate ?? DateTime.now();
        final remoteTimestamp = remoteMovie.lastModifiedAt;

        // Si las fechas difieren significativamente (más de 1 segundo), hay conflicto
        if (localMovie != null &&
            (localTimestamp.difference(remoteTimestamp).abs().inSeconds > 1)) {
          conflicts.add(ConflictInfo<SyncableWatchedMovie>(
            localEntity: SyncableWatchedMovie.fromWatchedMovie(
              userId: userId,
              watchedMovie: localMovie,
            ),
            remoteEntity: remoteMovie,
            conflictType: ConflictType.concurrentModification,
            detectedAt: DateTime.now(),
          ));
        }
      }

      LoggerFactory.debug(
          '🔍 Detected ${conflicts.length} watched movie conflicts');
      return conflicts;
    } catch (e) {
      LoggerFactory.error('❌ Watched movie conflict detection failed: $e');
      return [];
    }
  }

  @override
  Future<SyncableWatchedMovie> resolveConflict(
      ConflictInfo<SyncableWatchedMovie> conflict) async {
    // Estrategia simple: "last write wins"
    final resolved =
        conflict.localEntity.hasPrecedenceOver(conflict.remoteEntity)
            ? conflict.localEntity
            : conflict.remoteEntity;

    LoggerFactory.info(
        '⚖️ Resolved conflict for watched movie ${resolved.movieTitle}: ${conflict.conflictType.name}');
    return resolved;
  }

  @override
  Map<String, dynamic> serializeForLocal(SyncableWatchedMovie entity) {
    return entity.toLocalStorage();
  }

  @override
  SyncableWatchedMovie deserializeFromLocal(Map<String, dynamic> data) {
    return SyncableWatchedMovie.fromJson(data);
  }

  @override
  Map<String, dynamic> serializeForRemote(SyncableWatchedMovie entity) {
    return entity.toSupabaseJson();
  }

  @override
  SyncableWatchedMovie deserializeFromRemote(Map<String, dynamic> data) {
    return SyncableWatchedMovie.fromJson(data);
  }

  // =============================================
  // MÉTODOS ESPECÍFICOS PARA PELÍCULAS VISTAS
  // =============================================

  /// Agrega una película vista y la cola para sync
  Future<void> addWatchedMovie(SyncableWatchedMovie watchedMovie) async {
    try {
      // Guardar localmente primero
      final localData = serializeForLocal(watchedMovie);
      await _localStorage.put('watched_${watchedMovie.id}', localData);
      LoggerFactory.info(
          '💾 Saved watched movie locally: ${watchedMovie.movieTitle}');

      await queueOperation(
        type: SyncOperationType.create,
        entityId: watchedMovie.id,
        data: localData,
        priority: 3, // Prioridad media para películas vistas
      );

      LoggerFactory.info(
          '➕ Added watched movie to queue: ${watchedMovie.movieTitle}');
    } catch (e) {
      LoggerFactory.error(
          '❌ Error adding watched movie ${watchedMovie.movieTitle}: $e');
      rethrow;
    }
  }

  Future<void> markAsWatched(Movie movie) async {
    try {
      // Verificar si ya está marcada como vista
      final isAlreadyWatched = await _localDatasource.isMovieWatched(movie.id);
      if (isAlreadyWatched) {
        LoggerFactory.debug('📝 Movie ${movie.id} already marked as watched');
        return;
      }

      // Marcar como vista localmente
      await _localDatasource.markAsWatched(movie);

      // Crear el item sincronizable
      final watchedMovie = SyncableWatchedMovie.fromMovie(
        userId: userId,
        movie: movie,
        customId: 'watched_${movie.id}_$userId',
        watchedDate: DateTime.now(),
      );

      await queueOperation(
        type: SyncOperationType.create,
        entityId: watchedMovie.id,
        data: watchedMovie.toSupabaseJson(),
        priority: 3,
      );

      LoggerFactory.debug('📝 Movie marked as watched: ${movie.id}');
    } catch (e) {
      LoggerFactory.error('❌ Failed to mark movie as watched: $e');
      rethrow;
    }
  }

  /// Elimina una película vista y la cola para sync
  Future<void> removeWatchedMovie(String watchedMovieId) async {
    try {
      // Remover del almacenamiento local
      await _localStorage.delete('watched_$watchedMovieId');
      LoggerFactory.info(
          '🗑️ Removed watched movie from local storage: $watchedMovieId');

      await queueOperation(
        type: SyncOperationType.delete,
        entityId: watchedMovieId,
        data: {}, // No necesitamos datos adicionales para hard delete
        priority: 2, // Alta prioridad para eliminaciones
      );

      LoggerFactory.info(
          '🗑️ Removed watched movie from queue: $watchedMovieId');
    } catch (e) {
      LoggerFactory.error('❌ Error removing watched movie $watchedMovieId: $e');
      rethrow;
    }
  }

  /// Sincroniza películas vistas específicamente
  Future<SyncResult> syncWatchedMovies() async {
    LoggerFactory.info('🔄 Starting watched movies sync');

    // Primero procesar operaciones en cola
    final queueResult = await processQueuedOperations();

    // Luego realizar sync completo
    final syncResult = await performFullSync();

    // Combinar resultados
    final totalProcessed =
        queueResult.itemsProcessed + syncResult.itemsProcessed;
    final totalSuccessful =
        queueResult.itemsSuccessful + syncResult.itemsSuccessful;
    final allErrors = [...queueResult.errors, ...syncResult.errors];

    final combinedResult = SyncResult(
      success: allErrors.isEmpty,
      itemsProcessed: totalProcessed,
      itemsSuccessful: totalSuccessful,
      itemsFailed: totalProcessed - totalSuccessful,
      errors: allErrors,
      duration: (queueResult.duration ?? Duration.zero) +
          (syncResult.duration ?? Duration.zero),
    );

    LoggerFactory.info(
        '✅ Watched movies sync completed: ${combinedResult.toString()}');
    return combinedResult;
  }

  @override
  Future<void> deleteEntity(String entityId) async {
    try {
      // Eliminar de Supabase
      await _supabase.from('watched_movies').delete().eq('id', entityId);

      LoggerFactory.info('🗑️ Deleted watched movie entity: $entityId');
    } catch (e) {
      LoggerFactory.error(
          '❌ Failed to delete watched movie entity $entityId: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getRemoteEntity(String entityId) async {
    try {
      final response = await _supabase
          .from('watched_movies')
          .select()
          .eq('id', entityId)
          .maybeSingle();

      LoggerFactory.debug(
          '📥 Retrieved remote watched movie entity: $entityId');
      return response;
    } catch (e) {
      LoggerFactory.error(
          '❌ Failed to get remote watched movie entity $entityId: $e');
      return null;
    }
  }

  @override
  Future<SyncableWatchedMovie> mergeEntities(SyncableWatchedMovie localEntity,
      SyncableWatchedMovie remoteEntity) async {
    // Estrategia: usar la entidad con timestamp más reciente
    final localTimestamp = localEntity.lastModifiedAt;
    final remoteTimestamp = remoteEntity.lastModifiedAt;

    final merged =
        localTimestamp.isAfter(remoteTimestamp) ? localEntity : remoteEntity;

    LoggerFactory.info(
        '🔀 Merged watched movie entities for ${merged.movieTitle}');
    return merged;
  }
}
