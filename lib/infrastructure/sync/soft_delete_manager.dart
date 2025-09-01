/// Interfaz para entidades que soportan soft delete
abstract class SoftDeletable {
  /// Indica si la entidad está marcada como eliminada
  bool get isDeleted;
  
  /// Fecha y hora cuando fue marcada como eliminada
  DateTime? get deletedAt;
  
  /// Crea una copia de la entidad marcada como eliminada
  SoftDeletable copyWith({bool? isDeleted, DateTime? deletedAt});
}

/// Gestor de soft delete para entidades sincronizables
class SoftDeleteManager {
  /// Marca una entidad como eliminada (soft delete)
  T markAsDeleted<T extends SoftDeletable>(T entity) {
    return entity.copyWith(
      isDeleted: true,
      deletedAt: DateTime.now(),
    ) as T;
  }
  
  /// Restaura una entidad eliminada
  T restore<T extends SoftDeletable>(T entity) {
    return entity.copyWith(
      isDeleted: false,
      deletedAt: null,
    ) as T;
  }
  
  /// Verifica si una entidad está eliminada
  bool isDeleted(SoftDeletable entity) {
    return entity.isDeleted;
  }
  
  /// Filtra entidades no eliminadas de una lista
  List<T> filterActive<T extends SoftDeletable>(List<T> entities) {
    return entities.where((entity) => !entity.isDeleted).toList();
  }
  
  /// Filtra entidades eliminadas de una lista
  List<T> filterDeleted<T extends SoftDeletable>(List<T> entities) {
    return entities.where((entity) => entity.isDeleted).toList();
  }
}