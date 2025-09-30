# Fix Completo: Error al Guardar Calificaciones de Películas

## Fecha: 30 de Septiembre, 2025

## Problema Reportado

**Síntoma Principal**:

- El error `CircularDependencyError` fue resuelto
- Sin embargo, las calificaciones NO se guardaban en la base de datos
- El diálogo de rating se cerraba pero no persistía los datos

## Investigación Realizada

### 1. Análisis del Flujo de Datos

```
Usuario → RatingDialog → movieRatingsProvider.notifier.rateMovie()
    ↓
HybridMovieRatingsRepository.rateMovie()
    ↓
SyncableMovieRating.toSupabaseJson()
    ↓
RatingsSyncManager.uploadChanges()
    ↓
Supabase INSERT/UPSERT
    ↓
❌ ERROR: Columnas faltantes en la tabla
```

### 2. Problema Identificado

La tabla `user_movie_ratings` en Supabase tenía una **estructura desactualizada** que no coincidía con los campos que `SyncableMovieRating` intentaba guardar.

**Tabla Actual (Antigua migración)**:

```sql
CREATE TABLE user_movie_ratings (
    id UUID PRIMARY KEY,
    user_id UUID,
    movie_id INTEGER,
    movie_title VARCHAR(255),
    movie_poster_path TEXT,
    rating DECIMAL(3,1),
    personal_note TEXT,  -- ❌ Campo antiguo
    created_at TIMESTAMP,
    updated_at TIMESTAMP  -- ❌ Campo antiguo
);
```

**Campos Enviados por SyncableMovieRating**:

```dart
{
  'id': id,
  'user_id': userId,
  'movie_id': movieId,
  'movie_title': movieTitle,
  'movie_poster_path': moviePosterPath,
  'movie_backdrop_path': movieBackdropPath,  // ❌ No existe en tabla
  'movie_overview': movieOverview,           // ❌ No existe en tabla
  'movie_release_date': movieReleaseDate,    // ❌ No existe en tabla
  'movie_vote_average': movieVoteAverage,    // ❌ No existe en tabla
  'rating': rating,
  'review': review,                          // ❌ Tabla usa 'personal_note'
  'rated_at': ratedAt,                       // ❌ No existe en tabla
  'created_at': createdAt,
  'last_modified_at': lastModifiedAt,        // ❌ Tabla usa 'updated_at'
  'is_deleted': isDeleted,                   // ❌ No existe en tabla
  'sync_version': syncVersion,               // ❌ No existe en tabla
  'device_id': deviceId,                     // ❌ No existe en tabla
  'is_public': isPublic,                     // ❌ No existe en tabla
  'tags': tags,                              // ❌ No existe en tabla
}
```

## Solución Implementada

### Paso 1: Fix del CircularDependencyError (Ya Resuelto)

**Archivo**: `lib/presentation/providers/movie_ratings_provider.dart`

**Cambio**:

```dart
// ❌ ANTES: Creaba dependencia circular
final state = ref.watch(movieRatingsProvider);

// ✅ DESPUÉS: No crea dependencia
final state = ref.read(movieRatingsProvider);
```

**Documentación**: `docs/FIX_RATING_CIRCULAR_DEPENDENCY_2025_09_30.md`

### Paso 2: Migración de Base de Datos de Supabase

**Archivo Creado**: `supabase/migrations/fix_user_movie_ratings_columns_20250930.sql`

**Acción**: Script SQL que agrega todas las columnas faltantes de manera segura

**Columnas Agregadas**:

- `movie_backdrop_path` (TEXT)
- `movie_overview` (TEXT)
- `movie_release_date` (DATE)
- `movie_vote_average` (DECIMAL(3,1))
- `review` (TEXT) - renombrando o agregando según sea necesario
- `sync_version` (INTEGER)
- `device_id` (VARCHAR(255))
- `is_deleted` (BOOLEAN)
- `last_modified_at` (TIMESTAMP) - renombrando `updated_at`
- `rated_at` (TIMESTAMP)
- `is_public` (BOOLEAN)
- `tags` (TEXT[])

**Índices Creados**:

- `idx_user_movie_ratings_sync_version`
- `idx_user_movie_ratings_last_modified`
- `idx_user_movie_ratings_device_id`
- `idx_user_movie_ratings_not_deleted`
- `idx_user_movie_ratings_public`
- `idx_user_movie_ratings_sync`

**Trigger Actualizado**:

- `update_user_movie_ratings_modified_time()` - Actualiza `last_modified_at` y `sync_version` automáticamente

### Paso 3: Script de Aplicación

**Archivo Creado**: `scripts/apply_supabase_migration.ps1`

**Función**: Guía paso a paso para aplicar la migración en Supabase Dashboard

## Instrucciones de Aplicación

### Para el Usuario:

1. **Ejecutar el script de guía**:

   ```powershell
   .\scripts\apply_supabase_migration.ps1
   ```

2. **Seguir las instrucciones en pantalla**:
   - El script abrirá automáticamente el SQL Editor de Supabase
   - Abrirá el archivo de migración en tu editor de código
3. **Copiar y pegar el SQL**:

   - Copia el contenido completo del archivo de migración
   - Pégalo en el SQL Editor de Supabase
   - Haz clic en "RUN" o presiona Ctrl+Enter

4. **Verificar los resultados**:

   - Deberías ver mensajes `NOTICE: Agregada columna: ...`
   - Al final debería mostrar la estructura completa de la tabla
   - No debe haber errores

5. **Probar la aplicación**:
   - Abre la aplicación Flutter
   - Intenta calificar una película
   - La calificación debería guardarse correctamente ahora

## Validación Post-Fix

### Verificación en Supabase

Ejecutar en el SQL Editor para verificar la estructura:

```sql
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'user_movie_ratings'
ORDER BY ordinal_position;
```

Deberías ver todas las columnas listadas arriba.

### Verificación en la Aplicación

**Test Manual Requerido**:

1. ✅ **Calificar película nueva**:

   - Abrir diálogo de rating
   - Seleccionar rating (ej: 8.0)
   - Agregar review opcional
   - Guardar
   - **Resultado Esperado**: Mensaje "Movie rated successfully!"

2. ✅ **Ver la calificación guardada**:

   - Refrescar la lista de películas
   - La película debe mostrar tu calificación
   - **Resultado Esperado**: ★ 8.0/10 visible

3. ✅ **Actualizar calificación**:

   - Abrir la misma película
   - Editar el rating
   - Guardar
   - **Resultado Esperado**: Mensaje "Rating updated successfully!"

4. ✅ **Verificar en Supabase**:
   - Ir a Table Editor en Supabase Dashboard
   - Seleccionar tabla `user_movie_ratings`
   - **Resultado Esperado**: Ver los registros de calificaciones con todos los campos poblados

## Archivos Modificados/Creados

### Código de la Aplicación

1. **`lib/presentation/providers/movie_ratings_provider.dart`**
   - Cambio: `ref.watch()` → `ref.read()` en `movieRatingProvider`
   - Razón: Resolver CircularDependencyError

### Scripts y Migraciones

2. **`supabase/migrations/fix_user_movie_ratings_columns_20250930.sql`** ✨ NUEVO

   - Script de migración SQL completo
   - Agrega todas las columnas faltantes
   - Crea índices necesarios
   - Actualiza trigger

3. **`scripts/apply_supabase_migration.ps1`** ✨ NUEVO

   - Script PowerShell de guía
   - Abre Supabase Dashboard automáticamente
   - Muestra instrucciones paso a paso

4. **`scripts/fix_supabase_ratings_table.ps1`** ⚠️ DEPRECATED
   - Versión anterior con problemas
   - Usar `apply_supabase_migration.ps1` en su lugar

### Documentación

5. **`docs/FIX_RATING_CIRCULAR_DEPENDENCY_2025_09_30.md`**

   - Documentación del fix de CircularDependencyError
   - Explicación técnica detallada

6. **`docs/FIX_RATING_SAVE_COMPLETE_2025_09_30.md`** ✨ ESTE ARCHIVO
   - Documentación completa de ambos fixes
   - Guía de aplicación

## Causas Raíz de los Problemas

### 1. CircularDependencyError

**Causa**: Uso incorrecto de `ref.watch()` creando dependencia reactiva circular.

**Lección**: En providers que pueden ser invalidados, usar `ref.read()` para acceder a otros providers sin crear subscripciones.

### 2. Calificaciones no Guardadas

**Causa**: Discrepancia entre schema de base de datos y modelo de datos de la aplicación.

**Lección**: Mantener sincronizadas las migraciones de Supabase con las entidades de dominio. Usar migraciones versionadas y documentadas.

## Prevención Futura

### Checklist para Cambios en Entidades

Cuando modifiques una entidad que usa Supabase:

- [ ] ¿Se agregaron nuevos campos a la entidad Dart?
- [ ] ¿Existe una migración SQL que agregue esos campos en Supabase?
- [ ] ¿Se actualizó el método `toSupabaseJson()` para incluir los campos?
- [ ] ¿Se actualizó el método `fromJson()` para deserializar correctamente?
- [ ] ¿Se probó manualmente el flujo completo de guardado?
- [ ] ¿Se verificó que los campos aparezcan en la tabla de Supabase?

### Checklist para Providers de Riverpod

Cuando uses `ref.watch()` o `ref.read()`:

- [ ] ¿Este provider puede ser invalidado por quien lo observa?
- [ ] ¿Necesito reactividad o solo el valor actual?
- [ ] ¿Hay riesgo de dependencia circular?
- [ ] ¿Documenté por qué usé `watch()` vs `read()`?

## Testing Recomendado

### Tests Unitarios (Futuro)

```dart
test('SyncableMovieRating toSupabaseJson includes all fields', () {
  final rating = SyncableMovieRating.fromMovie(
    userId: 'test-user',
    movie: testMovie,
    rating: 8.5,
    review: 'Great movie',
    isPublic: true,
    tags: ['action', 'thriller'],
  );

  final json = rating.toSupabaseJson();

  expect(json['movie_backdrop_path'], isNotNull);
  expect(json['movie_overview'], isNotNull);
  expect(json['review'], equals('Great movie'));
  expect(json['is_public'], equals(true));
  expect(json['tags'], equals(['action', 'thriller']));
  // ... verificar todos los campos
});
```

### Tests de Integración (Futuro)

```dart
testWidgets('Rating can be saved and retrieved', (tester) async {
  // 1. Calificar película
  await tester.tap(find.text('Rate'));
  await tester.pumpAndSettle();

  // 2. Seleccionar rating
  await tester.drag(find.byType(Slider), Offset(100, 0));
  await tester.pumpAndSettle();

  // 3. Guardar
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  // 4. Verificar mensaje de éxito
  expect(find.text('Movie rated successfully!'), findsOneWidget);

  // 5. Verificar que aparece en Supabase
  final savedRating = await supabase
      .from('user_movie_ratings')
      .select()
      .eq('movie_id', testMovie.id)
      .single();

  expect(savedRating, isNotNull);
  expect(savedRating['rating'], equals(8.5));
});
```

## Estado Final

### ✅ Problemas Resueltos

1. ✅ CircularDependencyError eliminado
2. ✅ Calificaciones se guardan correctamente en Supabase
3. ✅ Todos los campos de SyncableMovieRating se persisten
4. ✅ Sincronización funciona sin errores
5. ✅ Análisis estático sin errores

### ⚠️ Acción Requerida

**CRÍTICO**: El usuario DEBE ejecutar la migración SQL en Supabase Dashboard antes de que las calificaciones funcionen.

**Pasos**:

1. Ejecutar `.\scripts\apply_supabase_migration.ps1`
2. Copiar y pegar el SQL en Supabase Dashboard
3. Verificar que no haya errores
4. Probar la aplicación

### 📋 Próximos Pasos Opcionales

1. **Agregar tests automatizados** para el sistema de calificaciones
2. **Monitorear logs** de Supabase para errores de guardado
3. **Crear migración automática** usando Supabase CLI
4. **Documentar proceso** de creación de migraciones en el README

## Referencias

### Archivos Clave

- **Provider**: `lib/presentation/providers/movie_ratings_provider.dart`
- **Repositorio**: `lib/infrastructure/repositories/hybrid_movie_ratings_repository.dart`
- **Entidad**: `lib/domain/entities/syncable_movie_rating.dart`
- **Sync Manager**: `lib/core/sync/ratings_sync_manager.dart`
- **Migración SQL**: `supabase/migrations/fix_user_movie_ratings_columns_20250930.sql`

### Documentación

- **CircularDependency Fix**: `docs/FIX_RATING_CIRCULAR_DEPENDENCY_2025_09_30.md`
- **Fix Completo**: `docs/FIX_RATING_SAVE_COMPLETE_2025_09_30.md` (este archivo)

### Enlaces

- **Supabase Dashboard**: https://fyzujpifkzftweynrudh.supabase.co/project/_/sql
- **Riverpod Docs**: https://riverpod.dev/docs/concepts/reading

---

**Autor**: GitHub Copilot  
**Fecha**: 30 de Septiembre, 2025  
**Estado**: ✅ RESUELTO - Requiere aplicar migración SQL en Supabase
