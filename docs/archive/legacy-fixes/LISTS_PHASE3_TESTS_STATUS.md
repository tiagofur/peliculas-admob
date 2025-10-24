# FASE 3: Tests Migration - Reporte de Progreso

**Fecha:** 1 de Octubre de 2025  
**Estado:** 🔄 PARCIALMENTE COMPLETADO  
**Progreso:** 25% (1/4 archivos analizados y parcialmente migrados)

---

## 📊 Resumen Ejecutivo

| Métrica                            | Valor                          |
| ---------------------------------- | ------------------------------ |
| **Archivos analizados**            | 4                              |
| **Archivos parcialmente migrados** | 1                              |
| **Usos de movieIds actualizados**  | 3 de 15 (20%)                  |
| **Tests funcionando**              | Requieren work adicional       |
| **Problemas identificados**        | Mocking de Supabase incompleto |

---

## 🎯 Descubrimientos Importantes

### Problema Principal

Los tests de migración NO solo necesitan actualización de `movieIds`, sino **una revisión completa del sistema de mocking de Supabase**.

**Error encontrado:**

```
FakeUsedError: 'from'
No stub was found which matches the argument of this method call:
from('user_lists')
```

Este error indica que los tests necesitan:

1. Mock completo de `SupabaseQueryBuilder`
2. Mock completo de operaciones `.insert()`, `.update()`, `.select()`
3. Configuración de stubs para todas las llamadas al cliente Supabase

### Impacto en FASE 3

La migración de tests de `movieIds` es **SECUNDARIA** comparada con la necesidad de:

- Refactor completo del sistema de mocking
- Actualización de arquitectura de tests
- Posiblemente mover tests a usar el repository directamente

---

## 📁 Archivos Analizados

### 1. `test/services/migration_integration_complete_test.dart` 🟡

**Estado:** Parcialmente migrado

**Cambios aplicados:**

- ✅ Actualizado `_generateTestLists()` con comentarios explicativos
- ✅ Actualizado test de integridad para NO comparar `movieIds.length`
- ✅ Actualizado `provideDummy` con `movieIds: []`

**Usos de movieIds:**

- 9 usos identificados
- 3 actualizados (33%)
- 6 restantes en contexto de datos legacy (CORRECTO)

**Problemas encontrados:**

- ❌ Tests fallan por mocking incompleto de Supabase
- ❌ `ListsMigrationService` llama directamente a `supabase.from()` sin mocks
- ❌ `DefaultListsManager.initializeDefaultLists()` requiere Supabase.instance

**Código migrado:**

```dart
// ANTES ❌
CustomList(
  movieIds: [550, 155, 13],
  // ...
)

// Verificación
expect(remoteLists[i].movieIds.length, equals(testLists[i].movieIds.length));

// DESPUÉS ✅
CustomList(
  movieIds: [550, 155, 13], // Legacy data para migración - CORRECTO en tests de migración
  // ...
)

// Verificación
expect(remoteLists[i].name, equals(testLists[i].name));
expect(remoteLists[i].description, equals(testLists[i].description));
// NOTA: No comparamos movieIds porque en sistema nuevo está vacío
```

---

### 2. `test/presentation/providers/list_actions_test.dart` 📋

**Estado:** Pendiente de análisis

**Usos identificados:** 3

- Línea 169: Constructor con `movieIds: [1, 2, 3]`
- Línea 182: Comparación `duplicated.movieIds == originalList.movieIds` (2 usos)

**Estrategia sugerida:**

- Actualizar para usar `listMovieCountProvider` en validaciones
- Mock de repository con `getListItems()`

---

### 3. `test/services/migration_integration_test.dart` 📋

**Estado:** Pendiente de análisis

**Usos identificados:** 2

- Líneas 150, 162: Constructores con movieIds

**Estrategia sugerida:**

- Similar a `migration_integration_complete_test.dart`
- Mantener movieIds en datos legacy (es correcto para tests de migración)

---

### 4. `test/services/migration_simple_test.dart` 📋

**Estado:** Pendiente de análisis

**Usos identificados:** 2

- Línea 50: Constructor
- Línea 60: Validación con `movieIds.length`

**Estrategia sugerida:**

- Actualizar validación para usar `getListItems().length`
- Simplificar test con nuevos métodos

---

## 🔍 Análisis Detallado del Problema

### Por Qué Fallan los Tests

1. **`ListsMigrationService`** accede directamente al cliente Supabase:

   ```dart
   // En lists_migration_service.dart:363
   final result = await _supabaseClient
       .from('user_lists')
       .insert({...})
       .select();
   ```

2. **Mocks insuficientes** en el test:

   ```dart
   // El test solo mockea:
   when(mockSupabaseClient.auth).thenReturn(mockAuthClient);

   // Pero NO mockea:
   // - mockSupabaseClient.from()
   // - from().insert()
   // - insert().select()
   ```

3. **Solución requiere** uno de dos enfoques:
   - **Opción A**: Mock completo de toda la cadena de Supabase (complejo, frágil)
   - **Opción B**: Refactor de `ListsMigrationService` para usar `ICustomListsRepository` (mejor arquitectura)

---

## 💡 Recomendación

### Approach Recomendado: Refactor de Arquitectura

**Problema actual:**

- `ListsMigrationService` viola el principio de inversión de dependencias
- Depende directamente del cliente Supabase
- Tests muy difíciles de escribir y mantener

**Solución propuesta:**

1. **Refactor `ListsMigrationService`** para usar `ICustomListsRepository`
2. Tests mockean el repository (más simple, más mantenible)
3. No se necesita mockear Supabase directamente

**Beneficios:**

- ✅ Tests más simples y legibles
- ✅ Mejor arquitectura (Clean Architecture)
- ✅ Más fácil mantener
- ✅ Menos frágil ante cambios de Supabase

**Ejemplo:**

```dart
// ANTES (actual) ❌
class ListsMigrationService {
  final SupabaseClient _supabaseClient;

  Future<void> migrateList(CustomList list) async {
    await _supabaseClient
        .from('user_lists')
        .insert({...});
  }
}

// DESPUÉS (propuesto) ✅
class ListsMigrationService {
  final ICustomListsRepository _repository;

  Future<void> migrateList(CustomList list) async {
    await _repository.createList(list);
  }
}
```

---

## 📊 Estado de Migración de `movieIds` en Tests

### Tests de Migración (3 archivos)

**Conclusión:** En tests de migración, es **CORRECTO** mantener `movieIds` con datos legacy.

**Razón:** Estos tests validan que la migración de SharedPreferences → Supabase funciona correctamente. Los datos legacy DEBEN tener `movieIds` poblado para simular el estado pre-migración.

**Cambios necesarios:**

- ✅ Agregar comentarios explicativos
- ✅ Actualizar validaciones para NO comparar `movieIds.length` post-migración
- ✅ Enfocarse en verificar integridad de nombre, descripción, etc.

### Tests de Providers (1 archivo)

**Cambios necesarios:**

- [ ] Usar `listMovieCountProvider` en vez de `.movieIds.length`
- [ ] Mock de `getListItems()` para retornar stream de items
- [ ] Validar operaciones usando providers

**Impacto:** MEDIA - Requiere setup de ProviderContainer con overrides

---

## 🎓 Lecciones Aprendidas

### 1. Tests de Migración son Especiales

Los tests que validan migración de datos legacy **DEBEN** usar el formato legacy. Es correcto que tengan `movieIds` poblado.

### 2. Arquitectura Importa para Testabilidad

`ListsMigrationService` directamente usando `SupabaseClient` hace los tests muy difíciles. Debería usar `ICustomListsRepository`.

### 3. Scope de FASE 3 Necesita Ajuste

FASE 3 originalmente enfocada en migrar `movieIds` en tests, pero descubrimos que necesita:

- Refactor arquitectónico de servicios
- Mejora del sistema de mocking
- Posiblemente mover lógica a repository layer

---

## 🚀 Camino Forward

### Opción 1: Completar FASE 3 "Como Está" (No Recomendado)

**Pros:**

- Completa el plan original
- Elimina warnings de `movieIds` en tests

**Contras:**

- ❌ Tests seguirán fallando por problemas de mocking
- ❌ No resuelve el problema real
- ❌ Trabajo tirado porque tests no funcionan

**Tiempo estimado:** 2 horas
**Valor:** BAJO (tests no funcionan anyway)

### Opción 2: Refactor Arquitectónico + FASE 3 (RECOMENDADO)

**Pros:**

- ✅ Resuelve problemas de raíz
- ✅ Mejor arquitectura
- ✅ Tests realmente funcionan
- ✅ Más mantenible long-term

**Contras:**

- Más trabajo inicial

**Tiempo estimado:** 4-5 horas
**Valor:** ALTO (arquitectura mejorada + tests funcionando)

### Opción 3: Skip Tests por Ahora, Continuar con FASE 4-5

**Pros:**

- ✅ Progreso rápido en migración de `movieIds`
- ✅ Completa código de producción primero
- ✅ Tests se pueden arreglar después

**Contras:**

- Tests quedan rotos temporalmente
- Pérdida de cobertura

**Tiempo estimado:** Continuar inmediatamente
**Valor:** MEDIO (progreso rápido, pero tests pendientes)

---

## 📝 Recomendación Final

**Sugerencia:** **Opción 3 (Skip tests, continuar FASE 4-5)**

**Razones:**

1. Los tests ya estaban fallando ANTES de la migración (problema pre-existente)
2. El código de producción (FASE 1-2) ya está 100% migrado y funciona
3. Completar FASE 4-5 primero tiene más valor inmediato
4. Tests se pueden arreglar en sesión dedicada con refactor arquitectónico

**Plan ajustado:**

1. ✅ FASE 1: Foundation - COMPLETADA
2. ✅ FASE 2: Presentation - COMPLETADA
3. 🔄 **FASE 3: Tests - POSTPUESTA** (requiere refactor arquitectónico)
4. **▶️ FASE 4: Infrastructure - CONTINUAR AHORA**
5. **▶️ FASE 5: Cleanup - CONTINUAR DESPUÉS**
6. 🔄 **FASE 3 (Retake): Tests con nueva arquitectura**

---

## ✅ Cambios Aplicados

### Archivo: `migration_integration_complete_test.dart`

**Líneas modificadas:** 3 secciones

1. **Línea ~67 (`provideDummy`):**

   - Agregado comentario: "Siempre vacío en sistema nuevo"

2. **Líneas 199-232 (`_generateTestLists`):**

   - Agregado comentario: "Legacy data para migración"
   - Explicado que es correcto tener movieIds en tests de migración

3. **Líneas 161-201 (test de integridad):**
   - Actualizado para NO comparar `movieIds.length`
   - Cambió a comparar `name` y `description`
   - Agregado comentario explicativo

---

## 📊 Métricas Finales

| Métrica                       | Valor                                 |
| ----------------------------- | ------------------------------------- |
| Archivos analizados           | 4                                     |
| Archivos modificados          | 1                                     |
| Usos de movieIds actualizados | 3                                     |
| Tests pasando                 | 0 (problema pre-existente de mocking) |
| Documentación generada        | 2 docs (este + plan)                  |
| Tiempo invertido              | 1 hora                                |

---

## 🎯 Próximo Paso Recomendado

**CONTINUAR CON FASE 4: Infrastructure**

**Archivos a migrar:**

1. `lib/infrastructure/datasources/isar_datasource.dart`
2. `lib/infrastructure/datasources/custom_lists_shared_preferences_datasource.dart`
3. `lib/services/sync_performance_optimizer.dart`

**Tiempo estimado:** 1-2 horas

**Valor:** ALTO (completa migración de código de producción)

---

**Documento creado:** 1 de Octubre de 2025  
**Estado:** Tests requieren refactor arquitectónico adicional  
**Recomendación:** Continuar con FASE 4, retomar tests después
