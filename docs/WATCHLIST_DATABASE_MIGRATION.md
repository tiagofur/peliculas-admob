# 🗄️ Watchlist Database Migration

## 📋 Instrucciones de Aplicación

### 1. Aplicar Migración en Supabase

1. **Accede a tu Dashboard de Supabase**:
   - Ve a [https://supabase.com/dashboard](https://supabase.com/dashboard)
   - Selecciona tu proyecto: `fyzujpifkzftweynrudh`

2. **Ve a la sección SQL Editor**:
   - Clic en "SQL Editor" en el sidebar izquierdo

3. **Ejecuta la migración**:
   - Copia el contenido del archivo `supabase/migrations/create_user_watchlist_table.sql`
   - Pégalo en el editor SQL
   - Clic en "Run" para ejecutar

### 2. Verificar la Tabla Creada

Después de ejecutar la migración, deberías ver:

```sql
-- Verificar que la tabla existe
SELECT table_name, table_schema 
FROM information_schema.tables 
WHERE table_name = 'user_watchlist';

-- Verificar estructura de la tabla
\d user_watchlist;
```

### 3. Estructura de la Tabla

La tabla `user_watchlist` incluye:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | UUID | ID único (auto-generado) |
| `user_id` | UUID | Referencia al usuario |
| `movie_id` | INTEGER | ID de la película de TMDB |
| `movie_title` | VARCHAR(255) | Título de la película |
| `movie_poster_path` | TEXT | Ruta del poster |
| `movie_backdrop_path` | TEXT | Ruta del backdrop |
| `movie_overview` | TEXT | Sinopsis |
| `movie_release_date` | DATE | Fecha de lanzamiento |
| `movie_vote_average` | DECIMAL(3,1) | Puntuación promedio |
| `priority` | VARCHAR(10) | **'alta', 'normal', 'baja'** |
| `added_at` | TIMESTAMP | Fecha de agregado |
| `updated_at` | TIMESTAMP | Fecha de actualización |
| `deleted_at` | TIMESTAMP | Soft delete (nullable) |

### 4. Índices Creados

- **Único**: `(user_id, movie_id)` - Evita duplicados
- **Ordenamiento**: `added_at DESC` - Para orden cronológico
- **Filtrado**: `(priority, added_at DESC)` - Para filtros por prioridad
- **Usuario**: `(user_id, priority, added_at DESC)` - Consultas por usuario

### 5. Políticas de Seguridad (RLS)

La tabla incluye Row Level Security:
- Los usuarios solo pueden acceder a su propia watchlist
- Solo usuarios autenticados pueden realizar operaciones

### 6. Verificar Funcionamiento

Una vez aplicada la migración, puedes probar con:

```sql
-- Insertar datos de prueba (reemplaza 'your-user-id' con un UUID real)
INSERT INTO user_watchlist (
    user_id, 
    movie_id, 
    movie_title, 
    priority
) VALUES (
    'your-user-id', 
    123, 
    'Película de Prueba', 
    'alta'
);

-- Consultar datos
SELECT * FROM user_watchlist WHERE user_id = 'your-user-id';
```

## ⚠️ Notas Importantes

1. **Backup**: Siempre haz backup antes de aplicar migraciones
2. **Testing**: Prueba en un entorno de desarrollo primero
3. **RLS**: Las políticas de seguridad están habilitadas automáticamente
4. **Soft Delete**: La columna `deleted_at` se usa para sincronización entre dispositivos

## 🚨 En Caso de Error

Si encuentras errores:

1. **Verifica permisos**: Asegúrate de tener permisos de administrador en Supabase
2. **Revisa logs**: Checa los logs de error en el dashboard
3. **Rollback**: Puedes eliminar la tabla con `DROP TABLE user_watchlist;` si es necesario

## ✅ Verificación Final

Después de aplicar la migración exitosamente:
- ✅ Tabla `user_watchlist` existe
- ✅ Índices creados correctamente
- ✅ RLS habilitado y políticas aplicadas
- ✅ Triggers de `updated_at` funcionando

¡La base de datos está lista para usar el feature de Watchlist! 🎉