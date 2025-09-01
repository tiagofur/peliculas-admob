import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sync_operation.g.dart';

/// Tipos de operaciones de sincronización disponibles
@HiveType(typeId: 11)
enum SyncOperationType {
  @HiveField(0)
  addFavorite,
  @HiveField(1)
  removeFavorite,
  @HiveField(2)
  markWatched,
  @HiveField(3)
  unmarkWatched,
  @HiveField(4)
  createCustomList,
  @HiveField(5)
  updateCustomList,
  @HiveField(6)
  deleteCustomList,
  @HiveField(7)
  addMovieToList,
  @HiveField(8)
  removeMovieFromList,
}

/// Estado de una operación de sincronización
@HiveType(typeId: 12)
enum SyncOperationStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  processing,
  @HiveField(2)
  completed,
  @HiveField(3)
  failed,
  @HiveField(4)
  retrying,
}

/// Representa una operación de sincronización que puede ser persistida
@HiveType(typeId: 10)
@JsonSerializable()
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.lastAttemptAt,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.status = SyncOperationStatus.pending,
    this.errorMessage,
    this.priority = 0,
    this.batchId,
  });

  /// Serialización JSON
  factory SyncOperation.fromJson(Map<String, dynamic> json) =>
      _$SyncOperationFromJson(json);
  @HiveField(0)
  final String id;

  @HiveField(1)
  final SyncOperationType type;

  @HiveField(2)
  final Map<String, dynamic> data;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime? lastAttemptAt;

  @HiveField(5)
  final int retryCount;

  @HiveField(6)
  final int maxRetries;

  @HiveField(7)
  final SyncOperationStatus status;

  @HiveField(8)
  final String? errorMessage;

  @HiveField(9)
  final int priority;

  @HiveField(10)
  final String? batchId;

  /// Crea una nueva operación con valores actualizados
  SyncOperation copyWith({
    String? id,
    SyncOperationType? type,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    int? retryCount,
    int? maxRetries,
    SyncOperationStatus? status,
    String? errorMessage,
    int? priority,
    String? batchId,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      priority: priority ?? this.priority,
      batchId: batchId ?? this.batchId,
    );
  }

  /// Marca la operación como fallida con un mensaje de error
  SyncOperation markAsFailed(String error) {
    return copyWith(
      status: SyncOperationStatus.failed,
      errorMessage: error,
      lastAttemptAt: DateTime.now(),
    );
  }

  /// Marca la operación como completada
  SyncOperation markAsCompleted() {
    return copyWith(
      status: SyncOperationStatus.completed,
      errorMessage: null,
      lastAttemptAt: DateTime.now(),
    );
  }

  /// Incrementa el contador de reintentos
  SyncOperation incrementRetry() {
    return copyWith(
      retryCount: retryCount + 1,
      status: SyncOperationStatus.retrying,
      lastAttemptAt: DateTime.now(),
    );
  }

  /// Marca la operación como en procesamiento
  SyncOperation markAsProcessing() {
    return copyWith(
      status: SyncOperationStatus.processing,
      lastAttemptAt: DateTime.now(),
    );
  }

  /// Verifica si la operación puede ser reintentada
  bool get canRetry =>
      retryCount < maxRetries && status == SyncOperationStatus.failed;

  /// Verifica si la operación está pendiente o reintentando
  bool get isPending =>
      status == SyncOperationStatus.pending ||
      status == SyncOperationStatus.retrying;

  /// Verifica si la operación está completada
  bool get isCompleted => status == SyncOperationStatus.completed;

  /// Verifica si la operación ha fallado definitivamente
  bool get isDefinitelyFailed =>
      status == SyncOperationStatus.failed && !canRetry;

  /// Calcula el tiempo de espera para el próximo reintento (backoff exponencial)
  Duration get nextRetryDelay {
    if (!canRetry) return Duration.zero;

    // Backoff exponencial: 2^retryCount segundos, máximo 5 minutos
    final baseDelay = Duration(seconds: 1 << retryCount);
    const maxDelay = Duration(minutes: 5);

    return baseDelay > maxDelay ? maxDelay : baseDelay;
  }

  /// Verifica si es tiempo de reintentar la operación
  bool get isReadyForRetry {
    if (!canRetry || lastAttemptAt == null) return false;

    final nextRetryTime = lastAttemptAt!.add(nextRetryDelay);
    return DateTime.now().isAfter(nextRetryTime);
  }

  Map<String, dynamic> toJson() => _$SyncOperationToJson(this);

  @override
  String toString() {
    return 'SyncOperation(id: $id, type: $type, status: $status, retryCount: $retryCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncOperation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Factory methods para crear operaciones específicas
class SyncOperationFactory {
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (1000 + (DateTime.now().microsecond % 9000)).toString();
  }

  /// Crea una operación para agregar a favoritos
  static SyncOperation addFavorite({
    required int movieId,
    required String userId,
    int priority = 0,
  }) {
    return SyncOperation(
      id: _generateId(),
      type: SyncOperationType.addFavorite,
      data: {
        'movieId': movieId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      priority: priority,
    );
  }

  /// Crea una operación para remover de favoritos
  static SyncOperation removeFavorite({
    required int movieId,
    required String userId,
    int priority = 0,
  }) {
    return SyncOperation(
      id: _generateId(),
      type: SyncOperationType.removeFavorite,
      data: {
        'movieId': movieId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      priority: priority,
    );
  }

  /// Crea una operación para marcar como visto
  static SyncOperation markWatched({
    required int movieId,
    required String userId,
    DateTime? watchedAt,
    int priority = 0,
  }) {
    return SyncOperation(
      id: _generateId(),
      type: SyncOperationType.markWatched,
      data: {
        'movieId': movieId,
        'userId': userId,
        'watchedAt': (watchedAt ?? DateTime.now()).toIso8601String(),
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      priority: priority,
    );
  }

  /// Crea una operación para desmarcar como visto
  static SyncOperation unmarkWatched({
    required int movieId,
    required String userId,
    int priority = 0,
  }) {
    return SyncOperation(
      id: _generateId(),
      type: SyncOperationType.unmarkWatched,
      data: {
        'movieId': movieId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      priority: priority,
    );
  }

  /// Crea una operación para crear lista personalizada
  static SyncOperation createCustomList({
    required String name,
    required String description,
    required String userId,
    int priority = 0,
  }) {
    return SyncOperation(
      id: _generateId(),
      type: SyncOperationType.createCustomList,
      data: {
        'name': name,
        'description': description,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      priority: priority,
    );
  }

  /// Crea una operación para actualizar lista personalizada
  static SyncOperation updateCustomList({
    required String listId,
    required String name,
    required String description,
    required String userId,
    int priority = 0,
  }) {
    return SyncOperation(
      id: _generateId(),
      type: SyncOperationType.updateCustomList,
      data: {
        'listId': listId,
        'name': name,
        'description': description,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      priority: priority,
    );
  }

  /// Crea una operación para eliminar lista personalizada
  static SyncOperation deleteCustomList({
    required String listId,
    required String userId,
    int priority = 0,
  }) {
    return SyncOperation(
      id: _generateId(),
      type: SyncOperationType.deleteCustomList,
      data: {
        'listId': listId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      priority: priority,
    );
  }

  /// Crea una operación para agregar película a lista
  static SyncOperation addMovieToList({
    required String listId,
    required int movieId,
    required String userId,
    int priority = 0,
  }) {
    return SyncOperation(
      id: _generateId(),
      type: SyncOperationType.addMovieToList,
      data: {
        'listId': listId,
        'movieId': movieId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      priority: priority,
    );
  }

  /// Crea una operación para remover película de lista
  static SyncOperation removeMovieFromList({
    required String listId,
    required int movieId,
    required String userId,
    int priority = 0,
  }) {
    return SyncOperation(
      id: _generateId(),
      type: SyncOperationType.removeMovieFromList,
      data: {
        'listId': listId,
        'movieId': movieId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      priority: priority,
    );
  }
}
