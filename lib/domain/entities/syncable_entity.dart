import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Interfaz base para todas las entidades que requieren sincronización
/// con Supabase. Proporciona la funcionalidad común para detección de
/// cambios, control de versiones y resolución de conflictos.
abstract class SyncableEntity {
  /// ID único de la entidad (UUID)
  String get id;

  /// ID del usuario propietario de la entidad
  String get userId;

  /// Timestamp de creación de la entidad
  DateTime get createdAt;

  /// Timestamp de última modificación
  DateTime get lastModifiedAt;

  /// Indica si la entidad está marcada como eliminada (soft delete)
  bool get isDeleted;

  /// Versión de sincronización para detección de conflictos
  int get syncVersion;

  /// ID del dispositivo que realizó la última modificación
  String? get deviceId;

  // =============================================
  // DETECCIÓN DE CAMBIOS
  // =============================================

  /// Verifica si la entidad ha sido modificada desde el timestamp dado
  bool hasChangedSince(DateTime timestamp) {
    return lastModifiedAt.isAfter(timestamp);
  }

  /// Genera un checksum MD5 de los datos principales de la entidad
  /// para detección rápida de cambios
  String generateChecksum() {
    final dataMap = toSupabaseJson();
    // Excluir campos que no afectan el contenido real
    dataMap.removeWhere((key, value) => [
          'id',
          'created_at',
          'last_modified_at',
          'sync_version',
          'device_id'
        ].contains(key));

    final dataString = json.encode(dataMap);
    final bytes = utf8.encode(dataString);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Compara dos entidades para detectar si tienen el mismo contenido
  bool hasSameContentAs(SyncableEntity other) {
    return generateChecksum() == other.generateChecksum();
  }

  // =============================================
  // SERIALIZACIÓN
  // =============================================

  /// Convierte la entidad a formato JSON para enviar a Supabase
  /// Debe incluir todos los campos necesarios para la base de datos
  Map<String, dynamic> toSupabaseJson();

  /// Convierte la entidad a formato JSON para almacenamiento local
  /// Puede excluir campos específicos de servidor si es necesario
  Map<String, dynamic> toLocalStorage() {
    return toSupabaseJson();
  }

  /// Crea una copia de la entidad con campos específicos actualizados
  /// Útil para resolver conflictos y actualizar metadatos
  SyncableEntity copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  });

  // =============================================
  // METADATOS DE SINCRONIZACIÓN
  // =============================================

  /// Indica si la entidad necesita ser sincronizada con el servidor
  bool get needsSync => true; // Por defecto, siempre sincronizar

  /// Indica si la entidad puede ser sincronizada automáticamente
  /// o requiere intervención manual
  bool get canAutoSync => !isDeleted; // No auto-sync si está eliminada

  /// Prioridad de sincronización (1 = alta, 5 = baja)
  int get syncPriority => 3; // Prioridad media por defecto

  /// Tipo de entidad para identificación en el sistema de sync
  String get entityType;

  // =============================================
  // RESOLUCIÓN DE CONFLICTOS
  // =============================================

  /// Determina si esta entidad tiene precedencia sobre otra en caso de conflicto
  /// Por defecto usa "last write wins"
  bool hasPrecedenceOver(SyncableEntity other) {
    // Comparar versiones de sync primero
    if (syncVersion != other.syncVersion) {
      return syncVersion > other.syncVersion;
    }
    // Si las versiones son iguales, usar timestamp
    return lastModifiedAt.isAfter(other.lastModifiedAt) ||
        (lastModifiedAt.isAtSameMomentAs(other.lastModifiedAt) &&
            id.compareTo(other.id) > 0);
  }

  /// Fusiona esta entidad con otra para resolver conflictos
  /// La implementación por defecto toma la entidad con precedencia
  SyncableEntity mergeWith(SyncableEntity other) {
    return hasPrecedenceOver(other) ? this : other;
  }

  // =============================================
  // VALIDACIÓN
  // =============================================

  /// Valida que la entidad tiene todos los campos requeridos
  /// para sincronización
  bool isValidForSync() {
    return id.isNotEmpty && userId.isNotEmpty && syncVersion > 0;
  }

  /// Lista de errores de validación, si los hay
  List<String> getValidationErrors() {
    final errors = <String>[];

    if (id.isEmpty) {
      errors.add('ID cannot be empty');
    }

    if (userId.isEmpty) {
      errors.add('User ID cannot be empty');
    }

    if (syncVersion <= 0) {
      errors.add('Sync version must be greater than 0');
    }

    return errors;
  }

  // =============================================
  // UTILIDADES
  // =============================================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncableEntity && other.id == id && other.userId == userId;
  }

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;

  @override
  String toString() {
    return '$entityType(id: $id, userId: $userId, version: $syncVersion, '
        'modified: $lastModifiedAt, deleted: $isDeleted)';
  }
}

/// Enumeración para los estados posibles de sincronización
enum SyncItemStatus {
  /// ✅ Entidad sincronizada exitosamente con el servidor
  synced('synced'),

  /// ⬆️ Pendiente de subir al servidor
  pendingUpload('pending_upload'),

  /// ⬇️ Pendiente de descargar del servidor
  pendingDownload('pending_download'),

  /// ⚠️ Conflicto detectado que requiere resolución
  conflict('conflict'),

  /// ❌ Error durante la sincronización
  error('error'),

  /// 🔄 Sincronizándose en este momento
  processing('processing');

  const SyncItemStatus(this.value);
  final String value;

  static SyncItemStatus fromString(String value) {
    return SyncItemStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SyncItemStatus.error,
    );
  }
}

/// Enumeración para la dirección de sincronización
enum SyncDirection {
  /// Local → Remote (subir cambios)
  upload('upload'),

  /// Remote → Local (descargar cambios)
  download('download'),

  /// Ambos direcciones (sincronización completa)
  bidirectional('bidirectional');

  const SyncDirection(this.value);
  final String value;

  static SyncDirection fromString(String value) {
    return SyncDirection.values.firstWhere(
      (direction) => direction.value == value,
      orElse: () => SyncDirection.bidirectional,
    );
  }
}

/// Wrapper para entidades con su estado de sincronización
class SyncableWrapper<T extends SyncableEntity> {
  const SyncableWrapper({
    required this.entity,
    required this.status,
    this.lastSyncAttempt,
    this.errorMessage,
    this.retryCount = 0,
  });
  final T entity;
  final SyncItemStatus status;
  final DateTime? lastSyncAttempt;
  final String? errorMessage;
  final int retryCount;

  /// Indica si la entidad puede ser reintentada para sync
  bool get canRetry => retryCount < 3 && status == SyncItemStatus.error;

  /// Crea una nueva instancia con estado actualizado
  SyncableWrapper<T> copyWith({
    T? entity,
    SyncItemStatus? status,
    DateTime? lastSyncAttempt,
    String? errorMessage,
    int? retryCount,
  }) {
    return SyncableWrapper<T>(
      entity: entity ?? this.entity,
      status: status ?? this.status,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  String toString() {
    return 'SyncableWrapper(${entity.entityType}: ${status.value}, '
        'retries: $retryCount)';
  }
}
