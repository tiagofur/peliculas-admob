import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/generic_entity_sync_manager.dart';
import '../../domain/entities/syncable_custom_list.dart';
import 'base_hybrid_repository.dart';

/// Repositorio híbrido para listas personalizadas que combina almacenamiento local y remoto
/// con sincronización automática usando el sistema de sync de Fase 3
class HybridCustomListsRepository
    extends BaseHybridRepository<SyncableCustomList> {
  HybridCustomListsRepository({
    required super.userId,
    SharedPreferences? prefs,
    GenericEntitySyncManager<SyncableCustomList>? syncManager,
    super.syncCoordinator,
  })  : _prefs = prefs,
        super(
          entityType: 'custom_list',
          syncManager: syncManager ??
              GenericEntitySyncManager<SyncableCustomList>(
                  userId: userId, entityType: 'custom_list'),
        );

  SharedPreferences? _prefs;
  static const String _storageKey = 'local_custom_lists';

  // =============================================
  // IMPLEMENTACIÓN DE MÉTODOS ABSTRACTOS
  // =============================================

  @override
  Future<void> initializeLocal() async {
    _prefs ??= await SharedPreferences.getInstance();
    LoggerFactory.info(
        '✅ HybridCustomListsRepository local storage initialized');
  }

  @override
  Future<List<SyncableCustomList>> getLocalData() async {
    if (_prefs == null) await initializeLocal();

    try {
      final jsonList = _prefs!.getStringList(_storageKey) ?? [];
      final customLists = jsonList
          .map((jsonStr) => SyncableCustomList.fromJsonString(jsonStr))
          .where((list) => list.userId == userId && !list.isDeleted)
          .toList();

      LoggerFactory.debug(
          '📋 Retrieved ${customLists.length} local custom lists for user $userId');
      return customLists;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get local custom lists: $e');
      return [];
    }
  }

  @override
  Future<void> saveToLocal(SyncableCustomList entity) async {
    if (_prefs == null) await initializeLocal();

    try {
      final existing = await getLocalData();
      final updated = <SyncableCustomList>[];

      // Remover lista existente con el mismo ID
      for (final list in existing) {
        if (list.id != entity.id) {
          updated.add(list);
        }
      }

      // Agregar nueva entidad
      updated.add(entity);

      // Guardar lista actualizada
      final jsonList = updated.map((list) => list.toJsonString()).toList();
      await _prefs!.setStringList(_storageKey, jsonList);

      LoggerFactory.debug('💾 Saved custom list locally: ${entity.name}');
    } catch (e) {
      LoggerFactory.error('❌ Failed to save custom list locally: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFromLocal(String id) async {
    if (_prefs == null) await initializeLocal();

    try {
      final existing = await getLocalData();
      final filtered = existing.where((list) => list.id != id).toList();

      final jsonList = filtered.map((list) => list.toJsonString()).toList();
      await _prefs!.setStringList(_storageKey, jsonList);

      LoggerFactory.debug('🗑️ Removed custom list from local storage: $id');
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove custom list locally: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateLocal(SyncableCustomList entity) async {
    // Reutilizar saveToLocal ya que maneja actualizaciones
    await saveToLocal(entity);
  }

  @override
  SyncableCustomList convertToModel(SyncableCustomList entity) {
    return entity;
  }

  @override
  SyncableCustomList convertFromModel(dynamic model, String userId) {
    if (model is SyncableCustomList) {
      return model;
    } else {
      throw ArgumentError(
          'Model must be a SyncableCustomList, got ${model.runtimeType}');
    }
  }

  // =============================================
  // MÉTODOS ESPECÍFICOS PARA LISTAS PERSONALIZADAS
  // =============================================

  /// Obtiene lista personalizada por nombre
  Future<SyncableCustomList?> getCustomListByName(String name) async {
    try {
      final customLists = await getAll();
      final matches = customLists.where((list) => list.name == name);
      return matches.isNotEmpty ? matches.first : null;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get custom list by name: $e');
      return null;
    }
  }

  /// Crea una nueva lista personalizada
  Future<void> createCustomList({
    required String name,
    String? description,
    List<int>? movieIds,
  }) async {
    try {
      final customList = SyncableCustomList(
        id: 'list_${userId}_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        name: name,
        description: description,
        movieIds: movieIds ?? [],
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
      );

      await add(customList);
      LoggerFactory.info('➕ Created custom list: $name');
    } catch (e) {
      LoggerFactory.error('❌ Failed to create custom list: $e');
      rethrow;
    }
  }

  /// Elimina una lista personalizada
  Future<void> deleteCustomList(String listId) async {
    try {
      await remove(listId);
      LoggerFactory.info('🗑️ Deleted custom list: $listId');
    } catch (e) {
      LoggerFactory.error('❌ Failed to delete custom list: $e');
      rethrow;
    }
  }

  /// Agrega una película a una lista personalizada
  Future<void> addMovieToList(String listId, int movieId) async {
    try {
      final customLists = await getAll();
      final list = customLists.firstWhere(
        (list) => list.id == listId,
        orElse: () => throw Exception('Custom list not found: $listId'),
      );

      if (!list.movieIds.contains(movieId)) {
        final updatedList = list.copyWithData(
          movieIds: [...list.movieIds, movieId],
          lastModifiedAt: DateTime.now(),
        );
        await update(updatedList);
        LoggerFactory.info('➕ Added movie $movieId to list: ${list.name}');
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to add movie to list: $e');
      rethrow;
    }
  }

  /// Remueve una película de una lista personalizada
  Future<void> removeMovieFromList(String listId, int movieId) async {
    try {
      final customLists = await getAll();
      final list = customLists.firstWhere(
        (list) => list.id == listId,
        orElse: () => throw Exception('Custom list not found: $listId'),
      );

      if (list.movieIds.contains(movieId)) {
        final updatedList = list.copyWithData(
          movieIds: list.movieIds.where((id) => id != movieId).toList(),
          lastModifiedAt: DateTime.now(),
        );
        await update(updatedList);
        LoggerFactory.info(
            '🗑️ Removed movie $movieId from list: ${list.name}');
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove movie from list: $e');
      rethrow;
    }
  }
}
