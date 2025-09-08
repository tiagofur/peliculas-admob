import '../sync/sync_utilities.dart';

/// Tipos de operaciones de sincronización
enum SyncOperationType {
  create('CREATE'),
  update('UPDATE'),
  delete('DELETE'),
  merge('MERGE');

  const SyncOperationType(this.value);
  final String value;

  static SyncOperationType fromString(String value) {
    return SyncOperationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => SyncOperationType.update,
    );
  }
}

/// Estado de una operación de sincronización
enum SyncOperationStatus {
  pending('PENDING'),
  processing('PROCESSING'),
  completed('COMPLETED'),
  failed('FAILED'),
  cancelled('CANCELLED');

  const SyncOperationStatus(this.value);
  final String value;

  static SyncOperationStatus fromString(String value) {
    return SyncOperationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SyncOperationStatus.pending,
    );
  }
}

/// Representa una operación de sincronización en la cola persistente
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.type,
    required this.data,
    required this.userId,
    required this.createdAt,
    required this.scheduledAt,
    this.lastAttemptAt,
    this.status = SyncOperationStatus.pending,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.priority = 5,
    this.errorMessage,
    this.conflictData,
    this.deviceId,
  });

  /// Factory constructor para crear una nueva operación
  factory SyncOperation.create({
    required String entityType,
    required String entityId,
    required SyncOperationType type,
    required Map<String, dynamic> data,
    required String userId,
    DateTime? scheduledAt,
    int priority = 5,
    int maxRetries = 3,
    String? deviceId,
  }) {
    final now = SyncUtilities.utcNow();
    return SyncOperation(
      id: SyncUtilities.generateUuid(),
      entityType: entityType,
      entityId: entityId,
      type: type,
      data: SyncUtilities.sanitizeJsonData(data),
      userId: userId,
      createdAt: now,
      scheduledAt: scheduledAt ?? now,
      priority: priority,
      maxRetries: maxRetries,
      deviceId: deviceId,
    );
  }

  /// Factory constructor desde JSON
  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      type: SyncOperationType.fromString(json['type'] as String),
      data: Map<String, dynamic>.from(json['data'] as Map),
      userId: json['user_id'] as String,
      createdAt: SyncUtilities.dateTimeFromIso(json['created_at'] as String) ??
          DateTime.now(),
      scheduledAt:
          SyncUtilities.dateTimeFromIso(json['scheduled_at'] as String) ??
              DateTime.now(),
      lastAttemptAt:
          SyncUtilities.dateTimeFromIso(json['last_attempt_at'] as String?),
      status: SyncOperationStatus.fromString(
          json['status'] as String? ?? 'PENDING'),
      retryCount: json['retry_count'] as int? ?? 0,
      maxRetries: json['max_retries'] as int? ?? 3,
      priority: json['priority'] as int? ?? 5,
      errorMessage: json['error_message'] as String?,
      conflictData: json['conflict_data'] != null
          ? Map<String, dynamic>.from(json['conflict_data'] as Map)
          : null,
      deviceId: json['device_id'] as String?,
    );
  }

  /// ID único de la operación
  final String id;

  /// Tipo de entidad (ej: "favorite", "watchlist", "custom_list")
  final String entityType;

  /// ID de la entidad que se va a sincronizar
  final String entityId;

  /// Tipo de operación (CREATE, UPDATE, DELETE, MERGE)
  final SyncOperationType type;

  /// Datos de la entidad a sincronizar
  final Map<String, dynamic> data;

  /// ID del usuario propietario
  final String userId;

  /// Fecha de creación de la operación
  final DateTime createdAt;

  /// Fecha programada para ejecutar la operación
  final DateTime scheduledAt;

  /// Fecha del último intento de ejecución
  final DateTime? lastAttemptAt;

  /// Estado actual de la operación
  final SyncOperationStatus status;

  /// Número de intentos realizados
  final int retryCount;

  /// Máximo número de reintentos permitidos
  final int maxRetries;

  /// Prioridad de la operación (1 = alta, 10 = baja)
  final int priority;

  /// Mensaje de error si la operación falló
  final String? errorMessage;

  /// Datos adicionales para resolución de conflictos
  final Map<String, dynamic>? conflictData;

  /// ID del dispositivo que creó la operación
  final String? deviceId;

  /// Convierte a JSON para almacenamiento
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'type': type.value,
      'data': data,
      'user_id': userId,
      'created_at': SyncUtilities.dateTimeToIso(createdAt),
      'scheduled_at': SyncUtilities.dateTimeToIso(scheduledAt),
      'last_attempt_at': lastAttemptAt != null
          ? SyncUtilities.dateTimeToIso(lastAttemptAt!)
          : null,
      'status': status.value,
      'retry_count': retryCount,
      'max_retries': maxRetries,
      'priority': priority,
      'error_message': errorMessage,
      'conflict_data': conflictData,
      'device_id': deviceId,
    };
  }

  /// Indica si la operación puede ser reintentada
  bool get canRetry {
    return retryCount < maxRetries &&
        status == SyncOperationStatus.failed &&
        SyncUtilities.isRetryableError(errorMessage);
  }

  /// Indica si la operación está pendiente
  bool get isPending => status == SyncOperationStatus.pending;

  /// Indica si la operación está en proceso
  bool get isProcessing => status == SyncOperationStatus.processing;

  /// Indica si la operación está completada
  bool get isCompleted => status == SyncOperationStatus.completed;

  /// Indica si la operación ha fallado
  bool get isFailed => status == SyncOperationStatus.failed;

  /// Indica si la operación está cancelada
  bool get isCancelled => status == SyncOperationStatus.cancelled;

  /// Indica si la operación está programada para el futuro
  bool get isScheduled => scheduledAt.isAfter(DateTime.now());

  /// Indica si la operación está lista para ejecutar
  bool get isReadyToExecute {
    return (isPending || (isFailed && canRetry)) && !isScheduled;
  }

  /// Calcula el delay para el próximo intento usando exponential backoff
  Duration get nextRetryDelay {
    return SyncUtilities.calculateBackoffDelay(retryCount);
  }

  /// Crea una copia con campos modificados
  SyncOperation copyWith({
    String? id,
    String? entityType,
    String? entityId,
    SyncOperationType? type,
    Map<String, dynamic>? data,
    String? userId,
    DateTime? createdAt,
    DateTime? scheduledAt,
    DateTime? lastAttemptAt,
    SyncOperationStatus? status,
    int? retryCount,
    int? maxRetries,
    int? priority,
    String? errorMessage,
    Map<String, dynamic>? conflictData,
    String? deviceId,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      type: type ?? this.type,
      data: data ?? this.data,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      priority: priority ?? this.priority,
      errorMessage: errorMessage ?? this.errorMessage,
      conflictData: conflictData ?? this.conflictData,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  /// Marca la operación como completada
  SyncOperation markAsCompleted() {
    return copyWith(
      status: SyncOperationStatus.completed,
      lastAttemptAt: SyncUtilities.utcNow(),
    );
  }

  /// Marca la operación como fallida con mensaje de error
  SyncOperation markAsFailed(String error) {
    return copyWith(
      status: SyncOperationStatus.failed,
      lastAttemptAt: SyncUtilities.utcNow(),
      retryCount: retryCount + 1,
      errorMessage: error,
    );
  }

  /// Marca la operación como en proceso
  SyncOperation markAsProcessing() {
    return copyWith(
      status: SyncOperationStatus.processing,
      lastAttemptAt: SyncUtilities.utcNow(),
    );
  }

  /// Programa la operación para reintentar más tarde
  SyncOperation scheduleRetry() {
    final nextAttempt = DateTime.now().add(nextRetryDelay);
    return copyWith(
      status: SyncOperationStatus.pending,
      scheduledAt: nextAttempt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncOperation &&
        other.id == id &&
        other.entityType == entityType &&
        other.entityId == entityId &&
        other.type == type &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return Object.hash(id, entityType, entityId, type, userId);
  }

  @override
  String toString() {
    return 'SyncOperation(id: ${id.substring(0, 8)}..., '
        'type: ${type.value}, entity: $entityType($entityId), '
        'status: ${status.value}, retries: $retryCount/$maxRetries)';
  }
}
