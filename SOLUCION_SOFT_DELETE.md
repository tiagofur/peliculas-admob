# 🎯 SOLUCIÓN: Eliminaciones Multi-Dispositivo

## 🚨 PROBLEMA IDENTIFICADO

**El sistema actual NO maneja eliminaciones entre dispositivos**:

```
📱 Dispositivo A: Elimina "Superman" → Solo se borra localmente
☁️ Supabase: "Superman" se elimina
📱 Dispositivo B: Aún tiene "Superman" → Lo vuelve a subir a Supabase
❌ RESULTADO: "Superman" resucita (eliminación se pierde)
```

## 🔧 SOLUCIÓN: Sistema de "Soft Delete" con Timestamps

### 1. **Agregar Campo `deleted_at` a Supabase**

```sql
-- Favoritos
ALTER TABLE user_favorites ADD COLUMN deleted_at TIMESTAMP NULL;

-- Listas
ALTER TABLE user_lists ADD COLUMN deleted_at TIMESTAMP NULL;

-- Películas vistas
ALTER TABLE user_watched_movies ADD COLUMN deleted_at TIMESTAMP NULL;
```

### 2. **Modificar Entidades Sync**

```dart
class SyncableFavorite extends SyncableEntity {
  final DateTime? deletedAt; // ✅ Nuevo campo

  SyncableFavorite({
    // ... campos existentes
    this.deletedAt, // ✅ Timestamp de eliminación
  });

  // ✅ Métodos helper
  bool get isDeleted => deletedAt != null;
  bool get isActive => deletedAt == null;
}
```

### 3. **Lógica de Eliminación Mejorada**

```dart
// ANTES: Eliminación directa
await datasource.removeMovie(movie);
await supabase.from('user_favorites').delete().eq('movie_id', movieId);

// DESPUÉS: Soft Delete
await datasource.markAsDeleted(movie, DateTime.now());
await supabase.from('user_favorites').update({
  'deleted_at': DateTime.now().toIso8601String()
}).eq('movie_id', movieId);
```

### 4. **ConflictResolver Inteligente**

```dart
class ConflictResolver {
  // ✅ Maneja eliminaciones correctamente
  static List<T> findLocalChanges<T extends SyncableEntity>(
    List<T> local,
    List<T> remote
  ) {
    return local.where((localItem) {
      final remoteItem = remote.firstWhere(
        (r) => r.id == localItem.id,
        orElse: () => null
      );

      // ✅ NUEVA LÓGICA:
      if (remoteItem == null) {
        return !localItem.isDeleted; // Solo subir si NO está eliminado
      }

      if (remoteItem.isDeleted && !localItem.isDeleted) {
        // ✅ Remoto eliminado, local activo → ELIMINAR LOCAL
        return false; // No subir, debe eliminarse localmente
      }

      if (!remoteItem.isDeleted && localItem.isDeleted) {
        // ✅ Local eliminado, remoto activo → SUBIR ELIMINACIÓN
        return true; // Subir para marcar como eliminado en remoto
      }

      // ✅ Lógica normal de timestamps
      return localItem.updatedAt.isAfter(remoteItem.updatedAt);
    }).toList();
  }
}
```

## 🔄 FLUJO CORRECTO CON SOFT DELETE

### **Escenario: Eliminar Favorito**

```
📱 Dispositivo A:
1. Usuario elimina "Superman"
2. Local: deleted_at = 2025-08-17 10:00:00
3. Sync: Sube eliminación a Supabase
4. Supabase: deleted_at = 2025-08-17 10:00:00

📱 Dispositivo B:
1. Aún tiene "Superman" (deleted_at = null)
2. Sync: Detecta que remoto tiene deleted_at
3. ConflictResolver: "Remoto eliminado, eliminar local"
4. Local: Marca como eliminado o remueve
```

### **Escenario: Conflicto de Eliminación**

```
📱 Dispositivo A: Elimina "Superman" (10:00:00)
📱 Dispositivo B: Modifica "Superman" (10:01:00)

🔄 Sincronización:
- ConflictResolver detecta conflicto
- deleted_at (10:00:00) vs updatedAt (10:01:00)
- ESTRATEGIA: Última acción gana
- RESULTADO: "Superman" se restaura con modificación
```

## 🛠️ IMPLEMENTACIÓN PRÁCTICA

### 1. **Migración de Base de Datos**

```sql
-- Agregar columnas de eliminación
ALTER TABLE user_favorites ADD COLUMN deleted_at TIMESTAMP NULL;
ALTER TABLE user_lists ADD COLUMN deleted_at TIMESTAMP NULL;
ALTER TABLE user_watched_movies ADD COLUMN deleted_at TIMESTAMP NULL;

-- Índices para performance
CREATE INDEX idx_user_favorites_deleted_at ON user_favorites(deleted_at);
CREATE INDEX idx_user_lists_deleted_at ON user_lists(deleted_at);
```

### 2. **Datasource con Soft Delete**

```dart
abstract class LocalStorageDatasource {
  // ✅ Nuevos métodos
  Future<void> markAsDeleted(Movie movie, DateTime deletedAt);
  Future<void> restoreFromDeleted(Movie movie);
  Future<List<Movie>> getDeletedMovies();

  // ✅ Modificar existentes para excluir eliminados
  Future<List<Movie>> loadMovies({bool includeDeleted = false});
}
```

### 3. **UI con Feedback de Eliminación**

```dart
// ✅ Papelera/Undo para recuperar
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('${movie.title} eliminado'),
    action: SnackBarAction(
      label: 'DESHACER',
      onPressed: () => restoreMovie(movie),
    ),
  ),
);
```

## 📋 BENEFICIOS

### ✅ **Eliminaciones Sincronizadas**

- Dispositivo A elimina → Dispositivo B elimina automáticamente
- No hay "resurrecciones" de elementos eliminados

### ✅ **Recuperación Posible**

- Soft delete permite deshacer eliminaciones
- Papelera temporal antes de eliminación permanente

### ✅ **Resolución de Conflictos**

- Timestamps determinan la acción final
- Modificación después de eliminación = restauración

### ✅ **Performance Mejorada**

- Solo sincronizar cambios reales
- Filtros eficientes con índices de BD

## 🚀 IMPLEMENTACIÓN GRADUAL

### **Fase 1**: Favoritos (más simple)

### **Fase 2**: Listas personalizadas

### **Fase 3**: Películas vistas

### **Fase 4**: Limpieza automática (purge después de 30 días)

¿Te parece bien esta solución? ¿Prefieres empezar con favoritos o implementar todo de una vez?
