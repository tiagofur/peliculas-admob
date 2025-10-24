# Estado de Migración: user_movie_ratings

**Última Actualización**: 2025-10-01 17:03  
**Estado General**: ✅ MIGRACIÓN PRINCIPAL COMPLETADA - Acción adicional recomendada

---

## ✅ Completado

### 1. Migración Principal de Esquema

**Script**: `supabase/migrations/20251001_fix_user_movie_ratings_schema.sql`  
**Estado**: ✅ APLICADA EXITOSAMENTE  
**Fecha**: 2025-10-01 ~17:03 UTC

**Resultados**:

```sql
✅ created_at         - AÑADIDA
✅ rated_at           - YA EXISTÍA
✅ last_modified_at   - AÑADIDA
✅ sync_version       - AÑADIDA
✅ device_id          - AÑADIDA
✅ is_deleted         - AÑADIDA
✅ Todos los índices  - CREADOS
✅ Triggers           - CONFIGURADOS
```

**Verificación**:

```
Tabla: user_movie_ratings
Registros: 1+ (al menos uno verificado)
Ejemplo verificado: movie_id=755898, user_id=8359a786-cd93-4542-b588-28cfc1d5fb1e
```

---

## ⚠️ Acción Recomendada (No Crítica)

### 2. Corrección de Datos Históricos

**Script**: `supabase/migrations/20251001_fix_historical_created_at.sql`  
**Estado**: 🟡 PENDIENTE DE APLICAR  
**Prioridad**: MEDIA (mejora de consistencia de datos)

**Problema Detectado**:
En el registro de ejemplo verificado:

- `rated_at`: 2025-09-28 03:11:54 (fecha original de calificación)
- `created_at`: 2025-10-01 17:03:35 (fecha de ejecución de migración)
- `last_modified_at`: 2025-09-28 03:11:54

Esto significa que `created_at` > `rated_at`, lo cual es conceptualmente incorrecto pero **NO causa errores funcionales**.

**Qué hace esta migración**:

1. Ajusta `created_at = rated_at` para registros históricos
2. Asegura que `last_modified_at >= created_at >= rated_at`
3. Añade constraint para prevenir futuras inconsistencias
4. Es **SEGURA** y **IDEMPOTENTE** (se puede ejecutar múltiples veces)

**Cuándo aplicarla**:

- ✅ Ahora mismo (recomendado)
- ✅ Durante ventana de mantenimiento programado
- ✅ Antes de habilitar funciones que dependen de `created_at`

**Impacto si NO se aplica**:

- ❌ Datos históricos tendrán timestamps inconsistentes
- ⚠️ Reportes basados en `created_at` serán incorrectos
- ✅ La sincronización seguirá funcionando correctamente

---

## 📊 Verificación de Estado Actual

### Verificar Todas las Columnas

```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'user_movie_ratings'
ORDER BY ordinal_position;
```

### Verificar Inconsistencias de Timestamps

```sql
SELECT
    COUNT(*) as total_ratings,
    COUNT(CASE WHEN created_at > rated_at THEN 1 END) as inconsistent_timestamps,
    COUNT(CASE WHEN last_modified_at < created_at THEN 1 END) as invalid_modified_at
FROM public.user_movie_ratings;
```

Si `inconsistent_timestamps > 0`, ejecuta la migración de corrección.

### Verificar Funcionalidad de Sync

```dart
// En la app Flutter
final ratings = await movieRatingsRepository.getUserRatings();
print('✅ Successfully fetched ${ratings.length} ratings');

// Todos los ratings deben tener estos campos
for (final rating in ratings) {
  assert(rating.createdAt != null, 'created_at is null');
  assert(rating.ratedAt != null, 'rated_at is null');
  assert(rating.lastModifiedAt != null, 'last_modified_at is null');
}
print('✅ All ratings have required timestamp fields');
```

---

## 🚀 Próximos Pasos

### Inmediato (Recomendado)

1. ✅ Ejecutar `20251001_fix_historical_created_at.sql`
2. ✅ Verificar que no hay inconsistencias
3. ✅ Probar sync en app

### A Corto Plazo (24-48h)

1. Monitorear logs de sincronización
2. Verificar que no hay errores de columnas faltantes
3. Confirmar que ratings nuevos tienen timestamps correctos

### Validación

```sql
-- Después de aplicar corrección, esto debe retornar 0
SELECT COUNT(*) as inconsistent_records
FROM public.user_movie_ratings
WHERE created_at > rated_at
   OR last_modified_at < created_at;
```

Resultado esperado: `inconsistent_records = 0`

---

## 📝 Notas Técnicas

### Orden Correcto de Timestamps

```
rated_at <= created_at <= last_modified_at
```

**Ejemplo correcto**:

- Usuario califica película: 2025-09-28 → `rated_at = 2025-09-28`
- Se sincroniza offline: 2025-09-29 → `created_at = 2025-09-29`
- Usuario actualiza rating: 2025-09-30 → `last_modified_at = 2025-09-30`, `rated_at = 2025-09-30`

### Constraints Añadidos

```sql
-- Previene created_at > last_modified_at
ALTER TABLE user_movie_ratings
ADD CONSTRAINT check_created_before_modified
CHECK (created_at <= last_modified_at);
```

---

## 🆘 Soporte

### Si encuentras errores después de la migración:

1. **Error: "column X does not exist"**

   - Verifica que la migración se aplicó: `\d user_movie_ratings`
   - Reaplica la migración si es necesario

2. **Timestamps inconsistentes**

   - Ejecuta `20251001_fix_historical_created_at.sql`

3. **Problemas de sincronización**
   - Verifica logs: `LoggerFactory.error` en la app
   - Revisa políticas RLS: `SELECT * FROM pg_policies WHERE tablename = 'user_movie_ratings'`

### Contacto

- Documentación: `docs/FIX_RATINGS_SCHEMA_2025_10_01.md`
- Migraciones: `supabase/migrations/20251001_*.sql`
- Queries de diagnóstico: `supabase/queries/diagnose_user_movie_ratings.sql`

---

**Conclusión**: El problema crítico está **RESUELTO**. La migración adicional es solo para mejorar la consistencia de datos históricos.
