# 💻 Código Listo para Implementar - Fixes Críticos

## 1. FIX: Custom Lists con Persistencia Local

### Archivo: `lib/presentation/providers/storage/direct_custom_lists_provider.dart`

```dart
// AGREGAR estos imports al inicio
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// AGREGAR estos métodos a la clase DirectCustomListsNotifier

  /// Persiste el estado actual en almacenamiento local
  Future<void> _persistToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar listas
      final listsJson = state.lists.values.map((list) => list.toJson()).toList();
      await prefs.setString('custom_lists_cache', jsonEncode(listsJson));

      // Guardar items de listas
      final itemsJson = <String, dynamic>{};
      state.listItems.forEach((listId, movieIds) {
        itemsJson[listId] = movieIds;
      });
      await prefs.setString('custom_list_items_cache', jsonEncode(itemsJson));

      LoggerFactory.debug('✅ Estado persistido localmente');
    } catch (e) {
      LoggerFactory.error('❌ Error persistiendo estado local: $e');
    }
  }

  /// Carga el estado desde almacenamiento local
  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cargar listas
      final listsString = prefs.getString('custom_lists_cache');
      if (listsString != null) {
        final listsJson = jsonDecode(listsString) as List;
        final lists = <String, CustomList>{};
        for (final json in listsJson) {
          final list = CustomList.fromJson(json as Map<String, dynamic>);
          lists[list.id] = list;
        }

        // Cargar items
        final itemsString = prefs.getString('custom_list_items_cache');
        final items = <String, List<int>>{};
        if (itemsString != null) {
          final itemsJson = jsonDecode(itemsString) as Map<String, dynamic>;
          itemsJson.forEach((listId, movieIds) {
            items[listId] = List<int>.from(movieIds as List);
          });
        }

        state = CustomListsState(
          lists: lists,
          listItems: items,
        );

        LoggerFactory.info('✅ Estado cargado desde caché local');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error cargando estado local: $e');
    }
  }

  // MODIFICAR el método addMovieToList para incluir persistencia
  Future<void> addMovieToList(String listId, int movieId) async {
    // ... código existente ...

    state = currentState.copyWith(listItems: updatedItems);
    LoggerFactory.info('✅ [DEBUG] Estado local actualizado optimísticamente');

    // AGREGAR esta línea
    await _persistToLocal();

    // ... resto del código ...
  }

  // MODIFICAR init() para cargar desde local primero
  Future<void> init() async {
    // Cargar desde caché local primero
    await _loadFromLocal();

    // Luego sincronizar con servidor
    // ... código existente de init ...
  }
```

## 2. FIX: Suscripciones Real-Time

### Archivo: `lib/presentation/providers/storage/direct_custom_lists_provider.dart`

```dart
// AGREGAR estos campos a la clase
  StreamSubscription? _listsSubscription;
  StreamSubscription? _itemsSubscription;
  Timer? _reconnectionTimer;

// AGREGAR este método para configurar real-time
  void _setupRealtimeSubscriptions() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    LoggerFactory.info('🔔 Configurando suscripciones real-time...');

    // Suscripción a cambios en listas
    _listsSubscription = _supabase
        .channel('user_lists_changes_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_lists',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            LoggerFactory.info('📨 Cambio real-time en listas: ${payload.eventType}');
            _handleListChange(payload);
          },
        )
        .subscribe();

    // Suscripción a cambios en items
    _itemsSubscription = _supabase
        .channel('user_list_items_changes_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_list_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            LoggerFactory.info('📨 Cambio real-time en items: ${payload.eventType}');
            _handleItemChange(payload);
          },
        )
        .subscribe();

    // Configurar reconexión automática
    _setupAutoReconnection();
  }

  void _handleListChange(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.insert) {
      final newList = _dataToCustomList(payload.newRecord);
      final updatedLists = Map<String, CustomList>.from(state.lists);
      updatedLists[newList.id] = newList;
      state = state.copyWith(lists: updatedLists);
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final updatedList = _dataToCustomList(payload.newRecord);
      final updatedLists = Map<String, CustomList>.from(state.lists);
      updatedLists[updatedList.id] = updatedList;
      state = state.copyWith(lists: updatedLists);
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      final listId = payload.oldRecord['id'] as String;
      final updatedLists = Map<String, CustomList>.from(state.lists);
      final updatedItems = Map<String, List<int>>.from(state.listItems);
      updatedLists.remove(listId);
      updatedItems.remove(listId);
      state = state.copyWith(lists: updatedLists, listItems: updatedItems);
    }

    _persistToLocal(); // Persistir cambios
  }

  void _handleItemChange(PostgresChangePayload payload) {
    final listId = payload.newRecord?['list_id'] ?? payload.oldRecord?['list_id'];
    final movieId = payload.newRecord?['movie_id'] ?? payload.oldRecord?['movie_id'];

    if (listId == null || movieId == null) return;

    final currentItems = state.listItems[listId] ?? [];
    final updatedItems = Map<String, List<int>>.from(state.listItems);

    if (payload.eventType == PostgresChangeEvent.insert) {
      if (!currentItems.contains(movieId)) {
        updatedItems[listId] = [...currentItems, movieId];
      }
    } else if (payload.eventType == PostgresChangeEvent.delete ||
               (payload.eventType == PostgresChangeEvent.update &&
                payload.newRecord?['is_deleted'] == true)) {
      updatedItems[listId] = currentItems.where((id) => id != movieId).toList();
    }

    state = state.copyWith(listItems: updatedItems);
    _persistToLocal(); // Persistir cambios
  }

  void _setupAutoReconnection() {
    _reconnectionTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (!_isConnected()) {
        LoggerFactory.info('🔄 Intentando reconectar real-time...');
        _reconnect();
      }
    });
  }

  bool _isConnected() {
    // Verificar estado de conexión
    return _listsSubscription != null && _itemsSubscription != null;
  }

  void _reconnect() {
    dispose();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _listsSubscription?.cancel();
    _itemsSubscription?.cancel();
    _reconnectionTimer?.cancel();
    super.dispose();
  }
```

## 3. FIX: Performance - Virtual Scrolling

### Archivo: `lib/presentation/widgets/movies/optimized_movie_grid.dart`

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OptimizedMovieGrid extends StatelessWidget {
  final List<int> movieIds;
  final Function(int) onMovieTap;

  const OptimizedMovieGrid({
    Key? key,
    required this.movieIds,
    required this.onMovieTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // Configuración optimizada
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      // Performance improvements
      cacheExtent: 500, // Pre-cachear 500 pixels
      addAutomaticKeepAlives: false, // No mantener widgets vivos
      addRepaintBoundaries: true, // Optimizar repintado
      itemCount: movieIds.length,
      itemBuilder: (context, index) {
        return OptimizedMovieCard(
          movieId: movieIds[index],
          onTap: () => onMovieTap(movieIds[index]),
        );
      },
    );
  }
}

class OptimizedMovieCard extends StatelessWidget {
  final int movieId;
  final VoidCallback onTap;

  const OptimizedMovieCard({
    Key? key,
    required this.movieId,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[900],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: 'https://image.tmdb.org/t/p/w200/movie_$movieId.jpg',
            fit: BoxFit.cover,
            memCacheWidth: 200, // Limitar tamaño en memoria
            memCacheHeight: 300,
            placeholder: (context, url) => Container(
              color: Colors.grey[800],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[800],
              child: const Icon(Icons.error, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}
```

## 4. FIX: Movie Mapper con Géneros

### Archivo: `lib/infrastructure/mappers/movie_mapper.dart`

```dart
class MovieMapper {
  static const Map<int, String> GENRE_MAP = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Science Fiction',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western'
  };

  static Movie movieDBToEntity(MovieMovieDB moviedb) {
    return Movie(
      adult: moviedb.adult,
      backdropPath: moviedb.backdropPath != null
          ? 'https://image.tmdb.org/t/p/w500${moviedb.backdropPath}'
          : 'https://via.placeholder.com/500x281',
      genreIds: moviedb.genreIds,
      // NUEVO: Agregar campo de nombres de géneros
      genreNames: _mapGenreIdsToNames(moviedb.genreIds),
      id: moviedb.id,
      originalLanguage: moviedb.originalLanguage,
      originalTitle: moviedb.originalTitle,
      overview: moviedb.overview ?? '',
      popularity: moviedb.popularity,
      posterPath: moviedb.posterPath != null
          ? 'https://image.tmdb.org/t/p/w500${moviedb.posterPath}'
          : 'https://via.placeholder.com/400x600',
      releaseDate: moviedb.releaseDate,
      title: moviedb.title,
      video: moviedb.video,
      voteAverage: moviedb.voteAverage,
      voteCount: moviedb.voteCount
    );
  }

  static String _mapGenreIdsToNames(List<int> genreIds) {
    if (genreIds.isEmpty) return 'Sin género';

    return genreIds
        .map((id) => GENRE_MAP[id] ?? 'Desconocido')
        .take(3) // Máximo 3 géneros para no sobrecargar UI
        .join(', ');
  }

  // Método helper para obtener género principal
  static String getPrimaryGenre(List<int> genreIds) {
    if (genreIds.isEmpty) return 'Sin género';
    return GENRE_MAP[genreIds.first] ?? 'Desconocido';
  }
}
```

## 5. SQL: Habilitar Real-Time en Supabase

### Archivo: `supabase/migrations/enable_realtime_all_tables.sql`

```sql
-- Habilitar real-time para todas las tablas necesarias
BEGIN;

-- Verificar y habilitar publicación real-time si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

-- Agregar tablas a la publicación real-time
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.user_lists;
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.user_list_items;
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.favorite_movies;
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.watched_movies;
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.watchlist_movies;
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.movie_ratings;

-- Verificar que las tablas tienen los campos necesarios
ALTER TABLE public.user_list_items
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Actualizar user_id basándose en el dueño de la lista
UPDATE public.user_list_items uli
SET user_id = ul.user_id
FROM public.user_lists ul
WHERE uli.list_id = ul.id
AND uli.user_id IS NULL;

-- Hacer user_id NOT NULL si no lo es
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_list_items'
        AND column_name = 'user_id'
        AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE public.user_list_items
        ALTER COLUMN user_id SET NOT NULL;
    END IF;
END $$;

-- Crear índices para mejorar performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_list_items_user_sync
ON public.user_list_items(user_id, list_id, is_deleted, last_modified_at DESC);

-- Actualizar políticas RLS
DROP POLICY IF EXISTS "Users can manage their own list items" ON public.user_list_items;

CREATE POLICY "Users can manage their own list items" ON public.user_list_items
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

COMMIT;

-- Verificar que todo está correcto
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename IN ('user_lists', 'user_list_items');
```

## 6. FIX: Memory Leaks en Providers

### Archivo: `lib/presentation/providers/base_provider_with_cleanup.dart`

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class BaseProviderWithCleanup<T> extends StateNotifier<T> {
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];

  BaseProviderWithCleanup(T state) : super(state);

  // Helper para agregar suscripciones que se limpiarán automáticamente
  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  // Helper para agregar timers que se cancelarán automáticamente
  void addTimer(Timer timer) {
    _timers.add(timer);
  }

  @override
  void dispose() {
    // Limpiar todas las suscripciones
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Cancelar todos los timers
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    // Llamar dispose personalizado si existe
    onDispose();

    super.dispose();
  }

  // Override este método en subclases para limpiar recursos adicionales
  void onDispose() {}
}
```

## 7. Script de Testing Rápido

### Archivo: `test_critical_fixes.sh`

```bash
#!/bin/bash

echo "🧪 Testing Critical Fixes..."

# 1. Test Custom Lists
echo "📋 Testing Custom Lists..."
flutter test test/providers/custom_lists_test.dart

# 2. Test Real-time Sync
echo "🔄 Testing Real-time Sync..."
flutter test test/sync/realtime_test.dart

# 3. Test Performance
echo "⚡ Testing Performance..."
flutter test test/widgets/optimized_grid_test.dart

# 4. Integration Test
echo "🔗 Running Integration Tests..."
flutter test integration_test/custom_lists_flow_test.dart

# 5. Build Check
echo "🏗️ Checking Build..."
flutter build apk --debug

echo "✅ All tests completed!"
```

---

## 🚀 Instrucciones de Implementación

1. **Backup primero**:
   ```bash
   git add .
   git commit -m "backup: before critical fixes"
   ```

2. **Implementar en orden**:
   - Primero: SQL migrations en Supabase
   - Segundo: Provider fixes
   - Tercero: UI optimizations

3. **Testing después de cada fix**:
   ```bash
   flutter test
   flutter run
   ```

4. **Monitorear logs**:
   ```bash
   flutter logs | grep -E "ERROR|WARNING|✅|❌"
   ```

---
**IMPORTANTE**: Implementar estos cambios uno a la vez y probar exhaustivamente antes de continuar con el siguiente.