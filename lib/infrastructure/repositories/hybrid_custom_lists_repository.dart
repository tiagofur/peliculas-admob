import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../core/services/persistent_sync_queue.dart';
import '../../core/sync/conflict_resolution/conflict_detector.dart';
import '../../core/sync/conflict_resolution/conflict_metrics_service.dart';
import '../../core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';
import '../../core/sync/conflict_resolution/soft_delete_manager.dart';
import '../../core/sync/conflict_resolution/strategies/custom_lists_conflict_strategy.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/entities/syncable_custom_list.dart';
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../datasources/custom_lists_shared_preferences_datasource.dart';
import '../services/connectivity_detector.dart';
// Removed unused import
import '../sync/conflict_statistics_service.dart';

// Repositorio híbrido que maneja listas personalizadas localmente y sincroniza con Supabase
class HybridCustomListsRepository
    implements SyncableRepository<SyncableCustomList> {
  HybridCustomListsRepository({
    required CustomListsSharedPreferencesDatasource localDatasource,
    required Ref ref,
    MultiplataformConflictResolver? conflictResolver,
    ConflictDetector? conflictDetector,
    SoftDeleteManager? softDeleteManager,
    ConflictMetricsService? metricsService,
  })  : _localDatasource = localDatasource,
        _ref = ref {
    _syncQueue = PersistentSyncQueue();

    // Inicializar componentes de resolución de conflictos
    _conflictResolver = conflictResolver ?? MultiplataformConflictResolver();
    // Removed unused _severityClassifier
    _statisticsService = ConflictStatisticsService();
    _conflictDetector = conflictDetector ??
        ConflictDetector(
          _softDeleteManager,
          _statisticsService,
        );
    _softDeleteManager = softDeleteManager ?? SoftDeleteManager();
    _metricsService = metricsService ?? ConflictMetricsService();

    // Registrar estrategia específica para listas personalizadas
    _conflictResolver.registerStrategy<SyncableCustomList>(
      CustomListsConflictStrategy(),
    );

    _initializeQueue();
    _metricsService.startSession('custom_lists_sync');
  }

  Future<void> _initializeQueue() async {
    await _syncQueue.initialize();
  }

  final CustomListsSharedPreferencesDatasource _localDatasource;
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  late final PersistentSyncQueue _syncQueue;

  // Componentes del nuevo sistema de resolución de conflictos
  late final MultiplataformConflictResolver _conflictResolver;
  // Removed unused _severityClassifier
  late final ConflictStatisticsService _statisticsService;
  late final ConflictDetector _conflictDetector;
  late final SoftDeleteManager _softDeleteManager;
  late final ConflictMetricsService _metricsService;

  // Métodos auxiliares
  Future<void> _checkOnline() async {
    final connectivityStatus = await ConnectivityDetector.instance.checkConnectivity();
    if (connectivityStatus == ConnectivityStatus.offline) {
      throw NetworkException();
    }
  }

  bool _isAuthenticated() {
    final appState = _ref.read(appStateProvider);
    return appState.isAuthenticated && appState.user != null;
  }

  String? _getCurrentUserId() {
    final appState = _ref.read(appStateProvider);
    return appState.user?.id;
  }

  // Métodos principales de listas personalizadas
  Future<List<CustomList>> getCustomLists() async {
    if (_isAuthenticated()) {
      try {
        await _checkOnline();
        await syncWithSupabase();
      } on SyncException catch (e) {
        LoggerFactory.warning(
            'Error en sincronización automática de listas: $e');
      }
    }

    try {
      return await _localDatasource.getCustomLists();
    } catch (e) {
      throw LocalStorageException(
          'Error al obtener las listas personalizadas: $e');
    }
  }

  Future<List<CustomList>> getDefaultLists() async {
    try {
      return await _localDatasource.getDefaultLists();
    } catch (e) {
      throw LocalStorageException(
          'Error al obtener las listas por defecto: $e');
    }
  }

  Future<void> saveCustomLists(List<CustomList> lists) async {
    try {
      await _localDatasource.saveCustomLists(lists);
    } catch (e) {
      throw LocalStorageException(
          'Error al guardar las listas personalizadas: $e');
    }
  }

  Future<void> saveDefaultLists(List<CustomList> lists) async {
    try {
      await _localDatasource.saveDefaultLists(lists);
    } catch (e) {
      throw LocalStorageException(
          'Error al guardar las listas por defecto: $e');
    }
  }

  Future<void> addCustomList(CustomList list) async {
    try {
      await _localDatasource.addCustomList(list);
    } catch (e) {
      throw LocalStorageException('Error al añadir la lista personalizada: $e');
    }

    // Agregar operación a la cola de sincronización
    final userId = _getCurrentUserId();
    if (userId != null) {
      final operation = SyncOperationFactory.createCustomList(
          name: list.name, description: list.description, userId: userId);

      LoggerFactory.info(
          '📝 Agregando operación a la cola: ${operation.type.name} para lista ${list.name}');
      await _syncQueue.enqueue(operation);
    }

    try {
      await _checkOnline();
      if (_isAuthenticated()) {
        await _syncSingleList(list, isDeleted: false);
      }
    } on SyncException catch (e) {
      LoggerFactory.logger
          .error('Error sincronizando nueva lista ${list.id}: $e');
    }
  }

  Future<void> updateCustomList(CustomList list) async {
    try {
      await _localDatasource.updateCustomList(list);
    } catch (e) {
      throw LocalStorageException(
          'Error al actualizar la lista personalizada: $e');
    }

    // Agregar operación a la cola de sincronización
    final userId = _getCurrentUserId();
    if (userId != null) {
      final operation = SyncOperationFactory.updateCustomList(
          listId: list.id,
          name: list.name,
          description: list.description,
          userId: userId);

      LoggerFactory.info(
          '📝 Agregando operación a la cola: ${operation.type.name} para lista ${list.name}');
      await _syncQueue.enqueue(operation);
    }

    try {
      await _checkOnline();
      if (_isAuthenticated()) {
        await _syncSingleList(list, isDeleted: false);
      }
    } on SyncException catch (e) {
      LoggerFactory.logger
          .error('Error sincronizando actualización de lista ${list.id}: $e');
    }
  }

  Future<void> deleteCustomList(String listId) async {
    try {
      await _localDatasource.deleteCustomList(listId);
    } catch (e) {
      throw LocalStorageException(
          'Error al eliminar la lista personalizada: $e');
    }

    // Agregar operación a la cola de sincronización
    final userId = _getCurrentUserId();
    if (userId != null) {
      final operation =
          SyncOperationFactory.deleteCustomList(listId: listId, userId: userId);

      LoggerFactory.info(
          '📝 Agregando operación a la cola: ${operation.type.name} para lista $listId');
      await _syncQueue.enqueue(operation);
    }

    try {
      await _checkOnline();
      if (_isAuthenticated()) {
        await _syncSingleListDeletion(listId);
      }
    } on SyncException catch (e) {
      LoggerFactory.logger
          .error('Error sincronizando eliminación de lista $listId: $e');
    }
  }

  Future<void> clearAllCustomLists() async {
    try {
      await _localDatasource.clearAllCustomLists();
      await _syncQueue.clearCompleted();
    } catch (e) {
      throw LocalStorageException(
          'Error al limpiar las listas personalizadas: $e');
    }
  }

  // Sincronizar un elemento individual
  Future<void> _syncSingleList(CustomList list,
      {required bool isDeleted}) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    try {
      if (!isDeleted) {
        // Agregar/actualizar lista en Supabase
        await _supabase.from('user_lists').upsert({
          'id': list.id,
          'user_id': userId,
          'name': list.name,
          'description': list.description,
          'color_hex': list.emoji, // Usando emoji como color por ahora
          'is_public': false,
          'created_at': list.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'deleted_at': null, // ✅ Marcar como activo (no eliminado)
        });

        // Sincronizar elementos de la lista
        await _syncListItems(list);
      }

      LoggerFactory.info(
          '✅ Sincronización individual completada para lista ${list.name}');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  Future<void> _syncSingleListDeletion(String listId) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    try {
      // ✅ Soft delete de elementos de la lista
      await _supabase.from('user_list_items').update({
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('list_id', listId);

      // ✅ Soft delete de la lista
      await _supabase
          .from('user_lists')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', listId)
          .eq('user_id', userId);

      LoggerFactory.info('✅ Eliminación de lista sincronizada: $listId');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  Future<void> _syncListItems(CustomList list) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    try {
      // Primero eliminar todos los elementos existentes de esta lista
      await _supabase.from('user_list_items').delete().eq('list_id', list.id);

      // Luego agregar los elementos actuales
      for (int i = 0; i < list.movieIds.length; i++) {
        final movieId = list.movieIds[i];
        await _supabase.from('user_list_items').insert({
          'id': '${list.id}_${movieId}_item',
          'list_id': list.id,
          'movie_id': movieId,
          'movie_title': '', // Se podría obtener del caché local
          'movie_poster_path': null,
          'movie_backdrop_path': null,
          'movie_overview': null,
          'movie_release_date': null,
          'movie_vote_average': null,
          'order_index': i,
          'added_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'deleted_at': null, // ✅ Marcar como activo
        });
      }
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  // Implementación de SyncableRepository
  @override
  Future<List<SyncableCustomList>> getLocalData() async {
    try {
      final customLists = await _localDatasource.getCustomLists();
      final userId = _getCurrentUserId();
      if (userId == null) return [];

      return customLists
          .map((list) => SyncableCustomList.fromCustomList(list))
          .toList();
    } catch (e) {
      throw LocalStorageException(
          'Error al obtener los datos locales de listas: $e');
    }
  }

  @override
  Future<List<SyncableCustomList>> getRemoteData() async {
    final userId = _getCurrentUserId();
    if (userId == null) return [];

    try {
      await _checkOnline();
      final response = await _supabase
          .from('user_lists')
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null); // ✅ Solo obtener listas activas

      List<SyncableCustomList> remoteLists = [];

      for (final data in response as List) {
        // Obtener elementos de la lista (solo activos)
        final itemsResponse = await _supabase
            .from('user_list_items')
            .select()
            .eq('list_id', data['id'])
            .isFilter('deleted_at', null) // ✅ Solo elementos activos
            .order('order_index');

        final movieIds = (itemsResponse as List)
            .map((item) => item['movie_id'] is int ? item['movie_id'] as int : int.tryParse(item['movie_id'].toString()) ?? 0)
            .where((id) => id > 0)
            .toList();

        remoteLists.add(_mapFromSupabase(data, movieIds));
      }

      return remoteLists;
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException('Error obteniendo listas remotas: $e');
    }
  }

  @override
  Future<void> markForSync(String itemId) async {
    // Las operaciones se agregan automáticamente a la cola
    LoggerFactory.info(
        '📝 Marcador de sincronización agregado automáticamente: $itemId');
  }

  @override
  Future<bool> hasPendingSync() async {
    final stats = _syncQueue.getStats();
    return stats.pendingOperations > 0;
  }

  @override
  Future<List<String>> getPendingSyncItems() async {
    final operations = _syncQueue.getPendingOperations();
    return operations
        .map((op) => '${op.data['listId']}_${op.type.name}')
        .toList();
  }

  @override
  Future<void> clearSyncMarker(String itemId) async {
    // Las operaciones se limpian automáticamente por la cola
    LoggerFactory.info(
        '🧹 Marcador de sincronización limpiado automáticamente: $itemId');
  }

  // Implementación de métodos abstractos faltantes
  @override
  Future<void> syncWithSupabase() async {
    if (!_isAuthenticated()) {
      LoggerFactory.info(
          '👤 Usuario no autenticado, omitiendo sincronización de listas');
      return;
    }

    try {
      await _checkOnline();
      LoggerFactory.info(
          '🔄 Iniciando sincronización de listas personalizadas con Supabase');

      final localData = await getLocalData();
      final remoteData = await getRemoteData();

      LoggerFactory.info(
          '📊 Datos obtenidos: ${localData.length} locales, ${remoteData.length} remotos');

      await resolveConflicts(localData, remoteData);

      LoggerFactory.info('✅ Sincronización de listas completada exitosamente');
    } catch (e) {
      LoggerFactory.error('💥 Error en sincronización de listas: $e');
      throw SyncException('Error en sincronización: $e');
    }
  }

  @override
  Future<void> upload(List<SyncableCustomList> items) async {
    if (!_isAuthenticated()) return;

    try {
      await _checkOnline();

      for (final item in items) {
        await _syncSingleList(item.toCustomList(), isDeleted: false);
      }
    } catch (e) {
      throw SyncException('Error subiendo listas: $e');
    }
  }

  @override
  Future<void> download(List<SyncableCustomList> items) async {
    if (!_isAuthenticated()) return;

    try {
      final customLists = items.map((item) => item.toCustomList()).toList();
      await saveCustomLists(customLists);
    } catch (e) {
      throw SyncException('Error descargando listas: $e');
    }
  }

  @override
  Future<void> resolveConflicts(
      List<SyncableCustomList> local, List<SyncableCustomList> remote) async {
    LoggerFactory.info(
        '🔍 Iniciando resolución de conflictos para ${local.length} listas locales y ${remote.length} remotas');

    try {
      // Detectar conflictos usando el nuevo sistema
      final conflicts = _conflictDetector.detectConflicts(local, remote);

      LoggerFactory.info(
          '⚠️ Detectados ${conflicts.length} conflictos en listas personalizadas');

      // Procesar cada conflicto individualmente
      for (final conflict in conflicts) {
        try {
          // Registrar conflicto detectado
          _metricsService.logConflictDetected(conflict);

          LoggerFactory.info(
              '🔧 Resolviendo conflicto ${conflict.type.name} para lista ${conflict.localItem.name}');

          // Detectar tipo de conflicto
          final conflictType = _conflictResolver.detectConflictType(
            conflict.localItem,
            conflict.remoteItem,
            conflict.localItem.deletedAt != null,
            conflict.remoteItem.deletedAt != null,
            conflict.localItem.updatedAt,
            conflict.remoteItem.updatedAt,
          );

          // Resolver usando la estrategia específica
          final resolution = _conflictResolver.resolveConflict(
            conflict.localItem,
            conflict.remoteItem,
            conflictType,
          );

          // Aplicar la resolución
          await _applyResolution(conflict, resolution);

          // Registrar resolución exitosa
          _metricsService.logConflictResolved(conflict, resolution);

          LoggerFactory.info('✅ Conflicto resuelto exitosamente');
        } catch (e) {
          LoggerFactory.error('❌ Error resolviendo conflicto: $e');
          _metricsService.logConflictResolutionError(
              conflict, e, StackTrace.current);
          rethrow;
        }
      }

      // Sincronizar elementos sin conflictos
      await _syncNonConflictingItems(local, remote, conflicts);

      // Obtener y mostrar estadísticas
      final stats = _conflictResolver.getConflictStats();
      LoggerFactory.info(
          '📊 Estadísticas de resolución: ${stats['totalConflicts']} conflictos, ${stats['dataLossIncidents']} con pérdida de datos');
    } catch (e) {
      LoggerFactory.error('💥 Error en resolución de conflictos de listas: $e');
      rethrow;
    }
  }

  /// Aplica la resolución de un conflicto tanto local como remotamente
  Future<void> _applyResolution<T>(
    ConflictInfo<T> conflict,
    ConflictResolutionResult<T> resolution,
  ) async {
    final resolvedItem = resolution.resolvedItem as SyncableCustomList;

    try {
      // Manejar soft deletes
      if (resolution.dataLoss) {
        _softDeleteManager.markAsDeleted(resolvedItem);

        // Aplicar soft delete remotamente para la lista
        await _supabase.from('user_lists').update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', resolvedItem.id);

        // Aplicar soft delete a los elementos de la lista
        await _supabase.from('user_list_items').update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('list_id', resolvedItem.id);

        // Remover localmente
        await _localDatasource.deleteCustomList(resolvedItem.id);

        LoggerFactory.info(
            '🗑️ Soft delete aplicado para lista ${resolvedItem.name}');
        return;
      }

      // Aplicar resolución localmente
      final customList = resolvedItem.toCustomList();
      await _localDatasource.updateCustomList(customList);

      // Aplicar resolución remotamente
      await _supabase.from('user_lists').upsert({
        'id': resolvedItem.id,
        'user_id': resolvedItem.userId,
        'name': resolvedItem.name,
        'description': resolvedItem.description,
        'color_hex': resolvedItem.emoji,
        'is_public': resolvedItem.isPublic,
        'created_at': resolvedItem.createdAt.toIso8601String(),
        'updated_at': resolvedItem.updatedAt.toIso8601String(),
        'deleted_at': null, // Asegurar que no esté marcado como eliminado
      });

      // Sincronizar elementos de la lista
      await _syncListItems(customList);

      LoggerFactory.info(
          '💾 Resolución aplicada para lista ${resolvedItem.name}');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(
          'Error aplicando resolución para ${resolvedItem.id}: ${e.message}',
          code: e.code);
    } catch (e) {
      throw LocalStorageException(
          'Error aplicando resolución para ${resolvedItem.id}: $e');
    }
  }

  /// Sincroniza elementos que no tienen conflictos
  Future<void> _syncNonConflictingItems(
    List<SyncableCustomList> localItems,
    List<SyncableCustomList> remoteItems,
    List<ConflictInfo<SyncableCustomList>> conflicts,
  ) async {
    // Obtener IDs de elementos en conflicto
    final conflictIds =
        conflicts.expand((c) => [c.localItem.id, c.remoteItem.id]).toSet();

    // Elementos locales sin conflictos para subir
    final localToUpload = localItems
        .where((item) => !conflictIds.contains(item.id))
        .where((local) => !remoteItems.any((remote) => remote.id == local.id))
        .toList();

    // Elementos remotos sin conflictos para descargar
    final remoteToDownload = remoteItems
        .where((item) => !conflictIds.contains(item.id))
        .where((remote) => !localItems.any((local) => local.id == remote.id))
        .toList();

    LoggerFactory.info(
        '⬆️ Subiendo ${localToUpload.length} listas sin conflictos');
    LoggerFactory.info(
        '⬇️ Descargando ${remoteToDownload.length} listas sin conflictos');

    // Subir elementos locales
    if (localToUpload.isNotEmpty) {
      await upload(localToUpload);
    }

    // Descargar elementos remotos
    if (remoteToDownload.isNotEmpty) {
      await download(remoteToDownload);
    }
  }

  // Método auxiliar que faltaba
  SyncableCustomList _mapFromSupabase(
      Map<String, dynamic> data, List<int> movieIds) {
    return SyncableCustomList(
      id: data['id'] as String? ?? '',
      userId: data['user_id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      emoji: data['color_hex'] as String? ?? '📝',
      color: data['color_hex'] as String? ?? 'blue',
      movieIds: movieIds,
      isPublic: data['is_public'] as bool? ?? false,
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
