// Interfaz base para repositorios que soportan sincronización con Supabase
abstract class SyncableRepository<T> {
  /// Sincroniza datos locales con Supabase
  Future<void> syncWithSupabase();

  /// Obtiene datos almacenados localmente
  Future<List<T>> getLocalData();

  /// Obtiene datos remotos desde Supabase
  Future<List<T>> getRemoteData();

  /// Sube datos locales a Supabase
  Future<void> upload(List<T> items);

  /// Descarga datos de Supabase y los guarda localmente
  Future<void> download(List<T> items);

  /// Resuelve conflictos entre datos locales y remotos
  Future<void> resolveConflicts(List<T> local, List<T> remote);

  /// Verifica si hay elementos pendientes de sincronizar
  Future<bool> hasPendingSync();

  /// Obtiene elementos marcados para sincronización
  Future<List<String>> getPendingSyncItems();
}

// Estados de sincronización
enum SyncStatus {
  synced, // Datos sincronizados correctamente
  pending, // Cambios locales pendientes de sincronizar
  conflict, // Conflicto detectado, requiere resolución
  error, // Error en sincronización, requiere retry
}

// Interfaz para elementos que pueden ser sincronizados
abstract class Syncable {
  String get id;
  DateTime get updatedAt;
  SyncStatus get syncStatus;
}

// Interfaz para elementos identificables
abstract class Identifiable {
  String get id;
}

// Interfaz para elementos con timestamp
abstract class Timestamped {
  DateTime get updatedAt;
}
