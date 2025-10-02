import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/custom_list.dart';
import '../domain/repositories/i_custom_lists_repository.dart';
import '../infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';

/// Servicio de migración de listas personalizadas
/// Maneja la migración de datos locales a Supabase
///
/// REFACTORED: Ahora usa ICustomListsRepository en lugar de SupabaseClient directamente
/// para seguir Clean Architecture y facilitar testing
class ListsMigrationService {
  ListsMigrationService(
    this._prefs,
    this._localDataSource,
    this._repository,
  );
  final SharedPreferences _prefs;
  final CustomListsSharedPreferencesDatasource _localDataSource;
  final ICustomListsRepository _repository;

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
  /// REFACTORED: Usa repository en lugar de acceso directo
  Future<List<CustomList>> _getRemoteLists(String userId) async {
    try {
      return await _repository.getUserLists();
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

      // MIGRADO: Los items ahora están en list_items table
      // La migración de items se hace directamente desde SharedPreferences a Supabase
      if (remoteList.id.isNotEmpty) {
        // NOTE: La lógica de detección de items faltantes se maneja
        // en _migrateLocalMoviesToSupabase que lee desde local storage
        // No necesitamos acceder a movieIds aquí
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
  /// MIGRADO: Estima basado en cantidad de listas, no en items individuales
  Duration _calculateEstimatedTime(List<CustomList> localLists) {
    // Estimación conservadora: 5 segundos por lista
    // Los items se migran automáticamente desde local storage
    final estimatedSeconds = localLists.length * 5;
    return Duration(seconds: estimatedSeconds);
  }

  /// Busca lista por defecto existente en Supabase
  /// REFACTORED: Usa repository y filtra localmente
  Future<CustomList?> _findExistingDefaultList(
      String userId, String name) async {
    try {
      final defaultLists = await _repository.getDefaultLists();
      return defaultLists
              .firstWhere(
                (list) => list.name == name && list.isDefault,
                orElse: () => CustomList(
                  id: '',
                  name: '',
                  description: '',
                  emoji: '',
                  movieIds: [],
                  createdAt: DateTime.now(),
                  lastModifiedAt: DateTime.now(),
                ),
              )
              .id
              .isEmpty
          ? null
          : defaultLists.firstWhere((list) => list.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Crea lista por defecto en Supabase
  /// REFACTORED: Usa repository.createList() en lugar de insert directo
  Future<CustomList> _createDefaultListInSupabase(
    String userId,
    OriginalDefaultListConfig config,
  ) async {
    const uuid = Uuid();
    final listId = uuid.v4();

    final newList = CustomList(
      id: listId,
      name: config.name,
      description: config.description,
      emoji: config.emoji,
      colorHex: config.colorHex,
      movieIds: [], // Deprecated - items en list_items table
      isDefault: true,
      defaultType: config.defaultType,
      userId: userId,
      createdAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      syncStatus: 'synced',
    );

    return await _repository.createList(newList);
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

      // MIGRADO: Leer items desde local storage (SharedPreferences)
      // En lugar de usar el array movieIds deprecated
      if (localList.id.isNotEmpty) {
        final localMovieIds = await _getLocalListMovieIds(localListId);
        for (int i = 0; i < localMovieIds.length; i++) {
          await _addMovieToSupabaseList(
            supabaseListId,
            localMovieIds[i],
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
  /// REFACTORED: Usa repository.addMovieToList() en lugar de insert directo
  Future<void> _addMovieToSupabaseList(
    String listId,
    int movieId,
    int position,
    String userId,
  ) async {
    await _repository.addMovieToList(listId, movieId, position: position);
  }

  /// Obtiene listas personalizadas locales
  Future<List<CustomList>> _getLocalCustomLists() async {
    final allLists = await _getLocalLists();
    return allLists.where((list) => !list.isDefault).toList();
  }

  /// Verifica si lista existe en Supabase
  /// REFACTORED: Usa repository.getListById() con try-catch
  Future<bool> _existsInSupabase(String listId, String userId) async {
    try {
      final list = await _repository.getListById(listId);
      return list != null;
    } catch (e) {
      return false;
    }
  }

  /// Crea lista en Supabase
  /// REFACTORED: Usa repository.createList() en lugar de insert directo
  Future<void> _createListInSupabase(String userId, CustomList list) async {
    await _repository.createList(list);
  }

  /// Migra elementos de lista
  /// MIGRADO: Lee desde local storage en lugar del array deprecated
  Future<void> _migrateListItems(CustomList list, String userId) async {
    final localMovieIds = await _getLocalListMovieIds(list.id);
    for (int i = 0; i < localMovieIds.length; i++) {
      await _addMovieToSupabaseList(
        list.id,
        localMovieIds[i],
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
      await _prefs.setString(
          _migrationBackupKey,
          json.encode({
            'timestamp': DateTime.now().toIso8601String(),
            'lists': localLists.map((list) => list.toJson()).toList(),
          }));
    } catch (e) {
      throw MigrationException('Error al crear backup: $e');
    }
  }

  /// Revierte migración en caso de error
  Future<void> _rollbackMigration() async {
    try {
      final backupJson = _prefs.getString(_migrationBackupKey);
      if (backupJson != null) {
        // Aquí se implementaría la lógica de rollback usando json.decode(backupJson)
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

  /// Helper method to get movie IDs from local storage
  /// MIGRADO: Lee desde SharedPreferences en lugar del array deprecated
  Future<List<int>> _getLocalListMovieIds(String listId) async {
    try {
      final customLists = await _localDataSource.getCustomLists();
      final defaultLists = await _localDataSource.getDefaultLists();
      final localLists = [...customLists, ...defaultLists];
      final list = localLists.firstWhere(
        (l) => l.id == listId,
        orElse: () => throw Exception('Lista no encontrada: $listId'),
      );
      // Temporalmente usamos movieIds del objeto local durante migración
      // En producción esto leería de una estructura separada
      // ignore: deprecated_member_use_from_same_package
      return list.movieIds;
    } catch (e) {
      // Error leyendo IDs de películas locales: $e
      return [];
    }
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
