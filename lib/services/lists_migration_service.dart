import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/custom_list.dart';
import '../domain/repositories/i_custom_lists_repository.dart';
import '../infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';

/// Servicio de migración de listas personalizadas
/// Maneja la migración de datos locales a Supabase
class ListsMigrationService {
  ListsMigrationService(
    this._repository,
    this._prefs,
    this._localDataSource,
    this._supabase,
  );
  final ICustomListsRepository _repository;
  final SharedPreferences _prefs;
  final CustomListsSharedPreferencesDatasource _localDataSource;
  final SupabaseClient _supabase;

  // Claves para SharedPreferences
  static const String _migrationCompletedKey = 'lists_migration_completed';
  static const String _migrationVersionKey = 'lists_migration_version';
  static const String _localToSupabaseMapKey = 'local_to_supabase_id_map';
  static const String _migrationBackupKey = 'migration_backup_data';

  // Versión actual de migración
  static const int _currentMigrationVersion = 1;

  // ========== DETECCIÓN Y ANÁLISIS ==========

  /// Analiza las necesidades de migración del usuario
  Future<MigrationPlan> analyzeMigrationNeeds(String userId) async {
    try {
      final localLists = await _getLocalLists();
      final remoteLists = await _getRemoteLists(userId);

      return MigrationPlan(
        userId: userId,
        defaultListsToCreate:
            _findDefaultListsToCreate(localLists, remoteLists),
        customListsToMigrate:
            _findCustomListsToMigrate(localLists, remoteLists),
        itemsToMigrate: await _findItemsToMigrate(localLists, remoteLists),
        conflictsToResolve: _findConflicts(localLists, remoteLists),
        totalEstimatedTime: _calculateEstimatedTime(localLists),
      );
    } catch (e) {
      throw MigrationException(
          'Error al analizar necesidades de migración: $e');
    }
  }

  /// Verifica si la migración ya fue completada
  bool isMigrationCompleted() {
    return _prefs.getBool(_migrationCompletedKey) ?? false;
  }

  /// Obtiene la versión de migración actual
  int getCurrentMigrationVersion() {
    return _prefs.getInt(_migrationVersionKey) ?? 0;
  }

  // ========== MIGRACIÓN DE LISTAS POR DEFECTO ==========

  /// Migra las 8 listas por defecto originales a Supabase
  Future<Map<String, String>> migrateDefaultLists(String userId) async {
    final idMapping = <String, String>{};

    try {
      // Crear backup antes de migrar
      await _createMigrationBackup();

      final defaultListsConfig = _getOriginalDefaultListsConfig();

      for (final config in defaultListsConfig) {
        // Verificar si ya existe en Supabase
        final existingList =
            await _findExistingDefaultList(userId, config.name);

        if (existingList == null) {
          // Crear nueva lista en Supabase
          final supabaseList =
              await _createDefaultListInSupabase(userId, config);
          idMapping[config.localId] = supabaseList.id;

          // Migrar películas locales si existen
          await _migrateLocalMoviesToSupabase(
            config.localId,
            supabaseList.id,
            userId,
          );
        } else {
          idMapping[config.localId] = existingList.id;
        }
      }

      // Guardar mapeo de IDs
      await _saveIdMapping(idMapping);

      return idMapping;
    } catch (e) {
      // Intentar rollback en caso de error
      await _rollbackMigration();
      throw MigrationException('Error al migrar listas por defecto: $e');
    }
  }

  /// Migra listas personalizadas existentes
  Future<void> migrateCustomLists(String userId) async {
    try {
      final localCustomLists = await _getLocalCustomLists();

      for (final localList in localCustomLists) {
        if (!await _existsInSupabase(localList.id, userId)) {
          await _createListInSupabase(userId, localList);
          await _migrateListItems(localList, userId);
        }
      }
    } catch (e) {
      throw MigrationException('Error al migrar listas personalizadas: $e');
    }
  }

  // ========== CONFIGURACIÓN DE LISTAS ORIGINALES ==========

  /// Obtiene la configuración de las 8 listas por defecto originales
  List<OriginalDefaultListConfig> _getOriginalDefaultListsConfig() {
    return [
      OriginalDefaultListConfig(
        localId: 'quiero-ver',
        name: 'Quiero Ver',
        description: 'Películas que quiero ver próximamente',
        emoji: '🍿',
        colorHex: '#3B82F6',
        defaultType: 'want_to_watch',
      ),
      OriginalDefaultListConfig(
        localId: 'para-el-fin-de-semana',
        name: 'Para el Fin de Semana',
        description: 'Películas perfectas para relajarse',
        emoji: '🛋️',
        colorHex: '#10B981',
        defaultType: 'weekend',
      ),
      OriginalDefaultListConfig(
        localId: 'noche-de-citas',
        name: 'Noche de Citas',
        description: 'Películas románticas para ver en pareja',
        emoji: '💕',
        colorHex: '#EC4899',
        defaultType: 'date_night',
      ),
      OriginalDefaultListConfig(
        localId: 'con-amigos',
        name: 'Con Amigos',
        description: 'Películas divertidas para ver en grupo',
        emoji: '👥',
        colorHex: '#F59E0B',
        defaultType: 'with_friends',
      ),
      OriginalDefaultListConfig(
        localId: 'clasicos-pendientes',
        name: 'Clásicos Pendientes',
        description: 'Películas clásicas que debo ver',
        emoji: '🎭',
        colorHex: '#8B5CF6',
        defaultType: 'classics',
      ),
      OriginalDefaultListConfig(
        localId: 'accion-y-aventura',
        name: 'Acción y Aventura',
        description: 'Para cuando quiero adrenalina',
        emoji: '💥',
        colorHex: '#EF4444',
        defaultType: 'action_adventure',
      ),
      OriginalDefaultListConfig(
        localId: 'documentales',
        name: 'Documentales',
        description: 'Para aprender algo nuevo',
        emoji: '📚',
        colorHex: '#14B8A6',
        defaultType: 'documentaries',
      ),
      OriginalDefaultListConfig(
        localId: 'cuando-llueve',
        name: 'Cuando Llueve',
        description: 'Películas perfectas para días lluviosos',
        emoji: '🌧️',
        colorHex: '#6366F1',
        defaultType: 'rainy_day',
      ),
    ];
  }

  // ========== MÉTODOS AUXILIARES ==========

  /// Obtiene listas locales
  Future<List<CustomList>> _getLocalLists() async {
    return await _localDataSource.getCustomLists();
  }

  /// Obtiene listas remotas de Supabase
  Future<List<CustomList>> _getRemoteLists(String userId) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .select()
          .filter('user_id', 'eq', userId);

      return (response as List)
          .map((json) => CustomList.fromJson(json as Map<String, dynamic>))
          .cast<CustomList>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Encuentra listas por defecto que necesitan ser creadas
  List<OriginalDefaultListConfig> _findDefaultListsToCreate(
    List<CustomList> localLists,
    List<CustomList> remoteLists,
  ) {
    final defaultConfigs = _getOriginalDefaultListsConfig();
    final remoteDefaultNames = remoteLists
        .where((list) => list.isDefault)
        .map((list) => list.name)
        .toSet();

    return defaultConfigs
        .where((config) => !remoteDefaultNames.contains(config.name))
        .toList();
  }

  /// Encuentra listas personalizadas que necesitan migración
  List<CustomList> _findCustomListsToMigrate(
    List<CustomList> localLists,
    List<CustomList> remoteLists,
  ) {
    final remoteIds = remoteLists.map((list) => list.id).toSet();
    return localLists
        .where((list) => !list.isDefault && !remoteIds.contains(list.id))
        .toList();
  }

  /// Encuentra elementos que necesitan migración
  Future<List<MigrationItem>> _findItemsToMigrate(
    List<CustomList> localLists,
    List<CustomList> remoteLists,
  ) async {
    final items = <MigrationItem>[];

    for (final localList in localLists) {
      final remoteList = remoteLists.firstWhere(
        (list) => list.id == localList.id || list.name == localList.name,
        orElse: () => CustomList(
          id: '',
          name: '',
          description: '',
          emoji: '',
          movieIds: [],
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
        ),
      );

      if (remoteList.id.isNotEmpty) {
        final missingMovies = localList.movieIds
            .where((movieId) => !remoteList.movieIds.contains(movieId))
            .toList();

        for (final movieId in missingMovies) {
          items.add(MigrationItem(
            listId: localList.id,
            movieId: movieId,
            type: MigrationItemType.movie,
          ));
        }
      }
    }

    return items;
  }

  /// Encuentra conflictos entre datos locales y remotos
  List<MigrationConflict> _findConflicts(
    List<CustomList> localLists,
    List<CustomList> remoteLists,
  ) {
    final conflicts = <MigrationConflict>[];

    for (final localList in localLists) {
      final existingList = remoteLists.firstWhere(
        (list) => list.name == localList.name,
        orElse: () => CustomList(
          id: '',
          name: '',
          description: '',
          emoji: '',
          movieIds: [],
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
        ),
      );

      if (existingList.id.isNotEmpty && existingList.id != localList.id) {
        conflicts.add(MigrationConflict(
          type: ConflictType.duplicateName,
          localList: localList,
          remoteList: existingList,
          description: 'Lista con nombre duplicado: ${localList.name}',
        ));
      }
    }

    return conflicts;
  }

  /// Calcula tiempo estimado de migración
  Duration _calculateEstimatedTime(List<CustomList> localLists) {
    final totalItems =
        localLists.fold(0, (sum, list) => sum + list.movieIds.length);
    final estimatedSeconds = (localLists.length * 2) + (totalItems * 0.5);
    return Duration(seconds: estimatedSeconds.round());
  }

  /// Busca lista por defecto existente en Supabase
  Future<CustomList?> _findExistingDefaultList(
      String userId, String name) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .select()
          .filter('user_id', 'eq', userId)
          .filter('user_id', 'eq', userId)
          .filter('user_id', 'eq', userId)
          .maybeSingle();

      return response != null ? CustomList.fromJson(response) : null;
    } catch (e) {
      return null;
    }
  }

  /// Crea lista por defecto en Supabase
  Future<CustomList> _createDefaultListInSupabase(
    String userId,
    OriginalDefaultListConfig config,
  ) async {
    const uuid = Uuid();
    final listId = uuid.v4();

    final listData = {
      'id': listId,
      'user_id': userId,
      'name': config.name,
      'description': config.description,
      'emoji': config.emoji,
      'color_hex': config.colorHex,
      'is_default': true,
      'default_type': config.defaultType,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _supabase.from('user_lists').insert(listData);

    return CustomList(
      id: listId,
      name: config.name,
      description: config.description,
      emoji: config.emoji,
      colorHex: config.colorHex,
      movieIds: [],
      isDefault: true,
      defaultType: config.defaultType,
      userId: userId,
      createdAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      syncStatus: 'synced',
    );
  }

  /// Migra películas locales a Supabase
  Future<void> _migrateLocalMoviesToSupabase(
    String localListId,
    String supabaseListId,
    String userId,
  ) async {
    try {
      final localLists = await _getLocalLists();
      final localList = localLists.firstWhere(
        (list) => list.id == localListId,
        orElse: () => CustomList(
          id: '',
          name: '',
          description: '',
          emoji: '',
          movieIds: [],
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
        ),
      );

      if (localList.id.isNotEmpty && localList.movieIds.isNotEmpty) {
        for (int i = 0; i < localList.movieIds.length; i++) {
          await _addMovieToSupabaseList(
            supabaseListId,
            localList.movieIds[i],
            i,
            userId,
          );
        }
      }
    } catch (e) {
      throw MigrationException('Error al migrar películas: $e');
    }
  }

  /// Agrega película a lista en Supabase
  Future<void> _addMovieToSupabaseList(
    String listId,
    int movieId,
    int position,
    String userId,
  ) async {
    const uuid = Uuid();
    final itemId = uuid.v4();

    final itemData = {
      'id': itemId,
      'list_id': listId,
      'movie_id': movieId,
      'position': position,
      'added_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _supabase.from('user_list_items').insert(itemData);
  }

  /// Obtiene listas personalizadas locales
  Future<List<CustomList>> _getLocalCustomLists() async {
    final allLists = await _getLocalLists();
    return allLists.where((list) => !list.isDefault).toList();
  }

  /// Verifica si lista existe en Supabase
  Future<bool> _existsInSupabase(String listId, String userId) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .select('id')
          .filter('user_id', 'eq', userId)
          .filter('user_id', 'eq', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Crea lista en Supabase
  Future<void> _createListInSupabase(String userId, CustomList list) async {
    final listData = {
      'id': list.id,
      'user_id': userId,
      'name': list.name,
      'description': list.description,
      'emoji': list.emoji,
      'color_hex': list.colorHex,
      'is_default': list.isDefault,
      'default_type': list.defaultType,
      'created_at': list.createdAt.toIso8601String(),
      'updated_at': list.lastModifiedAt.toIso8601String(),
    };

    await _supabase.from('user_lists').insert(listData);
  }

  /// Migra elementos de lista
  Future<void> _migrateListItems(CustomList list, String userId) async {
    for (int i = 0; i < list.movieIds.length; i++) {
      await _addMovieToSupabaseList(
        list.id,
        list.movieIds[i],
        i,
        userId,
      );
    }
  }

  // ========== BACKUP Y ROLLBACK ==========

  /// Crea backup de datos antes de migración
  Future<void> _createMigrationBackup() async {
    try {
      final localLists = await _getLocalLists();
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'lists': localLists.map((list) => list.toJson()).toList(),
      };

      await _prefs.setString(_migrationBackupKey, json.encode(backupData));
    } catch (e) {
      throw MigrationException('Error al crear backup: $e');
    }
  }

  /// Revierte migración en caso de error
  Future<void> _rollbackMigration() async {
    try {
      final backupJson = _prefs.getString(_migrationBackupKey);
      if (backupJson != null) {
        final backupData = json.decode(backupJson);
        // Aquí se implementaría la lógica de rollback
        // Por ahora solo limpiamos las marcas de migración
        await _prefs.remove(_migrationCompletedKey);
        await _prefs.remove(_localToSupabaseMapKey);
      }
    } catch (e) {
      throw MigrationException('Error en rollback: $e');
    }
  }

  /// Guarda mapeo de IDs locales a Supabase
  Future<void> _saveIdMapping(Map<String, String> mapping) async {
    await _prefs.setString(_localToSupabaseMapKey, json.encode(mapping));
  }

  /// Obtiene mapeo de IDs
  Map<String, String> getIdMapping() {
    final mappingJson = _prefs.getString(_localToSupabaseMapKey);
    if (mappingJson != null) {
      return Map<String, String>.from(json.decode(mappingJson));
    }
    return {};
  }

  /// Marca migración como completada
  Future<void> markMigrationCompleted() async {
    await _prefs.setBool(_migrationCompletedKey, true);
    await _prefs.setInt(_migrationVersionKey, _currentMigrationVersion);
  }
}

// ========== CLASES DE DATOS ==========

class MigrationPlan {
  MigrationPlan({
    required this.userId,
    required this.defaultListsToCreate,
    required this.customListsToMigrate,
    required this.itemsToMigrate,
    required this.conflictsToResolve,
    required this.totalEstimatedTime,
  });
  final String userId;
  final List<OriginalDefaultListConfig> defaultListsToCreate;
  final List<CustomList> customListsToMigrate;
  final List<MigrationItem> itemsToMigrate;
  final List<MigrationConflict> conflictsToResolve;
  final Duration totalEstimatedTime;

  bool get hasWork =>
      defaultListsToCreate.isNotEmpty ||
      customListsToMigrate.isNotEmpty ||
      itemsToMigrate.isNotEmpty;

  bool get hasConflicts => conflictsToResolve.isNotEmpty;
}

class OriginalDefaultListConfig {
  OriginalDefaultListConfig({
    required this.localId,
    required this.name,
    required this.description,
    required this.emoji,
    required this.colorHex,
    required this.defaultType,
  });
  final String localId;
  final String name;
  final String description;
  final String emoji;
  final String colorHex;
  final String defaultType;
}

class MigrationItem {
  MigrationItem({
    required this.listId,
    required this.movieId,
    required this.type,
  });
  final String listId;
  final int movieId;
  final MigrationItemType type;
}

enum MigrationItemType { movie, metadata }

class MigrationConflict {
  MigrationConflict({
    required this.type,
    required this.localList,
    required this.remoteList,
    required this.description,
  });
  final ConflictType type;
  final CustomList localList;
  final CustomList remoteList;
  final String description;
}

enum ConflictType { duplicateName, duplicateId, dataConflict }

class MigrationException implements Exception {
  MigrationException(this.message);
  final String message;

  @override
  String toString() => 'MigrationException: $message';
}
