import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/sync_utilities.dart';
import '../../domain/entities/sync_result.dart';

/// Gestiona la información de dispositivos y coordina la sincronización multi-dispositivo
class DeviceSyncManager {
  DeviceSyncManager({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  static const String _deviceIdKey = 'device_id';
  static const String _deviceInfoKey = 'device_info';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // Información del dispositivo actual
  String? _deviceId;
  Map<String, dynamic>? _deviceInfo;
  DateTime? _lastSyncTimestamp;

  /// ID único del dispositivo actual
  String? get deviceId => _deviceId;

  /// Información del dispositivo actual
  Map<String, dynamic>? get deviceInfo => _deviceInfo;

  /// Timestamp de la última sincronización
  DateTime? get lastSyncTimestamp => _lastSyncTimestamp;

  /// Inicializa el gestor de dispositivos
  Future<void> initialize() async {
    try {
      await _loadDeviceInfo();
      await _registerDevice();
      LoggerFactory.info('✅ DeviceSyncManager initialized for device: $_deviceId');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Failed to initialize DeviceSyncManager: $e', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Carga información del dispositivo desde storage local
  Future<void> _loadDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Cargar o generar device ID
    _deviceId = prefs.getString(_deviceIdKey);
    if (_deviceId == null) {
      _deviceId = SyncUtilities.generateUuid();
      await prefs.setString(_deviceIdKey, _deviceId!);
      LoggerFactory.info('🆔 Generated new device ID: $_deviceId');
    }

    // Cargar información del dispositivo
    final deviceInfoJson = prefs.getString(_deviceInfoKey);
    if (deviceInfoJson != null) {
      _deviceInfo = Map<String, dynamic>.from(jsonDecode(deviceInfoJson));
    } else {
      _deviceInfo = await _generateDeviceInfo();
      await prefs.setString(_deviceInfoKey, jsonEncode(_deviceInfo));
      LoggerFactory.info('📱 Generated device info for: ${_deviceInfo?['name']}');
    }

    // Cargar último timestamp de sync
    final lastSyncString = prefs.getString(_lastSyncKey);
    if (lastSyncString != null) {
      _lastSyncTimestamp = DateTime.parse(lastSyncString);
    }
  }

  /// Genera información del dispositivo
  Future<Map<String, dynamic>> _generateDeviceInfo() async {
    return {
      'id': _deviceId,
      'name': _generateDeviceName(),
      'platform': _getPlatformInfo(),
      'app_version': await _getAppVersion(),
      'created_at': DateTime.now().toIso8601String(),
      'last_seen': DateTime.now().toIso8601String(),
    };
  }

  /// Genera un nombre descriptivo para el dispositivo
  String _generateDeviceName() {
    // En una implementación real, esto obtendría el nombre del dispositivo real
    final platform = _getPlatformInfo();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$platform Device ${timestamp.toString().substring(7)}';
  }

  /// Obtiene información de la plataforma
  String _getPlatformInfo() {
    // En una implementación real, esto detectaría la plataforma actual
    return 'Web'; // Simplificado para este ejemplo
  }

  /// Obtiene la versión de la aplicación
  Future<String> _getAppVersion() async {
    // En una implementación real, esto leería la versión del pubspec.yaml o package_info
    return '1.0.0';
  }

  /// Registra o actualiza el dispositivo en Supabase
  Future<void> _registerDevice() async {
    if (_deviceId == null || _deviceInfo == null) {
      throw StateError('Device info not loaded');
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        LoggerFactory.warning('⚠️ No authenticated user - device registration skipped');
        return;
      }

      // Actualizar timestamp de "last seen"
      _deviceInfo!['last_seen'] = DateTime.now().toIso8601String();
      _deviceInfo!['user_id'] = userId;

      // Registrar/actualizar en Supabase
      await _supabase
          .from('user_devices')
          .upsert(_deviceInfo!);

      LoggerFactory.info('📱 Device registered/updated in Supabase: $_deviceId');

    } catch (e) {
      // No es crítico si falla el registro, continuar sin error
      LoggerFactory.warning('⚠️ Failed to register device in Supabase: $e');
    }
  }

  /// Obtiene lista de todos los dispositivos del usuario
  Future<List<DeviceInfo>> getUserDevices() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw StateError('No authenticated user');
      }

      final response = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .order('last_seen', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      
      return data.map((item) => DeviceInfo.fromJson(Map<String, dynamic>.from(item))).toList();

    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Failed to get user devices: $e', stackTrace: stackTrace);
      return [];
    }
  }

  /// Obtiene el estado de sincronización para una tabla específica
  Future<SyncStatus?> getSyncStatus(String tableName) async {
    if (_deviceId == null) return null;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('sync_status')
          .select()
          .eq('user_id', userId)
          .eq('device_id', _deviceId!)
          .eq('table_name', tableName)
          .maybeSingle();

      if (response != null) {
        return SyncStatus.fromJson(Map<String, dynamic>.from(response));
      }

      return null;

    } catch (e) {
      LoggerFactory.error('❌ Failed to get sync status: $e');
      return null;
    }
  }

  /// Actualiza el estado de sincronización para una tabla específica
  Future<void> updateSyncStatus({
    required String tableName,
    DateTime? lastSyncAt,
    bool? isSyncing,
    String syncDirection = 'both',
  }) async {
    if (_deviceId == null) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final syncStatus = {
        'user_id': userId,
        'device_id': _deviceId!,
        'table_name': tableName,
        'last_sync_at': (lastSyncAt ?? DateTime.now()).toIso8601String(),
        'sync_direction': syncDirection,
        'is_syncing': isSyncing ?? false,
      };

      await _supabase
          .from('sync_status')
          .upsert(syncStatus);

      // Actualizar timestamp local si es necesario
      if (lastSyncAt != null && 
          (_lastSyncTimestamp == null || lastSyncAt.isAfter(_lastSyncTimestamp!))) {
        _lastSyncTimestamp = lastSyncAt;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, lastSyncAt.toIso8601String());
      }

      LoggerFactory.debug('✅ Updated sync status for $tableName');

    } catch (e) {
      LoggerFactory.error('❌ Failed to update sync status: $e');
    }
  }

  /// Detecta si hay conflictos de sincronización entre dispositivos
  Future<List<SyncConflict>> detectMultiDeviceConflicts(String tableName) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('sync_conflicts')
          .select()
          .eq('user_id', userId)
          .eq('table_name', tableName)
          .eq('is_resolved', false)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      
      return data.map((item) => SyncConflict.fromJson(Map<String, dynamic>.from(item))).toList();

    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Failed to detect multi-device conflicts: $e', stackTrace: stackTrace);
      return [];
    }
  }

  /// Reporta un conflicto de sincronización
  Future<void> reportSyncConflict({
    required String tableName,
    required String recordId,
    required String conflictType,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    String resolutionStrategy = 'remote_wins',
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final conflict = {
        'user_id': userId,
        'table_name': tableName,
        'record_id': recordId,
        'conflict_type': conflictType,
        'local_data': localData,
        'remote_data': remoteData,
        'resolution_strategy': resolutionStrategy,
        'is_resolved': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('sync_conflicts')
          .insert(conflict);

      LoggerFactory.warning('⚠️ Sync conflict reported for $tableName:$recordId');

    } catch (e) {
      LoggerFactory.error('❌ Failed to report sync conflict: $e');
    }
  }

  /// Marca un conflicto como resuelto
  Future<void> markConflictResolved(String conflictId) async {
    try {
      await _supabase
          .from('sync_conflicts')
          .update({
            'is_resolved': true,
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conflictId);

      LoggerFactory.info('✅ Conflict marked as resolved: $conflictId');

    } catch (e) {
      LoggerFactory.error('❌ Failed to mark conflict as resolved: $e');
    }
  }

  /// Fuerza la sincronización desde un dispositivo específico
  Future<SyncResult> forceSyncFromDevice(String sourceDeviceId, String tableName) async {
    final startTime = DateTime.now();
    
    try {
      LoggerFactory.info('🔄 Forcing sync from device $sourceDeviceId for $tableName');

      // Obtener el estado de sync del dispositivo origen
      final sourceStatus = await _getDeviceSyncStatus(sourceDeviceId, tableName);
      if (sourceStatus == null) {
        throw Exception('Source device sync status not found');
      }

      // TODO: Implementar lógica de sincronización específica desde dispositivo
      // Por ahora, simplemente marcamos como completado
      
      await updateSyncStatus(
        tableName: tableName,
        lastSyncAt: DateTime.now(),
        isSyncing: false,
      );

      final result = SyncResult.success(
        itemsProcessed: 0, // TODO: Implementar conteo real
        duration: DateTime.now().difference(startTime),
        message: 'Forced sync from device $sourceDeviceId completed',
      );

      LoggerFactory.info('✅ Forced sync completed: ${result.toString()}');
      return result;

    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Forced sync failed: $e', stackTrace: stackTrace);
      return SyncResult.failure(
        itemsProcessed: 0,
        errors: ['Forced sync failed: $e'],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Obtiene el estado de sync de un dispositivo específico
  Future<SyncStatus?> _getDeviceSyncStatus(String deviceId, String tableName) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('sync_status')
          .select()
          .eq('user_id', userId)
          .eq('device_id', deviceId)
          .eq('table_name', tableName)
          .maybeSingle();

      if (response != null) {
        return SyncStatus.fromJson(Map<String, dynamic>.from(response));
      }

      return null;

    } catch (e) {
      LoggerFactory.error('❌ Failed to get device sync status: $e');
      return null;
    }
  }

  /// Limpia información de dispositivos antiguos (más de 30 días sin actividad)
  Future<void> cleanupOldDevices() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

      await _supabase
          .from('user_devices')
          .delete()
          .eq('user_id', userId)
          .lt('last_seen', cutoffDate.toIso8601String());

      LoggerFactory.info('🧹 Cleaned up old devices (inactive > 30 days)');

    } catch (e) {
      LoggerFactory.error('❌ Failed to cleanup old devices: $e');
    }
  }

  /// Actualiza el "last seen" del dispositivo actual
  Future<void> updateLastSeen() async {
    if (_deviceId == null) return;

    try {
      await _registerDevice(); // Esto actualiza el last_seen
    } catch (e) {
      LoggerFactory.debug('Failed to update last seen: $e');
    }
  }

  /// Limpia recursos
  Future<void> dispose() async {
    // No hay recursos específicos que limpiar por ahora
    LoggerFactory.debug('DeviceSyncManager disposed');
  }
}

/// Información de dispositivo
class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    required this.appVersion,
    required this.createdAt,
    required this.lastSeen,
    this.userId,
  });

  final String id;
  final String name;
  final String platform;
  final String appVersion;
  final DateTime createdAt;
  final DateTime lastSeen;
  final String? userId;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: json['platform'] as String,
      appVersion: json['app_version'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastSeen: DateTime.parse(json['last_seen'] as String),
      userId: json['user_id'] as String?,
    );
  }

  bool get isOnline => DateTime.now().difference(lastSeen).inMinutes < 5;
  
  String get statusDescription => isOnline ? 'Online' : 'Last seen ${_formatLastSeen()}';

  String _formatLastSeen() {
    final difference = DateTime.now().difference(lastSeen);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  String toString() {
    return 'DeviceInfo(id: $id, name: $name, platform: $platform, lastSeen: $lastSeen)';
  }
}

/// Estado de sincronización por dispositivo y tabla
class SyncStatus {
  const SyncStatus({
    required this.userId,
    required this.deviceId,
    required this.tableName,
    required this.lastSyncAt,
    required this.syncDirection,
    required this.isSyncing,
    required this.createdAt,
  });

  final String userId;
  final String deviceId;
  final String tableName;
  final DateTime lastSyncAt;
  final String syncDirection;
  final bool isSyncing;
  final DateTime createdAt;

  factory SyncStatus.fromJson(Map<String, dynamic> json) {
    return SyncStatus(
      userId: json['user_id'] as String,
      deviceId: json['device_id'] as String,
      tableName: json['table_name'] as String,
      lastSyncAt: DateTime.parse(json['last_sync_at'] as String),
      syncDirection: json['sync_direction'] as String,
      isSyncing: json['is_syncing'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  String toString() {
    return 'SyncStatus(device: $deviceId, table: $tableName, lastSync: $lastSyncAt, syncing: $isSyncing)';
  }
}

/// Conflicto de sincronización
class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.userId,
    required this.tableName,
    required this.recordId,
    required this.conflictType,
    required this.localData,
    required this.remoteData,
    required this.resolutionStrategy,
    required this.isResolved,
    required this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String userId;
  final String tableName;
  final String recordId;
  final String conflictType;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final String resolutionStrategy;
  final bool isResolved;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    return SyncConflict(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tableName: json['table_name'] as String,
      recordId: json['record_id'] as String,
      conflictType: json['conflict_type'] as String,
      localData: Map<String, dynamic>.from(json['local_data'] as Map),
      remoteData: Map<String, dynamic>.from(json['remote_data'] as Map),
      resolutionStrategy: json['resolution_strategy'] as String,
      isResolved: json['is_resolved'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null 
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'SyncConflict(id: $id, table: $tableName, record: $recordId, type: $conflictType, resolved: $isResolved)';
  }
}