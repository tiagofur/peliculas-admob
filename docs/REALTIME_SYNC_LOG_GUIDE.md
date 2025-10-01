# 🎯 Guía de Logs para Real-Time Sync

## 📍 DÓNDE VER LOS LOGS

**Chrome DevTools → Console**

- Abre con: `F12` o `Ctrl+Shift+I` (Windows/Linux) o `Cmd+Option+I` (Mac)
- Tab: **Console**

---

## 🔍 QUÉ BUSCAR EN LOS LOGS

### 1️⃣ Al iniciar la app (después de login)

Busca estos mensajes **en orden**:

```
🚀 Starting NON-BLOCKING post-login initialization for user: <userId>
```

✅ **Significa:** El servicio de inicialización post-login está funcionando

```
✅ UnifiedFavorites habilitado para sync tiempo real
```

✅ **Significa:** El provider de Favorites se activó correctamente

```
✅ UnifiedWatched habilitado para sync tiempo real
```

✅ **Significa:** El provider de Watched se activó correctamente

---

### 2️⃣ Al configurar el stream de Favorites

```
👀 [Favorites] Iniciando watchUserItems para user: <userId>
👀 [Favorites] Tabla: user_favorites
✅ [Favorites] Stream configurado correctamente para user_favorites
```

✅ **Significa:** El stream de Supabase se configuró bien

```
🎯 UnifiedFavorites: Configurando Real-Time Sync para user: <userId>
✅ UnifiedFavorites: Real-Time Sync listener activo para user: <userId>
```

✅ **Significa:** El listener está esperando eventos

---

### 3️⃣ Al hacer toggle de un favorito

**Inmediatamente después de hacer clic en ❤️:**

```
📡 [Favorites] Stream emitió X registros totales
```

✅ **Esperado:** X > 0 (debe haber al menos 1 registro)
❌ **Problema:** X = 0 → El stream no está recibiendo datos de Supabase

```
🔄 [Favorites] Real-time update: Y items después de filtrar
```

✅ **Esperado:** Y > 0 (tus favoritos después de filtrar)
❌ **Problema:** Y = 0 pero X > 0 → El filtro no funciona (verifica userId)

```
🔄 UnifiedFavorites: Real-time update recibido - Y items
```

✅ **Esperado:** Debe aparecer con el mismo número Y
❌ **Problema:** No aparece → El listener no está funcionando

```
📝 UnifiedFavorites: Actualizando state (A -> B)
```

✅ **Esperado:** A < B cuando agregas, A > B cuando quitas
❌ **Problema:** No aparece → El state no se está actualizando

---

### 4️⃣ Mensajes de WARNING/ERROR

```
⚠️ UnifiedFavorites: No user ID para real-time
```

❌ **Problema:** No hay usuario autenticado o el userId es null

```
⚠️ [Favorites] Sin items después de filtrar (userId: <userId>)
```

⚠️ **Posible problema:**

- No tienes favoritos en Supabase
- El userId en la tabla no coincide con el userId del filtro
- El campo `is_deleted` está en true

```
⚠️ UnifiedFavorites: Stream de real-time cerrado
```

❌ **Problema:** El stream se cerró inesperadamente

- El provider se recreó
- La conexión a Supabase falló
- Se hizo logout

```
❌ UnifiedFavorites: Real-time error: <error>
```

❌ **Problema:** Error en el stream de Supabase

- Lee el mensaje de error para más detalles

---

## 🧪 PRUEBAS A REALIZAR

### Prueba 1: Agregar favorito

1. Buscar una película (ej: "Inception")
2. Click en ❤️ (agregar a favoritos)
3. **Verificar en logs:**
   - ✅ `Stream emitió X registros` (X > 0)
   - ✅ `Real-time update: Y items` (Y = X o Y < X si hay filtrado)
   - ✅ `Actualizando state (4 -> 5)` (ejemplo)
4. **Verificar en UI:**
   - ❤️ debe cambiar a rojo **INMEDIATAMENTE**
   - **NO debe requerir refresh**

### Prueba 2: Quitar favorito

1. En una película favorita (❤️ rojo)
2. Click en ❤️ (quitar de favoritos)
3. **Verificar en logs:**
   - ✅ `Stream emitió X registros` (X >= 0)
   - ✅ `Real-time update: Y items` (Y = X-1)
   - ✅ `Actualizando state (5 -> 4)` (ejemplo)
4. **Verificar en UI:**
   - ❤️ debe cambiar a gris **INMEDIATAMENTE**
   - **NO debe requerir refresh**

### Prueba 3: Multi-dispositivo (si tienes 2 tabs)

1. Abrir app en 2 tabs de Chrome
2. Login en ambas con el mismo usuario
3. En Tab 1: Agregar favorito
4. **Verificar en Tab 2:**
   - ✅ Los logs deben mostrar `Real-time update recibido`
   - ✅ El ❤️ debe cambiar a rojo **AUTOMÁTICAMENTE**

---

## 📊 INTERPRETACIÓN DE RESULTADOS

### ✅ CASO 1: Todo funciona perfectamente

```
📡 Stream emitió 5 registros totales
🔄 Real-time update: 5 items después de filtrar
🔄 UnifiedFavorites: Real-time update recibido - 5 items
📝 Actualizando state (4 -> 5)
```

**→ Real-time sync está funcionando correctamente**
**→ No hay problema**

---

### ❌ CASO 2: Stream no recibe datos

```
📡 Stream emitió 0 registros totales
⚠️ Sin items después de filtrar
```

**→ Problema: Publicación de Supabase**

**Solución:**

1. Ir a Supabase Dashboard
2. Database → Publications
3. Verificar que `supabase_realtime` incluye `user_favorites`
4. Si no existe, ejecutar:

```sql
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE
    public.user_favorites,
    public.user_watched,
    public.user_watchlist,
    public.user_movie_ratings,
    public.user_lists,
    public.user_list_items;
```

---

### ❌ CASO 3: Stream recibe datos pero filtra todo

```
📡 Stream emitió 10 registros totales
🔄 Real-time update: 0 items después de filtrar
```

**→ Problema: Filtrado por userId**

**Solución:**

1. Verificar userId en logs: `Configurando Real-Time Sync para user: <userId>`
2. Verificar userId en Supabase:

```sql
SELECT user_id, movie_id, movie_title
FROM user_favorites
LIMIT 5;
```

3. Comparar ambos UUIDs - deben coincidir

---

### ❌ CASO 4: Stream funciona pero UI no actualiza

```
📡 Stream emitió 5 registros totales
🔄 Real-time update: 5 items después de filtrar
🔄 UnifiedFavorites: Real-time update recibido - 5 items
⏭️ UnifiedFavorites: Sin cambios en state, ignorando update
```

**→ Problema: El state ya estaba actualizado**

**Posible causa:**

- La UI ya se actualizó antes (optimistic update)
- El real-time llegó tarde pero ya habías guardado localmente

**Esto es NORMAL y esperado** - significa que el optimistic update funcionó.

---

### ❌ CASO 5: No aparece ningún log de real-time

```
(No hay logs con emojis 👀 📡 🔄)
```

**→ Problema: El provider no se está inicializando**

**Solución:**

1. Verificar que `PostLoginInitializationService` se está llamando
2. Buscar log: `UnifiedFavorites habilitado para sync tiempo real`
3. Si no aparece, revisar `post_login_initialization_service.dart`

---

## 🛠️ COMANDOS ÚTILES EN SUPABASE

### Verificar publicación:

```sql
SELECT tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;
```

### Verificar datos en tabla:

```sql
SELECT * FROM user_favorites
WHERE user_id = '<tu_user_id>'
LIMIT 10;
```

### Verificar políticas RLS:

```sql
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'user_favorites';
```

---

## 📞 REPORTAR PROBLEMA

Si el problema persiste, copia estos logs:

1. **Logs de inicialización:**

   - Los primeros logs con 🚀 y ✅

2. **Logs del stream:**

   - Los logs con 👀 y 📡

3. **Logs del evento:**

   - Los logs con 🔄 y 📝 (o la ausencia de ellos)

4. **Mensajes de error:**

   - Cualquier log con ⚠️ o ❌

5. **Resultado de la query de Supabase:**

```sql
SELECT COUNT(*) as total,
       COUNT(CASE WHEN is_deleted = false THEN 1 END) as activos
FROM user_favorites
WHERE user_id = '<tu_user_id>';
```

---

**Fecha:** 2025-10-01  
**Archivo relacionado:** `docs/REALTIME_SYNC_LOGGING_2025_10_01.md`
