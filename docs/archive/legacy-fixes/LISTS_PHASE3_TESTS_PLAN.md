# FASE 3: Tests Migration - Plan de Trabajo

**Fecha:** 1 de Octubre de 2025  
**Estado:** 🔄 EN PROGRESO  
**Prioridad:** ALTA

---

## 🎯 Objetivo

Actualizar todos los tests relacionados con listas personalizadas para usar la nueva arquitectura basada en streams y providers, asegurando que la cobertura de tests se mantenga al 100%.

---

## 📊 Alcance

### Tests Identificados con `movieIds`

Según el análisis del código, se encontraron **15 usos de `movieIds`** en **4 archivos de test**:

| Archivo                                                  | Usos | Complejidad | Prioridad  |
| -------------------------------------------------------- | ---- | ----------- | ---------- |
| `test/services/migration_integration_complete_test.dart` | 9    | ALTA        | 🔴 CRÍTICO |
| `test/presentation/providers/list_actions_test.dart`     | 3    | MEDIA       | 🟡 ALTA    |
| `test/services/migration_integration_test.dart`          | 2    | MEDIA       | 🟡 ALTA    |
| `test/services/migration_simple_test.dart`               | 2    | BAJA        | 🟢 MEDIA   |

**Total:** 4 archivos directos + archivos relacionados estimados

---

## 📋 Categorización de Tests

### 1. Tests de Servicios (3 archivos) 🔴

**Archivos identificados:**

- `test/services/migration_integration_complete_test.dart` (9 usos)
- `test/services/migration_integration_test.dart` (2 usos)
- `test/services/migration_simple_test.dart` (2 usos)

**Archivos relacionados a revisar:**

- `test/services/list_sync_service_test.dart` (posible)
- `test/services/default_lists_manager_test.dart` (posible)
- `test/services/lists_fix_service_test.dart` (posible)

**Estrategia:**

- Actualizar mocks para usar `listItemsProvider` en lugar de `movieIds`
- Validar operaciones de migración usando conteos y queries
- Verificar que la migración legacy funcione correctamente

### 2. Tests de Providers (1 archivo) 🟡

**Archivos identificados:**

- `test/presentation/providers/list_actions_test.dart` (3 usos)

**Archivos relacionados a revisar:**

- `test/presentation/providers/custom_lists_provider_test.dart` (posible)
- `test/presentation/providers/list_items_provider_test.dart` (nuevo - crear?)

**Estrategia:**

- Usar `listMovieCountProvider` para validar conteos
- Usar `isMovieInListProvider` para validar membership
- Actualizar assertions para usar providers en vez de acceso directo

### 3. Widget Tests 🟢

**Archivos a revisar:**

- `test/presentation/widgets/performance/optimized_list_view_test.dart`
- Tests de `list_detail_view.dart` (si existe)
- Tests de `custom_lists_view.dart` (si existe)
- Tests de `movie_lists_widget.dart` (si existe)

**Estrategia:**

- Mock de `listItemsProvider` con streams de test
- Validar UI updates con stream changes
- Verificar performance de widgets

### 4. Integration Tests 🟢

**Nota:** El grep en `integration_test/` no encontró usos de `movieIds`, pero validar flujos end-to-end.

**Archivos a revisar:**

- `integration_test/*list*_test.dart` (si existe)

**Estrategia:**

- Validar flujos completos de creación/edición de listas
- Verificar sincronización multi-dispositivo
- Asegurar que la UI refleja cambios en tiempo real

---

## 🔧 Patrones de Migración para Tests

### Patrón 1: Setup de Test Data

**ANTES** ❌:

```dart
final testList = CustomList(
  id: 'test-id',
  name: 'Test List',
  movieIds: [1, 2, 3],
  userId: 'user-123',
  createdAt: DateTime.now(),
  lastModifiedAt: DateTime.now(),
);

// Validar
expect(testList.movieIds.length, equals(3));
expect(testList.movieIds, contains(2));
```

**DESPUÉS** ✅:

```dart
final testList = CustomList(
  id: 'test-id',
  name: 'Test List',
  movieIds: [], // Deprecado pero necesario para constructor
  userId: 'user-123',
  createdAt: DateTime.now(),
  lastModifiedAt: DateTime.now(),
);

// Setup: Agregar items a través del repository
await repository.addMovieToList('test-id', 1);
await repository.addMovieToList('test-id', 2);
await repository.addMovieToList('test-id', 3);

// Validar usando providers
final items = await ref.read(listItemsProvider('test-id').future);
expect(items.length, equals(3));
expect(items.any((item) => item.movieId == 2), isTrue);
```

### Patrón 2: Mocking de Repository

**ANTES** ❌:

```dart
when(mockRepository.getList('test-id')).thenAnswer((_) async =>
  CustomList(
    id: 'test-id',
    name: 'Test',
    movieIds: [1, 2, 3],
    // ...
  )
);
```

**DESPUÉS** ✅:

```dart
// Mock de lista sin movieIds
when(mockRepository.getList('test-id')).thenAnswer((_) async =>
  CustomList(
    id: 'test-id',
    name: 'Test',
    movieIds: [], // Vacío - se obtiene de items
    // ...
  )
);

// Mock de items stream
when(mockRepository.getListItems('test-id')).thenAnswer((_) =>
  Stream.value([
    ListItem(id: '1', listId: 'test-id', movieId: 1, position: 0),
    ListItem(id: '2', listId: 'test-id', movieId: 2, position: 1),
    ListItem(id: '3', listId: 'test-id', movieId: 3, position: 2),
  ])
);

// Mock de count
when(mockRepository.getListMovieCount('test-id')).thenAnswer((_) =>
  Stream.value(3)
);
```

### Patrón 3: Assertions y Validaciones

**ANTES** ❌:

```dart
// Test de duplicación
final duplicated = await service.duplicateList(originalList);
expect(duplicated.movieIds, equals(originalList.movieIds));
expect(duplicated.movieIds.length, equals(3));
```

**DESPUÉS** ✅:

```dart
// Test de duplicación
final duplicated = await service.duplicateList(originalList);

// Validar usando provider de conteo
final originalCount = ref.read(listMovieCountProvider(originalList.id));
final duplicatedCount = ref.read(listMovieCountProvider(duplicated.id));
expect(duplicatedCount, equals(originalCount));

// O validar items directamente
final originalItems = await ref.read(listItemsProvider(originalList.id).future);
final duplicatedItems = await ref.read(listItemsProvider(duplicated.id).future);
expect(duplicatedItems.length, equals(originalItems.length));
expect(duplicatedItems.map((i) => i.movieId).toSet(),
       equals(originalItems.map((i) => i.movieId).toSet()));
```

### Patrón 4: Tests de Migración

**ANTES** ❌:

```dart
// Setup local data
final localList = CustomList(
  id: 'local-1',
  movieIds: [1, 2, 3],
  // ...
);

// Run migration
await migrationService.migrateLocalToSupabase();

// Verify
final remoteList = await repository.getList('local-1');
expect(remoteList.movieIds.length, equals(3));
```

**DESPUÉS** ✅:

```dart
// Setup local data
final localList = CustomList(
  id: 'local-1',
  movieIds: [1, 2, 3], // OK para datos legacy en test de migración
  // ...
);

// Run migration
await migrationService.migrateLocalToSupabase();

// Verify usando repository methods (no providers en tests de migración)
final itemCount = await repository.getListItems('local-1').first.then((items) => items.length);
expect(itemCount, equals(3));

// O verificar directamente en DB
final items = await repository.getListItems('local-1').first;
expect(items.length, equals(3));
expect(items.map((i) => i.movieId), containsAll([1, 2, 3]));
```

---

## 📝 Checklist por Archivo

### 🔴 CRÍTICO - Prioridad 1

#### `test/services/migration_integration_complete_test.dart`

- [ ] Línea 67: Crear lista con movieIds vacío
- [ ] Línea 163: Actualizar a usar getListItems() para obtener movieIds
- [ ] Línea 192-193: Validar length usando stream de items
- [ ] Líneas 207, 219, 231: Setup con addMovieToList() en vez de constructor
- [ ] Actualizar todos los expect() para usar repository methods
- [ ] Verificar que migración legacy funciona correctamente

### 🟡 ALTA - Prioridad 2

#### `test/presentation/providers/list_actions_test.dart`

- [ ] Línea 169: Crear lista con movieIds vacío, populate con repository
- [ ] Línea 182: Usar listMovieCountProvider para validar duplicación
- [ ] Actualizar setup de test data
- [ ] Mock de listItemsProvider

#### `test/services/migration_integration_test.dart`

- [ ] Líneas 150, 162: Setup con addMovieToList()
- [ ] Actualizar validaciones de migración
- [ ] Verificar conteos post-migración

### 🟢 MEDIA - Prioridad 3

#### `test/services/migration_simple_test.dart`

- [ ] Línea 50: Actualizar constructor de test data
- [ ] Línea 60: Usar repository.getListItems() para validar length
- [ ] Simplificar test con nuevos métodos

---

## 🎓 Guías de Testing

### Cuándo Usar Providers vs Repository

**Usa Providers cuando:**

- Testeas UI components o widgets
- Necesitas simular realtime updates
- Validas reactividad de la aplicación
- Testeas state management

**Usa Repository directamente cuando:**

- Testeas services o business logic
- Validas operaciones de migración
- Testeas comportamiento de datasources
- No necesitas streams/reactividad

### Mock de ProviderContainer

```dart
// Setup para tests con providers
late ProviderContainer container;
late MockCustomListsRepository mockRepository;

setUp(() {
  mockRepository = MockCustomListsRepository();

  container = ProviderContainer(
    overrides: [
      customListsRepositoryProvider.overrideWithValue(mockRepository),
    ],
  );
});

tearDown(() {
  container.dispose();
});

// Uso en test
test('should watch list items', () async {
  // Setup mock
  when(mockRepository.getListItems('test-id')).thenAnswer((_) =>
    Stream.value([/* items */])
  );

  // Read provider
  final itemsAsync = container.read(listItemsProvider('test-id'));

  // Validate
  await expectLater(
    itemsAsync.future,
    completion(hasLength(3)),
  );
});
```

### Testing Streams

```dart
test('should emit updates when items change', () async {
  // Setup stream controller for mock
  final streamController = StreamController<List<ListItem>>();

  when(mockRepository.getListItems('test-id')).thenAnswer((_) =>
    streamController.stream
  );

  // Start listening
  final itemsStream = container.read(listItemsProvider('test-id').stream);

  // Emit first value
  streamController.add([
    ListItem(id: '1', listId: 'test-id', movieId: 1, position: 0),
  ]);

  // Validate first emission
  await expectLater(
    itemsStream,
    emits(hasLength(1)),
  );

  // Emit second value
  streamController.add([
    ListItem(id: '1', listId: 'test-id', movieId: 1, position: 0),
    ListItem(id: '2', listId: 'test-id', movieId: 2, position: 1),
  ]);

  // Validate second emission
  await expectLater(
    itemsStream,
    emits(hasLength(2)),
  );

  // Cleanup
  await streamController.close();
});
```

---

## 📊 Estimación de Esfuerzo

| Categoría                    | Archivos | Complejidad | Tiempo Est. |
| ---------------------------- | -------- | ----------- | ----------- |
| **Tests de Migración**       | 3        | ALTA        | 60 min      |
| **Tests de Providers**       | 1-2      | MEDIA       | 30 min      |
| **Widget Tests**             | 2-3      | MEDIA       | 30 min      |
| **Integration Tests**        | 1-2      | BAJA        | 20 min      |
| **Creación de nuevos tests** | 1-2      | MEDIA       | 30 min      |
| **Verificación y ajustes**   | -        | -           | 20 min      |

**TOTAL ESTIMADO:** 2.5 - 3 horas

---

## ✅ Criterios de Éxito

### Objetivos de Calidad

1. **Cobertura de Tests:**

   - ✅ Mantener o mejorar cobertura actual
   - ✅ Todos los tests pasan sin warnings deprecation

2. **Compilation:**

   - ✅ 0 errores de compilación
   - ✅ 0 warnings (excepto los esperados durante migración)

3. **Funcionalidad:**

   - ✅ Tests validan correctamente la nueva arquitectura
   - ✅ Tests cubren casos edge de streams
   - ✅ Mocks reflejan comportamiento real

4. **Documentación:**
   - ✅ Comentarios actualizados en tests
   - ✅ Documento de completitud generado

---

## 🚀 Plan de Ejecución

### Sesión 1: Tests Críticos (60-90 min)

1. **Migrar migration_integration_complete_test.dart** (30 min)

   - 9 usos de movieIds
   - Test más complejo
   - Base para los demás

2. **Migrar migration_integration_test.dart** (15 min)

   - 2 usos
   - Simpler que el anterior

3. **Migrar migration_simple_test.dart** (15 min)
   - 2 usos
   - Test más simple
   - Validación rápida

### Sesión 2: Tests de Providers y Widgets (60 min)

4. **Migrar list_actions_test.dart** (20 min)

   - 3 usos
   - Actualizar mocks

5. **Revisar y actualizar widget tests** (20 min)

   - optimized_list_view_test.dart
   - Otros relacionados

6. **Crear tests para list_items_provider** (20 min)
   - Test nuevo para el provider principal
   - Validar streams y updates

### Sesión 3: Verificación y Documentación (30 min)

7. **Ejecutar suite completa de tests** (10 min)

   ```bash
   flutter test
   flutter test --coverage
   ```

8. **Ajustes y fixes** (10 min)

9. **Generar documentación de completitud** (10 min)
   - Documento LISTS_PHASE3_TESTS_COMPLETE.md
   - Actualizar LISTS_MIGRATION_SUMMARY.md

---

## 📚 Referencias

- **Documentación de Riverpod Testing:** https://riverpod.dev/docs/essentials/testing
- **Flutter Testing Best Practices:** https://flutter.dev/docs/testing
- **Mockito Guide:** https://pub.dev/packages/mockito

---

## 🎯 Próximo Paso

**¿Listo para comenzar con el primer archivo?**

Empezaremos con `test/services/migration_integration_complete_test.dart` (el más complejo, 9 usos).

**Comando para verificar tests actuales:**

```bash
flutter test test/services/migration_integration_complete_test.dart
```

---

**Documento creado:** 1 de Octubre de 2025  
**Autor:** GitHub Copilot  
**Estado:** 🔄 Plan listo para ejecución
