# 📋 Instrucciones para Aplicar Migración de Sync Schema

## 🎯 Objetivo
Aplicar el script de migración unificado para preparar la base de datos para sincronización offline-first robusta.

## 📂 Archivos de Migración
- **Migración Principal**: `supabase/migrations/20250904000000_unify_sync_schema.sql`
- **Validación**: `supabase/migrations/validate_sync_schema.sql`

## 🚀 Opciones de Aplicación

### Opción 1: Supabase Dashboard (Recomendado)
1. Ir a [Supabase Dashboard](https://app.supabase.com/project/fyzujpifkzftweynrudh)
2. Navegar a **SQL Editor**
3. Copiar y pegar el contenido de `20250904000000_unify_sync_schema.sql`
4. Ejecutar el script
5. Ejecutar el script de validación `validate_sync_schema.sql`
6. Verificar que todas las validaciones muestren ✅

### Opción 2: Instalar Supabase CLI (Para futuras migraciones)
```bash
# Windows (usando npm)
npm install -g supabase

# Luego configurar
supabase login
supabase link --project-ref fyzujpifkzftweynrudh

# Aplicar migración
supabase db push
```

### Opción 3: Continuar sin migración (Para desarrollo)
Si prefieres continuar con el desarrollo de código mientras tanto:
- ✅ Podemos proceder a implementar la interfaz `SyncableEntity`
- ✅ Crear los repositorios base
- ⚠️ Los tests de integración fallarán hasta aplicar la migración

## ✅ Verificación Post-Migración

Después de ejecutar la migración, deberías ver:

**Tablas con campos sync estandarizados**:
- `user_watchlist`: `is_deleted` (BOOLEAN), `last_modified_at`, `sync_version`, `device_id`
- `user_favorites`: `is_deleted`, `last_modified_at`, `sync_version`, `device_id` 
- `user_watched_movies`: `is_deleted`, `last_modified_at`, `sync_version`, `device_id`
- `user_lists`: `is_deleted`, `last_modified_at`, `sync_version`, `device_id`
- `user_list_items`: `is_deleted`, `last_modified_at`, `sync_version`, `device_id`

**Nuevas tablas de control**:
- `sync_status`: Estado de sincronización por usuario/dispositivo
- `sync_conflicts`: Tracking de conflictos

**Triggers actualizados**:
- `update_sync_metadata()`: Función unificada para actualizar timestamps y versiones

## 🎯 Siguiente Paso
Una vez aplicada la migración, proceder a **Fase 2**: Implementación de interfaces `SyncableEntity`.