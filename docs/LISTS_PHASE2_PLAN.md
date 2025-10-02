# FASE 2: Migración de UI Components - Plan Detallado

**Fecha:** 1 de octubre de 2025  
**Estado:** 🚧 EN PROGRESO

---

## 🎯 Objetivo

Migrar los componentes UI para usar los nuevos providers basados en streams (`listItemsProvider`) en lugar de acceder directamente a `customList.movieIds`.

---

## 📋 Archivos Prioritarios

### 🔴 Alta Prioridad (Críticos)

1. **`lib/presentation/views/movies/list_detail_view.dart`** (~1272 líneas)

   - **Usos de movieIds:** 15+ referencias
   - **Complejidad:** Alta
   - **Impacto:** Usuario final directo
   - **Cambios necesarios:**
     - `customList.movieIds.isEmpty` → `listItemsProvider` + check length
     - `customList.movieIds.length` → `listMovieCountProvider`
     - `customList.movieIds.map(...)` → `listItemsProvider` + extract movieId
     - Cargar películas desde items en lugar de IDs

2. **`lib/presentation/views/movies/custom_lists_view.dart`** (~1500 líneas)

   - **Usos de movieIds:** 4 referencias
   - **Complejidad:** Media
   - **Impacto:** Dashboard de listas
   - **Cambios necesarios:**
     - `list.movieIds.length` → `listMovieCountProvider`
     - `list.movieIds.isNotEmpty` → contador > 0
     - Drag & drop de películas entre listas

3. **`lib/presentation/widgets/movies/movie_lists_widget.dart`**
   - **Usos de movieIds:** 2 referencias
   - **Complejidad:** Baja
   - **Impacto:** Selector de listas
   - **Cambios necesarios:**
     - Usar `isMovieInListProvider` para checks

### 🟡 Media Prioridad (Services)

4. **`lib/services/list_sync_service.dart`**

   - Usa `movieIds` para sincronización
   - Necesita migración a `listItemsProvider`

5. **`lib/services/lists_migration_service.dart`**
   - Usa `movieIds` para migraciones
   - Puede mantener temporalmente para compatibilidad

### 🟢 Baja Prioridad (Tests y Debug)

6. **Tests** - Varios archivos
7. **Debug views** - Views de debug pueden mantener deprecated

---

## 🔧 Estrategia de Migración

### Patrón 1: Verificar si lista está vacía

**ANTES:**

```dart
if (customList.movieIds.isEmpty) {
  return _buildEmptyState();
}
```

**DESPUÉS:**

```dart
// Opción A: Usar contador
final movieCount = ref.watch(listMovieCountProvider(customList.id));
if (movieCount == 0) {
  return _buildEmptyState();
}

// Opción B: Usar stream de items
final itemsAsync = ref.watch(listItemsProvider(customList.id));
return itemsAsync.when(
  data: (items) => items.isEmpty ? _buildEmptyState() : _buildList(items),
  loading: () => CircularProgressIndicator(),
  error: (e, s) => ErrorWidget(e),
);
```

### Patrón 2: Obtener IDs de películas

**ANTES:**

```dart
final movieIds = customList.movieIds;
for (final id in movieIds) {
  loadMovie(id);
}
```

**DESPUÉS:**

```dart
final itemsAsync = ref.watch(listItemsProvider(customList.id));
itemsAsync.whenData((items) {
  for (final item in items) {
    loadMovie(item.movieId);
  }
});
```

### Patrón 3: Contar películas

**ANTES:**

```dart
Text('${customList.movieIds.length} películas')
```

**DESPUÉS:**

```dart
final count = ref.watch(listMovieCountProvider(customList.id));
Text('$count películas')
```

### Patrón 4: Verificar si película está en lista

**ANTES:**

```dart
final isInList = customList.movieIds.contains(movieId);
```

**DESPUÉS:**

```dart
final isInList = ref.watch(isMovieInListProvider(
  listId: customList.id,
  movieId: movieId,
));
```

---

## 📝 Plan de Ejecución

### Paso 1: list_detail_view.dart (Más Complejo)

#### Cambios Específicos:

1. **Línea 79**: Verificar si lista está vacía

```dart
// ANTES:
if (customList.movieIds.isEmpty) {

// DESPUÉS:
final movieCount = ref.watch(listMovieCountProvider(customList.id));
if (movieCount == 0) {
```

2. **Líneas 116-145**: Cargar películas

```dart
// ANTES:
final requestedMovieIds = customList.movieIds.map((id) => id.toString()).toList();

// DESPUÉS:
final itemsAsync = ref.watch(listItemsProvider(customList.id));
// Use itemsAsync.when() para manejar loading/error/data
```

3. **Línea 184-185**: Comparar longitudes

```dart
// ANTES:
missingMovieIds.length == customList.movieIds.length

// DESPUÉS:
final totalCount = ref.watch(listMovieCountProvider(customList.id));
missingMovieIds.length == totalCount
```

4. **Línea 293**: Mostrar contador

```dart
// ANTES:
'${customList.movieIds.length} películas'

// DESPUÉS:
final count = ref.watch(listMovieCountProvider(customList.id));
'$count películas'
```

#### Consideraciones:

- El archivo es largo y complejo
- Necesita refactor de lógica de carga
- Puede necesitar widget helper nuevo
- Testing exhaustivo requerido

### Paso 2: custom_lists_view.dart

#### Cambios Específicos:

1. **Línea 336**: Sumar total de películas

```dart
// ANTES:
lists.fold<int>(0, (sum, list) => sum + list.movieIds.length);

// DESPUÉS:
final totalMovies = ref.watch(totalMoviesInListsProvider);
```

2. **Línea 337**: Contar listas activas

```dart
// ANTES:
lists.where((list) => list.movieIds.isNotEmpty).length

// DESPUÉS:
// Crear nuevo provider o calcular inline con listMovieCountProvider
```

3. **Línea 548, 1393**: Mostrar contadores

```dart
// ANTES:
'${list.movieIds.length} películas'

// DESPUÉS:
final count = ref.watch(listMovieCountProvider(list.id));
'$count películas'
```

### Paso 3: movie_lists_widget.dart

Cambios simples - usar `isMovieInListProvider`.

---

## ⚠️ Consideraciones Importantes

### Performance

- ✅ `listMovieCountProvider` es optimizado (no carga items)
- ⚠️ Múltiples `listItemsProvider` en un loop pueden ser costosos
- 💡 Considerar batch loading o caching

### Testing

- 🧪 Cada componente debe testearse después de migración
- 🧪 Tests de integración críticos
- 🧪 Performance testing en listas grandes

### Backward Compatibility

- ✅ Providers antiguos todavía funcionan (deprecated)
- ✅ No breaking changes inmediatos
- ⚠️ Warnings guiarán migración adicional

---

## 📊 Métricas de Progreso

| Archivo                 | Líneas | Refs movieIds | Estado  | Prioridad |
| ----------------------- | ------ | ------------- | ------- | --------- |
| list_detail_view.dart   | 1272   | 15+           | ⏳ TODO | 🔴 Alta   |
| custom_lists_view.dart  | 1500   | 4             | ⏳ TODO | 🔴 Alta   |
| movie_lists_widget.dart | ~200   | 2             | ⏳ TODO | 🔴 Alta   |
| list_sync_service.dart  | ~400   | 6             | ⏳ TODO | 🟡 Media  |
| Tests                   | varios | 8             | ⏳ TODO | 🟢 Baja   |

**Progreso Total:** 0% (0/5 archivos críticos)

---

## 🚀 Orden de Ejecución

1. ✅ **COMPLETADO**: FASE 1 - Providers y repositorio
2. 🚧 **EN PROGRESO**: FASE 2 - UI Components
   - [ ] Step 2.1: list_detail_view.dart
   - [ ] Step 2.2: custom_lists_view.dart
   - [ ] Step 2.3: movie_lists_widget.dart
   - [ ] Step 2.4: Validación y testing
3. ⏳ **PENDIENTE**: FASE 3 - Services
4. ⏳ **PENDIENTE**: FASE 4 - Tests
5. ⏳ **PENDIENTE**: FASE 5 - Limpieza final

---

## 📚 Referencias

- `LISTS_MIGRATION_GUIDE.md` - Ejemplos de migración
- `LISTS_PHASE1_COMPLETE.md` - Providers disponibles
- `list_items_provider.dart` - API de nuevos providers

---

**Próximo:** Comenzar con `list_detail_view.dart`

**Fecha de este documento:** 1 de octubre de 2025, 22:15 UTC
