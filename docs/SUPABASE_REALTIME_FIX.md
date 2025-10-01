# Supabase Realtime Configuration Fix

**Fecha**: 2025-10-01
**Problema**: Las calificaciones no se sincronizan en tiempo real
**Causa**: La publicación `supabase_realtime` solo incluía `user_movie_ratings`, excluyendo otras tablas
**Estado**: 🔧 REQUIERE ACCIÓN EN SUPABASE

## 🚨 Problema Identificado

La migración original en `20250908120000_create_user_movie_ratings_table.sql` contenía este código problemático:

```sql
-- ❌ PROBLEMA: Esto SOBRESCRIBE la publicación existente
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE public.user_movie_ratings;
```

**Efecto**: Al crear la publicación solo para `user_movie_ratings`, se deshabilitó Realtime para:
- ❌ `user_favorites` (favoritos)
- ❌ `user_watchlist` (lista para ver)
- ❌ `user_watched` (películas vistas)
- ❌ `user_custom_lists` (listas personalizadas)
- ❌ `user_custom_list_items` (items de listas)

## ✅ Solución

Necesitas ejecutar el SQL de corrección en Supabase para incluir **TODAS** las tablas en la publicación.

### Método 1: Supabase Dashboard (RECOMENDADO) 👈

1. **Abre Supabase Dashboard**
   - Ve a: https://supabase.com/dashboard
   - Selecciona tu proyecto

2. **Abre SQL Editor**
   - En el menú lateral, busca "SQL Editor"
   - Click en "New Query"

3. **Copia y pega este SQL:**

```sql
-- Fix Realtime Publications for Multiple Tables
-- Corrects the supabase_realtime publication to include ALL tables

-- Step 1: Drop the incorrect publication
DROP PUBLICATION IF EXISTS supabase_realtime;

-- Step 2: Recreate publication with ALL tables that need realtime
CREATE PUBLICATION supabase_realtime FOR TABLE
    public.user_favorites,
    public.user_watchlist,
    public.user_watched,
    public.user_movie_ratings,
    public.user_custom_lists,
    public.user_custom_list_items;

-- Step 3: Verify the publication was created
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication
        WHERE pubname = 'supabase_realtime'
    ) THEN
        RAISE NOTICE '✅ Publication supabase_realtime created successfully';
    ELSE
        RAISE EXCEPTION '❌ Failed to create supabase_realtime publication';
    END IF;
END $$;

-- Step 4: Grant necessary permissions
GRANT ALL ON public.user_movie_ratings TO authenticated;
GRANT ALL ON public.user_movie_ratings TO service_role;
```

4. **Ejecuta la query**
   - Click en "Run" o presiona `Ctrl+Enter`
   - Deberías ver el mensaje: `✅ Publication supabase_realtime created successfully`

5. **Verifica la configuración**

Ejecuta esta query para confirmar:

```sql
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
```

Deberías ver 6 filas (una por cada tabla):
- ✅ user_favorites
- ✅ user_watchlist
- ✅ user_watched
- ✅ user_movie_ratings
- ✅ user_custom_lists
- ✅ user_custom_list_items

### Método 2: Supabase CLI

Si tienes Supabase CLI instalado:

```bash
# Aplicar todas las migraciones pendientes
supabase db push
```

### Método 3: Script PowerShell (Windows)

Ejecuta el script incluido:

```powershell
.\scripts\apply_realtime_fix.ps1
```

Este script:
- Lee las credenciales de `.env`
- Muestra las instrucciones
- Copia el SQL al portapapeles
- Te guía en el proceso

## 🔍 Verificación

### Paso 1: Verificar en Supabase

Ejecuta esta query en SQL Editor:

```sql
SELECT
    schemaname,
    tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;
```

**Resultado esperado:**
```
schemaname | tablename
-----------|-------------------------
public     | user_custom_list_items
public     | user_custom_lists
public     | user_favorites
public     | user_movie_ratings
public     | user_watched
public     | user_watchlist
```

### Paso 2: Test de Realtime

1. Abre la app en **Dispositivo A**
2. Abre la app en **Dispositivo B** con la misma cuenta
3. En Dispositivo A: Califica una película con 8.5/10
4. **Verifica**: En Dispositivo B debería aparecer la calificación **instantáneamente** (sin recargar)

### Paso 3: Revisar Logs

En la app, deberías ver estos logs (usa el debugger o revisa los logs de la consola):

```
🎯 DirectRatings: Setting up real-time sync for user: <userId>
✅ DirectRatings: Real-time sync configured
👀 [TriggerFreeRatings] Configurando stream en tiempo real para usuario: <userId>
```

Cuando se recibe una actualización:
```
🔄 [TriggerFreeRatings] Real-time update recibido: X ratings
🔄 DirectRatings: Real-time update received: X ratings
✅ DirectRatings: State updated from real-time sync: X ratings
```

## 🐛 Troubleshooting

### Problema 1: "No veo el mensaje de éxito al ejecutar el SQL"

**Causa**: Error en la sintaxis o permisos insuficientes

**Solución**:
1. Verifica que copiaste el SQL completo
2. Asegúrate de tener permisos de administrador en el proyecto
3. Revisa los mensajes de error en el panel de resultados

### Problema 2: "La query de verificación no muestra todas las tablas"

**Causa**: La publicación no se creó correctamente

**Solución**:
```sql
-- Verificar que existe la publicación
SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime';

-- Si no existe, ejecuta nuevamente el SQL de fix
```

### Problema 3: "Los cambios aún no se sincronizan en tiempo real"

**Posibles causas**:
1. La publicación no se aplicó correctamente
2. Problemas de red/firewall bloqueando WebSockets
3. La app no se reinició después del fix

**Soluciones**:
1. Verifica la publicación con la query de verificación
2. Asegúrate de que tu red permite conexiones WebSocket
3. **Cierra completamente la app** y vuelve a abrirla (kill process)
4. Verifica los logs en la consola para ver errores

### Problema 4: "Error: relation 'user_favorites' does not exist"

**Causa**: Alguna de las tablas mencionadas no existe en tu base de datos

**Solución**:
Modifica el SQL para incluir solo las tablas que existen:

```sql
-- Lista solo las tablas que EXISTEN en tu base de datos
CREATE PUBLICATION supabase_realtime FOR TABLE
    public.user_movie_ratings;
    -- Agrega solo las tablas que tengas creadas
```

Luego ejecuta esta query para ver qué tablas tienes:
```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename LIKE 'user_%';
```

## 📊 Configuración de Realtime en Supabase Dashboard

### Verificar que Realtime está habilitado globalmente:

1. Ve a **Database → Replication** en Supabase Dashboard
2. Verifica que `supabase_realtime` esté en la lista de publicaciones
3. Asegúrate de que está marcada como activa

### Habilitar Realtime para la tabla (UI):

Alternativamente, puedes configurarlo desde la UI:

1. Ve a **Database → Replication**
2. Busca la sección "Realtime"
3. Click en "Manage Replication"
4. Selecciona las tablas:
   - ✅ user_favorites
   - ✅ user_watchlist
   - ✅ user_watched
   - ✅ user_movie_ratings
   - ✅ user_custom_lists
   - ✅ user_custom_list_items
5. Click en "Save"

## 🎯 Después del Fix

Una vez aplicado correctamente:

1. ✅ **Calificaciones** se sincronizarán en tiempo real
2. ✅ **Favoritos** seguirán funcionando (no se rompen)
3. ✅ **Watchlist** seguirá funcionando
4. ✅ **Watched** seguirá funcionando
5. ✅ **Listas personalizadas** seguirán funcionando

**NO necesitas**:
- ❌ Reiniciar Supabase
- ❌ Redesplegar la app
- ❌ Modificar código

**SÍ necesitas**:
- ✅ Cerrar y reabrir la app (kill process completo)
- ✅ Hacer logout/login en la app (opcional, pero recomendado)

## 📝 Notas Importantes

1. **Seguridad**: Esta configuración respeta las RLS policies existentes
   - Los usuarios solo verán sus propios datos
   - Las políticas de seguridad siguen aplicándose

2. **Performance**: Realtime usa WebSockets que son eficientes
   - Bajo impacto en el rendimiento
   - Conexiones persistentes (no polling)

3. **Límites**: Supabase tiene límites de conexiones simultáneas
   - Plan gratuito: 200 conexiones simultáneas
   - Plan Pro: 500+ conexiones

4. **Compatibilidad**: Compatible con todas las funcionalidades existentes
   - No rompe código actual
   - Agrega funcionalidad sin quitar nada

## ✅ Checklist de Aplicación

Usa esta lista para verificar que todo está configurado:

- [ ] Ejecuté el SQL fix en Supabase SQL Editor
- [ ] Vi el mensaje: "✅ Publication supabase_realtime created successfully"
- [ ] La query de verificación muestra las 6 tablas (o las que tengo)
- [ ] Cerré completamente la app en todos los dispositivos
- [ ] Abrí la app nuevamente
- [ ] Hice logout/login
- [ ] Probé calificar una película en un dispositivo
- [ ] Verifiqué que apareció instantáneamente en otro dispositivo
- [ ] Revisé los logs y veo los mensajes de real-time sync
- [ ] ¡Todo funciona! 🎉

## 🆘 ¿Aún no funciona?

Si después de aplicar el fix sigue sin funcionar:

1. **Compartir logs**: Revisa los logs de la consola y busca errores
2. **Verificar red**: Asegúrate de que WebSockets no están bloqueados
3. **Revisar RLS**: Verifica que las policies permiten SELECT
4. **Probar con usuario nuevo**: A veces el cache del usuario causa problemas

**Comandos útiles para debugging**:

```dart
// En la app, agrega esto temporalmente para debug:
LoggerFactory.setLevel(LogLevel.debug);

// Verifica que el stream se está creando:
// Deberías ver: "👀 [TriggerFreeRatings] Configurando stream..."
```

## 🔗 Referencias

- **Supabase Realtime Docs**: https://supabase.com/docs/guides/realtime
- **PostgreSQL Publications**: https://www.postgresql.org/docs/current/sql-createpublication.html
- **Migración Fix**: [20251001_fix_realtime_publications.sql](../supabase/migrations/20251001_fix_realtime_publications.sql)
- **Script PowerShell**: [apply_realtime_fix.ps1](../scripts/apply_realtime_fix.ps1)

---

**Última actualización**: 2025-10-01
**Estado**: 🔧 REQUIERE EJECUCIÓN MANUAL EN SUPABASE
