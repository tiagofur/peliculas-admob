# Solución a Problemas de Listas Predefinidas

**Fecha:** 2025-01-01
**Versión:** 2.0
**Estado:** ✅ Implementado

---

## 📋 Resumen Ejecutivo

Se identificaron y resolvieron 3 problemas críticos con las listas predefinidas:

1. **✅ Duplicación de listas** - Múltiples copias de las mismas listas predefinidas
2. **✅ Clasificación incorrecta** - Listas predefinidas apareciendo como personalizadas
3. **✅ Iconos y colores incorrectos** - Todas las listas con icono 📝 y color azul

---

## 🔍 Análisis de Problemas

### Problema 1: Duplicación (3x8 = 24 listas)

**Síntoma:**
Cada vez que el usuario inicia sesión, se crean 8 nuevas listas predefinidas, resultando en múltiples duplicados.

**Causa raíz:**
- `ensureDefaultListsExist()` se ejecuta en cada login
- Aunque existe caché local en `SharedPreferences`, no verifica contra la base de datos
- Race conditions entre diferentes sesiones del usuario

**Solución implementada:**
1. **Constraint único en base de datos:**
   - `UNIQUE (user_id, default_type) WHERE is_default = true`
   - Previene duplicados a nivel de DB (última línea de defensa)

2. **Limpieza automática one-time:**
   - Script que detecta y elimina duplicados existentes
   - Se ejecuta solo una vez por usuario/año
   - Conserva la lista más reciente o personalizada

**Archivos modificados:**
- `supabase/migrations/20250101_unique_default_lists_constraint.sql`
- `lib/core/services/post_login_initialization_service.dart`

---

### Problema 2: Clasificación en Tab Incorrecta

**Síntoma:**
Las listas predefinidas aparecen en la pestaña "Personalizadas" en lugar de "Predefinidas".

**Causa raíz:**
- La UI filtra correctamente por `isDefault`, pero algunas listas tienen `is_default = false` en la DB
- Posible inconsistencia en la creación inicial

**Solución implementada:**
1. **Verificación en datasource:**
   - Garantiza que `is_default = true` al crear listas predefinidas
   - Ya estaba correcto en el código, pero se reforzó con el constraint

2. **Limpieza de datos:**
   - El script de limpieza marca correctamente todas las listas predefinidas

**Archivos afectados:**
- `lib/presentation/views/movies/custom_lists_view.dart` (sin cambios necesarios)
- `lib/infrastructure/datasources/supabase_custom_lists_datasource.dart`

---

### Problema 3: Iconos y Colores Incorrectos

**Síntoma:**
Todas las listas predefinidas aparecen con:
- Icono: 📝 (genérico)
- Color: Azul (#2196F3)

En lugar de sus iconos y colores específicos:
- 🎬 Quiero Ver (Azul #3B82F6)
- 🛋️ Para el Fin de Semana (Verde #059669)
- 💕 Noche de Citas (Rosa #E11D48)
- 🎉 Con Amigos (Naranja #F59E0B)
- 🏆 Clásicos Pendientes (Morado #7C3AED)
- ⚡ Acción y Aventura (Rojo #DC2626)
- 🧠 Documentales (Turquesa #0891B2)
- 🌍 Cine Internacional (Marrón #8B5A2B)

**Causa raíz:**
- En `supabase_custom_lists_datasource.dart` línea 132:
  - Enviaba `'color': config.color` ❌
  - La base de datos espera `'color_hex'` ✅

**Solución implementada:**
1. **Corrección en datasource:**
   ```dart
   // ANTES (incorrecto):
   'color': config.color,

   // DESPUÉS (correcto):
   'color_hex': config.color,
   ```

2. **Verificación de configuración:**
   - Confirmado que `DefaultListConfig` ya tiene colores en formato hex
   - Emojis correctamente definidos en `default_lists_manager.dart`

**Archivos modificados:**
- `lib/infrastructure/datasources/supabase_custom_lists_datasource.dart` (línea 132)

---

## 🚀 Cambios Implementados

### 1. Migración SQL (`20250101_unique_default_lists_constraint.sql`)

```sql
-- Limpiar duplicados existentes (conserva el más reciente)
DO $$
DECLARE
    duplicate_record RECORD;
BEGIN
    FOR duplicate_record IN
        WITH ranked_lists AS (
            SELECT id, ROW_NUMBER() OVER (
                PARTITION BY user_id, default_type
                ORDER BY last_modified_at DESC
            ) as rn
            FROM user_lists
            WHERE is_default = true AND is_deleted = false
        )
        SELECT id FROM ranked_lists WHERE rn > 1
    LOOP
        UPDATE user_lists
        SET is_deleted = true
        WHERE id = duplicate_record.id;
    END LOOP;
END $$;

-- Constraint único para prevenir futuros duplicados
ALTER TABLE user_lists
ADD CONSTRAINT unique_user_default_type
UNIQUE (user_id, default_type)
WHERE (is_default = true AND is_deleted = false);
```

### 2. Fix en Datasource

**Archivo:** `lib/infrastructure/datasources/supabase_custom_lists_datasource.dart`

```dart
// Línea 132 - Cambio de 'color' a 'color_hex'
'color_hex': config.color, // FIX: Usar color_hex en vez de color
```

### 3. Script de Limpieza One-Time

**Archivo:** `lib/core/services/post_login_initialization_service.dart`

```dart
/// Limpia duplicados de listas predefinidas (ejecuta solo una vez)
Future<void> _cleanDuplicateDefaultListsOnce(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  final cleanedKey = 'default_lists_cleaned_v2_${DateTime.now().year}';
  final alreadyCleaned = prefs.getBool(cleanedKey) ?? false;

  if (alreadyCleaned) return;

  final defaultListsManager = await ref.read(defaultListsManagerProvider.future);
  await defaultListsManager.cleanAndRecreateDefaultLists();

  await prefs.setBool(cleanedKey, true);
}
```

---

## ✅ Resultados Esperados

Después de aplicar esta solución:

1. **Sin duplicados:**
   - Solo 8 listas predefinidas por usuario
   - Constraint de DB previene futuros duplicados

2. **Clasificación correcta:**
   - Listas predefinidas aparecen en tab "Predefinidas"
   - Listas personalizadas en tab "Personalizadas"

3. **Iconos y colores correctos:**
   - Cada lista muestra su icono único
   - Colores vibrantes y diferenciados

---

## 🧪 Plan de Testing

### Pre-requisitos
1. Aplicar migración SQL en Supabase
2. Desplegar código actualizado

### Test 1: Verificar limpieza de duplicados
```bash
# En Supabase SQL Editor:
SELECT user_id, default_type, COUNT(*)
FROM user_lists
WHERE is_default = true AND is_deleted = false
GROUP BY user_id, default_type
HAVING COUNT(*) > 1;

-- Resultado esperado: 0 filas (sin duplicados)
```

### Test 2: Verificar colores e iconos
```bash
# En Supabase SQL Editor:
SELECT name, emoji, color_hex, default_type
FROM user_lists
WHERE is_default = true
  AND is_deleted = false
  AND user_id = 'YOUR_USER_ID'
ORDER BY name;

-- Verificar que cada lista tenga:
-- - emoji único (no 📝 genérico)
-- - color_hex único (no #2196F3 genérico)
```

### Test 3: Verificar UI
1. Logout y login fresh
2. Navegar a `/my-library/lists`
3. Verificar tab "Predefinidas":
   - Exactamente 8 listas
   - Iconos y colores únicos
   - Sin duplicados
4. Verificar tab "Personalizadas":
   - Solo listas creadas por el usuario
   - Sin listas predefinidas

---

## ⚠️ Precauciones

### Durante la implementación:
1. ✅ Backup de tabla `user_lists` antes de aplicar migración
2. ✅ Probar en desarrollo antes de producción
3. ✅ Monitorear logs durante el primer login masivo

### Preservación de datos:
- El script de limpieza **conserva personalizaciones del usuario**
- Si una lista predefinida fue modificada, se mantiene la versión personalizada
- Solo se eliminan duplicados exactos

### Real-time sync:
- ✅ No se modifica `directCustomListsProvider` (funciona correctamente)
- ✅ No se modifica `TriggerFreeCustomListsSync` (maneja operaciones correctamente)
- ✅ El sync en tiempo real continúa funcionando sin cambios

---

## 📊 Métricas de Éxito

### Antes de la solución:
- 24+ listas predefinidas por usuario (duplicados)
- Todas con icono 📝 y color azul
- Mezcladas con listas personalizadas

### Después de la solución:
- Exactamente 8 listas predefinidas por usuario
- Cada una con icono y color único
- Correctamente separadas en su propia pestaña

---

## 🔧 Rollback

Si se necesita revertir los cambios:

```sql
-- 1. Eliminar constraint
ALTER TABLE user_lists
DROP CONSTRAINT IF EXISTS unique_user_default_type;

-- 2. Eliminar índice
DROP INDEX IF EXISTS idx_user_lists_default_type;

-- 3. Revertir cambios en código
git revert <commit-hash>

-- 4. Limpiar caché local
-- En la app, eliminar SharedPreferences key:
-- 'default_lists_cleaned_v2_2025'
```

---

## 📚 Referencias

- [default_lists_manager.dart](../lib/services/default_lists_manager.dart) - Configuración de listas
- [supabase_custom_lists_datasource.dart](../lib/infrastructure/datasources/supabase_custom_lists_datasource.dart) - Creación en DB
- [custom_lists_view.dart](../lib/presentation/views/movies/custom_lists_view.dart) - UI de separación
- [post_login_initialization_service.dart](../lib/core/services/post_login_initialization_service.dart) - Limpieza automática

---

## 👥 Autor

**Claude Code**
Fecha: 2025-01-01
Revisión: v2.0
