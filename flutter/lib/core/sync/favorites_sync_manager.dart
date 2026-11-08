import 'dart:async';

import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/entities.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/entities/syncable_favorite.dart';
import '../../domain/entities/syncable_favorite_movie.dart';
import '../../infrastructure/datasources/favorite_movies_hive_datasource.dart';
import '../../infrastructure/models/favorite_model.dart';
import '../logging/logger_factory.dart';
import 'entity_sync_manager.dart';
import 'sync_operation.dart';

/// Implementación específica del EntitySyncManager para favoritos
class FavoritesSyncManager extends EntitySyncManager<SyncableFavorite> {
  FavoritesSyncManager({
    required super.userId,
    SupabaseClient? supabaseClient,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        super(entityType: 'favorite') {
    _localStorage = Hive.box('favorites_local_storage');
  }
  final FavoriteMoviesHiveDatasource _localDatasource =
      FavoriteMoviesHiveDatasource();

  final SupabaseClient _supabase;
  static const String _tableName = 'user_favorites';
  late final Box _localStorage;

  // =============================================
  // IMPLEMENTACIONES REQUERIDAS
  // =============================================

  @override
  Future<List<SyncableFavorite>> getLocalPendingSync({DateTime? since}) async {
    try {
      // ✅ FIX: Identificar favoritos locales que necesitan sincronización
      final localMovies =
          await _localDatasource.loadMovies(limit: 10000, offset: 0);
      final remoteFavorites = await getRemoteChanges(since: since);

      // Crear conjunto de IDs remotos para comparación rápida
      final remoteMovieIds = {for (var fav in remoteFavorites) fav.movieId};

      // Filtrar favoritos locales que NO están en remoto
      final pendingMovies = localMovies
          .where((movie) => !remoteMovieIds.contains(movie.id))
          .toList();

      // Convertir a SyncableFavorite con timestamps apropiados
      final pendingFavorites = pendingMovies.map((movie) {
        // ✅ FIX: Usar el timestamp real del favorito local si está disponible
        final existingFavorite = FavoriteModel.fromMovie(movie, userId);
        return SyncableFavorite.fromFavoriteModel(existingFavorite, userId);
      }).toList();

      LoggerFactory.info(
          '🔍 Found ${pendingFavorites.length} local favorites pending sync (${localMovies.length} local, ${remoteFavorites.length} remote)');

      if (pendingFavorites.isNotEmpty) {
        LoggerFactory.info(
            '📤 Favorites to upload: ${pendingFavorites.map((f) => f.movieTitle).join(', ')}');
      }

      return pendingFavorites;
    } catch (e) {
      LoggerFactory.error('❌ Error getting local pending sync: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableFavorite>> getRemoteChanges({DateTime? since}) async {
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

      final favorites = data
          .map((item) => deserializeFromRemote(Map<String, dynamic>.from(item)))
          .toList();

      LoggerFactory.info('📥 Retrieved ${favorites.length} remote favorites');
      return favorites;
    } catch (e) {
      LoggerFactory.error('❌ Failed to fetch remote changes: $e');
      rethrow;
    }
  }

  @override
  Future<SyncResult> uploadChanges(List<SyncableFavorite> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info('📤 Uploading ${entities.length} favorites');

      for (final entity in entities) {
        try {
          final data = serializeForRemote(entity);

          // Usar upsert para crear o actualizar
          await _supabase.from(_tableName).upsert(data);

          successful++;
          LoggerFactory.debug('✅ Uploaded favorite: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to upload favorite ${entity.id}: $e';
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
  Future<SyncResult> downloadChanges(List<SyncableFavorite> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info('📥 Processing ${entities.length} remote favorites');

      for (final entity in entities) {
        try {
          // This will be handled by the hybrid repository when it processes the download
          // For now, just count as successful - the hybrid repository handles actual storage
          successful++;
          LoggerFactory.debug('✅ Downloaded favorite: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to save favorite ${entity.id}: $e';
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
  Future<List<ConflictInfo<SyncableFavorite>>> detectConflicts() async {
    try {
      final conflicts = <ConflictInfo<SyncableFavorite>>[];

      // Obtener favoritos locales
      final localFavorites = await _localDatasource.loadMovies();

      // Obtener cambios remotos para comparar
      final remoteFavorites = await getRemoteChanges();

      for (final remoteFavorite in remoteFavorites) {
        // Buscar si existe localmente
        final localFavorite = localFavorites.cast<Movie?>().firstWhere(
              (movie) => movie?.id == remoteFavorite.movieId,
              orElse: () => null,
            );

        // Detectar conflicto si ambos existen pero tienen diferentes timestamps
        final localTimestamp = DateTime
            .now(); // Para favoritos usamos timestamp actual como referencia
        final remoteTimestamp = remoteFavorite.lastModifiedAt;

        // Si las fechas difieren significativamente (más de 1 segundo), hay conflicto
        if (localFavorite != null &&
            (localTimestamp.difference(remoteTimestamp).abs().inSeconds > 1)) {
          conflicts.add(ConflictInfo<SyncableFavorite>(
            localEntity:
                SyncableFavorite.fromFavoriteModel(localFavorite, userId),
            remoteEntity: remoteFavorite,
            conflictType: ConflictType.concurrentModification,
            detectedAt: DateTime.now(),
          ));
        }
      }

      LoggerFactory.debug('🔍 Detected ${conflicts.length} favorite conflicts');
      return conflicts;
    } catch (e) {
      LoggerFactory.error('❌ Favorite conflict detection failed: $e');
      return [];
    }
  }

  @override
  Future<SyncableFavorite> resolveConflict(
      ConflictInfo<SyncableFavorite> conflict) async {
    // Estrategia simple: "last write wins"
    final resolved =
        conflict.localEntity.hasPrecedenceOver(conflict.remoteEntity)
            ? conflict.localEntity
            : conflict.remoteEntity;

    LoggerFactory.info(
        '⚖️ Resolved conflict for favorite ${resolved.movieTitle}: ${conflict.conflictType.name}');
    return resolved;
  }

  @override
  Map<String, dynamic> serializeForLocal(SyncableFavorite entity) {
    return entity.toLocalStorage();
  }

  @override
  SyncableFavorite deserializeFromLocal(Map<String, dynamic> data) {
    return SyncableFavorite.fromJson(data);
  }

  @override
  Map<String, dynamic> serializeForRemote(SyncableFavorite entity) {
    return entity.toSupabaseJson();
  }

  @override
  SyncableFavorite deserializeFromRemote(Map<String, dynamic> data) {
    return SyncableFavorite.fromJson(data);
  }

  // =============================================
  // MÉTODOS ESPECÍFICOS PARA FAVORITOS
  // =============================================

  /// Agrega una película a favoritos
  Future<void> addToFavorites(Movie movie) async {
    try {
      // Verificar si ya está en favoritos localmente
      final isAlreadyFavorite =
          await _localDatasource.isMovieFavorite(movie.id);
      if (isAlreadyFavorite) {
        LoggerFactory.debug('⚠️ Movie ${movie.title} is already in favorites');
        return;
      }

      // Agregar a storage local primero
      await _localDatasource.saveFavorite(movie);

      final now = DateTime.now();
      final syncableFavorite = SyncableFavorite(
        id: '${userId}_${movie.id}',
        userId: userId,
        movieId: movie.id,
        movieTitle: movie.title,
        addedAt: now,
        createdAt: now,
        lastModifiedAt: now,
      );

      // Encolar operación de sincronización
      await queueOperation(
        type: SyncOperationType.create,
        entityId: syncableFavorite.id,
        data: syncableFavorite.toSupabaseJson(),
        priority: 1, // Alta prioridad
      );

      LoggerFactory.debug(
          '✅ Movie ${movie.title} added to favorites and queued for sync');
    } catch (e) {
      LoggerFactory.error('❌ Failed to add movie to favorites: $e');
      rethrow;
    }
  }

  /// Agrega un favorito y lo cola para sync
  Future<void> addFavorite(SyncableFavorite favorite) async {
    try {
      // Guardar localmente primero
      final localData = serializeForLocal(favorite);
      await _localStorage.put('favorite_${favorite.id}', localData);
      LoggerFactory.info('💾 Saved favorite locally: ${favorite.movieTitle}');

      // Luego agregar a cola de sincronización
      await queueOperation(
        type: SyncOperationType.create,
        entityId: favorite.id,
        data: localData,
        priority: 3, // Prioridad media para favoritos
      );

      LoggerFactory.info(
          '➕ Added favorite to sync queue: ${favorite.movieTitle}');
    } catch (e) {
      LoggerFactory.error('❌ Error adding favorite ${favorite.movieTitle}: $e');
      rethrow;
    }
  }

  /// Elimina una película de favoritos
  Future<void> removeFromFavorites(Movie movie) async {
    try {
      // Verificar si está en favoritos localmente
      final isCurrentlyFavorite =
          await _localDatasource.isMovieFavorite(movie.id);
      if (!isCurrentlyFavorite) {
        LoggerFactory.debug('⚠️ Movie ${movie.title} is not in favorites');
        return;
      }

      // Remover de storage local primero
      await _localDatasource.removeFavoriteById(movie.id);

      final favoriteId = '${userId}_${movie.id}';

      // Encolar operación de eliminación
      await queueOperation(
        type: SyncOperationType.delete,
        entityId: favoriteId,
        data: {}, // No necesitamos datos adicionales para hard delete
        priority: 1, // Alta prioridad
      );

      LoggerFactory.debug(
          '✅ Movie ${movie.title} removed from favorites and queued for sync');
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove movie from favorites: $e');
      rethrow;
    }
  }

  /// Elimina un favorito y lo cola para sync
  Future<void> removeFavorite(String favoriteId) async {
    try {
      // Remover del almacenamiento local
      await _localStorage.delete('favorite_$favoriteId');
      LoggerFactory.info(
          '🗑️ Removed favorite from local storage: $favoriteId');

      // Agregar operación de eliminación a la cola
      await queueOperation(
        type: SyncOperationType.delete,
        entityId: favoriteId,
        data: {}, // No necesitamos datos adicionales para hard delete
        priority: 2, // Alta prioridad para eliminaciones
      );

      LoggerFactory.info(
          '🗑️ Added favorite deletion to sync queue: $favoriteId');
    } catch (e) {
      LoggerFactory.error('❌ Error removing favorite $favoriteId: $e');
      rethrow;
    }
  }

  /// Sincroniza favoritos específicamente
  Future<SyncResult> syncFavorites() async {
    LoggerFactory.info('🔄 Starting favorites sync');

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
        '✅ Favorites sync completed: ${combinedResult.toString()}');
    return combinedResult;
  }

  // =============================================
  // MÉTODOS ABSTRACTOS REQUERIDOS
  // =============================================

  @override
  Future<void> deleteEntity(String entityId) async {
    try {
      await _supabase.from(_tableName).delete().eq('id', entityId);

      LoggerFactory.info('🗑️ Deleted favorite entity: $entityId');
    } catch (e) {
      LoggerFactory.error('❌ Failed to delete favorite entity $entityId: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getRemoteEntity(String entityId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', entityId)
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      LoggerFactory.error(
          '❌ Failed to get remote favorite entity $entityId: $e');
      return null;
    }
  }

  @override
  Future<SyncableFavorite> mergeEntities(
      SyncableFavorite localEntity, SyncableFavorite remoteEntity) async {
    // Estrategia simple: usar la entidad con timestamp más reciente
    final localTimestamp = localEntity.lastModifiedAt;
    final remoteTimestamp = remoteEntity.lastModifiedAt;

    if (localTimestamp.isAfter(remoteTimestamp)) {
      LoggerFactory.info(
          '🔀 Merged favorites: keeping local version for ${localEntity.movieTitle}');
      return localEntity;
    } else {
      LoggerFactory.info(
          '🔀 Merged favorites: keeping remote version for ${remoteEntity.movieTitle}');
      return remoteEntity;
    }
  }
}
