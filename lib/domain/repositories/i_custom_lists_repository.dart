import '../entities/custom_list.dart';
import '../entities/list_item.dart';

/// Repositorio abstracto para el manejo de listas personalizadas
/// Proporciona la interfaz para operaciones CRUD y sincronización
abstract class ICustomListsRepository {
  // ========== OPERACIONES DE LISTAS ==========

  /// Obtiene todas las listas del usuario actual
  Future<List<CustomList>> getUserLists();

  /// Obtiene una lista específica por ID
  Future<CustomList?> getListById(String listId);

  /// Crea una nueva lista personalizada
  Future<CustomList> createList(CustomList list);

  /// Actualiza una lista existente
  Future<CustomList> updateList(CustomList list);

  /// Elimina una lista (soft delete)
  Future<void> deleteList(String listId);

  /// Obtiene las listas por defecto del sistema
  Future<List<CustomList>> getDefaultLists();

  /// Inicializa las listas por defecto para un usuario
  Future<void> initializeDefaultLists(String userId);

  // ========== OPERACIONES DE ELEMENTOS ==========

  /// Obtiene todos los elementos de una lista
  Future<List<ListItem>> getListItems(String listId);

  /// Agrega una película a una lista
  Future<ListItem> addMovieToList(String listId, int movieId, {int? position});

  /// Remueve una película de una lista
  Future<void> removeMovieFromList(String listId, int movieId);

  /// Reordena los elementos de una lista
  Future<void> reorderListItems(String listId, List<ListItem> items);

  /// Verifica si una película está en una lista específica
  Future<bool> isMovieInList(String listId, int movieId);

  /// Duplica una lista con todas sus películas
  Future<CustomList> duplicateList(String listId, String newName);

  /// Elimina todas las películas de una lista
  Future<void> clearListMovies(String listId);

  // ========== SINCRONIZACIÓN ==========

  /// Stream para escuchar cambios en las listas del usuario
  Stream<List<CustomList>> watchUserLists();

  /// Stream para escuchar cambios en los elementos de una lista
  Stream<List<ListItem>> watchListItems(String listId);

  /// Sincroniza las listas locales con el servidor
  Future<void> syncLists();

  /// Maneja conflictos de sincronización
  Future<CustomList> resolveConflict(
      CustomList localList, CustomList remoteList);

  // ========== OPERACIONES OFFLINE ==========

  /// Obtiene las listas almacenadas localmente
  Future<List<CustomList>> getLocalLists();

  /// Guarda una lista localmente
  Future<void> saveListLocally(CustomList list);

  /// Obtiene las operaciones pendientes de sincronización
  Future<List<Map<String, dynamic>>> getPendingOperations();

  /// Marca una operación como sincronizada
  Future<void> markOperationAsSynced(String operationId);

  // ========== UTILIDADES ==========

  /// Verifica si hay conexión a internet
  Future<bool> hasInternetConnection();

  /// Obtiene el estado de sincronización actual
  Future<String> getSyncStatus();

  /// Limpia la caché local
  Future<void> clearLocalCache();
}
