# ✅ Checklist de Verificación - Sistema Unificado de Sincronización

## 🎯 Objetivo

Verificar que el sistema unificado de sincronización funciona correctamente para Favorites y Watched.

---

## 📋 PRE-REQUISITOS

- [ ] Aplicación compilada sin errores
- [ ] Usuario autenticado en Supabase
- [ ] Conexión a internet disponible
- [ ] DevTools abierto para ver logs

---

## 🧪 TESTS DE FAVORITES

### Test 1: Toggle Favorite (Online)

**Objetivo**: Verificar que agregar/quitar favoritos sincroniza correctamente

1. [ ] Buscar una película que NO sea favorita
2. [ ] Hacer tap en el botón de favorito (corazón)
3. [ ] **Verificar**:
   - [ ] El ícono cambia INMEDIATAMENTE
   - [ ] Ver log: `✅ UnifiedFavorites: Toggle exitoso`
4. [ ] Cerrar la app completamente
5. [ ] Abrir la app nuevamente
6. [ ] **Verificar**: La película sigue marcada como favorita

### Test 2: Toggle Favorite Removal

1. [ ] Ir a una película que SÍ sea favorita
2. [ ] Hacer tap en el botón de favorito para quitarla
3. [ ] **Verificar**:
   - [ ] El ícono cambia INMEDIATAMENTE
   - [ ] Ver log: `✅ UnifiedFavorites: Toggle exitoso`
4. [ ] Cerrar y abrir la app
5. [ ] **Verificar**: La película ya NO está en favoritos

### Test 3: Sync entre Dispositivos (Favorites)

**Objetivo**: Verificar real-time sync

**Setup**: Necesitas 2 dispositivos/ventanas con la misma cuenta

1. [ ] **Dispositivo A**: Agregar película a favoritos
2. [ ] **Dispositivo B**: Esperar 2-5 segundos
3. [ ] **Verificar en B**:
   - [ ] La película aparece automáticamente
   - [ ] Ver log: `🔄 UnifiedFavorites: Real-time update`
4. [ ] **Dispositivo B**: Quitar la película de favoritos
5. [ ] **Dispositivo A**: Esperar 2-5 segundos
6. [ ] **Verificar en A**:
   - [ ] La película desaparece automáticamente
   - [ ] Ver log: `🔄 UnifiedFavorites: Real-time update`

### Test 4: Offline → Online Sync (Favorites)

**Objetivo**: Verificar sincronización offline

1. [ ] **DESCONECTAR** internet (modo avión)
2. [ ] Agregar 3 películas a favoritos
3. [ ] **Verificar**: Las películas se ven como favoritas localmente
4. [ ] Cerrar la app
5. [ ] **RECONECTAR** internet
6. [ ] Abrir la app
7. [ ] **Verificar**:
   - [ ] Ver log: `📤 HybridFavorites: Subiendo X favoritos locales`
   - [ ] Ver log: `✅ HybridFavorites: Sync completado`
8. [ ] En web browser, ir a Supabase Dashboard
9. [ ] **Verificar**: Las 3 películas están en tabla `user_favorites`

---

## 🎬 TESTS DE WATCHED

### Test 5: Marcar como Vista (Online)

1. [ ] Buscar una película que NO esté marcada como vista
2. [ ] Hacer tap en el botón de "marcar como vista"
3. [ ] **Verificar**:
   - [ ] El ícono cambia INMEDIATAMENTE
   - [ ] Ver log: `✅ HybridWatched: Marcado exitosamente`
4. [ ] Cerrar y abrir la app
5. [ ] **Verificar**: La película sigue marcada como vista

### Test 6: Remover de Vistas

1. [ ] Ir a una película marcada como vista
2. [ ] Hacer tap para desmarcarla
3. [ ] **Verificar**:
   - [ ] El ícono cambia INMEDIATAMENTE
   - [ ] Ver log: `✅ HybridWatched: Película X removida exitosamente`
4. [ ] Cerrar y abrir la app
5. [ ] **Verificar**: La película ya NO está marcada como vista

### Test 7: Sync entre Dispositivos (Watched)

**Setup**: 2 dispositivos/ventanas con la misma cuenta

1. [ ] **Dispositivo A**: Marcar película como vista
2. [ ] **Dispositivo B**: Esperar 2-5 segundos
3. [ ] **Verificar en B**:
   - [ ] La película aparece como vista
   - [ ] Ver log: `🔄 UnifiedWatched: Real-time update`
4. [ ] **Dispositivo B**: Desmarcar película
5. [ ] **Dispositivo A**: Esperar 2-5 segundos
6. [ ] **Verificar en A**:
   - [ ] La película ya no está como vista
   - [ ] Ver log: `🔄 UnifiedWatched: Real-time update`

### Test 8: Offline → Online Sync (Watched)

1. [ ] **DESCONECTAR** internet
2. [ ] Marcar 3 películas como vistas
3. [ ] **Verificar**: Se ven como vistas localmente
4. [ ] Cerrar la app
5. [ ] **RECONECTAR** internet
6. [ ] Abrir la app
7. [ ] **Verificar**:
   - [ ] Ver log: `📤 HybridWatched: Subiendo X películas locales`
   - [ ] Ver log: `✅ HybridWatched: Sync completado`
8. [ ] En Supabase Dashboard
9. [ ] **Verificar**: Las 3 películas están en `user_watched_movies`

---

## 🔄 TESTS DE INICIALIZACIÓN

### Test 9: Post-Login Initialization

1. [ ] Logout de la aplicación
2. [ ] Login nuevamente
3. [ ] **Verificar logs en orden**:
   ```
   ✅ UnifiedFavorites habilitado para sync tiempo real
   ✅ UnifiedWatched habilitado para sync tiempo real
   ✅ Auto-refresh habilitado
   ✅ DirectFavorites listeners habilitados
   ✅ DirectWatched listeners habilitados
   ```
4. [ ] **Verificar**: Los favoritos y películas vistas cargan correctamente

### Test 10: Cold Start (App cerrada)

1. [ ] Cerrar app completamente (kill process)
2. [ ] Abrir app
3. [ ] **Verificar logs**:
   ```
   📥 UnifiedFavorites: Cargando datos iniciales...
   ✅ UnifiedFavorites: X favoritos locales cargados
   🔄 UnifiedFavorites: Sincronizando con Supabase...
   ✅ UnifiedFavorites: X favoritos sincronizados
   🎯 UnifiedFavorites: Configurando Real-Time Sync...
   ✅ UnifiedFavorites: Real-Time Sync configurado
   ```
4. [ ] Repetir para Watched
5. [ ] **Verificar**: Todo carga sin errores

---

## 🚨 TESTS DE ERROR HANDLING

### Test 11: Rollback en Error

**Simular error de red durante sync**

1. [ ] **DESCONECTAR** internet justo después de hacer toggle
2. [ ] Toggle favorite/watched
3. [ ] **Verificar**:
   - [ ] UI muestra cambio inicial (optimistic)
   - [ ] Después de timeout, ver error en log
   - [ ] UI revierte al estado anterior (rollback)

### Test 12: Conflict Resolution

**2 dispositivos modifican el mismo item**

1. [ ] **Dispositivo A**: DESCONECTAR internet
2. [ ] **Dispositivo B**: DESCONECTAR internet
3. [ ] **Dispositivo A**: Agregar película a favoritos
4. [ ] **Dispositivo B**: Agregar la MISMA película a favoritos
5. [ ] **Dispositivo A**: RECONECTAR internet
6. [ ] Esperar sync completo
7. [ ] **Dispositivo B**: RECONECTAR internet
8. [ ] **Verificar**:
   - [ ] NO hay duplicados
   - [ ] Película está en favoritos en AMBOS dispositivos
   - [ ] Ver log: `✅ UnifiedFavorites: Sync completado`

---

## 📊 TESTS DE PERFORMANCE

### Test 13: Batch Sync

**Objetivo**: Verificar que batch sync funciona para muchos items

1. [ ] En Supabase, agregar manualmente 100+ favoritos
2. [ ] En app, hacer logout
3. [ ] Login nuevamente
4. [ ] **Verificar**:
   - [ ] Ver log: `📦 UnifiedFavorites: Sincronizando X items en lote`
   - [ ] Ver log: `✅ UnifiedFavorites: Lote 1 sincronizado`
   - [ ] Ver log: `✅ UnifiedFavorites: Lote 2 sincronizado` (si X > 50)
   - [ ] Todos los items cargan correctamente
5. [ ] **Tiempo de carga**: Debe ser < 10 segundos para 100 items

### Test 14: Real-Time Latency

**Objetivo**: Medir velocidad de real-time sync

1. [ ] **Dispositivo A**: Agregar favorite
2. [ ] **Medir tiempo**: Cuánto tarda en aparecer en Dispositivo B
3. [ ] **Objetivo**: < 3 segundos en buena conexión
4. [ ] **Verificar**: Cambio es smooth, sin parpadeos

---

## 🎯 TESTS DE UI/UX

### Test 15: Optimistic Updates

1. [ ] Toggle favorite en una película
2. [ ] **Verificar**:
   - [ ] UI responde INSTANTÁNEAMENTE (< 100ms)
   - [ ] No hay delay visible
   - [ ] No hay parpadeos/flickers
3. [ ] Repetir con marcando como vista
4. [ ] **Verificar**: Misma respuesta instantánea

### Test 16: Loading States

1. [ ] En cold start, observar carga inicial
2. [ ] **Verificar**:
   - [ ] Datos locales cargan PRIMERO (rápido)
   - [ ] Sync con Supabase es transparente
   - [ ] No bloquea la UI
   - [ ] No hay "loading spinners" innecesarios

---

## 🔍 VERIFICACIÓN EN SUPABASE

### Test 17: Data Integrity

1. [ ] En Supabase Dashboard, ir a tabla `user_favorites`
2. [ ] **Verificar estructura**:
   - [ ] `user_id` está correcto
   - [ ] `movie_id` es el ID correcto
   - [ ] `last_modified_at` tiene timestamp reciente
   - [ ] `sync_version` > 0
   - [ ] `is_deleted` = false
3. [ ] Repetir para `user_watched_movies`

### Test 18: No Duplicates

1. [ ] En Supabase, ejecutar query:
   ```sql
   SELECT user_id, movie_id, COUNT(*)
   FROM user_favorites
   WHERE user_id = 'YOUR_USER_ID'
   GROUP BY user_id, movie_id
   HAVING COUNT(*) > 1;
   ```
2. [ ] **Verificar**: Resultado está VACÍO (no duplicados)
3. [ ] Repetir para `user_watched_movies`

---

## ✅ RESUMEN DE VERIFICACIÓN

### Functionality

- [ ] Toggle favorites funciona
- [ ] Toggle watched funciona
- [ ] Sync bidireccional funciona
- [ ] Real-time sync funciona
- [ ] Offline sync funciona

### Performance

- [ ] Respuesta UI < 100ms
- [ ] Batch sync < 10s para 100 items
- [ ] Real-time latency < 3s

### Reliability

- [ ] No hay duplicados
- [ ] Rollback automático funciona
- [ ] Conflict resolution funciona
- [ ] Data integrity correcta

### User Experience

- [ ] Optimistic updates smooth
- [ ] No loading spinners innecesarios
- [ ] Funciona sin internet
- [ ] Multi-device sync transparente

---

## 🐛 SI ALGO FALLA

### Checklist de Debug:

1. [ ] Revisar logs en DevTools
2. [ ] Verificar conexión a Supabase
3. [ ] Verificar que usuario está autenticado
4. [ ] Revisar tabla en Supabase Dashboard
5. [ ] Verificar que real-time está habilitado en Supabase
6. [ ] Limpiar cache local (`flutter clean`)
7. [ ] Reinstalar app

### Logs Importantes:

```
✅ = Success
❌ = Error (revisar stack trace)
🔄 = Sync en progreso
📥 = Cargando datos
📤 = Subiendo datos
🎯 = Real-time configurado
```

---

## 📝 NOTAS

- Cada test debe pasar ANTES de continuar al siguiente
- Si un test falla, documentar el error antes de continuar
- Real-time puede tomar hasta 5 segundos en conexiones lentas
- Batch sync divide en chunks de 50 items automáticamente

---

**Fecha de creación**: Octubre 1, 2025  
**Versión**: 1.0  
**Estado**: Lista para testing
