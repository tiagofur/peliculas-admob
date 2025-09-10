import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/custom_list.dart';
import '../domain/entities/list_item.dart';
import '../domain/repositories/i_custom_lists_repository.dart';

/// Servicio especializado para sincronización de listas
/// Maneja conflictos, operaciones offline y estrategias de sincronización
class ListSyncService {
  final ICustomListsRepository _repository;
  final SharedPreferences _prefs;
  final Connectivity _connectivity;
  
  // Claves para SharedPreferences
  static const String _conflictQueueKey = 'conflict_queue';
  static const String _syncConfigKey = 'sync_config';
  static const String _offlineChangesKey = 'offline_changes';
  
  // Configuración de sincronización
  late SyncConfig _syncConfig;
  
  // Streams para notificaciones
  final StreamController<SyncStatus> _syncStatusController = StreamController.broadcast();
  final StreamController<List<ConflictInfo>> _conflictsController = StreamController.broadcast();
  
  ListSyncService(
    this._repository,
    this._prefs,
    this._connectivity,
  ) {
    _loadSyncConfig();
    _startConnectivityMonitoring();
  }
  
  // ========== STREAMS PÚBLICOS ==========
  
  /// Stream del estado de sincronización
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  
  /// Stream de conflictos detectados
  Stream<List<ConflictInfo>> get conflictsStream => _conflictsController.stream;
  
  // ========== OPERACIONES DE SINCRONIZACIÓN ==========
  
  /// Inicia sincronización automática
  Future<void> startAutoSync() async {
    if (!_syncConfig.autoSyncEnabled) return;
    
    _emitSyncStatus(SyncStatus.syncing);
    
    try {
      if (await _repository.hasInternetConnection()) {
        await _performFullSync();
        _emitSyncStatus(SyncStatus.synced);
      } else {
        _emitSyncStatus(SyncStatus.offline);
      }
    } catch (e) {
      _emitSyncStatus(SyncStatus.error);
      print('Error en sincronización automática: $e');
    }
  }
  
  /// Fuerza una sincronización manual
  Future<SyncResult> forcSync() async {
    _emitSyncStatus(SyncStatus.syncing);
    
    try {
      if (!await _repository.hasInternetConnection()) {
        _emitSyncStatus(SyncStatus.offline);
        return SyncResult(
          success: false,
          message: 'Sin conexión a internet',
          conflictsResolved: 0,
          itemsSynced: 0,
        );
      }
      
      final result = await _performFullSync();
      _emitSyncStatus(SyncStatus.synced);
      return result;
    } catch (e) {
      _emitSyncStatus(SyncStatus.error);
      return SyncResult(
        success: false,
        message: 'Error durante la sincronización: $e',
        conflictsResolved: 0,
        itemsSynced: 0,
      );
    }
  }
  
  /// Realiza sincronización completa
  Future<SyncResult> _performFullSync() async {
    int itemsSynced = 0;
    int conflictsResolved = 0;
    
    try {
      // 1. Sincronizar operaciones pendientes
      await _repository.syncLists();
      
      // 2. Detectar y resolver conflictos
      final conflicts = await _detectConflicts();
      if (conflicts.isNotEmpty) {
        conflictsResolved = await _resolveConflicts(conflicts);
      }
      
      // 3. Sincronizar cambios offline
      itemsSynced = await _syncOfflineChanges();
      
      // 4. Actualizar timestamp de última sincronización
      await _updateLastSyncTimestamp();
      
      return SyncResult(
        success: true,
        message: 'Sincronización completada exitosamente',
        conflictsResolved: conflictsResolved,
        itemsSynced: itemsSynced,
      );
    } catch (e) {
      throw Exception('Error en sincronización completa: $e');
    }
  }
  
  // ========== MANEJO DE CONFLICTOS ==========
  
  /// Detecta conflictos entre datos locales y remotos
  Future<List<ConflictInfo>> _detectConflicts() async {
    final conflicts = <ConflictInfo>[];
    
    try {
      final localLists = await _repository.getLocalLists();
      final remoteLists = await _repository.getUserLists();
      
      for (final localList in localLists) {
        final remoteList = remoteLists.firstWhere(
          (r) => r.id == localList.id,
          orElse: () => throw StateError('No encontrado'),
        );
        
        if (remoteList != null && _hasConflict(localList, remoteList)) {
          conflicts.add(ConflictInfo(
            listId: localList.id,
            localList: localList,
            remoteList: remoteList,
            conflictType: _determineConflictType(localList, remoteList),
            detectedAt: DateTime.now(),
          ));
        }
      }
      
      if (conflicts.isNotEmpty) {
        _conflictsController.add(conflicts);
        await _saveConflictsToQueue(conflicts);
      }
      
      return conflicts;
    } catch (e) {
      print('Error al detectar conflictos: $e');
      return [];
    }
  }
  
  /// Resuelve conflictos automáticamente según la estrategia configurada
  Future<int> _resolveConflicts(List<ConflictInfo> conflicts) async {
    int resolved = 0;
    
    for (final conflict in conflicts) {
      try {
        final resolvedList = await _resolveConflict(conflict);
        if (resolvedList != null) {
          await _repository.saveListLocally(resolvedList);
          resolved++;
        }
      } catch (e) {
        print('Error al resolver conflicto ${conflict.listId}: $e');
      }
    }
    
    await _clearResolvedConflicts(conflicts.take(resolved).toList());
    return resolved;
  }
  
  /// Resuelve un conflicto individual
  Future<CustomList?> _resolveConflict(ConflictInfo conflict) async {
    switch (_syncConfig.conflictResolutionStrategy) {
      case ConflictResolutionStrategy.localWins:
        return await _repository.updateList(conflict.localList);
      
      case ConflictResolutionStrategy.remoteWins:
        return conflict.remoteList;
      
      case ConflictResolutionStrategy.lastModifiedWins:
        return await _repository.resolveConflict(
          conflict.localList,
          conflict.remoteList,
        );
      
      case ConflictResolutionStrategy.manual:
        // Guardar para resolución manual
        await _saveConflictForManualResolution(conflict);
        return null;
      
      case ConflictResolutionStrategy.merge:
        return await _mergeConflictedLists(conflict.localList, conflict.remoteList);
    }
  }
  
  /// Fusiona dos listas en conflicto
  Future<CustomList> _mergeConflictedLists(CustomList local, CustomList remote) async {
    // Estrategia de fusión: combinar elementos únicos, usar datos más recientes
    final mergedMovieIds = <int>{...local.movieIds, ...remote.movieIds}.toList();
    
    final mergedList = local.lastModifiedAt.isAfter(remote.lastModifiedAt)
        ? local.copyWith(movieIds: mergedMovieIds)
        : remote.copyWith(movieIds: mergedMovieIds);
    
    return mergedList;
  }
  
  // ========== OPERACIONES OFFLINE ==========
  
  /// Registra un cambio offline para sincronización posterior
  Future<void> recordOfflineChange(OfflineChange change) async {
    try {
      final offlineChanges = await _getOfflineChanges();
      offlineChanges.add(change);
      await _saveOfflineChanges(offlineChanges);
    } catch (e) {
      print('Error al registrar cambio offline: $e');
    }
  }
  
  /// Sincroniza todos los cambios offline pendientes
  Future<int> _syncOfflineChanges() async {
    final offlineChanges = await _getOfflineChanges();
    int synced = 0;
    
    for (final change in offlineChanges) {
      try {
        await _applyOfflineChange(change);
        synced++;
      } catch (e) {
        print('Error al aplicar cambio offline ${change.id}: $e');
      }
    }
    
    // Limpiar cambios sincronizados
    await _clearOfflineChanges();
    return synced;
  }
  
  /// Aplica un cambio offline específico
  Future<void> _applyOfflineChange(OfflineChange change) async {
    switch (change.type) {
      case OfflineChangeType.createList:
        await _repository.createList(CustomList.fromJson(change.data));
        break;
      case OfflineChangeType.updateList:
        await _repository.updateList(CustomList.fromJson(change.data));
        break;
      case OfflineChangeType.deleteList:
        await _repository.deleteList(change.data['id']);
        break;
      case OfflineChangeType.addMovie:
        await _repository.addMovieToList(
          change.data['listId'],
          change.data['movieId'],
          position: change.data['position'],
        );
        break;
      case OfflineChangeType.removeMovie:
        await _repository.removeMovieFromList(
          change.data['listId'],
          change.data['movieId'],
        );
        break;
    }
  }
  
  // ========== CONFIGURACIÓN ==========
  
  /// Actualiza la configuración de sincronización
  Future<void> updateSyncConfig(SyncConfig config) async {
    _syncConfig = config;
    await _saveSyncConfig();
  }
  
  /// Obtiene la configuración actual
  SyncConfig getSyncConfig() => _syncConfig;
  
  // ========== MÉTODOS PRIVADOS ==========
  
  void _loadSyncConfig() {
    final configJson = _prefs.getString(_syncConfigKey);
    if (configJson != null) {
      _syncConfig = SyncConfig.fromJson(json.decode(configJson));
    } else {
      _syncConfig = SyncConfig.defaultConfig();
    }
  }
  
  Future<void> _saveSyncConfig() async {
    await _prefs.setString(_syncConfigKey, json.encode(_syncConfig.toJson()));
  }
  
  void _startConnectivityMonitoring() {
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && _syncConfig.autoSyncEnabled) {
        startAutoSync();
      }
    });
  }
  
  void _emitSyncStatus(SyncStatus status) {
    _syncStatusController.add(status);
  }
  
  bool _hasConflict(CustomList local, CustomList remote) {
    return local.lastModifiedAt != remote.lastModifiedAt &&
           (local.name != remote.name ||
            local.description != remote.description ||
            !_listsEqual(local.movieIds, remote.movieIds));
  }
  
  bool _listsEqual(List<int> list1, List<int> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }
  
  ConflictType _determineConflictType(CustomList local, CustomList remote) {
    if (local.name != remote.name || local.description != remote.description) {
      return ConflictType.metadata;
    } else if (!_listsEqual(local.movieIds, remote.movieIds)) {
      return ConflictType.content;
    }
    return ConflictType.timestamp;
  }
  
  Future<void> _saveConflictsToQueue(List<ConflictInfo> conflicts) async {
    final conflictsJson = json.encode(conflicts.map((c) => c.toJson()).toList());
    await _prefs.setString(_conflictQueueKey, conflictsJson);
  }
  
  Future<void> _clearResolvedConflicts(List<ConflictInfo> resolved) async {
    // Implementar lógica para limpiar conflictos resueltos
  }
  
  Future<void> _saveConflictForManualResolution(ConflictInfo conflict) async {
    // Implementar lógica para guardar conflictos manuales
  }
  
  Future<List<OfflineChange>> _getOfflineChanges() async {
    final changesJson = _prefs.getString(_offlineChangesKey);
    if (changesJson == null) return [];
    
    final List<dynamic> changesData = json.decode(changesJson);
    return changesData.map((json) => OfflineChange.fromJson(json)).toList();
  }
  
  Future<void> _saveOfflineChanges(List<OfflineChange> changes) async {
    final changesJson = json.encode(changes.map((c) => c.toJson()).toList());
    await _prefs.setString(_offlineChangesKey, changesJson);
  }
  
  Future<void> _clearOfflineChanges() async {
    await _prefs.remove(_offlineChangesKey);
  }
  
  Future<void> _updateLastSyncTimestamp() async {
    await _prefs.setString('last_sync', DateTime.now().toIso8601String());
  }
  
  void dispose() {
    _syncStatusController.close();
    _conflictsController.close();
  }
}

// ========== CLASES DE DATOS ==========

class SyncConfig {
  final bool autoSyncEnabled;
  final Duration syncInterval;
  final ConflictResolutionStrategy conflictResolutionStrategy;
  final bool syncOnlyOnWifi;
  final int maxRetries;
  
  SyncConfig({
    required this.autoSyncEnabled,
    required this.syncInterval,
    required this.conflictResolutionStrategy,
    required this.syncOnlyOnWifi,
    required this.maxRetries,
  });
  
  factory SyncConfig.defaultConfig() {
    return SyncConfig(
      autoSyncEnabled: true,
      syncInterval: Duration(minutes: 5),
      conflictResolutionStrategy: ConflictResolutionStrategy.lastModifiedWins,
      syncOnlyOnWifi: false,
      maxRetries: 3,
    );
  }
  
  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      autoSyncEnabled: json['autoSyncEnabled'] ?? true,
      syncInterval: Duration(minutes: json['syncIntervalMinutes'] ?? 5),
      conflictResolutionStrategy: ConflictResolutionStrategy.values[
          json['conflictResolutionStrategy'] ?? 2],
      syncOnlyOnWifi: json['syncOnlyOnWifi'] ?? false,
      maxRetries: json['maxRetries'] ?? 3,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'autoSyncEnabled': autoSyncEnabled,
      'syncIntervalMinutes': syncInterval.inMinutes,
      'conflictResolutionStrategy': conflictResolutionStrategy.index,
      'syncOnlyOnWifi': syncOnlyOnWifi,
      'maxRetries': maxRetries,
    };
  }
}

class ConflictInfo {
  final String listId;
  final CustomList localList;
  final CustomList remoteList;
  final ConflictType conflictType;
  final DateTime detectedAt;
  
  ConflictInfo({
    required this.listId,
    required this.localList,
    required this.remoteList,
    required this.conflictType,
    required this.detectedAt,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'listId': listId,
      'localList': localList.toJson(),
      'remoteList': remoteList.toJson(),
      'conflictType': conflictType.index,
      'detectedAt': detectedAt.toIso8601String(),
    };
  }
}

class OfflineChange {
  final String id;
  final OfflineChangeType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  
  OfflineChange({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
  });
  
  factory OfflineChange.fromJson(Map<String, dynamic> json) {
    return OfflineChange(
      id: json['id'],
      type: OfflineChangeType.values[json['type']],
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int conflictsResolved;
  final int itemsSynced;
  
  SyncResult({
    required this.success,
    required this.message,
    required this.conflictsResolved,
    required this.itemsSynced,
  });
}

// ========== ENUMS ==========

enum SyncStatus {
  idle,
  syncing,
  synced,
  offline,
  error,
}

enum ConflictResolutionStrategy {
  localWins,
  remoteWins,
  lastModifiedWins,
  manual,
  merge,
}

enum ConflictType {
  metadata,
  content,
  timestamp,
}

enum OfflineChangeType {
  createList,
  updateList,
  deleteList,
  addMovie,
  removeMovie,
}