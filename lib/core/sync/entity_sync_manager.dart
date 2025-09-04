import 'dart:async';

import '../../domain/entities/syncable_entity.dart';


/// Información de conflicto entre versiones local y remota
class ConflictInfo<T extends SyncableEntity> {
  /// Versión local de la entidad
  final T localEntity;
  
  /// Versión remota de la entidad
  final T remoteEntity;
  
  /// Tipo de conflicto detectado
  final ConflictType conflictType;
  
  /// Metadatos adicionales del conflicto
  final Map<String, dynamic>? metadata;

  const ConflictInfo({
    required this.localEntity,
    required this.remoteEntity,
    required this.conflictType,
    this.metadata,
  });
}

/// Tipos de conflicto posibles
enum ConflictType {
  /// Ambas versiones fueron modificadas simultáneamente
  concurrentModification,
  
  /// La entidad fue eliminada remotamente pero modificada localmente
  deletedRemotelyModifiedLocally,
  
  /// La entidad fue eliminada localmente pero modificada remotamente
  deletedLocallyModifiedRemotely,
  
  /// Conflicto en el versionado
  versionMismatch,
  
  /// Conflicto personalizado específico de la entidad
  custom,
}

/// Estrategia de resolución de conflictos
enum ConflictResolutionStrategy {
  /// La última escritura gana (por timestamp)
  lastWriteWins,
  
  /// El servidor siempre gana
  serverWins,
  
  /// El cliente siempre gana
  clientWins,
  
  /// Requiere intervención del usuario
  userChoice,
  
  /// Intentar fusionar automáticamente
  merge,
  
  /// Lógica personalizada
  custom,
}

/// Estadísticas de sincronización
class SyncStats {
  /// Total de entidades sincronizadas
  final int totalSynced;
  
  /// Entidades con errores
  final int errors;
  
  /// Conflictos detectados
  final int conflicts;
  
  /// Tiempo de la última sincronización
  final DateTime? lastSyncTime;
  
  /// Duración de la última sincronización
  final Duration? lastSyncDuration;
  
  /// Entidades pendientes de sincronización
  final int pendingSync;

  const SyncStats({
    required this.totalSynced,
    required this.errors,
    required this.conflicts,
    this.lastSyncTime,
    this.lastSyncDuration,
    required this.pendingSync,
  });

  /// Indica si hay problemas de sincronización
  bool get hasIssues => errors > 0 || conflicts > 0;
  
  /// Indica si la sincronización está al día
  bool get isUpToDate => pendingSync == 0 && !hasIssues;
}

/// Evento de progreso de sincronización
class SyncProgressEvent {
  /// Tipo de evento
  final SyncProgressType type;
  
  /// Mensaje descriptivo
  final String message;
  
  /// Progreso actual (0.0 - 1.0)
  final double progress;
  
  /// Entidad siendo procesada (opcional)
  final String? entityId;
  
  /// Datos adicionales del evento
  final Map<String, dynamic>? data;

  const SyncProgressEvent({
    required this.type,
    required this.message,
    required this.progress,
    this.entityId,
    this.data,
  });
}

/// Tipos de eventos de progreso
enum SyncProgressType {
  started,
  progress,
  entityProcessed,
  conflictDetected,
  error,
  completed,
}

/// Gestor base de sincronización para entidades
/// 
/// Esta clase abstracta define la interfaz común para todos los gestores
/// de sincronización específicos de entidad.
abstract class EntitySyncManager<T extends SyncableEntity> {
  /// Stream de eventos de progreso de sincronización
  Stream<SyncProgressEvent> get syncProgress;
  
  /// Controlador interno para eventos de progreso
  final StreamController<SyncProgressEvent> _progressController = 
      StreamController<SyncProgressEvent>.broadcast();

  /// Constructor base
  EntitySyncManager() {
    // Configurar el stream de progreso
    _syncProgress = _progressController.stream;
  }
  
  late final Stream<SyncProgressEvent> _syncProgress;
  
  @override
  Stream<SyncProgressEvent> get syncProgress => _syncProgress;

  // ==================== OPERACIONES BÁSICAS ====================
  
  /// Obtiene todas las entidades locales que necesitan sincronización
  Future<List<T>> getLocalPendingSync();
  
  /// Obtiene cambios remotos desde una fecha específica
  Future<List<T>> getRemoteChanges({DateTime? since});
  
  /// Sube cambios locales al servidor
  Future<void> uploadChanges(List<T> entities);
  
  /// Descarga cambios del servidor
  Future<void> downloadChanges(List<T> entities);

  // ==================== DETECCIÓN Y RESOLUCIÓN DE CONFLICTOS ====================
  
  /// Detecta conflictos entre versiones locales y remotas
  Future<List<ConflictInfo<T>>> detectConflicts();
  
  /// Resuelve un conflicto específico
  Future<T> resolveConflict(ConflictInfo<T> conflict);
  
  /// Obtiene la estrategia de resolución para un tipo de conflicto
  ConflictResolutionStrategy getResolutionStrategy(ConflictType type);

  // ==================== MONITOREO Y DIAGNÓSTICO ====================
  
  /// Obtiene estadísticas de sincronización
  Future<SyncStats> getSyncStatistics();
  
  /// Realiza una sincronización completa
  Future<void> performFullSync() async {
    _emitProgress(SyncProgressType.started, 'Iniciando sincronización completa', 0.0);
    
    try {
      // 1. Detectar conflictos
      _emitProgress(SyncProgressType.progress, 'Detectando conflictos', 0.1);
      final conflicts = await detectConflicts();
      
      if (conflicts.isNotEmpty) {
        _emitProgress(SyncProgressType.conflictDetected, 
            'Detectados ${conflicts.length} conflictos', 0.2);
        
        // Resolver conflictos automáticamente cuando sea posible
        for (final conflict in conflicts) {
          await resolveConflict(conflict);
        }
      }
      
      // 2. Subir cambios locales
      _emitProgress(SyncProgressType.progress, 'Subiendo cambios locales', 0.4);
      final localChanges = await getLocalPendingSync();
      if (localChanges.isNotEmpty) {
        await uploadChanges(localChanges);
      }
      
      // 3. Descargar cambios remotos
      _emitProgress(SyncProgressType.progress, 'Descargando cambios remotos', 0.7);
      final remoteChanges = await getRemoteChanges();
      if (remoteChanges.isNotEmpty) {
        await downloadChanges(remoteChanges);
      }
      
      _emitProgress(SyncProgressType.completed, 'Sincronización completada', 1.0);
      
    } catch (error) {
      _emitProgress(SyncProgressType.error, 'Error en sincronización: $error', 0.0);
      rethrow;
    }
  }
  
  /// Valida que una entidad esté lista para sincronización
  bool validateEntityForSync(T entity) {
    // Validaciones básicas
    if (entity.id.isEmpty) return false;
    if (entity.userId.isEmpty) return false;
    
    // La entidad debe tener cambios pendientes o ser nueva
    return entity.needsSync;
  }
  
  /// Emite un evento de progreso
  void _emitProgress(SyncProgressType type, String message, double progress, 
      {String? entityId, Map<String, dynamic>? data}) {
    final event = SyncProgressEvent(
      type: type,
      message: message,
      progress: progress,
      entityId: entityId,
      data: data,
    );
    
    if (!_progressController.isClosed) {
      _progressController.add(event);
    }
  }
  
  /// Limpia recursos
  void dispose() {
    _progressController.close();
  }
}

/// Utilidades comunes para gestores de sincronización
class SyncManagerUtils {
  /// Genera un ID único para operaciones de sincronización
  static String generateOperationId() {
    return 'sync_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }
  
  /// Genera una cadena aleatoria
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) => 
        chars[(random + index) % chars.length]).join();
  }
  
  /// Calcula el hash de una entidad para detección de cambios
  static String calculateEntityHash(Map<String, dynamic> data) {
    // Implementación simple de hash basada en contenido
    final sortedKeys = data.keys.toList()..sort();
    final content = sortedKeys.map((key) => '$key:${data[key]}').join('|');
    return content.hashCode.toString();
  }
  
  /// Determina si dos timestamps indican un conflicto
  static bool hasTimestampConflict(DateTime local, DateTime remote, 
      {Duration tolerance = const Duration(seconds: 1)}) {
    final diff = local.difference(remote).abs();
    return diff > tolerance;
  }
}