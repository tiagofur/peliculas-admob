import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/custom_list.dart';
import '../infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import 'id_mapping_service.dart';

/// Servicio de rollback para revertir migraciones fallidas
/// Restaura el estado anterior y limpia datos parciales
class MigrationRollbackService {
  final SharedPreferences _prefs;
  final SupabaseClient _supabase;
  final CustomListsSharedPreferencesDatasource _localDataSource;
  final IdMappingService _idMappingService;
  
  // Claves para SharedPreferences
  static const String _rollbackDataKey = 'migration_rollback_data';
  static const String _rollbackPointsKey = 'migration_rollback_points';
  static const String _rollbackHistoryKey = 'migration_rollback_history';
  
  MigrationRollbackService(
    this._prefs,
    this._supabase,
    this._localDataSource,
    this._idMappingService,
  );
  
  // ========== CREACIÓN DE PUNTOS DE ROLLBACK ==========
  
  /// Crea un punto de rollback antes de iniciar la migración
  Future<String> createRollbackPoint(String userId, String description) async {
    try {
      final rollbackId = 'rollback_${DateTime.now().millisecondsSinceEpoch}';
      
      // Capturar estado actual
      final rollbackData = await _captureCurrentState(userId);
      
      final rollbackPoint = RollbackPoint(
        id: rollbackId,
        userId: userId,
        description: description,
        timestamp: DateTime.now(),
        data: rollbackData,
      );
      
      // Guardar punto de rollback
      await _saveRollbackPoint(rollbackPoint);
      
      // Agregar a historial
      await _addToRollbackHistory(rollbackPoint);
      
      return rollbackId;
    } catch (e) {
      throw RollbackException('Error al crear punto de rollback: $e');
    }
  }
  
  /// Captura el estado actual del sistema
  Future<RollbackData> _captureCurrentState(String userId) async {
    // Capturar datos locales
    final localLists = await _localDataSource.getCustomLists();
    final idMappings = _idMappingService.exportMappings();
    
    // Capturar datos remotos
    final remoteLists = await _getRemoteLists(userId);
    final remoteItems = await _getRemoteItems(userId);
    
    // Capturar configuraciones
    final migrationFlags = _getMigrationFlags();
    
    return RollbackData(
      localLists: localLists.map((list) => list.toJson()).toList(),
      remoteLists: remoteLists,
      remoteItems: remoteItems,
      idMappings: idMappings,
      migrationFlags: migrationFlags,
      timestamp: DateTime.now(),
    );
  }
  
  // ========== EJECUCIÓN DE ROLLBACK ==========
  
  /// Ejecuta rollback completo a un punto específico
  Future<RollbackResult> executeRollback(String rollbackId, String userId) async {
    try {
      final rollbackPoint = await _getRollbackPoint(rollbackId);
      if (rollbackPoint == null) {
        throw RollbackException('Punto de rollback no encontrado: $rollbackId');
      }
      
      final result = RollbackResult(rollbackId: rollbackId);
      
      // 1. Limpiar datos remotos creados durante la migración
      await _cleanupRemoteData(rollbackPoint, userId, result);
      
      // 2. Restaurar datos locales
      await _restoreLocalData(rollbackPoint, result);
      
      // 3. Restaurar mapeos de IDs
      await _restoreIdMappings(rollbackPoint, result);
      
      // 4. Restaurar flags de migración
      await _restoreMigrationFlags(rollbackPoint, result);
      
      // 5. Limpiar datos de rollback
      await _cleanupRollbackData(rollbackId);
      
      result.markAsSuccessful('Rollback ejecutado exitosamente');
      return result;
      
    } catch (e) {
      throw RollbackException('Error durante rollback: $e');
    }
  }
  
  /// Ejecuta rollback automático en caso de error crítico
  Future<RollbackResult> executeAutoRollback(String userId) async {
    try {
      // Buscar el punto de rollback más reciente
      final recentRollbackId = await _getMostRecentRollbackId(userId);
      if (recentRollbackId == null) {
        throw RollbackException('No hay puntos de rollback disponibles');
      }
      
      return await executeRollback(recentRollbackId, userId);
    } catch (e) {
      throw RollbackException('Error en rollback automático: $e');
    }
  }
  
  // ========== LIMPIEZA DE DATOS REMOTOS ==========
  
  /// Limpia datos remotos creados durante la migración fallida
  Future<void> _cleanupRemoteData(
    RollbackPoint rollbackPoint,
    String userId,
    RollbackResult result,
  ) async {
    try {
      // Obtener listas remotas actuales
      final currentRemoteLists = await _getRemoteLists(userId);
      final originalRemoteLists = rollbackPoint.data.remoteLists;
      
      // Identificar listas creadas durante la migración
      final originalIds = originalRemoteLists.map((list) => list['id'] as String).toSet();
      final listsToDelete = currentRemoteLists
          .where((list) => !originalIds.contains(list['id']))
          .toList();
      
      // Eliminar listas creadas durante la migración
      for (final list in listsToDelete) {
        await _deleteRemoteList(list['id'] as String, userId);
        result.addAction('Lista remota eliminada: ${list['name']}');
      }
      
      // Restaurar listas modificadas
      for (final originalList in originalRemoteLists) {
        final listId = originalList['id'] as String;
        final currentList = currentRemoteLists.firstWhere(
          (list) => list['id'] == listId,
          orElse: () => <String, dynamic>{},
        );
        
        if (currentList.isNotEmpty) {
          await _restoreRemoteList(originalList, userId);
          result.addAction('Lista remota restaurada: ${originalList['name']}');
        }
      }
      
    } catch (e) {
      result.addError('Error al limpiar datos remotos: $e');
    }
  }
  
  /// Elimina una lista remota
  Future<void> _deleteRemoteList(String listId, String userId) async {
    // Eliminar elementos de la lista
    await _supabase
        .from('user_list_items')
        .delete()
        .filter("user_id", "eq", userId);
    
    // Eliminar la lista
    await _supabase
        .from('user_lists')
        .delete()
        .filter("user_id", "eq", userId)
        .filter("user_id", "eq", userId);
  }
  
  /// Restaura una lista remota a su estado original
  Future<void> _restoreRemoteList(Map<String, dynamic> originalList, String userId) async {
    final listId = originalList['id'] as String;
    
    // Actualizar metadatos de la lista
    await _supabase
        .from('user_lists')
        .update({
          'name': originalList['name'],
          'description': originalList['description'],
          'emoji': originalList['emoji'],
          'color_hex': originalList['color_hex'],
          'is_default': originalList['is_default'],
          'default_type': originalList['default_type'],
          'updated_at': DateTime.now().toIso8601String(),
        })
        .filter("user_id", "eq", userId)
        .filter("user_id", "eq", userId);
    
    // Restaurar elementos originales
    await _restoreRemoteListItems(listId, originalList, userId);
  }
  
  /// Restaura elementos de una lista remota
  Future<void> _restoreRemoteListItems(String listId, Map<String, dynamic> originalList, String userId) async {
    // Eliminar elementos actuales
    await _supabase
        .from('user_list_items')
        .delete()
        .filter("user_id", "eq", userId);
    
    // Restaurar elementos originales si existen
    final originalItems = originalList['items'] as List<dynamic>? ?? [];
    for (final item in originalItems) {
      await _supabase.from('user_list_items').insert(item);
    }
  }
  
  // ========== RESTAURACIÓN DE DATOS LOCALES ==========
  
  /// Restaura datos locales al estado anterior
  Future<void> _restoreLocalData(RollbackPoint rollbackPoint, RollbackResult result) async {
    try {
      final originalLists = rollbackPoint.data.localLists
          .map((json) => CustomList.fromJson(json))
          .toList();
      
      // Restaurar listas locales
      await _localDataSource.saveCustomLists(originalLists);
      
      result.addAction('Datos locales restaurados: ${originalLists.length} listas');
    } catch (e) {
      result.addError('Error al restaurar datos locales: $e');
    }
  }
  
  /// Restaura mapeos de IDs
  Future<void> _restoreIdMappings(RollbackPoint rollbackPoint, RollbackResult result) async {
    try {
      // Limpiar mapeos actuales
      await _idMappingService.clearAllMappings();
      
      // Restaurar mapeos originales
      final originalMappings = rollbackPoint.data.idMappings;
      if (originalMappings['local_to_supabase'] != null) {
        await _idMappingService.importMappings(
          Map<String, String>.from(originalMappings['local_to_supabase']),
        );
      }
      
      result.addAction('Mapeos de IDs restaurados');
    } catch (e) {
      result.addError('Error al restaurar mapeos de IDs: $e');
    }
  }
  
  /// Restaura flags de migración
  Future<void> _restoreMigrationFlags(RollbackPoint rollbackPoint, RollbackResult result) async {
    try {
      final originalFlags = rollbackPoint.data.migrationFlags;
      
      for (final entry in originalFlags.entries) {
        if (entry.value is bool) {
          await _prefs.setBool(entry.key, entry.value);
        } else if (entry.value is int) {
          await _prefs.setInt(entry.key, entry.value);
        } else if (entry.value is String) {
          await _prefs.setString(entry.key, entry.value);
        }
      }
      
      result.addAction('Flags de migración restaurados');
    } catch (e) {
      result.addError('Error al restaurar flags de migración: $e');
    }
  }
  
  // ========== GESTIÓN DE PUNTOS DE ROLLBACK ==========
  
  /// Guarda un punto de rollback
  Future<void> _saveRollbackPoint(RollbackPoint rollbackPoint) async {
    final rollbackPoints = await _getRollbackPoints();
    rollbackPoints[rollbackPoint.id] = rollbackPoint.toJson();
    
    await _prefs.setString(_rollbackPointsKey, jsonEncode(rollbackPoints));
  }
  
  /// Obtiene un punto de rollback específico
  Future<RollbackPoint?> _getRollbackPoint(String rollbackId) async {
    final rollbackPoints = await _getRollbackPoints();
    final pointData = rollbackPoints[rollbackId];
    
    if (pointData != null) {
      return RollbackPoint.fromJson(pointData);
    }
    
    return null;
  }
  
  /// Obtiene todos los puntos de rollback
  Future<Map<String, dynamic>> _getRollbackPoints() async {
    final json = _prefs.getString(_rollbackPointsKey);
    if (json != null) {
      return Map<String, dynamic>.from(jsonDecode(json));
    }
    return {};
  }
  
  /// Obtiene el ID del rollback más reciente para un usuario
  Future<String?> _getMostRecentRollbackId(String userId) async {
    final rollbackPoints = await _getRollbackPoints();
    
    RollbackPoint? mostRecent;
    for (final pointData in rollbackPoints.values) {
      final point = RollbackPoint.fromJson(pointData);
      if (point.userId == userId) {
        if (mostRecent == null || point.timestamp.isAfter(mostRecent.timestamp)) {
          mostRecent = point;
        }
      }
    }
    
    return mostRecent?.id;
  }
  
  /// Limpia datos de rollback después de uso exitoso
  Future<void> _cleanupRollbackData(String rollbackId) async {
    final rollbackPoints = await _getRollbackPoints();
    rollbackPoints.remove(rollbackId);
    
    await _prefs.setString(_rollbackPointsKey, jsonEncode(rollbackPoints));
  }
  
  /// Agrega punto al historial de rollbacks
  Future<void> _addToRollbackHistory(RollbackPoint rollbackPoint) async {
    final history = await _getRollbackHistory();
    history.add({
      'id': rollbackPoint.id,
      'userId': rollbackPoint.userId,
      'description': rollbackPoint.description,
      'timestamp': rollbackPoint.timestamp.toIso8601String(),
    });
    
    // Mantener solo los últimos 10 registros
    if (history.length > 10) {
      history.removeRange(0, history.length - 10);
    }
    
    await _prefs.setString(_rollbackHistoryKey, jsonEncode(history));
  }
  
  /// Obtiene historial de rollbacks
  Future<List<dynamic>> _getRollbackHistory() async {
    final json = _prefs.getString(_rollbackHistoryKey);
    if (json != null) {
      return List<dynamic>.from(jsonDecode(json));
    }
    return [];
  }
  
  // ========== MÉTODOS AUXILIARES ==========
  
  /// Obtiene listas remotas
  Future<List<Map<String, dynamic>>> _getRemoteLists(String userId) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .select()
          .filter("user_id", "eq", userId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
  
  /// Obtiene elementos remotos
  Future<List<Map<String, dynamic>>> _getRemoteItems(String userId) async {
    try {
      final response = await _supabase
          .from('user_list_items')
          .select('*, user_lists!inner(user_id)')
          .filter("user_id", "eq", userId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
  
  /// Obtiene flags de migración actuales
  Map<String, dynamic> _getMigrationFlags() {
    final flags = <String, dynamic>{};
    
    // Flags relacionados con migración
    final migrationKeys = [
      'lists_migration_completed',
      'lists_migration_version',
      'local_to_supabase_id_map',
      'migration_backup_data',
    ];
    
    for (final key in migrationKeys) {
      final value = _prefs.get(key);
      if (value != null) {
        flags[key] = value;
      }
    }
    
    return flags;
  }
  
  // ========== INFORMACIÓN Y ESTADÍSTICAS ==========
  
  /// Obtiene información sobre rollbacks disponibles
  Future<List<RollbackInfo>> getAvailableRollbacks(String userId) async {
    final rollbackPoints = await _getRollbackPoints();
    final rollbacks = <RollbackInfo>[];
    
    for (final pointData in rollbackPoints.values) {
      final point = RollbackPoint.fromJson(pointData);
      if (point.userId == userId) {
        rollbacks.add(RollbackInfo(
          id: point.id,
          description: point.description,
          timestamp: point.timestamp,
          dataSize: _calculateDataSize(point.data),
        ));
      }
    }
    
    // Ordenar por timestamp descendente
    rollbacks.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return rollbacks;
  }
  
  /// Calcula el tamaño aproximado de los datos de rollback
  int _calculateDataSize(RollbackData data) {
    final json = jsonEncode(data.toJson());
    return json.length;
  }
  
  /// Limpia rollbacks antiguos
  Future<void> cleanupOldRollbacks({Duration maxAge = const Duration(days: 7)}) async {
    final rollbackPoints = await _getRollbackPoints();
    final cutoffTime = DateTime.now().subtract(maxAge);
    final toRemove = <String>[];
    
    for (final entry in rollbackPoints.entries) {
      final point = RollbackPoint.fromJson(entry.value);
      if (point.timestamp.isBefore(cutoffTime)) {
        toRemove.add(entry.key);
      }
    }
    
    for (final id in toRemove) {
      rollbackPoints.remove(id);
    }
    
    await _prefs.setString(_rollbackPointsKey, jsonEncode(rollbackPoints));
  }
}

// ========== CLASES DE DATOS ==========

class RollbackPoint {
  final String id;
  final String userId;
  final String description;
  final DateTime timestamp;
  final RollbackData data;
  
  RollbackPoint({
    required this.id,
    required this.userId,
    required this.description,
    required this.timestamp,
    required this.data,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'data': data.toJson(),
    };
  }
  
  factory RollbackPoint.fromJson(Map<String, dynamic> json) {
    return RollbackPoint(
      id: json['id'],
      userId: json['userId'],
      description: json['description'],
      timestamp: DateTime.parse(json['timestamp']),
      data: RollbackData.fromJson(json['data']),
    );
  }
}

class RollbackData {
  final List<Map<String, dynamic>> localLists;
  final List<Map<String, dynamic>> remoteLists;
  final List<Map<String, dynamic>> remoteItems;
  final Map<String, dynamic> idMappings;
  final Map<String, dynamic> migrationFlags;
  final DateTime timestamp;
  
  RollbackData({
    required this.localLists,
    required this.remoteLists,
    required this.remoteItems,
    required this.idMappings,
    required this.migrationFlags,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'localLists': localLists,
      'remoteLists': remoteLists,
      'remoteItems': remoteItems,
      'idMappings': idMappings,
      'migrationFlags': migrationFlags,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  factory RollbackData.fromJson(Map<String, dynamic> json) {
    return RollbackData(
      localLists: List<Map<String, dynamic>>.from(json['localLists']),
      remoteLists: List<Map<String, dynamic>>.from(json['remoteLists']),
      remoteItems: List<Map<String, dynamic>>.from(json['remoteItems']),
      idMappings: Map<String, dynamic>.from(json['idMappings']),
      migrationFlags: Map<String, dynamic>.from(json['migrationFlags']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class RollbackResult {
  final String rollbackId;
  final List<String> _actions = [];
  final List<String> _errors = [];
  bool _isSuccessful = false;
  String? _message;
  
  RollbackResult({required this.rollbackId});
  
  void addAction(String action) => _actions.add(action);
  void addError(String error) => _errors.add(error);
  void markAsSuccessful(String message) {
    _isSuccessful = true;
    _message = message;
  }
  
  bool get isSuccessful => _isSuccessful && _errors.isEmpty;
  bool get hasErrors => _errors.isNotEmpty;
  List<String> get actions => List.unmodifiable(_actions);
  List<String> get errors => List.unmodifiable(_errors);
  String? get message => _message;
  
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('Rollback $rollbackId:');
    buffer.writeln('Estado: ${isSuccessful ? "Exitoso" : "Con errores"}');
    
    if (_message != null) {
      buffer.writeln('Mensaje: $_message');
    }
    
    if (_actions.isNotEmpty) {
      buffer.writeln('\nAcciones realizadas:');
      for (final action in _actions) {
        buffer.writeln('- $action');
      }
    }
    
    if (_errors.isNotEmpty) {
      buffer.writeln('\nErrores encontrados:');
      for (final error in _errors) {
        buffer.writeln('- $error');
      }
    }
    
    return buffer.toString();
  }
}

class RollbackInfo {
  final String id;
  final String description;
  final DateTime timestamp;
  final int dataSize;
  
  RollbackInfo({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.dataSize,
  });
}

class RollbackException implements Exception {
  final String message;
  RollbackException(this.message);
  
  @override
  String toString() => 'RollbackException: $message';
}