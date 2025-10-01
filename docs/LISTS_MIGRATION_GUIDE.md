# 🔄 Guía de Migración: De `movieIds` a `listItemsProvider`

**Fecha:** 1 de octubre de 2025  
**Versión:** FASE 1 - Migración Incremental

---

## ⚠️ Cambio Importante

El campo `movieIds` en `CustomList` está siendo **deprecado** y será eliminado en la próxima versión mayor.

**Razón:** Inconsistencia entre el modelo de código (array de IDs) y la base de datos (tabla relacional `user_list_items`).

---

## 🎯 Nueva Arquitectura

### Antes (Deprecated)

```dart
// ❌ Forma antigua - NO USAR
class CustomList {
  final List<int> movieIds; // Deprecated
}

// Uso antiguo
final list = ref.watch(listByIdProvider(listId));
final movieCount = list.movieIds.length;
final hasMovie = list.movieIds.contains(movieId);
```

### Después (Recomendado)

```dart
// ✅ Nueva forma - USAR ESTO
import 'package:peliculas_admob/presentation/providers/list_items_provider.dart';

// Obtener items de una lista
final itemsAsync = ref.watch(listItemsProvider(listId));
final items = itemsAsync.when(
  data: (items) => items,
  loading: () => <ListItem>[],
  error: (_, __) => <ListItem>[],
);

// Contar películas (sin cargar todos los items)
final count = ref.watch(listMovieCountProvider(listId));

// Verificar si película está en lista
final hasMovie = ref.watch(isMovieInListProvider(
  (movieId: movieId, listId: listId),
));

// Obtener todas las listas que contienen una película
final listIds = ref.watch(movieListsProvider(movieId));
```

---

## 📋 Casos de Uso Comunes

### 1. Mostrar Contador de Películas

#### ❌ Antes:

```dart
Text('${list.movieIds.length} películas')
```

#### ✅ Después:

```dart
Consumer(
  builder: (context, ref, child) {
    final count = ref.watch(listMovieCountProvider(list.id));
    return Text('$count películas');
  },
)
```

---

### 2. Verificar si Película está en Lista

#### ❌ Antes:

```dart
final isInList = list.movieIds.contains(movieId);
```

#### ✅ Después:

```dart
final isInList = ref.watch(isMovieInListProvider(
  (movieId: movieId, listId: list.id),
));
```

---

### 3. Mostrar Lista de Películas

#### ❌ Antes:

```dart
ListView.builder(
  itemCount: list.movieIds.length,
  itemBuilder: (context, index) {
    final movieId = list.movieIds[index];
    // Cargar detalles de película desde TMDB
    return MovieTile(movieId: movieId);
  },
)
```

#### ✅ Después:

```dart
Consumer(
  builder: (context, ref, child) {
    final itemsAsync = ref.watch(listItemsProvider(list.id));

    return itemsAsync.when(
      data: (items) => ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return MovieTile(
            movieId: item.movieId,
            movieTitle: item.movieTitle, // Ya tenemos el título!
            posterPath: item.moviePosterPath, // Y el poster!
          );
        },
      ),
      loading: () => CircularProgressIndicator(),
      error: (error, _) => Text('Error: $error'),
    );
  },
)
```

**Ventaja:** `ListItem` ya incluye `movieTitle` y `moviePosterPath`, eliminando llamadas adicionales a TMDB.

---

### 4. Agregar Película a Lista

#### ❌ Antes:

```dart
// Actualización optimista del estado local
ref.read(allListsNotifierProvider.notifier).addMovieToList(
  listId,
  movieId,
);
```

#### ✅ Después:

```dart
// El provider actualiza automáticamente con realtime
await ref.read(allListsNotifierProvider.notifier).addMovieToListAsync(
  listId,
  movieId,
  movieTitle: movie.title,
  posterPath: movie.posterPath,
);

// UI se actualiza automáticamente gracias a StreamProvider
```

---

### 5. Reordenar Películas

#### ❌ Antes:

```dart
// Actualización local del array
ref.read(allListsNotifierProvider.notifier).reorderMoviesInList(
  listId,
  oldIndex,
  newIndex,
);
```

#### ✅ Después:

```dart
// Obtener items actuales
final itemsAsync = ref.watch(listItemsProvider(listId));
final items = itemsAsync.asData?.value ?? [];

// Crear nueva lista reordenada
final reorderedItems = [...items];
final item = reorderedItems.removeAt(oldIndex);
reorderedItems.insert(newIndex, item);

// Actualizar posiciones en backend
await ref.read(allListsNotifierProvider.notifier).reorderMoviesAsync(
  listId,
  reorderedItems,
);
```

---

### 6. Filtrar Listas Vacías

#### ❌ Antes:

```dart
final nonEmptyLists = allLists.where((list) => list.movieIds.isNotEmpty).toList();
```

#### ✅ Después:

```dart
final nonEmptyLists = allLists.where((list) {
  final count = ref.watch(listMovieCountProvider(list.id));
  return count > 0;
}).toList();
```

---

### 7. Ordenar por Cantidad de Películas

#### ❌ Antes:

```dart
final sorted = [...allLists]
  ..sort((a, b) => b.movieIds.length.compareTo(a.movieIds.length));
```

#### ✅ Después:

```dart
final sorted = [...allLists]..sort((a, b) {
  final countA = ref.watch(listMovieCountProvider(a.id));
  final countB = ref.watch(listMovieCountProvider(b.id));
  return countB.compareTo(countA);
});
```

---

## 🔧 Migrando Providers y Notifiers

### En AllListsNotifier

#### ❌ Métodos a Deprecar:

```dart
// NO USAR - Serán eliminados
void toggleMovieInList(String listId, int movieId) { ... }
void reorderMoviesInList(String listId, int oldIndex, int newIndex) { ... }
void clearList(String listId) { ... }
```

#### ✅ Nuevos Métodos Async:

```dart
// USAR ESTOS
Future<void> addMovieToListAsync(
  String listId,
  int movieId, {
  String? movieTitle,
  String? posterPath,
}) async { ... }

Future<void> removeMovieFromListAsync(
  String listId,
  int movieId,
) async { ... }

Future<void> reorderMoviesAsync(
  String listId,
  List<ListItem> newOrder,
) async { ... }
```

---

## 📊 Beneficios de la Nueva Arquitectura

### ✅ Ventajas

1. **Actualización Automática**: UI se actualiza automáticamente con cambios realtime
2. **Performance**: No cargar todos los movieIds cuando solo necesitas el count
3. **Consistencia**: Refleja correctamente la estructura de la BD
4. **Datos Adicionales**: `ListItem` incluye título y poster (menos llamadas a TMDB)
5. **Separación de Responsabilidades**: Listas != Películas en listas

### 📈 Mejoras de Performance

```dart
// ❌ Antes: Cargar toda la lista para obtener el count
final list = await repository.getListById(listId);
final count = list.movieIds.length;

// ✅ Después: Solo obtener el count
final count = ref.watch(listMovieCountProvider(listId));
// Stream optimizado, no carga todos los items
```

---

## 🧪 Testing

### Actualizar Tests

#### ❌ Antes:

```dart
test('should add movie to list', () {
  // ...
  expect(list.movieIds, contains(movieId));
});
```

#### ✅ Después:

```dart
test('should add movie to list', () async {
  // ...
  final items = await ref.read(listItemsProvider(listId).future);
  expect(items.any((item) => item.movieId == movieId), isTrue);
});
```

---

## ⏰ Timeline de Deprecación

### Octubre 2025 (ACTUAL)

- ✅ `movieIds` marcado como `@Deprecated`
- ✅ Nuevos providers creados
- ⚠️ Warnings de deprecación en código que use `movieIds`

### Noviembre 2025 (Próximo mes)

- 🔴 `movieIds` será **ELIMINADO**
- 🔴 Código que use `movieIds` **NO COMPILARÁ**

---

## 🆘 Ayuda y Soporte

### Documentación Relacionada

- [LISTS_LOGIC_ANALYSIS_AND_PLAN.md](LISTS_LOGIC_ANALYSIS_AND_PLAN.md) - Plan completo
- [LISTS_REFACTOR_CHANGELOG.md](LISTS_REFACTOR_CHANGELOG.md) - Changelog

### Ejemplos Completos

Ver: `lib/presentation/providers/list_items_provider.dart`

### ¿Dudas?

Crear issue en GitHub con etiqueta `migration` o consultar con el equipo.

---

## 🚀 Checklist de Migración

Para cada archivo que use `movieIds`:

- [ ] Identificar uso de `movieIds`
- [ ] Reemplazar con provider apropiado
- [ ] Actualizar tests relacionados
- [ ] Verificar que compile sin warnings
- [ ] Probar funcionalidad end-to-end
- [ ] Actualizar documentación inline

---

**¡Gracias por migrar! 🎉**
