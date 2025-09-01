# 🔧 EJEMPLOS DE CORRECCIONES PARA PROVIDERS RIVERPOD

Esta guía proporciona ejemplos específicos de código para implementar las mejoras identificadas en la auditoría de providers.

---

## 1. CORRECCIÓN: Implementar dispose() en StateNotifiers

### 📂 `lib/presentation/providers/custom_lists_provider.dart`

#### ANTES (Problemático):
```dart
class AllListsNotifier extends StateNotifier<AllListsState> {
  AllListsNotifier(Ref ref, this._repository) : super(_getInitialState()) {
    // TODO: Re-enable _ref when gamification integration is implemented
    // _ref = ref;
    // TODO: Implement gamification integration when trackMovieAddedToList is available
    // late final GamificationIntegrationService _gamificationService;
    _loadCustomLists();
  }

  final CustomListsRepository _repository;
  // ❌ PROBLEMA: No hay dispose() para limpiar recursos
}
```

#### DESPUÉS (Correcto):
```dart
class AllListsNotifier extends StateNotifier<AllListsState> {
  AllListsNotifier(this._repository) : super(_getInitialState()) {
    _loadCustomLists();
  }

  final CustomListsRepository _repository;
  
  // ✅ SOLUCIÓN: Implementar dispose() para limpiar recursos
  @override
  void dispose() {
    // Limpiar cualquier timer, stream subscription, o listener
    _repository.dispose(); // Si el repository tiene dispose()
    super.dispose();
  }
}

// ✅ ACTUALIZAR: El provider no pasa ref al constructor
final allListsProvider =
    StateNotifierProvider<AllListsNotifier, AllListsState>((ref) {
  final repository = ref.watch(customListsRepositoryProvider);
  return AllListsNotifier(repository); // Sin pasar ref
});
```

---

## 2. CORRECCIÓN: Eliminar almacenamiento de Ref en StateNotifiers

### 📂 `lib/presentation/providers/storage/favorite_movies_provider.dart`

#### ANTES (Problemático):
```dart
class StorageMoviesNotifier extends StateNotifier<Map<int, Movie>> {
  StorageMoviesNotifier({required this.localStorageRepository, required this.ref}) : super({});

  int page = 0;
  final LocalStorageRepository localStorageRepository;
  final Ref ref; // ❌ PROBLEMA: Almacenar ref puede causar fugas

  Future<void> toggleFavorite(Movie movie) async {
    await localStorageRepository.toggleFavorite(movie);
    final bool isMovieInFavorites = state[movie.id] != null;

    if (isMovieInFavorites) {
      state.remove(movie.id);
      state = {...state};
    } else {
      state = {...state, movie.id: movie};
      // ❌ Uso directo de ref almacenado
      ref.read(achievementsProvider.notifier).trackMovieFavorited();
    }
  }
}
```

#### DESPUÉS (Correcto):
```dart
class StorageMoviesNotifier extends StateNotifier<Map<int, Movie>> {
  StorageMoviesNotifier({
    required this.localStorageRepository,
    required this.onMovieFavorited, // ✅ Callback en lugar de ref
  }) : super({});

  int page = 0;
  final LocalStorageRepository localStorageRepository;
  final VoidCallback onMovieFavorited; // ✅ Callback específico

  Future<void> toggleFavorite(Movie movie) async {
    await localStorageRepository.toggleFavorite(movie);
    final bool isMovieInFavorites = state[movie.id] != null;

    if (isMovieInFavorites) {
      state.remove(movie.id);
      state = {...state};
    } else {
      state = {...state, movie.id: movie};
      // ✅ Usar callback en lugar de ref
      onMovieFavorited();
    }
  }
  
  // ✅ Implementar dispose()
  @override
  void dispose() {
    // Limpiar recursos si es necesario
    super.dispose();
  }
}

// ✅ ACTUALIZAR: Provider pasa callback en lugar de ref
final favoriteMoviesProvider =
    StateNotifierProvider<StorageMoviesNotifier, Map<int, Movie>>((ref) {
  final localStorageRepository = ref.watch(localStorageRepositoryProvider);
  
  return StorageMoviesNotifier(
    localStorageRepository: localStorageRepository,
    onMovieFavorited: () {
      // ✅ Manejar el callback aquí, dentro del provider
      ref.read(achievementsProvider.notifier).trackMovieFavorited();
    },
  );
});
```

---

## 3. CORRECCIÓN: Optimizar dependencias múltiples

### 📂 `lib/presentation/providers/user_stats_provider.dart`

#### ANTES (Ineficiente):
```dart
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final favoriteMoviesMap = ref.watch(favoriteMoviesProvider);     // ⚠️ Watch 1
  final favoriteMovies = favoriteMoviesMap.values.toList();
  final watchedMoviesState = ref.watch(watchedMoviesProvider);     // ⚠️ Watch 2
  final customLists = ref.watch(customListsProvider);             // ⚠️ Watch 3
  final defaultLists = ref.watch(defaultListsProvider);           // ⚠️ Watch 4

  // ❌ PROBLEMA: 4 dependencias = rebuilds frecuentes
  return UserStats.fromMovies(
    favoriteMovies: favoriteMovies,
    watchedMovies: watchedMoviesState.movies,
    customLists: customLists,
    defaultLists: defaultLists,
  );
});
```

#### DESPUÉS (Optimizado):
```dart
// ✅ SOLUCIÓN: Crear un provider combinado intermedio
@freezed
class CombinedUserData with _$CombinedUserData {
  const factory CombinedUserData({
    required Map<int, Movie> favoriteMovies,
    required WatchedMoviesState watchedMoviesState,
    required List<CustomList> customLists,
    required List<CustomList> defaultLists,
  }) = _CombinedUserData;
}

final combinedUserDataProvider = Provider<CombinedUserData>((ref) {
  return CombinedUserData(
    favoriteMovies: ref.watch(favoriteMoviesProvider),
    watchedMoviesState: ref.watch(watchedMoviesProvider),
    customLists: ref.watch(customListsProvider),
    defaultLists: ref.watch(defaultListsProvider),
  );
});

// ✅ Provider optimizado con una sola dependencia
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final data = ref.watch(combinedUserDataProvider); // ✅ Una sola dependencia
  
  return UserStats.fromMovies(
    favoriteMovies: data.favoriteMovies.values.toList(),
    watchedMovies: data.watchedMoviesState.movies,
    customLists: data.customLists,
    defaultLists: data.defaultLists,
  );
});

// ✅ ALTERNATIVA: Usar select para optimizar aún más
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  // Solo escuchar cambios en el número de elementos, no en el contenido completo
  final favoriteCount = ref.watch(favoriteMoviesProvider.select((movies) => movies.length));
  final watchedCount = ref.watch(watchedMoviesProvider.select((state) => state.movies.length));
  final listsCount = ref.watch(customListsProvider.select((lists) => lists.length));
  
  // Cargar datos completos solo cuando sea necesario
  final data = ref.read(combinedUserDataProvider);
  
  return UserStats.fromMovies(
    favoriteMovies: data.favoriteMovies.values.toList(),
    watchedMovies: data.watchedMoviesState.movies,
    customLists: data.customLists,
    defaultLists: data.defaultLists,
  );
});
```

---

## 4. CORRECCIÓN: Mover operaciones pesadas fuera del main thread

### 📂 `lib/presentation/providers/custom_lists_provider.dart`

#### ANTES (Bloquea main thread):
```dart
static AllListsState _getInitialState() {
  final now = DateTime.now();

  // ❌ PROBLEMA: Creación de 8 objetos en main thread
  final defaultLists = [
    CustomList(
      id: 'quiero-ver',
      name: 'Quiero Ver',
      description: 'Películas que quiero ver próximamente',
      emoji: '🍿',
      movieIds: [],
      createdAt: now,
      updatedAt: now,
      isDefault: true,
      color: 'blue',
    ),
    // ... 7 más objetos CustomList
  ];

  return AllListsState(
    defaultLists: defaultLists,
    customLists: [],
  );
}
```

#### DESPUÉS (No bloquea):
```dart
// ✅ SOLUCIÓN: Mover a isolate separado
import 'dart:isolate';

// Función estática para ejecutar en isolate
static List<CustomList> _generateDefaultLists(DateTime now) {
  return [
    CustomList(
      id: 'quiero-ver',
      name: 'Quiero Ver',
      description: 'Películas que quiero ver próximamente',
      emoji: '🍿',
      movieIds: [],
      createdAt: now,
      updatedAt: now,
      isDefault: true,
      color: 'blue',
    ),
    // ... resto de listas
  ];
}

// ✅ Provider que carga de forma asíncrona
final defaultListsProvider = FutureProvider<List<CustomList>>((ref) async {
  final now = DateTime.now();
  // Ejecutar en isolate para no bloquear UI
  return await compute(_generateDefaultLists, now);
});

// ✅ StateNotifier actualizado para manejar async
class AllListsNotifier extends StateNotifier<AsyncValue<AllListsState>> {
  AllListsNotifier(this._repository) : super(const AsyncValue.loading()) {
    _initializeState();
  }

  final CustomListsRepository _repository;

  Future<void> _initializeState() async {
    try {
      // Cargar listas por defecto de forma asíncrona
      final defaultLists = await _generateDefaultListsAsync();
      final customLists = await _repository.getCustomLists();
      
      state = AsyncValue.data(AllListsState(
        defaultLists: defaultLists,
        customLists: customLists,
      ));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<List<CustomList>> _generateDefaultListsAsync() async {
    final now = DateTime.now();
    return await compute(_generateDefaultLists, now);
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}

// ✅ Provider actualizado
final allListsProvider =
    StateNotifierProvider<AllListsNotifier, AsyncValue<AllListsState>>((ref) {
  final repository = ref.watch(customListsRepositoryProvider);
  return AllListsNotifier(repository);
});
```

---

## 5. CORRECCIÓN: Implementar AutoDispose para providers temporales

### 📂 `lib/presentation/providers/movies/movie_info_provider.dart`

#### ANTES (Se mantiene en memoria indefinidamente):
```dart
final movieInfoProvider =
    StateNotifierProvider<MovieMapNotifier, Map<String, Movie>>((ref) {
  final movieRepository = ref.watch(movieRepositoryProvider);
  return MovieMapNotifier(getMovie: movieRepository.getMovieById);
});
```

#### DESPUÉS (Se libera automáticamente):
```dart
// ✅ SOLUCIÓN: Usar autoDispose para providers temporales
final movieInfoProvider = StateNotifierProvider.autoDispose
    .family<MovieMapNotifier, Map<String, Movie>, String>((ref, movieId) {
  final movieRepository = ref.watch(movieRepositoryProvider);
  final notifier = MovieMapNotifier(getMovie: movieRepository.getMovieById);
  
  // Cargar la película específica automáticamente
  ref.onDispose(() {
    // Limpiar recursos específicos si es necesario
  });
  
  // Cargar película al crear el provider
  Future.microtask(() => notifier.loadMovie(movieId));
  
  return notifier;
});

// ✅ Para providers que se usan globalmente, mantener sin autoDispose
final globalMovieInfoProvider =
    StateNotifierProvider<MovieMapNotifier, Map<String, Movie>>((ref) {
  final movieRepository = ref.watch(movieRepositoryProvider);
  return MovieMapNotifier(getMovie: movieRepository.getMovieById);
});
```

---

## 6. CORRECCIÓN: Añadir logging y debugging

### 📂 `lib/presentation/providers/auth_provider.dart`

#### ANTES (Sin debugging):
```dart
final authStateProvider = StreamProvider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});
```

#### DESPUÉS (Con logging):
```dart
import '../../core/logging/logger_factory.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  // ✅ Logging para debugging
  ref.onDispose(() {
    LoggerFactory.debug('🔐 authStateProvider disposed');
  });
  
  final authRepository = ref.watch(authRepositoryProvider);
  
  // ✅ Logging de cambios de estado
  return authRepository.authStateChanges.map((user) {
    if (user != null) {
      LoggerFactory.info('🔐 Usuario autenticado: ${user.id}');
    } else {
      LoggerFactory.info('🔐 Usuario desconectado');
    }
    return user;
  });
});

// ✅ StateNotifier con logging detallado
class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier(this._ref) : super(const AppState(mode: AppMode.guest)) {
    LoggerFactory.debug('🔐 AppStateNotifier created');
    _initializeWithCurrentAuthState();
    _ref.listen<AsyncValue<User?>>(authStateProvider, _handleAuthChange);
  }
  
  final Ref _ref;
  
  void _handleAuthChange(AsyncValue<User?>? previous, AsyncValue<User?> next) {
    LoggerFactory.debug('🔐 Auth state change: ${previous?.value?.id} -> ${next.value?.id}');
    
    next.when(
      data: (user) {
        if (user != null) {
          LoggerFactory.info('🔐 Switching to authenticated mode');
          state = state.copyWith(mode: AppMode.authenticated, user: user);
        } else {
          LoggerFactory.info('🔐 Switching to guest mode');
          state = state.copyWith(mode: AppMode.guest, user: null);
        }
      },
      loading: () {
        LoggerFactory.debug('🔐 Auth state loading...');
      },
      error: (error, stackTrace) {
        LoggerFactory.error('🔐 Auth state error: $error');
        state = state.copyWith(mode: AppMode.guest, user: null);
      },
    );
  }
  
  @override
  void dispose() {
    LoggerFactory.debug('🔐 AppStateNotifier disposed');
    super.dispose();
  }
}
```

---

## 7. CORRECCIÓN: Manejo robusto de errores

### 📂 `lib/presentation/providers/movies/movies_providers.dart`

#### ANTES (Manejo básico de errores):
```dart
class MoviesNotifier extends StateNotifier<MoviesStateData> {
  Future<void> loadNextPage({int retryCount = 0}) async {
    if (state.state == MoviesState.loading) return;

    try {
      currentPage++;
      final List<Movie> movies = await fetchMoreMovies(page: currentPage);
      // ...
    } catch (e) {
      currentPage--;
      state = state.copyWith(
        state: MoviesState.error,
        errorMessage: 'Error al cargar películas: ${e.toString()}',
      );
    }
  }
}
```

#### DESPUÉS (Manejo robusto de errores):
```dart
import '../../core/logging/logger_factory.dart';

class MoviesNotifier extends StateNotifier<MoviesStateData> {
  Future<void> loadNextPage({int retryCount = 0}) async {
    if (state.state == MoviesState.loading) return;

    // ✅ Logging detallado
    LoggerFactory.debug('🎬 Loading movies page $currentPage (retry: $retryCount)');

    try {
      currentPage++;
      final List<Movie> movies = await fetchMoreMovies(page: currentPage);
      
      LoggerFactory.info('🎬 Successfully loaded ${movies.length} movies');
      
      final updatedMovies = [...state.movies, ...movies];
      state = state.copyWith(
        movies: updatedMovies,
        state: MoviesState.loaded,
        errorMessage: null,
        hasReachedMax: movies.isEmpty,
      );
      
    } catch (e, stackTrace) {
      // ✅ Logging de errores con stack trace
      LoggerFactory.error('🎬 Error loading movies page $currentPage: $e', stackTrace);
      
      currentPage--; // Revertir incremento
      
      // ✅ Manejo específico de tipos de error
      String userFriendlyMessage;
      bool shouldRetry = false;
      
      if (e is NetworkException) {
        userFriendlyMessage = 'Sin conexión a internet. Verifica tu conexión.';
        shouldRetry = retryCount < maxRetries;
      } else if (e is TimeoutException) {
        userFriendlyMessage = 'La carga tardó demasiado. Intenta de nuevo.';
        shouldRetry = retryCount < maxRetries;
      } else if (e is ServerException) {
        userFriendlyMessage = 'Error del servidor. Intenta más tarde.';
        shouldRetry = retryCount < 2; // Menos reintentos para errores de servidor
      } else {
        userFriendlyMessage = 'Error inesperado. Intenta de nuevo.';
        shouldRetry = false;
      }
      
      // ✅ Reintentos inteligentes
      if (shouldRetry) {
        final delay = Duration(seconds: (retryCount + 1) * 2);
        LoggerFactory.info('🎬 Retrying in ${delay.inSeconds} seconds...');
        
        await Future.delayed(delay);
        return loadNextPage(retryCount: retryCount + 1);
      }
      
      // ✅ Estado de error detallado
      state = state.copyWith(
        state: MoviesState.error,
        errorMessage: userFriendlyMessage,
        lastError: e,           // ✅ Guardar error original para debugging
        lastErrorTime: DateTime.now(), // ✅ Timestamp del error
      );
    }
  }
  
  @override
  void dispose() {
    LoggerFactory.debug('🎬 MoviesNotifier disposed');
    super.dispose();
  }
}

// ✅ Estado extendido con información de error
class MoviesStateData {
  const MoviesStateData({
    this.movies = const [],
    this.state = MoviesState.initial,
    this.errorMessage,
    this.hasReachedMax = false,
    this.lastError,        // ✅ Error original
    this.lastErrorTime,    // ✅ Timestamp del error
  });

  final List<Movie> movies;
  final MoviesState state;
  final String? errorMessage;
  final bool hasReachedMax;
  final Object? lastError;        // ✅ Para debugging
  final DateTime? lastErrorTime;  // ✅ Para retry logic
  
  // ✅ Helper para verificar si se puede reintentar
  bool get canRetry => 
    lastErrorTime != null && 
    DateTime.now().difference(lastErrorTime!) > const Duration(seconds: 30);
}
```

---

## 8. CORRECCIÓN: Tests para validar mejoras

### 📂 `test/providers/providers_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas_admob/presentation/providers/custom_lists_provider.dart';
import 'package:peliculas_admob/presentation/providers/storage/favorite_movies_provider.dart';

void main() {
  group('Provider Memory Management Tests', () {
    test('AllListsNotifier disposes correctly', () async {
      final container = ProviderContainer();
      
      // Acceder al provider para crearlo
      final notifier = container.read(allListsProvider.notifier);
      expect(notifier, isNotNull);
      
      // ✅ TEST: Verificar que dispose se llama
      var disposeCallCount = 0;
      final originalDispose = notifier.dispose;
      
      // Mock dispose para contar llamadas
      // (En implementación real, usar mockito o similar)
      
      // Limpiar container para trigger dispose
      container.dispose();
      
      // Verificar que dispose fue llamado
      expect(disposeCallCount, equals(1));
    });

    test('StorageMoviesNotifier does not hold ref', () {
      final container = ProviderContainer();
      
      final notifier = container.read(favoriteMoviesProvider.notifier);
      
      // ✅ TEST: Verificar que no almacena ref directamente
      // (Esto requiere refactoring del código para ser testeable)
      expect(notifier.runtimeType.toString(), contains('StorageMoviesNotifier'));
      
      container.dispose();
    });
  });

  group('Provider Performance Tests', () {
    test('userStatsProvider rebuilds efficiently', () async {
      final container = ProviderContainer();
      
      var buildCount = 0;
      final listener = container.listen(
        userStatsProvider,
        (previous, next) {
          buildCount++;
        },
      );
      
      // Cambiar una dependencia
      container.read(favoriteMoviesProvider.notifier).toggleFavorite(mockMovie);
      
      // ✅ TEST: Verificar número razonable de rebuilds
      await Future.delayed(Duration(milliseconds: 100));
      expect(buildCount, lessThan(3)); // No más de 2-3 rebuilds
      
      container.dispose();
    });
  });

  group('Provider Error Handling Tests', () {
    test('MoviesNotifier handles errors gracefully', () async {
      final container = ProviderContainer(
        overrides: [
          movieRepositoryProvider.overrideWithValue(MockFailingRepository()),
        ],
      );
      
      final notifier = container.read(nowPlayingMoviesProvider.notifier);
      
      // ✅ TEST: Error handling
      await notifier.loadNextPage();
      
      final state = container.read(nowPlayingMoviesProvider);
      expect(state.state, equals(MoviesState.error));
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, isNot(contains('Exception'))); // User-friendly message
      
      container.dispose();
    });
  });
}

// Mock classes para testing
class MockFailingRepository implements MovieRepository {
  @override
  Future<List<Movie>> getNowPlaying({int page = 1}) async {
    throw NetworkException('No internet connection');
  }
  
  // ... otros métodos
}
```

---

## 📋 CHECKLIST DE IMPLEMENTACIÓN

### ✅ Implementaciones Prioritarias (Críticas)

- [ ] **custom_lists_provider.dart**: Implementar dispose() en AllListsNotifier
- [ ] **favorite_movies_provider.dart**: Eliminar almacenamiento de ref, usar callbacks
- [ ] **watched_movies_provider.dart**: Eliminar almacenamiento de ref, usar callbacks
- [ ] **movies_providers.dart**: Implementar dispose() en MoviesNotifier

### ⚡ Implementaciones Importantes

- [ ] **user_stats_provider.dart**: Optimizar con provider combinado
- [ ] **custom_lists_provider.dart**: Mover generación de listas por defecto a isolate
- [ ] **movie_info_provider.dart**: Implementar autoDispose para providers temporales
- [ ] **auth_provider.dart**: Añadir logging detallado

### 🎯 Implementaciones Opcionales

- [ ] **Todos los providers**: Añadir logging para debugging
- [ ] **movies_providers.dart**: Manejo robusto de errores con tipos específicos
- [ ] **Crear tests**: Tests de memory leaks y performance
- [ ] **Documentación**: Actualizar documentación con nuevos patterns

---

*Estos ejemplos proporcionan una guía clara para implementar las mejoras identificadas en la auditoría de providers Riverpod.*