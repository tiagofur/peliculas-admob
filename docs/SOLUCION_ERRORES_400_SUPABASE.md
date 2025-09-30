# Solución para Errores 400 en Supabase

## 🔴 Problema Detectado

Estás experimentando errores **400 Bad Request** al intentar guardar datos en Supabase:

```
POST https://fyzujpifkzftweynrudh.supabase.co/rest/v1/user_lists 400 (Bad Request)
POST https://fyzujpifkzftweynrudh.supabase.co/rest/v1/user_profiles?on_conflict=user_id&select=%2A 400 (Bad Request)
```

### Causa Raíz

El código Dart está intentando insertar columnas que **NO EXISTEN** en la base de datos:

#### user_profiles - Columnas Faltantes:

- ❌ `display_name` - El código lo envía, pero la tabla solo tiene `full_name`
- ❌ `email` - No existe en el esquema actual
- ❌ `last_active_date` - No existe en el esquema actual
- ❌ `banner_url` - No existe en el esquema actual
- ❌ `custom_fields` - No existe en el esquema actual
- ❌ **CRÍTICO**: Falta índice único en `user_id` (necesario para `upsert`)

#### user_lists - Columnas Faltantes:

- ❌ `emoji` - El código lo envía, pero no existe en la tabla
- ❌ `color` - La tabla tiene `color_hex` en su lugar
- ❌ `is_default` - No existe en el esquema actual
- ❌ `default_type` - No existe en el esquema actual
- ❌ `last_modified_at` - La tabla tiene `updated_at` en su lugar

---

## ✅ Solución

### Paso 1: Acceder a Supabase Dashboard

1. Ve a [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Selecciona tu proyecto: `peliculas-admob`
3. Ve a **SQL Editor** en el menú lateral

### Paso 2: Ejecutar Script de Corrección

1. Abre el archivo: `supabase/migrations/fix_schema_400_errors.sql`
2. **Copia TODO el contenido** del archivo
3. En Supabase Dashboard > SQL Editor:
   - Crea una nueva query
   - Pega el contenido completo
   - Haz clic en **Run** (o presiona `Ctrl+Enter`)

### Paso 3: Verificar Resultado

El script mostrará mensajes de diagnóstico y corrección:

✅ **Resultado Exitoso** - Deberías ver:

```
✅ user_profiles: Agregada columna display_name
✅ user_profiles: Agregada columna email
✅ user_profiles: Creado índice único en user_id
✅ user_lists: Agregada columna emoji
✅ user_lists: Renombrada columna color_hex a color
🎉 ¡CORRECCIÓN COMPLETADA CON ÉXITO!
```

⏭️ **Si ves estos mensajes** - Significa que las columnas ya existían:

```
⏭️ user_profiles: Columna display_name ya existe
⏭️ user_lists: Columna emoji ya existe
```

---

## 🧪 Verificación Post-Corrección

### 1. Verificar en Supabase Table Editor

Ve a **Table Editor** y verifica que las tablas tengan estas columnas:

#### `user_profiles` debe tener:

- ✅ `id` (UUID, primary key)
- ✅ `user_id` (UUID, con índice UNIQUE)
- ✅ `full_name` (VARCHAR)
- ✅ `display_name` (VARCHAR) ← **NUEVO**
- ✅ `email` (VARCHAR) ← **NUEVO**
- ✅ `bio` (TEXT)
- ✅ `avatar_url` (TEXT)
- ✅ `banner_url` (TEXT) ← **NUEVO**
- ✅ `last_active_date` (TIMESTAMPTZ) ← **NUEVO**
- ✅ `custom_fields` (JSONB) ← **NUEVO**
- ✅ `created_at` (TIMESTAMPTZ)
- ✅ `updated_at` (TIMESTAMPTZ)

#### `user_lists` debe tener:

- ✅ `id` (UUID, primary key)
- ✅ `user_id` (UUID)
- ✅ `name` (VARCHAR)
- ✅ `description` (TEXT)
- ✅ `emoji` (VARCHAR) ← **NUEVO**
- ✅ `color` (VARCHAR) ← **RENOMBRADO desde color_hex**
- ✅ `is_default` (BOOLEAN) ← **NUEVO**
- ✅ `default_type` (VARCHAR) ← **NUEVO**
- ✅ `is_public` (BOOLEAN)
- ✅ `last_modified_at` (TIMESTAMPTZ) ← **RENOMBRADO desde updated_at**
- ✅ `created_at` (TIMESTAMPTZ)

### 2. Probar en la Aplicación

1. **Limpia el caché de la app**:

   ```powershell
   flutter clean
   flutter pub get
   ```

2. **Reinicia la aplicación**:

   ```powershell
   flutter run
   ```

3. **Prueba las funciones afectadas**:
   - ✅ Iniciar sesión / Registro de usuario
   - ✅ Cargar perfil de usuario
   - ✅ Crear listas personalizadas
   - ✅ Agregar películas a listas

---

## 🔍 Qué Hace el Script

El script `fix_schema_400_errors.sql` realiza las siguientes acciones:

### Diagnóstico (Paso 1)

- Lista todas las columnas actuales de ambas tablas
- Identifica qué está faltando

### Correcciones en user_profiles (Paso 2)

1. Agrega columnas faltantes: `display_name`, `email`, `last_active_date`, `banner_url`, `custom_fields`
2. Hace que `full_name` sea nullable (opcional)
3. **CRÍTICO**: Crea índice único en `user_id` (necesario para `upsert`)
4. Actualiza triggers para mantener `updated_at` automáticamente

### Correcciones en user_lists (Paso 3)

1. Agrega columnas faltantes: `emoji`, `is_default`, `default_type`
2. Renombra `color_hex` → `color`
3. Renombra `updated_at` → `last_modified_at`
4. Agrega columnas de sincronización: `sync_version`, `device_id`, `is_deleted`, `sync_status`
5. Actualiza triggers para sincronización

### Verificación Final (Paso 5)

- Cuenta las columnas críticas
- Verifica la existencia del índice único
- Muestra un resumen del estado final

---

## 🚨 Si el Error Persiste

### Opción 1: Ejecutar Migraciones Individuales

Si `fix_schema_400_errors.sql` no resuelve todo, ejecuta estos archivos en orden:

1. `fix_user_profiles_simple.sql` - Corrige solo user_profiles
2. `fix_user_lists_schema.sql` - Corrige solo user_lists

### Opción 2: Verificar Logs de Error

En la consola del navegador (DevTools), busca el mensaje de error completo:

```javascript
// Ejemplo de error detallado
{
  "code": "42703",
  "message": "column \"display_name\" of relation \"user_profiles\" does not exist",
  "details": null,
  "hint": null
}
```

Esto te dirá **exactamente** qué columna está causando el problema.

### Opción 3: Verificar Políticas RLS

Si las columnas existen pero el error persiste, verifica las políticas de seguridad:

```sql
-- Ver políticas de user_profiles
SELECT * FROM pg_policies WHERE tablename = 'user_profiles';

-- Ver políticas de user_lists
SELECT * FROM pg_policies WHERE tablename = 'user_lists';
```

Las políticas deben permitir `INSERT` y `UPDATE` para el usuario autenticado.

---

## 📞 Soporte Adicional

Si después de seguir estos pasos el problema persiste:

1. **Exporta el esquema actual**:

   ```sql
   -- En Supabase SQL Editor
   SELECT column_name, data_type, is_nullable
   FROM information_schema.columns
   WHERE table_name IN ('user_profiles', 'user_lists')
   AND table_schema = 'public'
   ORDER BY table_name, ordinal_position;
   ```

2. **Captura el error completo** desde la consola del navegador

3. **Verifica los logs de Supabase**:
   - Ve a **Logs** > **API Logs** en Supabase Dashboard
   - Filtra por status code `400`
   - Copia el mensaje de error completo

---

## 📝 Resumen

- ✅ **Script de corrección**: `supabase/migrations/fix_schema_400_errors.sql`
- ✅ **Acción**: Ejecutar en Supabase Dashboard > SQL Editor
- ✅ **Tiempo estimado**: 1-2 minutos
- ✅ **Efecto**: Agrega todas las columnas faltantes y corrige nombres
- ✅ **Reversible**: Sí (las columnas se pueden eliminar si es necesario)

**¡Esto debería resolver los errores 400 completamente!** 🎉
