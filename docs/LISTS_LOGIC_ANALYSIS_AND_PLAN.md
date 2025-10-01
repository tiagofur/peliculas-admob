# 📋 Análisis y Plan de Lógica de Listas Personalizadas

**Fecha:** 1 de octubre de 2025  
**Estado:** 🔴 REQUIERE REFACTORIZACIÓN COMPLETA

---

## 🔍 Análisis de la Situación Actual

### Problemas Identificados

#### 1. **PROBLEMA CRÍTICO: Modelo de Datos Inconsistente**

##### En el Código (Entidad CustomList)
```dart
// lib/domain/entities/custom_list.dart
class CustomList {
  final String id;
  final String name;
  final List<int> movieIds;  // ❌ PROBLEMA: Almacena solo IDs de películas
  // ... otros campos
}
```

##### En la Base de Datos
```sql
-- Supabase tiene DOS tablas:
-- 1. user_lists (sin columna movieIds)
-- 2. user_list_items (tabla separada para películas)
```

**🚨 CONFLICTO**: El modelo de entidad `CustomList` tiene un array `movieIds` que NO corresponde con la estructura de Supabase que usa una tabla relacional separada `user_list_items`.

#### 2. **Sincronización Rota**

- **Provider**: `custom_lists_provider.dart` maneja listas con `movieIds[]`
- **DataSource**: `supabase_custom_lists_datasource.dart` no sincroniza `movieIds` porque esa columna no existe
- **Repository**: `custom_lists_repository_impl.dart` intenta guardar `movieIds` localmente pero nunca se sincronizan correctamente con Supabase

#### 3. **Operaciones CRUD Incompletas**

##### Para LISTAS (`user_lists`):
- ✅ CREATE: Funciona básicamente
- ⚠️ READ: Funciona pero sin películas asociadas
- ⚠️ UPDATE: Funciona pero pierde películas
- ⚠️ DELETE: Funciona pero no limpia `user_list_items`

##### Para PELÍCULAS EN LISTAS (`user_list_items`):
- ⚠️ ADD: Existe la función pero no actualiza el estado local
- ⚠️ REMOVE: Existe la función pero no actualiza el estado local
- ❌ REORDER: Función existe pero no se usa correctamente
- ❌ SYNC: No hay sincronización bidireccional

#### 4. **Realtime Sync No Funcional**

```dart
// Streams definidos pero no integrados correctamente
Stream<List<CustomList>> watchUserLists(String userId);
Stream<List<ListItem>> watchListItems(String listId);
```

- Los streams existen pero no actualizan el provider
- No hay listeners activos
- No hay manejo de eventos realtime

#### 5. **Estado Local vs Remoto Desincronizado**

```dart
// SharedPreferences guarda CustomList con movieIds[]
await _saveListsLocally(lists);

// Pero Supabase necesita:
// 1. INSERT en user_lists
// 2. INSERT múltiple en user_list_items
```

---

## 📊 Estructura de Datos Actual

### Tablas en Supabase

#### Tabla: `user_lists`
```sql
CREATE TABLE user_lists (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    color_hex VARCHAR(7),
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
);
```

#### Tabla: `user_list_items`
```sql
CREATE TABLE user_list_items (
    id UUID PRIMARY KEY,
    list_id UUID REFERENCES user_lists(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL,
    movie_title VARCHAR(255),
    movie_poster_path TEXT,
    position INTEGER DEFAULT 0,
    added_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
);
```

### Entidades en Dart

#### ✅ Bien Diseñadas
```dart
// lib/domain/entities/list_item.dart
class ListItem {
  final String id;
  final String listId;
  final int movieId;
  final String movieTitle;
  final String? moviePosterPath;
  final int position;
  // ...
}
```

#### ❌ Mal Diseñadas
```dart
// lib/domain/entities/custom_list.dart
class CustomList {
  final String id;
  final List<int> movieIds; // ❌ No debería estar aquí
  // ...
}
```

---

## 🎯 Plan de Refactorización

### FASE 1: Refactorizar Modelo de Datos (CRÍTICO)

#### Opción A: Eliminar `movieIds` de `CustomList` (RECOMENDADO)

**Ventajas:**
- Refleja correctamente la estructura de Supabase
- Separación clara de responsabilidades
- Facilita sync realtime
- Evita duplicación de datos

**Cambios Necesarios:**

1. **Modificar `CustomList`**
```dart
class CustomList {
  CustomList({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    // ❌ ELIMINAR: final List<int> movieIds,
    required this.createdAt,
    // ... resto de campos
  });
  
  // Agregar método helper para obtener películas
  // pero NO almacenar el array
}
```

2. **Crear Provider Separado para Películas de Lista**
```dart
// lib/presentation/providers/list_items_provider.dart
final listItemsProvider = StreamProvider.family<List<ListItem>, String>(
  (ref, listId) {
    final repository = ref.watch(customListsRepositoryProvider);
    return repository.when(
      data: (repo) => repo.watchListItems(listId),
      loading: () => Stream.value([]),
      error: (_, __) => Stream.value([]),
    );
  },
);
```

3. **Actualizar UI para usar ambos providers**
```dart
// En MovieListDetailScreen
final list = ref.watch(listByIdProvider(listId));
final items = ref.watch(listItemsProvider(listId));
```

#### Opción B: Mantener `movieIds` como Cache Local (NO RECOMENDADO)

**Solo si:** Necesitas offline-first absoluto y aceptas complejidad adicional.

**Requeriría:**
- Sync bidireccional complejo
- Manejo de conflictos avanzado
- Más propenso a errores

---

### FASE 2: Implementar CRUD Completo

#### 2.1 Operaciones de Listas

```dart
// lib/domain/repositories/i_custom_lists_repository.dart

/// CREATE: Crear lista vacía
Future<CustomList> createList(CustomList list);

/// READ: Obtener lista con su metadata
Future<CustomList?> getListById(String listId);

/// READ: Obtener todas las listas del usuario
Future<List<CustomList>> getUserLists();

/// UPDATE: Actualizar metadata de lista
Future<CustomList> updateList(CustomList list);

/// DELETE: Eliminar lista y sus películas (CASCADE)
Future<void> deleteList(String listId);
```

#### 2.2 Operaciones de Películas en Listas

```dart
// lib/domain/repositories/i_custom_lists_repository.dart

/// ADD: Agregar película a lista
Future<ListItem> addMovieToList(
  String listId, 
  int movieId, {
  int? position,
  String? movieTitle,
  String? posterPath,
});

/// REMOVE: Remover película de lista
Future<void> removeMovieFromList(String listId, int movieId);

/// REORDER: Cambiar posición de película
Future<void> updateMoviePosition(
  String listId, 
  String itemId, 
  int newPosition,
);

/// BULK REORDER: Reordenar múltiples películas
Future<void> reorderListItems(String listId, List<ListItem> items);

/// CHECK: Verificar si película está en lista
Future<bool> isMovieInList(String listId, int movieId);

/// GET: Obtener todas las películas de una lista
Future<List<ListItem>> getListItems(String listId);
```

---

### FASE 3: Implementar Sync Realtime

#### 3.1 Setup Realtime en Supabase

```sql
-- Ya existe en: supabase/migrations/enable_realtime.sql
-- Verificar que esté habilitado:
ALTER PUBLICATION supabase_realtime ADD TABLE user_lists;
ALTER PUBLICATION supabase_realtime ADD TABLE user_list_items;
```

#### 3.2 Listeners en DataSource

```dart
// lib/infrastructure/datasources/supabase_custom_lists_datasource.dart

class SupabaseCustomListsDataSource {
  /// Stream para listas del usuario (YA EXISTE)
  Stream<List<CustomList>> watchUserLists(String userId) {
    return _supabase
      .from('user_lists')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((data) => data.map((json) => CustomList.fromJson(json)).toList());
  }

  /// Stream para películas de una lista (YA EXISTE)
  Stream<List<ListItem>> watchListItems(String listId) {
    return _supabase
      .from('user_list_items')
      .stream(primaryKey: ['id'])
      .eq('list_id', listId)
      .order('position')
      .map((data) => data.map((json) => ListItem.fromJson(json)).toList());
  }

  /// NUEVO: Stream para detectar cambios en una lista específica
  Stream<CustomList?> watchList(String listId) {
    return _supabase
      .from('user_lists')
      .stream(primaryKey: ['id'])
      .eq('id', listId)
      .map((data) {
        if (data.isEmpty) return null;
        return CustomList.fromJson(data.first);
      });
  }
}
```

#### 3.3 Integrar Streams con Providers

```dart
// lib/presentation/providers/custom_lists_provider.dart

// REEMPLAZAR FutureProvider por StreamProvider
final allListsProvider = StreamProvider<AllListsState>((ref) async* {
  final repository = await ref.watch(customListsRepositoryProvider.future);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  
  if (userId == null) {
    yield AllListsState(defaultLists: [], customLists: []);
    return;
  }

  // Stream desde Supabase
  await for (final lists in repository.watchUserLists()) {
    final defaultLists = lists.where((list) => list.isDefault).toList();
    final customLists = lists.where((list) => !list.isDefault).toList();
    
    yield AllListsState(
      defaultLists: defaultLists,
      customLists: customLists,
    );
  }
});

// NUEVO: Provider para películas de una lista
final listItemsProvider = StreamProvider.family<List<ListItem>, String>(
  (ref, listId) async* {
    final repository = await ref.watch(customListsRepositoryProvider.future);
    await for (final items in repository.watchListItems(listId)) {
      yield items;
    }
  },
);

// NUEVO: Provider para contar películas en una lista
final listMovieCountProvider = Provider.family<int, String>((ref, listId) {
  return ref.watch(listItemsProvider(listId)).when(
    data: (items) => items.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
```

---

### FASE 4: Implementar Operaciones Offline

#### 4.1 Queue de Operaciones Pendientes

```dart
// lib/services/list_sync_service.dart

class ListSyncService {
  // Agregar tipo para operaciones de list_items
  enum OfflineChangeType {
    createList,
    updateList,
    deleteList,
    addMovie,        // ✅ Ya existe
    removeMovie,     // ✅ Ya existe
    reorderMovies,   // ❌ AGREGAR
    updateMoviePosition, // ❌ AGREGAR
  }

  /// NUEVO: Registrar reorden de películas
  Future<void> recordMovieReorder(
    String listId, 
    List<ListItem> items,
  ) async {
    await recordOfflineChange(OfflineChange(
      id: 'reorder_${listId}_${DateTime.now().millisecondsSinceEpoch}',
      type: OfflineChangeType.reorderMovies,
      data: {
        'listId': listId,
        'items': items.map((item) => {
          'id': item.id,
          'position': item.position,
        }).toList(),
      },
      timestamp: DateTime.now(),
    ));
  }
}
```

#### 4.2 Sincronización de Cambios Offline

```dart
// lib/infrastructure/repositories/custom_lists_repository_impl.dart

@override
Future<void> syncLists() async {
  if (!await hasInternetConnection()) {
    throw Exception('Sin conexión a internet');
  }

  final pendingOps = await getPendingOperations();

  // ORDENAR operaciones por prioridad:
  // 1. CREATE lists
  // 2. UPDATE lists
  // 3. ADD movies
  // 4. REORDER movies
  // 5. REMOVE movies
  // 6. DELETE lists

  final sortedOps = _sortOperationsByPriority(pendingOps);

  for (final op in sortedOps) {
    try {
      await _executePendingOperation(op);
      await markOperationAsSynced(op['id']);
    } catch (e) {
      LoggerFactory.error('Error sincronizando operación ${op['id']}: $e');
      // Continuar con las demás operaciones
    }
  }
}

List<Map<String, dynamic>> _sortOperationsByPriority(
  List<Map<String, dynamic>> operations,
) {
  final priority = {
    'createList': 1,
    'updateList': 2,
    'addMovie': 3,
    'reorderMovies': 4,
    'updateMoviePosition': 4,
    'removeMovie': 5,
    'deleteList': 6,
  };

  operations.sort((a, b) {
    final aPriority = priority[a['type']] ?? 99;
    final bPriority = priority[b['type']] ?? 99;
    return aPriority.compareTo(bPriority);
  });

  return operations;
}
```

---

### FASE 5: Actualizar UI

#### 5.1 MovieListDetailScreen

```dart
// lib/presentation/screens/lists/movie_list_detail_screen.dart

class MovieListDetailScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(listByIdProvider(listId));
    final itemsAsync = ref.watch(listItemsProvider(listId));

    return itemsAsync.when(
      data: (items) => ReorderableListView.builder(
        itemCount: items.length,
        onReorder: (oldIndex, newIndex) {
          // Notifier actualiza posiciones
          ref.read(allListsNotifierProvider.notifier)
            .reorderMoviesInList(listId, oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            key: ValueKey(item.id),
            title: Text(item.movieTitle),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                ref.read(allListsNotifierProvider.notifier)
                  .removeMovieFromList(listId, item.movieId);
              },
            ),
          );
        },
      ),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error),
    );
  }
}
```

#### 5.2 Actualizar Notifier

```dart
// lib/presentation/providers/custom_lists_provider.dart

class AllListsNotifier extends Notifier<AllListsState> {
  // ELIMINAR métodos que manipulan movieIds
  // ❌ void toggleMovieInList(String listId, int movieId)
  // ❌ void reorderMoviesInList(String listId, int oldIndex, int newIndex)
  // ❌ void clearList(String listId)

  // AGREGAR métodos que usan repository
  Future<void> addMovieToListAsync(
    String listId, 
    int movieId, {
    String? movieTitle,
    String? posterPath,
  }) async {
    try {
      await _repository.addMovieToList(
        listId, 
        movieId,
        movieTitle: movieTitle,
        posterPath: posterPath,
      );
      
      // No actualizar estado local, el stream lo hará automáticamente
      
      await _runGamificationAction(
        (service) => service.trackMovieAddedToList(movieId, listId),
      );
    } catch (e) {
      LoggerFactory.error('Error añadiendo película a lista: $e');
      rethrow;
    }
  }

  Future<void> removeMovieFromListAsync(
    String listId, 
    int movieId,
  ) async {
    try {
      await _repository.removeMovieFromList(listId, movieId);
      // Stream actualizará automáticamente
    } catch (e) {
      LoggerFactory.error('Error removiendo película de lista: $e');
      rethrow;
    }
  }

  Future<void> reorderMoviesAsync(
    String listId, 
    List<ListItem> newOrder,
  ) async {
    try {
      await _repository.reorderListItems(listId, newOrder);
      // Stream actualizará automáticamente
    } catch (e) {
      LoggerFactory.error('Error reordenando películas: $e');
      rethrow;
    }
  }
}
```

---

## 🔄 Flujo de Datos Correcto

### Flujo CREATE LISTA:

```
1. UI: User taps "Create List"
   ↓
2. UI: Calls notifier.createList(name, description, emoji, color)
   ↓
3. Notifier: Calls repository.createList(newList)
   ↓
4. Repository: 
   - Si online: dataSource.createList() → Supabase INSERT
   - Si offline: Save to SharedPreferences + Queue operation
   ↓
5. Supabase: INSERT into user_lists → Triggers realtime event
   ↓
6. DataSource: Stream watchUserLists() emits new list
   ↓
7. Provider: allListsProvider updates automatically
   ↓
8. UI: Rebuilds with new list
```

### Flujo ADD MOVIE TO LIST:

```
1. UI: User taps "Add to List" on movie
   ↓
2. UI: Shows list picker
   ↓
3. UI: User selects list → Calls notifier.addMovieToListAsync()
   ↓
4. Notifier: Calls repository.addMovieToList(listId, movieId)
   ↓
5. Repository:
   - Si online: dataSource.addMovieToList() → Supabase INSERT
   - Si offline: Queue operation
   ↓
6. Supabase: INSERT into user_list_items → Triggers realtime event
   ↓
7. DataSource: Stream watchListItems(listId) emits new item
   ↓
8. Provider: listItemsProvider(listId) updates automatically
   ↓
9. UI: Rebuilds showing new movie in list
```

### Flujo REMOVE MOVIE FROM LIST:

```
1. UI: User swipes to delete or taps delete button
   ↓
2. UI: Calls notifier.removeMovieFromListAsync(listId, movieId)
   ↓
3. Notifier: Calls repository.removeMovieFromList()
   ↓
4. Repository:
   - Si online: dataSource.removeMovieFromList() → Supabase DELETE
   - Si offline: Queue operation
   ↓
5. Supabase: DELETE from user_list_items → Triggers realtime event
   ↓
6. DataSource: Stream watchListItems(listId) emits updated items
   ↓
7. Provider: listItemsProvider(listId) updates automatically
   ↓
8. UI: Rebuilds without deleted movie
```

### Flujo REORDER MOVIES:

```
1. UI: User drags movie to new position in ReorderableListView
   ↓
2. UI: onReorder callback → Calls notifier.reorderMoviesAsync()
   ↓
3. Notifier: Calls repository.reorderListItems(listId, newOrderedItems)
   ↓
4. Repository:
   - Si online: dataSource.reorderListItems() → Multiple Supabase UPDATEs
   - Si offline: Queue operation
   ↓
5. Supabase: UPDATE user_list_items SET position → Triggers realtime events
   ↓
6. DataSource: Stream watchListItems(listId) emits reordered items
   ↓
7. Provider: listItemsProvider(listId) updates automatically
   ↓
8. UI: Rebuilds with new order
```

---

## ⚠️ Problemas que se Resolverán

### ✅ Problema 1: movieIds Desincronizado
**Solución:** Eliminar `movieIds` de `CustomList`, usar `listItemsProvider` separado

### ✅ Problema 2: Sin Sync Realtime
**Solución:** Cambiar de `FutureProvider` a `StreamProvider`, integrar streams de Supabase

### ✅ Problema 3: CRUD Incompleto
**Solución:** Implementar todas las operaciones en repository y dataSource

### ✅ Problema 4: Offline No Funciona Bien
**Solución:** Queue priorizado + sincronización ordenada

### ✅ Problema 5: UI No Actualiza Automáticamente
**Solución:** Usar `StreamProvider` que se actualiza automáticamente con realtime

---

## 📝 Tareas Prioritarias

### 🔴 URGENTE (Hacer Primero)

1. [ ] **Refactorizar `CustomList`**: Eliminar `movieIds`
2. [ ] **Crear `listItemsProvider`**: StreamProvider para películas
3. [ ] **Cambiar `allListsProvider`**: De Future a Stream
4. [ ] **Actualizar Repository**: Implementar todos los métodos de list_items
5. [ ] **Actualizar Notifier**: Eliminar métodos síncronos, usar async

### 🟡 IMPORTANTE (Hacer Después)

6. [ ] **Actualizar UI**: MovieListDetailScreen con streams
7. [ ] **Implementar Offline Queue Priorizado**
8. [ ] **Testing**: Unit tests para nuevos providers
9. [ ] **Testing**: Integration tests para sync realtime
10. [ ] **Documentación**: Actualizar README con nueva arquitectura

### 🟢 OPCIONAL (Mejoras Futuras)

11. [ ] **Optimistic Updates**: Para mejor UX
12. [ ] **Conflict Resolution**: Para sync avanzado
13. [ ] **Batch Operations**: Para múltiples cambios
14. [ ] **Analytics**: Tracking de uso de listas
15. [ ] **Sharing**: Compartir listas públicas

---

## 🧪 Testing Plan

### Unit Tests

```dart
// test/providers/list_items_provider_test.dart
test('listItemsProvider emits items when list updated', () async {
  // Setup
  final container = ProviderContainer(
    overrides: [
      customListsRepositoryProvider.overrideWithValue(mockRepository),
    ],
  );

  // Mock stream
  when(mockRepository.watchListItems(any))
    .thenAnswer((_) => Stream.value([testItem1, testItem2]));

  // Test
  final items = await container.read(listItemsProvider('list1').future);

  // Assert
  expect(items, hasLength(2));
  expect(items[0].movieId, equals(123));
});
```

### Integration Tests

```dart
// integration_test/lists_flow_test.dart
testWidgets('Create list and add movie realtime sync', (tester) async {
  // 1. Login
  await tester.pumpWidget(MyApp());
  await login(tester);

  // 2. Create list
  await tapCreateListButton(tester);
  await enterListName(tester, 'Test List');
  await tapSaveButton(tester);

  // 3. Verify list appears (realtime)
  await tester.pumpAndSettle();
  expect(find.text('Test List'), findsOneWidget);

  // 4. Add movie to list
  await navigateToMovie(tester, 123);
  await tapAddToListButton(tester);
  await selectList(tester, 'Test List');

  // 5. Navigate to list
  await navigateToList(tester, 'Test List');

  // 6. Verify movie appears (realtime)
  await tester.pumpAndSettle(Duration(seconds: 2));
  expect(find.byType(MovieListTile), findsOneWidget);
});
```

---

## 📚 Referencias

### Archivos Clave a Modificar

1. `lib/domain/entities/custom_list.dart` - Eliminar movieIds
2. `lib/domain/repositories/i_custom_lists_repository.dart` - Métodos completos
3. `lib/infrastructure/repositories/custom_lists_repository_impl.dart` - Implementación
4. `lib/infrastructure/datasources/supabase_custom_lists_datasource.dart` - Streams
5. `lib/presentation/providers/custom_lists_provider.dart` - StreamProviders
6. `lib/services/list_sync_service.dart` - Queue priorizado
7. `lib/presentation/screens/lists/movie_list_detail_screen.dart` - UI actualizada

### Esquema de Base de Datos

- `supabase/migrations/create_sync_tables.sql` - Tablas existentes ✅
- `supabase/migrations/enable_realtime.sql` - Realtime habilitado ✅

---

## 🎯 Resultado Esperado

Después de implementar este plan:

✅ Listas y películas se sincronizan automáticamente vía realtime  
✅ CRUD completo para listas y películas funcional  
✅ Offline-first con queue priorizado  
✅ UI se actualiza automáticamente sin refreshes manuales  
✅ Modelo de datos consistente entre local y remoto  
✅ Tests completos para garantizar estabilidad  

---

**Próximo Paso:** Comenzar con FASE 1 - Refactorizar Modelo de Datos
