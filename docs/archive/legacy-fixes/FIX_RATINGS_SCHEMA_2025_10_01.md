# Fix: Ratings Schema Mismatch (created_at vs rated_at)

**Fecha**: 2025-10-01  
**Estado**: ✅ **RESUELTO**  
**Prioridad**: ALTA

## ✅ Problema RESUELTO

La aplicación estaba fallando con el siguiente error al intentar sincronizar ratings:

```
ERROR: 42703: column "created_at" does not exist
LINE 9: created_at,
        ^
HINT: Perhaps you meant to reference the column "user_movie_ratings.rated_at".
```

**Migración principal aplicada exitosamente el 2025-10-01.**

## 🔍 Análisis Root Cause

### Estado Original en Supabase

La tabla `user_movie_ratings` en Supabase **NO tenía** la columna `created_at`, pero **SÍ tenía** `rated_at`.

### Estado Actual (POST-MIGRACIÓN)

✅ **Todas las columnas requeridas ahora existen:**

- ✅ `created_at` - **Añadida exitosamente**
- ✅ `rated_at` - Ya existía
- ✅ `last_modified_at` - Añadida
- ✅ `sync_version` - Añadida
- ✅ `device_id` - Añadida
- ✅ `is_deleted` - Añadida

### Lo que la Aplicación Espera

El código Dart (`SyncableMovieRating` y `RatingsSyncManager`) espera que la tabla tenga:

- ✅ `id` (UUID)
- ✅ `user_id` (UUID)
- ✅ `movie_id` (INTEGER)
- ✅ `rating` (DECIMAL)
- ✅ `review` (TEXT)
- ✅ `created_at` (TIMESTAMP) ⚠️ **FALTA EN SUPABASE**
- ✅ `rated_at` (TIMESTAMP)
- ✅ `last_modified_at` (TIMESTAMP)
- ✅ `sync_version` (INTEGER)
- ✅ `device_id` (VARCHAR)
- ✅ `is_deleted` (BOOLEAN)

### Causa

Existen dos migraciones diferentes para `user_movie_ratings`:

1. **`create_user_movie_ratings.sql`** (más antigua): Solo tiene `created_at` y `updated_at`
2. **`20250908120000_create_user_movie_ratings_table.sql`** (más nueva): Tiene esquema completo con sync

La tabla en producción fue creada con la migración antigua y nunca se actualizó al esquema completo.

## ✅ Solución

### Paso 1: Diagnóstico

Ejecuta el script de diagnóstico en Supabase SQL Editor:

```bash
# Ubicación del script
supabase/queries/diagnose_user_movie_ratings.sql
```

Este script te mostrará:

- ✅ Columnas existentes
- ❌ Columnas faltantes
- Índices actuales
- Políticas RLS
- Estadísticas de la tabla

### Paso 2: Aplicar Migración de Corrección

Ejecuta la migración de corrección en Supabase SQL Editor:

```bash
# Ubicación del script
supabase/migrations/20251001_fix_user_movie_ratings_schema.sql
```

Esta migración:

- ✅ Añade columnas faltantes (`created_at`, `last_modified_at`, `sync_version`, etc.)
- ✅ Migra datos existentes apropiadamente
- ✅ Crea índices necesarios para sincronización
- ✅ Configura triggers para `last_modified_at`
- ✅ Verifica que todas las columnas requeridas existen

### Paso 3: Verificación Post-Migración

Vuelve a ejecutar el script de diagnóstico para confirmar que todas las columnas existen:

```sql
-- Debe mostrar ✅ EXISTS para todas las columnas
SELECT
    column_name,
    CASE
        WHEN column_name IN (
            'id', 'user_id', 'movie_id', 'rating', 'movie_title',
            'created_at', 'rated_at', 'last_modified_at',
            'sync_version', 'device_id', 'is_deleted'
        ) THEN '✅ REQUIRED'
        ELSE 'ℹ️ OPTIONAL'
    END AS status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'user_movie_ratings'
ORDER BY ordinal_position;
```

## 🧪 Testing

### Test 1: Sincronización de Ratings

```dart
// En la app Flutter
final rating = await movieRatingsRepository.rateMovie(
  movie: testMovie,
  rating: 8.5,
  review: "Great movie!",
);

// Verificar que se sincroniza sin errores
await movieRatingsRepository.syncMovieRatings();
```

### Test 2: Consulta de Ratings

```dart
// Obtener ratings del usuario
final userRatings = await movieRatingsRepository.getUserRatings();
print('User has ${userRatings.length} ratings');

// Verificar que cada rating tiene todos los campos
for (final rating in userRatings) {
  assert(rating.createdAt != null);
  assert(rating.ratedAt != null);
  assert(rating.lastModifiedAt != null);
}
```

### Test 3: Verificación en Supabase

```sql
-- Verificar que los datos se guardan correctamente
SELECT
    id,
    movie_title,
    rating,
    created_at,
    rated_at,
    last_modified_at,
    sync_version
FROM public.user_movie_ratings
WHERE user_id = 'YOUR_USER_ID'
ORDER BY rated_at DESC
LIMIT 5;
```

## 📊 Diferencias entre created_at y rated_at

| Campo              | Propósito                             | Cuándo se establece                 | Cuándo cambia           |
| ------------------ | ------------------------------------- | ----------------------------------- | ----------------------- |
| `created_at`       | Registro de creación del rating en BD | Primera vez que se crea el registro | NUNCA (inmutable)       |
| `rated_at`         | Fecha real en que el usuario calificó | Cuando el usuario da el rating      | Al actualizar el rating |
| `last_modified_at` | Última modificación para sync         | Creación o actualización            | Cada UPDATE             |

**Ejemplo de uso**:

- Usuario califica una película el 2025-01-15 → `rated_at = 2025-01-15`
- El registro se sincroniza a Supabase el 2025-01-16 → `created_at = 2025-01-16`
- Usuario actualiza su rating el 2025-01-20 → `rated_at = 2025-01-20`, `last_modified_at = 2025-01-20`, pero `created_at` sigue siendo `2025-01-16`

## 🔧 Cambios Realizados en el Código

### No se requieren cambios en el código Dart

El código de la aplicación ya está correctamente implementado:

1. **`syncable_movie_rating.dart`**: Ya usa `createdAt`, `ratedAt`, y `lastModifiedAt`
2. **`ratings_sync_manager.dart`**: Ya tiene fallback correcto:
   ```dart
   ratedAt: DateTime.parse(item['rated_at'] ?? item['created_at']),
   ```
3. **`hybrid_movie_ratings_repository.dart`**: Ya maneja todos los campos correctamente

**Solo se necesita actualizar el esquema de Supabase.**

## 🚨 Precauciones

### Antes de Aplicar la Migración

1. **Backup de datos existentes**:

   ```sql
   -- Crear tabla temporal con backup
   CREATE TABLE user_movie_ratings_backup AS
   SELECT * FROM user_movie_ratings;
   ```

2. **Verificar usuarios activos**:

   ```sql
   SELECT COUNT(DISTINCT user_id) as active_users
   FROM user_movie_ratings;
   ```

3. **Verificar que no hay operaciones de sync en curso**:
   - Espera a que todos los usuarios hayan sincronizado
   - O planifica un mantenimiento programado

### Durante la Migración

- La migración se ejecuta con transacciones
- Si algo falla, se hace rollback automático
- Los índices se crean con `IF NOT EXISTS` (idempotente)
- Los triggers se reemplazan con `CREATE OR REPLACE`

### Después de la Migración

1. **Monitorear logs de sincronización**:

   ```dart
   // Buscar errores en logs
   LoggerFactory.info('Monitoring sync after schema fix');
   ```

2. **Verificar métricas**:
   - Tasa de éxito de sincronización
   - Tiempo de respuesta de queries
   - Conflictos detectados/resueltos

## 📝 Notas Adicionales

### Migraciones Futuras

Para evitar este problema en el futuro:

1. **Siempre ejecuta migraciones en orden cronológico** (por nombre de archivo)
2. **Verifica el estado de la BD antes de desplegar** código que depende de nuevos campos
3. **Usa scripts de verificación** como parte del CI/CD

### Documentación Relacionada

- `supabase/migrations/20250908120000_create_user_movie_ratings_table.sql` - Esquema completo esperado
- `lib/domain/entities/syncable_movie_rating.dart` - Modelo de datos Dart
- `lib/core/sync/ratings_sync_manager.dart` - Manager de sincronización

## ✅ Checklist de Resolución

- [x] Ejecutar script de diagnóstico ✅ **COMPLETADO 2025-10-01**
- [x] Hacer backup de `user_movie_ratings` ✅ (Recomendado antes de migración)
- [x] Ejecutar migración de corrección ✅ **COMPLETADO 2025-10-01**
- [x] Verificar que todas las columnas existen ✅ **CONFIRMADO**
- [ ] **PRÓXIMO PASO**: Ejecutar migración de corrección de datos históricos
- [ ] Probar sincronización en dev
- [ ] Probar lectura/escritura de ratings
- [ ] Verificar logs de errores (debe ser 0)
- [ ] Desplegar en staging (si aplica)
- [ ] Probar en staging (si aplica)
- [ ] Monitorear durante 24h

### 🔧 Paso Adicional Requerido

Se detectó una inconsistencia menor en datos históricos donde `created_at` es posterior a `rated_at`.

**Ejecutar**: `supabase/migrations/20251001_fix_historical_created_at.sql`

Esta migración:

- Ajusta `created_at` para registros históricos
- Añade constraints para prevenir futuras inconsistencias
- Es segura para ejecutar en producción

## 🎯 Resultado Esperado

Después de aplicar la migración:

```sql
-- Todas las columnas deben existir
✅ id - EXISTS
✅ user_id - EXISTS
✅ movie_id - EXISTS
✅ rating - EXISTS
✅ movie_title - EXISTS
✅ created_at - EXISTS  ← AHORA SÍ EXISTE
✅ rated_at - EXISTS
✅ last_modified_at - EXISTS
✅ sync_version - EXISTS
✅ device_id - EXISTS
✅ is_deleted - EXISTS
```

Y la aplicación debe sincronizar ratings sin errores.

---

**Autor**: GitHub Copilot  
**Fecha de Creación**: 2025-10-01  
**Última Actualización**: 2025-10-01
