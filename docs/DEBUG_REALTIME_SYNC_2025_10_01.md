# 🐛 Debug Real-Time Sync - Logging Mejorado

**Fecha**: 1 de Octubre, 2025  
**Problema Reportado**:

- ✅ Watched ADD funciona
- ❌ Watched DELETE no funciona
- ❌ Favorites ADD no funciona
- ❌ Favorites DELETE no funciona

---

## 🔧 Cambios Implementados

### 1. Logging Detallado en `base_hybrid_repository.dart`

Ahora cada evento realtime muestra información completa:

#### INSERT Event

```
⚡️ Realtime event received for favorite: PostgresChangeEvent.insert
📦 INSERT payload newRecord: {id: abc123, movie_id: 12345, ...}
🔄 Deserialized entity: abc123, movieId: 12345
✅ Realtime INSERT processed successfully: abc123
```

#### DELETE Event

```
⚡️ Realtime event received for favorite: PostgresChangeEvent.delete
📦 DELETE payload oldRecord: {id: abc123, movie_id: 12345, ...}
🔍 DELETE IDs found - movie_id: 12345, id: abc123
🗑️ Attempting to remove with ID: 12345
✅ Realtime DELETE processed successfully: 12345
```

### 2. Mejor Manejo de Errores en `hybrid_favorites_repository.dart`

#### `saveToLocal()` con Try-Catch

```dart
try {
  final favoriteModel = convertToModel(entity);
  final movie = favoriteModel.toMovie();
  await _localDatasource.saveFavorite(movie);
  LoggerFactory.debug('💾 Saved favorite locally: ${entity.movieTitle}');
} catch (e, stackTrace) {
  LoggerFactory.error('❌ Failed to save favorite locally: $e');
  LoggerFactory.error('Stack trace: $stackTrace');
  rethrow;
}
```

#### `removeFromLocal()` con Doble Estrategia

```dart
// 1. Intenta como movie_id directo (número)
final movieId = int.tryParse(id);
if (movieId != null) {
  await _localDatasource.removeFavoriteById(movieId);
} else {
  // 2. Busca por UUID y obtiene movie_id
  final favorite = localFavorites.firstWhere((fav) => fav.id == id);
  await _localDatasource.removeFavoriteById(favorite.movieId);
}
```

---

## 🧪 Testing con Logs Detallados

### Paso 1: Abrir DevTools Console

1. Abre la app: `flutter run -d chrome --web-port 8080`
2. Presiona F12 para abrir Chrome DevTools
3. Ve a la pestaña "Console"
4. Filtra por: `Realtime` o `⚡️`

### Paso 2: Test Favorites ADD

**En Tab 1:**

```
1. Ve a cualquier película
2. Haz clic en ❤️ (favorito)
3. Mira la consola
```

**Logs Esperados en Tab 1:**

```
➕ Added favorite to sync queue: [Movie Title]
📤 Uploading 1 favorite items
✅ Uploaded favorite: [Movie Title]
```

**Logs Esperados en Tab 2:**

```
⚡️ Realtime event received for favorite: PostgresChangeEvent.insert
📦 INSERT payload newRecord: {id: "...", movie_id: 12345, movie_title: "..."}
🔄 Deserialized entity: abc-123-uuid, movieId: 12345
💾 Saved favorite locally: [Movie Title] (movieId: 12345)
✅ Realtime INSERT processed successfully: abc-123-uuid
```

### Paso 3: Test Favorites DELETE

**En Tab 1:**

```
1. En la película favorita, haz clic en ❤️ de nuevo
2. Mira la consola
```

**Logs Esperados en Tab 2:**

```
⚡️ Realtime event received for favorite: PostgresChangeEvent.delete
📦 DELETE payload oldRecord: {id: "abc-123", movie_id: 12345}
🔍 DELETE IDs found - movie_id: 12345, id: abc-123
🗑️ Attempting to remove with ID: 12345
🔍 Attempting to remove favorite with ID: 12345
🗑️ Removing favorite by movie_id: 12345
✅ Favorite removed successfully (movie_id: 12345)
✅ Realtime DELETE processed successfully: 12345
```

### Paso 4: Test Watched DELETE

**En Tab 1:**

```
1. Ve a Watched Movies
2. Elimina una película vista
3. Mira la consola
```

**Logs Esperados en Tab 2:**

```
⚡️ Realtime event received for watched_movie: PostgresChangeEvent.delete
📦 DELETE payload oldRecord: {id: "xyz-789", movie_id: 67890}
🔍 DELETE IDs found - movie_id: 67890, id: xyz-789
🗑️ Attempting to remove with ID: 67890
🗑️ Removed watched movie from local storage: 67890 (movieId: 67890)
✅ Realtime DELETE processed successfully: 67890
```

---

## 🔍 Qué Buscar en los Logs

### ✅ Si Funciona Correctamente

Para **INSERT**:

1. ✅ Ves `⚡️ Realtime event received`
2. ✅ Ves `📦 INSERT payload newRecord`
3. ✅ Ves `🔄 Deserialized entity`
4. ✅ Ves `💾 Saved ... locally`
5. ✅ Ves `✅ Realtime INSERT processed successfully`
6. ✅ La película aparece en la UI sin refresh

Para **DELETE**:

1. ✅ Ves `⚡️ Realtime event received`
2. ✅ Ves `📦 DELETE payload oldRecord`
3. ✅ Ves `🔍 DELETE IDs found` con valores no-null
4. ✅ Ves `🗑️ Attempting to remove`
5. ✅ Ves `✅ Realtime DELETE processed successfully`
6. ✅ La película desaparece de la UI sin refresh

### ❌ Si NO Funciona

#### Problema: No Llegan Eventos

**Logs que NO ves:**

```
⚡️ Realtime event received
```

**Posibles Causas:**

1. No estás logueado con el mismo usuario en ambos tabs
2. El filtro `user_id` no está funcionando
3. La suscripción realtime no se configuró

**Solución:**

```powershell
# Verifica en Tab 2 al cargar la app:
⚡️ Realtime subscription setup for user_favorites (user: abc123, channel: favorite-abc123)
```

#### Problema: Eventos Llegan pero Fallan

**Logs que ves:**

```
⚡️ Realtime event received for favorite: PostgresChangeEvent.insert
📦 INSERT payload newRecord: {...}
❌ Failed to process INSERT: [Error Message]
```

**Posibles Causas:**

1. Error al deserializar la entidad
2. Error al guardar localmente
3. Campos faltantes en el payload

**Información a Reportar:**

- Copia el contenido completo del `payload newRecord`
- Copia el error completo
- Indica qué tipo de entidad (watched/favorite)

#### Problema: DELETE No Encuentra ID

**Logs que ves:**

```
⚡️ Realtime event received for favorite: PostgresChangeEvent.delete
📦 DELETE payload oldRecord: {...}
🔍 DELETE IDs found - movie_id: null, id: null
⚠️ Cannot process DELETE - missing both movie_id and id in oldRecord
```

**Posibles Causas:**

1. La tabla en Supabase no envía `movie_id` ni `id` en oldRecord
2. Configuración incorrecta de RLS en Supabase

**Solución:**
Revisa las políticas RLS en Supabase:

```sql
-- Debe permitir SELECT en DELETE para obtener oldRecord
CREATE POLICY "Users can delete their favorites"
  ON user_favorites FOR DELETE
  USING (auth.uid()::text = user_id);
```

---

## 📊 Tabla de Diagnóstico

| Síntoma                           | Posible Causa         | Solución                                   |
| --------------------------------- | --------------------- | ------------------------------------------ |
| No hay logs `⚡️`                 | No llegan eventos     | Verificar mismo usuario, suscripción setup |
| Evento llega, falla INSERT        | Error deserialización | Ver payload completo, verificar campos     |
| Evento llega, falla DELETE        | IDs null              | Verificar políticas RLS en Supabase        |
| INSERT funciona, DELETE no        | `oldRecord` vacío     | Agregar política SELECT en DELETE          |
| Favorites no funciona en absoluto | Problema tabla/filtro | Verificar nombre tabla, filtro user_id     |

---

## 🚀 Comandos de Testing

### Testing Rápido (2 terminales)

**Terminal 1:**

```powershell
flutter run -d chrome --web-port 8080
```

**Terminal 2:**

```powershell
flutter run -d chrome --web-port 8081
```

### Ver Solo Logs Realtime

En Chrome Console:

```javascript
// Filtrar por emoji
⚡️

// O por palabra
Realtime
```

---

## 📝 Checklist de Debugging

Completa este checklist mientras pruebas:

### Favorites ADD

- [ ] Tab 1: Agrego película a favoritos
- [ ] Tab 1: Veo logs de upload
- [ ] Tab 2: Veo `⚡️ Realtime event received for favorite: PostgresChangeEvent.insert`
- [ ] Tab 2: Veo `📦 INSERT payload newRecord` con datos
- [ ] Tab 2: Veo `✅ Realtime INSERT processed successfully`
- [ ] Tab 2: Película aparece en favoritos sin refresh

### Favorites DELETE

- [ ] Tab 1: Elimino película de favoritos
- [ ] Tab 1: Veo logs de delete
- [ ] Tab 2: Veo `⚡️ Realtime event received for favorite: PostgresChangeEvent.delete`
- [ ] Tab 2: Veo `📦 DELETE payload oldRecord` con datos
- [ ] Tab 2: Veo `🔍 DELETE IDs found - movie_id: [número], id: [uuid]`
- [ ] Tab 2: Veo `✅ Realtime DELETE processed successfully`
- [ ] Tab 2: Película desaparece de favoritos sin refresh

### Watched DELETE

- [ ] Tab 1: Elimino película de watched
- [ ] Tab 1: Veo logs de delete
- [ ] Tab 2: Veo `⚡️ Realtime event received for watched_movie: PostgresChangeEvent.delete`
- [ ] Tab 2: Veo `📦 DELETE payload oldRecord` con datos
- [ ] Tab 2: Veo `🔍 DELETE IDs found - movie_id: [número], id: [uuid]`
- [ ] Tab 2: Veo `✅ Realtime DELETE processed successfully`
- [ ] Tab 2: Película desaparece de watched sin refresh

---

## 💡 Próximos Pasos

1. **Ejecuta el testing** con las 2 tabs abiertas
2. **Copia los logs completos** de cada operación (ADD/DELETE)
3. **Reporta qué funciona y qué no** con los logs
4. Si algo falla, **copia el error completo** incluyendo stack trace

---

## 📚 Archivos Modificados

1. `lib/infrastructure/repositories/base_hybrid_repository.dart`

   - Método `_handleRealtimePayload()` ahora es async
   - Logging detallado para INSERT/UPDATE/DELETE
   - Mejor estrategia para obtener IDs en DELETE

2. `lib/infrastructure/repositories/hybrid_favorites_repository.dart`
   - `saveToLocal()` con try-catch y logging
   - `removeFromLocal()` con doble estrategia (movie_id directo o UUID)

---

**Estado**: ✅ Código actualizado con logging mejorado  
**Siguiente**: 🧪 Testing manual con análisis de logs
