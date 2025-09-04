/// Estados y direcciones de sincronización para el sistema de sync
/// 
/// Este archivo define los enums fundamentales para el manejo de estados
/// de sincronización en la aplicación.

/// Estado de sincronización de un elemento individual
enum SyncItemStatus {
  /// ✅ Sincronizado con servidor - no requiere acción
  synced,
  
  /// ⬆️ Esperando subir al servidor - cambios locales pendientes
  pendingUpload,
  
  /// ⬇️ Esperando bajar del servidor - cambios remotos disponibles
  pendingDownload,
  
  /// ⚠️ Conflicto detectado - requiere resolución manual o automática
  conflict,
  
  /// ❌ Error en sincronización - falló el último intento
  error,
  
  /// 🔄 Sincronizando ahora - operación en progreso
  processing,
}

/// Dirección de la operación de sincronización
enum SyncDirection {
  /// Local → Remote - subir cambios locales al servidor
  upload,
  
  /// Remote → Local - descargar cambios del servidor
  download,
  
  /// Ambos - sincronización bidireccional
  bidirectional,
}

/// Tipo de operación de sincronización
enum SyncOperationType {
  /// Crear nueva entidad
  create,
  
  /// Actualizar entidad existente
  update,
  
  /// Eliminar entidad (soft delete)
  delete,
  
  /// Restaurar entidad eliminada
  restore,
}

/// Extensiones útiles para los enums
extension SyncItemStatusExtension on SyncItemStatus {
  /// Indica si el elemento requiere sincronización
  bool get needsSync {
    switch (this) {
      case SyncItemStatus.synced:
      case SyncItemStatus.processing:
        return false;
      case SyncItemStatus.pendingUpload:
      case SyncItemStatus.pendingDownload:
      case SyncItemStatus.conflict:
      case SyncItemStatus.error:
        return true;
    }
  }
  
  /// Indica si el elemento está en un estado de error
  bool get hasError {
    return this == SyncItemStatus.error || this == SyncItemStatus.conflict;
  }
  
  /// Indica si el elemento se puede sincronizar automáticamente
  bool get canAutoSync {
    switch (this) {
      case SyncItemStatus.pendingUpload:
      case SyncItemStatus.pendingDownload:
      case SyncItemStatus.error:
        return true;
      case SyncItemStatus.synced:
      case SyncItemStatus.processing:
      case SyncItemStatus.conflict:
        return false;
    }
  }
}

extension SyncDirectionExtension on SyncDirection {
  /// Indica si la dirección incluye upload
  bool get includesUpload {
    return this == SyncDirection.upload || this == SyncDirection.bidirectional;
  }
  
  /// Indica si la dirección incluye download
  bool get includesDownload {
    return this == SyncDirection.download || this == SyncDirection.bidirectional;
  }
}

extension SyncOperationTypeExtension on SyncOperationType {
  /// Indica si la operación modifica datos
  bool get isModifying {
    return this != SyncOperationType.create;
  }
  
  /// Indica si la operación es destructiva
  bool get isDestructive {
    return this == SyncOperationType.delete;
  }
}