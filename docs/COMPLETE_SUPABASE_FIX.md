## 🔧 GUÍA COMPLETA: Fix de Supabase para Realtime Sync

**Fecha**: 2025-10-01
**Problema**: Calificaciones no se sincronizan en tiempo real
**Causa**: Nombres de tablas inconsistentes + Configuración incorrecta de Realtime
**Solución**: 2 migraciones SQL en Supabase

---

## 📋 Resumen de Cambios

### Problemas Identificados:
1. ❌ Tabla `user_watched_movies` tiene nombre inconsistente (debería ser `user_watched`)
2. ❌ Publicación `supabase_realtime` solo incluía `user_movie_ratings`
3. ❌ Otras tablas (`user_favorites`, `user_watched`) no estaban en Realtime

### Solución:
1. ✅ Renombrar `user_watched_movies` → `user_watched`
2. ✅ Actualizar código para usar `user_watched`
3. ✅ Recrear publicación con TODAS las tablas

---

## 🚀 PASOS A SEGUIR EN SUPABASE

### **Paso 1: Renombrar Tabla (CRÍTICO)**

Ejecuta este SQL en **Supabase Dashboard → SQL Editor**:

```sql
-- Renombrar user_watched_movies a user_watched
ALTER TABLE IF EXISTS public.user_watched_movies
RENAME TO user_watched;

-- Verificar el renombre
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename = 'user_watched'
    ) THEN
        RAISE NOTICE '✅ Table successfully renamed to user_watched';
    ELSE
        RAISE EXCEPTION '❌ Failed to rename table to user_watched';
    END IF;

    -- Verificar que la tabla vieja no existe
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename = 'user_watched_movies'
    ) THEN
        RAISE WARNING '⚠️ Old table user_watched_movies still exists!';
    END IF;
END $$;

-- Permisos para la tabla renombrada
GRANT ALL ON public.user_watched TO authenticated;
GRANT ALL ON public.user_watched TO service_role;

-- Comentario
COMMENT ON TABLE public.user_watched IS 'Stores movies watched by users (renamed from user_watched_movies for consistency)';
```

**Resultado esperado**: Deberías ver `✅ Table successfully renamed to user_watched`

---

### **Paso 2: Configurar Realtime para TODAS las Tablas**

Ejecuta este SQL **DESPUÉS** del Paso 1:

```sql
-- Fix completo de Realtime Publications

-- Step 1: Drop the incorrect publication
DROP PUBLICATION IF EXISTS supabase_realtime;

-- Step 2: Recreate publication with ALL existing tables
CREATE PUBLICATION supabase_realtime FOR TABLE
    public.user_favorites,
    public.user_watched,
    public.user_movie_ratings;

-- Step 3: Verify the publication was created
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication
        WHERE pubname = 'supabase_realtime'
    ) THEN
        RAISE NOTICE '✅ Publication supabase_realtime created successfully with 3 tables';
    ELSE
        RAISE EXCEPTION '❌ Failed to create supabase_realtime publication';
    END IF;
END $$;

-- Step 4: Grant necessary permissions
GRANT ALL ON public.user_favorites TO authenticated;
GRANT ALL ON public.user_favorites TO service_role;
GRANT ALL ON public.user_watched TO authenticated;
GRANT ALL ON public.user_watched TO service_role;
GRANT ALL ON public.user_movie_ratings TO authenticated;
GRANT ALL ON public.user_movie_ratings TO service_role;

-- Step 5: Add comment
COMMENT ON PUBLICATION supabase_realtime IS 'Realtime publication for user_favorites, user_watched, and user_movie_ratings tables';
```

**Resultado esperado**: `✅ Publication supabase_realtime created successfully with 3 tables`

---

### **Paso 3: Verificar la Configuración**

Ejecuta esta query para confirmar:

```sql
SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;
```

**Deberías ver exactamente 3 filas:**
```
tablename
-------------------
user_favorites
user_movie_ratings
user_watched
```

---

## ✅ Verificación Final

### 1. **Verificar que la tabla se renombró**:
```sql
-- Debe devolver 1 fila
SELECT * FROM user_watched LIMIT 1;

-- NO debe devolver nada (tabla ya no existe)
SELECT * FROM user_watched_movies LIMIT 1;
```

### 2. **Verificar permisos**:
```sql
SELECT grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_name IN ('user_favorites', 'user_watched', 'user_movie_ratings')
AND grantee IN ('authenticated', 'service_role')
ORDER BY table_name, grantee;
```

### 3. **Verificar Realtime**:
```sql
-- Debe mostrar las 3 tablas
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
```

---

## 🧪 Probar la Sincronización

### Test en la App:

1. **Cerrar COMPLETAMENTE la app** en todos los dispositivos (kill process)
2. Abrir app en **Dispositivo A**
3. Abrir app en **Dispositivo B** (misma cuenta)
4. En Dispositivo A: **Calificar una película** (ej: 8.5/10)
5. **Verificar Dispositivo B**: La calificación debe aparecer **INSTANTÁNEAMENTE** sin recargar

### Logs Esperados:

Deberías ver en la consola:

```
🎯 DirectRatings: Setting up real-time sync for user: <userId>
✅ DirectRatings: Real-time sync configured
👀 [TriggerFreeRatings] Configurando stream en tiempo real...
```

Al recibir actualización:
```
🔄 [TriggerFreeRatings] Real-time update recibido: X ratings
🔄 DirectRatings: Real-time update received: X ratings
✅ DirectRatings: State updated from real-time sync: X ratings
```

---

## ⚠️ Importante

### NO olvides:
1. ✅ Ejecutar **AMBOS** SQLs (Paso 1 y Paso 2)
2. ✅ Ejecutar en el **orden correcto** (primero renombrar, luego realtime)
3. ✅ Cerrar completamente la app después de los cambios

### Cambios en el Código:
- ✅ **Ya están aplicados** - Todo el código ahora usa `user_watched`
- ✅ No necesitas cambiar nada en la app
- ✅ Solo necesitas ejecutar los SQLs en Supabase

---

## 🔍 Troubleshooting

### Error: "relation 'user_watched_movies' does not exist"
**Solución**: Ya ejecutaste el Paso 1 anteriormente. Continúa con el Paso 2.

### Error: "relation 'user_watched' does not exist"
**Solución**: Ejecuta primero el Paso 1 para renombrar la tabla.

### La sincronización no funciona
**Posibles causas**:
1. No ejecutaste el Paso 2
2. La publicación no se creó correctamente
3. No cerraste completamente la app

**Solución**:
```sql
-- Verificar estado de la publicación
SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime';

-- Si no existe, ejecuta el Paso 2 nuevamente
```

### "No veo los cambios en tiempo real"
1. Cierra completamente la app (kill process)
2. Reabre la app
3. Haz logout/login
4. Verifica los logs

---

## 📊 Archivos Modificados en el Código

✅ Todos ya actualizados automáticamente:

| Archivo | Cambio |
|---------|--------|
| `lib/core/sync/trigger_free_watched_sync.dart` | ✅ `user_watched_movies` → `user_watched` |
| `lib/core/sync/watched_sync_manager.dart` | ✅ Actualizado |
| `lib/infrastructure/repositories/hybrid_watched_repository.dart` | ✅ Actualizado |
| `lib/presentation/providers/storage/direct_watched_provider.dart` | ✅ Actualizado |
| Todos los archivos de test | ✅ Actualizados |

**Análisis**: ✅ `flutter analyze` pasa sin errores

---

## 🎉 Resultado Final

Después de aplicar los 2 SQLs:

| Feature | Estado |
|---------|--------|
| Tabla `user_watched` renombrada | ✅ |
| Código actualizado | ✅ |
| Realtime para `user_favorites` | ✅ |
| Realtime para `user_watched` | ✅ |
| Realtime para `user_movie_ratings` | ✅ |
| Sincronización instantánea | ⚡ ✅ |

---

## 📝 Resumen de Comandos

**Copy-Paste Ready** - Ejecuta estos 2 bloques en orden:

### 1️⃣ PRIMERO - Renombrar Tabla:
```sql
ALTER TABLE IF EXISTS public.user_watched_movies RENAME TO user_watched;
GRANT ALL ON public.user_watched TO authenticated;
GRANT ALL ON public.user_watched TO service_role;
```

### 2️⃣ SEGUNDO - Configurar Realtime:
```sql
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE
    public.user_favorites,
    public.user_watched,
    public.user_movie_ratings;
GRANT ALL ON public.user_favorites TO authenticated;
GRANT ALL ON public.user_favorites TO service_role;
GRANT ALL ON public.user_watched TO authenticated;
GRANT ALL ON public.user_watched TO service_role;
GRANT ALL ON public.user_movie_ratings TO authenticated;
GRANT ALL ON public.user_movie_ratings TO service_role;
```

### 3️⃣ VERIFICAR:
```sql
SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;
```

**Debe mostrar**: `user_favorites`, `user_movie_ratings`, `user_watched`

---

¡Listo! 🚀 Ahora tu app tendrá sincronización en tiempo real completa para todas las funcionalidades.
