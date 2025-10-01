# 🔍 DEBUG: Real-Time Sync - Logs Mejorados 2025-10-01

## ✅ CAMBIOS APLICADOS

### 1. Logging detallado en `unified_sync_provider.dart` (Favorites y Watched)

**Mejoras:**

- ✅ Verificación de `userId` antes de configurar stream
- ✅ Logs con userId específico para tracking
- ✅ Detección de eventos recibidos del stream
- ✅ Comparación de estados antes de actualizar UI
- ✅ Callbacks `onError` con stack trace completo
- ✅ Callback `onDone` para detectar cierre de stream
- ✅ Logs informativos en cada paso

### 2. Logging detallado en `unified_sync_base.dart`

**Mejoras:**

- ✅ Log de inicio con userId y tabla específica
- ✅ Log de datos crudos del stream (total de registros)
- ✅ Log después de filtrar por userId e is_deleted
- ✅ Warning cuando no hay items después de filtrar
- ✅ Stack trace completo en errores

---

## 📊 LOGS ESPERADOS

### Al iniciar la app:

```
🚀 Starting NON-BLOCKING post-login initialization
✅ UnifiedFavorites habilitado para sync tiempo real
✅ UnifiedWatched habilitado para sync tiempo real
```

### Al configurar real-time:

```
👀 [Favorites] Iniciando watchUserItems para user: 12345...
👀 [Favorites] Tabla: user_favorites
✅ [Favorites] Stream configurado correctamente para user_favorites
🎯 UnifiedFavorites: Configurando Real-Time Sync para user: 12345...
✅ UnifiedFavorites: Real-Time Sync listener activo para user: 12345...
```

### Al recibir eventos (toggle favorite):

```
📡 [Favorites] Stream emitió 5 registros totales
🔄 [Favorites] Real-time update: 5 items después de filtrar
🔄 UnifiedFavorites: Real-time update recibido - 5 items
📝 UnifiedFavorites: Actualizando state (4 -> 5)
```

### Si hay problemas:

```
⚠️ UnifiedFavorites: No user ID para real-time
⚠️ [Favorites] Sin items después de filtrar (userId: 12345...)
⚠️ UnifiedFavorites: Stream de real-time cerrado
❌ UnifiedFavorites: Real-time error: <error>
```

---

## 🧪 PASOS PARA DEBUGGING

### 1. Ejecutar app con logs:

```bash
flutter run -d chrome
```

### 2. Abrir Chrome DevTools → Console

### 3. Buscar estos logs al iniciar:

- ✅ "UnifiedFavorites habilitado"
- ✅ "Stream configurado correctamente"
- ✅ "Real-Time Sync listener activo"

### 4. Hacer toggle de un favorito y buscar:

- 📡 "Stream emitió X registros totales"
- 🔄 "Real-time update recibido"
- 📝 "Actualizando state"

---

## 🔧 SI EL PROBLEMA PERSISTE

### Si NO aparece "Stream configurado":

- El provider no se está inicializando
- Verificar que `enableAfterLogin()` se llama

### Si aparece "0 registros totales":

- El stream de Supabase no está recibiendo datos
- Verificar publicación: `supabase_realtime`
- Verificar permisos RLS

### Si aparece "X registros pero 0 después de filtrar":

- El userId no coincide
- El is_deleted está en true
- Agregar logs de userId en filtro

### Si aparece "Stream de real-time cerrado":

- El stream se canceló prematuramente
- Verificar que el provider no se recrea constantemente

---

## 📝 ARCHIVOS MODIFICADOS

1. `lib/presentation/providers/unified_sync_provider.dart`

   - Método `_setupRealtimeSync()` en `UnifiedFavoritesNotifier`
   - Método `_setupRealtimeSync()` en `UnifiedWatchedNotifier`
   - Agregado `_mapsAreEqual()` helper

2. `lib/core/sync/unified_sync_base.dart`
   - Método `watchUserItems()`

---

**Estado:** ✅ Logs mejorados implementados  
**Próximo paso:** Ejecutar app y revisar logs
