# 🚀 Guía Rápida de Implementación y Testing

## ⚡ COMANDOS PARA EMPEZAR

### 1. Verificar que todo compila

```powershell
# Limpiar y obtener dependencias
flutter clean
flutter pub get

# Verificar que no hay errores de compilación
flutter analyze --fatal-infos --fatal-warnings
```

### 2. Ejecutar la app

```powershell
# Para Web
flutter run -d chrome

# Para Android
flutter run -d android

# Para Windows
flutter run -d windows
```

### 3. Ver logs en tiempo real

```powershell
# Los logs mostrarán el flujo completo de sincronización
# Buscar estos patrones:
# ✅ = Éxito
# ❌ = Error
# 🔄 = Sync en progreso
# 📥 = Cargando datos
# 📤 = Subiendo datos
```

---

## 🔍 QUÉ BUSCAR EN LOS LOGS

### Al iniciar sesión:

```
🚀 Starting NON-BLOCKING post-login initialization for user: [user_id]
✅ UnifiedFavorites habilitado para sync tiempo real
✅ UnifiedWatched habilitado para sync tiempo real
📥 UnifiedFavorites: Cargando datos iniciales...
✅ UnifiedFavorites: X favoritos locales cargados
🔄 UnifiedFavorites: Sincronizando con Supabase...
✅ UnifiedFavorites: X favoritos sincronizados
🎯 UnifiedFavorites: Configurando Real-Time Sync...
✅ UnifiedFavorites: Real-Time Sync configurado
```

### Al hacer toggle de favorito:

```
🔄 UnifiedFavorites: Toggle [Movie Title] (actual: false)
✅ UnifiedFavorites: Toggle exitoso para [Movie Title]
```

### Al recibir cambio remoto:

```
🔄 UnifiedFavorites: Real-time update - X items
```

### Si hay error:

```
❌ UnifiedFavorites: Error en toggle: [error message]
Stack trace: [stack trace]
```

---

## 🧪 TEST RÁPIDO (5 minutos)

### Test Básico de Favorites:

1. **Ejecutar la app**

   ```powershell
   flutter run -d chrome
   ```

2. **Login** con tu cuenta de prueba

3. **Agregar un favorito**

   - Buscar una película
   - Click en el corazón
   - Verificar que cambia inmediatamente

4. **Verificar persistencia**

   - Refrescar la página (F5)
   - Verificar que el favorito sigue ahí

5. **Verificar Supabase**
   - Ir a Supabase Dashboard
   - Tabla `user_favorites`
   - Verificar que la película está ahí

### Test de Real-Time (si tienes 2 dispositivos):

1. **Dispositivo A**: Agregar favorito
2. **Dispositivo B**: Esperar 3 segundos
3. **Verificar**: El favorito aparece automáticamente en B

---

## 🐛 TROUBLESHOOTING RÁPIDO

### Error: "UnifiedFavoritesProvider not found"

**Solución**: Asegúrate de que el import está correcto

```dart
import 'package:tu_app/presentation/providers/unified_sync_provider.dart';
```

### Error: "Table user_favorites doesn't exist"

**Solución**: Verificar que las tablas existen en Supabase

```sql
-- En Supabase SQL Editor:
SELECT * FROM user_favorites LIMIT 1;
SELECT * FROM user_watched_movies LIMIT 1;
```

### Error: "Real-time not working"

**Solución**: Verificar que real-time está habilitado en Supabase

1. Ir a Supabase Dashboard
2. Database → Replication
3. Verificar que `user_favorites` y `user_watched_movies` tienen replication habilitada

### Error: "Sync is slow"

**Posibles causas**:

- Conexión lenta
- Muchos items (>1000)
- Supabase en región lejana

**Solución**: Verificar logs de batch sync

```
📦 UnifiedFavorites: Sincronizando X items en lote
✅ UnifiedFavorites: Lote 1 sincronizado
```

---

## 📊 VERIFICAR DATA EN SUPABASE

### Query para ver favoritos de un usuario:

```sql
SELECT
  movie_id,
  movie_title,
  added_at,
  last_modified_at,
  sync_version
FROM user_favorites
WHERE user_id = 'YOUR_USER_ID'
ORDER BY added_at DESC;
```

### Query para verificar no duplicados:

```sql
SELECT
  user_id,
  movie_id,
  COUNT(*) as count
FROM user_favorites
GROUP BY user_id, movie_id
HAVING COUNT(*) > 1;
```

### Query para ver películas vistas:

```sql
SELECT
  movie_id,
  movie_title,
  watched_at,
  rewatch_count
FROM user_watched_movies
WHERE user_id = 'YOUR_USER_ID'
ORDER BY watched_at DESC;
```

---

## 🎯 PRÓXIMOS PASOS DESPUÉS DE VERIFICAR

### 1. Aplicar a Watchlist

```dart
// Crear nuevo archivo: lib/core/sync/unified_watchlist_sync.dart
class UnifiedWatchlistSync extends UnifiedSyncBase<SyncableWatchlistItem> {
  // Copiar estructura de UnifiedFavoritesSync
  // Adaptar para watchlist
}
```

### 2. Crear provider de Watchlist

```dart
// En unified_sync_provider.dart agregar:
class UnifiedWatchlistNotifier extends Notifier<Map<int, SyncableWatchlistItem>> {
  // Copiar estructura de UnifiedFavoritesNotifier
  // Adaptar para watchlist
}
```

### 3. Actualizar repository de Watchlist

```dart
// Similar a HybridFavoritesRepository
final UnifiedWatchlistSync _unifiedSync = UnifiedWatchlistSync.instance;

@override
Future<void> addToWatchlist(Movie movie) async {
  await _localDatasource.add(movie);
  await _unifiedSync.addOrUpdateItem(userId, movie);
}
```

### 4. Inicializar en post-login

```dart
// En PostLoginInitializationService
Timer(const Duration(milliseconds: 120), () {
  ref.read(unifiedWatchlistProvider.notifier).enableAfterLogin();
});
```

---

## 📚 RECURSOS

### Documentación:

- **Arquitectura completa**: `docs/UNIFIED_SYNC_ARCHITECTURE.md`
- **Referencia rápida**: `docs/UNIFIED_SYNC_QUICK_REFERENCE.md`
- **Testing checklist**: `docs/UNIFIED_SYNC_TESTING_CHECKLIST.md`

### Código principal:

- Base: `lib/core/sync/unified_sync_base.dart`
- Favorites: `lib/core/sync/unified_favorites_sync.dart`
- Watched: `lib/core/sync/unified_watched_sync.dart`
- Providers: `lib/presentation/providers/unified_sync_provider.dart`

### Para debugging:

```dart
// Agregar más logs si necesitas:
LoggerFactory.debug('🔍 Debug info: $variable');
LoggerFactory.info('ℹ️ Info: $message');
LoggerFactory.warning('⚠️ Warning: $message');
LoggerFactory.error('❌ Error: $error');
```

---

## ✅ CHECKLIST FINAL

Antes de considerar completo:

- [ ] App compila sin errores
- [ ] Toggle favorites funciona
- [ ] Toggle watched funciona
- [ ] Datos persisten después de reload
- [ ] Real-time sync funciona (si tienes 2 dispositivos)
- [ ] Datos aparecen en Supabase
- [ ] No hay duplicados en Supabase
- [ ] Logs muestran flujo completo sin errores
- [ ] Offline → Online sync funciona

Si todos están ✅, el sistema está funcionando correctamente!

---

## 🎉 ÉXITO!

Si llegaste aquí y todos los tests pasan, **¡felicidades!**

Has implementado exitosamente una arquitectura unificada que:

- ✅ Elimina código duplicado
- ✅ Garantiza consistencia
- ✅ Facilita mantenimiento
- ✅ Escala fácilmente

**Próximo paso**: Aplicar el mismo patrón a Watchlist y cualquier otro sistema que necesites.

---

**Creado**: Octubre 1, 2025  
**Versión**: 1.0  
**Mantenedor**: Tu equipo de desarrollo
