import 'dart:math';

import '../../core/sync/sync_states.dart';

/// Información de una operación de sincronización pendiente
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.type,
    required this.data,
    required this.userId,
    this.retryCount = 0,
    required this.scheduledAt,
    this.lastAttemptAt,
    this.status = SyncItemStatus.pendingUpload,
    this.errorMessage,
    this.conflictData,
    this.priority = 5,
  });

  /// Crea desde JSON
  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      type: SyncOperationType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      data: Map<String, dynamic>.from(json['data'] as Map),
      userId: json['userId'] as String,
      retryCount: json['retryCount'] as int? ?? 0,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
      status: SyncItemStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SyncItemStatus.pendingUpload,
      ),
      errorMessage: json['errorMessage'] as String?,
      conflictData: json['conflictData'] != null
          ? Map<String, dynamic>.from(json['conflictData'] as Map)
          : null,
      priority: json['priority'] as int? ?? 5,
    );
  }

  /// ID único de la operación
  final String id;

  /// Tipo de entidad ("favorite", "watchlist", "watched", "custom_list")
  final String entityType;

  /// ID de la entidad específica
  final String entityId;

  /// Tipo de operación a realizar
  final SyncOperationType type;

  /// Datos de la entidad para la operación
  final Map<String, dynamic> data;

  /// Número de intentos realizados
  final int retryCount;

  /// Cuándo está programada para ejecutarse
  final DateTime scheduledAt;

  /// Último intento de ejecución
  final DateTime? lastAttemptAt;

  /// Estado actual de la operación
  final SyncItemStatus status;

  /// Mensaje de error si falló
  final String? errorMessage;

  /// Datos de conflicto si los hay
  final Map<String, dynamic>? conflictData;

  /// Prioridad de la operación (0 = máxima, mayor número = menor prioridad)
  final int priority;

  /// ID del usuario propietario
  final String userId;

  /// Crea una copia con campos modificados
  SyncOperation copyWith({
    String? id,
    String? entityType,
    String? entityId,
    SyncOperationType? type,
    Map<String, dynamic>? data,
    String? userId,
    int? retryCount,
    DateTime? scheduledAt,
    DateTime? lastAttemptAt,
    SyncItemStatus? status,
    String? errorMessage,
    Map<String, dynamic>? conflictData,
    int? priority,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      type: type ?? this.type,
      data: data ?? this.data,
      userId: userId ?? this.userId,
      retryCount: retryCount ?? this.retryCount,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      conflictData: conflictData ?? this.conflictData,
      priority: priority ?? this.priority,
    );
  }

  /// Convierte a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'type': type.name,
      'data': data,
      'userId': userId,
      'retryCount': retryCount,
      'scheduledAt': scheduledAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'status': status.name,
      'errorMessage': errorMessage,
      'conflictData': conflictData,
      'priority': priority,
    };
  }

  /// Indica si la operación debe reintentarse
  bool get shouldRetry {
    const maxRetries = 5;
    return retryCount < maxRetries &&
        status == SyncItemStatus.error &&
        DateTime.now().isAfter(nextRetryAt);
  }

  /// Cuándo debe reintentarse la operación (exponential backoff)
  DateTime get nextRetryAt {
    if (lastAttemptAt == null) return scheduledAt;

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s
    final backoffSeconds = pow(2, retryCount).toInt();
    return lastAttemptAt!.add(Duration(seconds: backoffSeconds));
  }

  /// Indica si la operación está lista para ejecutarse
  bool get isReadyToExecute {
    return status.canAutoSync && DateTime.now().isAfter(scheduledAt);
  }

  @override
  String toString() {
    return 'SyncOperation(id: $id, type: $type, entity: $entityType/$entityId, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncOperation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Resultado de una operación de sincronización
class SyncOperationResult {
  const SyncOperationResult({
    required this.success,
    this.errorMessage,
    this.conflictData,
    required this.newStatus,
  });

  factory SyncOperationResult.success() {
    return const SyncOperationResult(
      success: true,
      newStatus: SyncItemStatus.synced,
    );
  }

  factory SyncOperationResult.error(String message) {
    return SyncOperationResult(
      success: false,
      errorMessage: message,
      newStatus: SyncItemStatus.error,
    );
  }

  factory SyncOperationResult.conflict(Map<String, dynamic> conflictData) {
    return SyncOperationResult(
      success: false,
      conflictData: conflictData,
      newStatus: SyncItemStatus.conflict,
    );
  }
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic>? conflictData;
  final SyncItemStatus newStatus;
}

/// Estadísticas de la cola de sincronización
class SyncQueueStats {
  const SyncQueueStats({
    required this.totalOperations,
    required this.pendingOperations,
    required this.errorOperations,
    required this.conflictOperations,
    this.oldestOperation,
    this.newestOperation,
  });
  final int totalOperations;
  final int pendingOperations;
  final int errorOperations;
  final int conflictOperations;
  final DateTime? oldestOperation;
  final DateTime? newestOperation;

  bool get hasErrors => errorOperations > 0;
  bool get hasConflicts => conflictOperations > 0;
  bool get isEmpty => totalOperations == 0;
  bool get hasPendingWork => pendingOperations > 0;
}