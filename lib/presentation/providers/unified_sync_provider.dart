import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/unified_favorites_sync.dart';
import '../../../core/sync/unified_watched_sync.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/syncable_favorite.dart';
import '../../../domain/entities/syncable_watched_movie.dart';
import '../../../infrastructure/datasources/favorite_movies_hive_datasource.dart';
import '../../../infrastructure/datasources/watched_movies_hive_datasource.dart';

// ============================================
// PROVIDER PARA FAVORITES CON REAL-TIME SYNC
// ============================================

/// Provider unificado para Favorites con sincronización en tiempo real
class UnifiedFavoritesNotifier extends Notifier<Map<int, SyncableFavorite>> {
  late final UnifiedFavoritesSync _syncService;
  late final FavoriteMoviesHiveDatasource _localDatasource;
  StreamSubscription? _realtimeSubscription;
  String? _currentUserId;
  bool _isInitialized = false;

  @override
  Map<int, SyncableFavorite> build() {
    _syncService = UnifiedFavoritesSync.instance;
    _localDatasource = FavoriteMoviesHiveDatasource();

    // Limpiar suscripción anterior al dispose
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
      _isInitialized = false;
    });

    _initializeWithCurrentUser();
    return {};
  }

  void _initializeWithCurrentUser() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.id;
      _loadInitialData();
      _setupRealtimeSync();
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      LoggerFactory.info('📥 UnifiedFavorites: Cargando datos iniciales...');

      // 1. Cargar datos locales primero (rápido)
      final localMovies =
          await _localDatasource.loadMovies(limit: 1000, offset: 0);
      final localMap = <int, SyncableFavorite>{};

      for (final movie in localMovies) {
        localMap[movie.id] = SyncableFavorite.fromMovie(
          userId: userId,
          movie: movie,
        );
      }

      // Actualizar UI con datos locales
      state = localMap;
      LoggerFactory.info(
          '✅ UnifiedFavorites: ${localMap.length} favoritos locales cargados');

      // 2. Luego sincronizar con Supabase (en background)
      _syncWithSupabase();

      _isInitialized = true;
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ UnifiedFavorites: Error cargando datos iniciales: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      state = {};
    }
  }

  Future<void> _syncWithSupabase() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      LoggerFactory.info('🔄 UnifiedFavorites: Sincronizando con Supabase...');

      final remoteData = await _syncService.getUserItems(userId);
      final syncedMap = <int, SyncableFavorite>{};

      for (final data in remoteData) {
        final favorite = _syncService.supabaseDataToEntity(data);
        syncedMap[favorite.movieId] = favorite;

        // Guardar en local si no existe
        if (!await _localDatasource.isMovieFavorite(favorite.movieId)) {
          await _localDatasource.saveFavorite(favorite.toMovie());
        }
      }

      // Actualizar estado con datos sincronizados
      state = syncedMap;
      LoggerFactory.info(
          '✅ UnifiedFavorites: ${syncedMap.length} favoritos sincronizados');
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ UnifiedFavorites: Error sincronizando con Supabase: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
    }
  }

  void _setupRealtimeSync() {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      LoggerFactory.warning(
          '⚠️ UnifiedFavorites: No se puede configurar real-time sync sin userId');
      return;
    }

    // Cancelar suscripción anterior si existe
    _realtimeSubscription?.cancel();

    try {
      LoggerFactory.info(
          '🎯 UnifiedFavorites: Configurando Real-Time Sync para usuario: $userId');

      // ✅ SUSCRIPCIÓN AL STREAM - USAR LA MISMA LÓGICA QUE WATCHLIST
      _realtimeSubscription = _syncService.watchUserItems(userId).listen(
        (favorites) {
          LoggerFactory.info(
              '🔄 UnifiedFavorites: Real-time update recibido - ${favorites.length} items');

          // Convertir a Map<int, SyncableFavorite>
          final newState = <int, SyncableFavorite>{};
          for (final favorite in favorites) {
            newState[favorite.movieId] = favorite;
          }

          // Comparar con estado anterior
          final oldCount = state.length;
          final newCount = newState.length;

          if (oldCount != newCount || !_mapsAreEqual(state, newState)) {
            LoggerFactory.info(
                '📝 UnifiedFavorites: Actualizando state ($oldCount -> $newCount)');
            state = newState;

            // ✅ SINCRONIZAR CON LOCAL STORAGE (igual que Watchlist)
            _updateLocalStorage(favorites);
          } else {
            LoggerFactory.debug(
                '⏭️ UnifiedFavorites: State sin cambios, skip update');
          }
        },
        onError: (error, stackTrace) {
          LoggerFactory.error('❌ UnifiedFavorites: Real-time error: $error');
          LoggerFactory.error('Stack trace: $stackTrace');
        },
        onDone: () {
          LoggerFactory.warning(
              '⚠️ UnifiedFavorites: Stream de real-time cerrado');
        },
        cancelOnError: false, // ✅ NO cancelar el stream en caso de error
      );

      LoggerFactory.info('✅ UnifiedFavorites: Real-Time Sync listener activo');
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ UnifiedFavorites: Error configurando Real-Time: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
    }
  }

  bool _mapsAreEqual(
      Map<int, SyncableFavorite> map1, Map<int, SyncableFavorite> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;
      if (map1[key]!.movieId != map2[key]!.movieId) return false;
    }
    return true;
  }

  Future<void> _updateLocalStorage(List<SyncableFavorite> favorites) async {
    try {
      // Obtener IDs actuales en Supabase
      final remoteIds = favorites.map((f) => f.movieId).toSet();

      // Obtener IDs locales
      final localMovies =
          await _localDatasource.loadMovies(limit: 1000, offset: 0);
      final localIds = localMovies.map((m) => m.id).toSet();

      // Agregar nuevos favoritos al local
      for (final favorite in favorites) {
        if (!localIds.contains(favorite.movieId)) {
          await _localDatasource.saveFavorite(favorite.toMovie());
        }
      }

      // Remover favoritos que ya no están en Supabase
      for (final movieId in localIds) {
        if (!remoteIds.contains(movieId)) {
          await _localDatasource.removeFavoriteById(movieId);
        }
      }
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ UnifiedFavorites: Error actualizando local storage: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
    }
  }

  /// Toggle favorito con sincronización automática
  Future<void> toggleFavorite(Movie movie) async {
    final userId = _currentUserId;
    if (userId == null) {
      LoggerFactory.warning('⚠️ UnifiedFavorites: No hay usuario autenticado');
      return;
    }

    final isCurrentlyFavorite = state.containsKey(movie.id);

    LoggerFactory.info(
        '🔄 UnifiedFavorites: Toggle ${movie.title} (actual: $isCurrentlyFavorite)');

    // Actualización optimista en UI
    final optimisticState = Map<int, SyncableFavorite>.from(state);
    if (isCurrentlyFavorite) {
      optimisticState.remove(movie.id);
    } else {
      final favorite = SyncableFavorite.fromMovie(
        userId: userId,
        movie: movie,
      );
      optimisticState[movie.id] = favorite;
    }
    state = optimisticState;

    try {
      // Actualizar local
      await _localDatasource.toggleFavorite(movie);

      // Sincronizar con Supabase
      if (isCurrentlyFavorite) {
        await _syncService.removeItem(userId, movie.id);
      } else {
        await _syncService.addOrUpdateItem(userId, movie);
      }

      LoggerFactory.info(
          '✅ UnifiedFavorites: Toggle exitoso para ${movie.title}');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ UnifiedFavorites: Error en toggle: $e');
      LoggerFactory.error('Stack trace: $stackTrace');

      // Revertir cambio optimista en caso de error
      if (isCurrentlyFavorite) {
        final favorite = SyncableFavorite.fromMovie(
          userId: userId,
          movie: movie,
        );
        state = {...state, movie.id: favorite};
      } else {
        final revertedState = Map<int, SyncableFavorite>.from(state);
        revertedState.remove(movie.id);
        state = revertedState;
      }

      rethrow;
    }
  }

  /// Verifica si una película es favorita
  bool isFavorite(int movieId) {
    return state.containsKey(movieId);
  }

  /// Obtiene todos los favoritos como lista de películas
  List<Movie> getFavorites() {
    return state.values.map((f) => f.toMovie()).toList();
  }

  /// Obtiene favoritos como Map de IDs a Movies
  Map<int, Movie> getFavoritesMap() {
    final result = <int, Movie>{};
    for (final entry in state.entries) {
      result[entry.key] = entry.value.toMovie();
    }
    return result;
  }

  /// Refresca datos desde Supabase
  Future<void> refresh() async {
    await _loadInitialData();
  }

  /// Habilita el servicio después del login
  void enableAfterLogin() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.id;
      _loadInitialData();
      _setupRealtimeSync();
    }
  }

  /// Deshabilita el servicio después del logout
  void disableAfterLogout() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _currentUserId = null;
    _isInitialized = false;
    state = {};
    LoggerFactory.info('🚪 UnifiedFavorites: Deshabilitado después del logout');
  }

  /// Verifica si el provider está inicializado
  bool get isInitialized => _isInitialized;
}

// ============================================
// PROVIDER PARA WATCHED CON REAL-TIME SYNC
// ============================================

/// Provider unificado para Watched con sincronización en tiempo real
class UnifiedWatchedNotifier extends Notifier<Map<int, SyncableWatchedMovie>> {
  late final UnifiedWatchedSync _syncService;
  late final WatchedMoviesHiveDatasource _localDatasource;
  StreamSubscription? _realtimeSubscription;
  String? _currentUserId;
  bool _isInitialized = false;

  @override
  Map<int, SyncableWatchedMovie> build() {
    _syncService = UnifiedWatchedSync.instance;
    _localDatasource = WatchedMoviesHiveDatasource();

    // Limpiar suscripción anterior al dispose
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
      _isInitialized = false;
    });

    _initializeWithCurrentUser();
    return {};
  }

  void _initializeWithCurrentUser() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.id;
      _loadInitialData();
      _setupRealtimeSync();
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      LoggerFactory.info('📥 UnifiedWatched: Cargando datos iniciales...');

      // 1. Cargar datos locales primero (rápido)
      final localWatchedMovies =
          await _localDatasource.loadWatchedMovies(limit: 1000, offset: 0);
      final localMap = <int, SyncableWatchedMovie>{};

      for (final watchedMovie in localWatchedMovies) {
        localMap[watchedMovie.movie.id] = SyncableWatchedMovie.fromWatchedMovie(
          userId: userId,
          watchedMovie: watchedMovie,
        );
      }

      // Actualizar UI con datos locales
      state = localMap;
      LoggerFactory.info(
          '✅ UnifiedWatched: ${localMap.length} películas vistas cargadas localmente');

      // 2. Luego sincronizar con Supabase (en background)
      _syncWithSupabase();

      _isInitialized = true;
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ UnifiedWatched: Error cargando datos iniciales: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      state = {};
    }
  }

  Future<void> _syncWithSupabase() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      LoggerFactory.info('🔄 UnifiedWatched: Sincronizando con Supabase...');

      final remoteData = await _syncService.getUserItems(userId);
      final syncedMap = <int, SyncableWatchedMovie>{};

      for (final data in remoteData) {
        final watched = _syncService.supabaseDataToEntity(data);
        syncedMap[watched.movieId] = watched;

        // Guardar en local si no existe
        if (!await _localDatasource.isMovieWatched(watched.movieId)) {
          await _localDatasource.markAsWatched(watched.toMovie());
        }
      }

      // Actualizar estado con datos sincronizados
      state = syncedMap;
      LoggerFactory.info(
          '✅ UnifiedWatched: ${syncedMap.length} películas sincronizadas');
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ UnifiedWatched: Error sincronizando con Supabase: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
    }
  }

  void _setupRealtimeSync() {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      LoggerFactory.warning(
          '⚠️ UnifiedWatched: No se puede configurar real-time sync sin userId');
      return;
    }

    // Cancelar suscripción anterior si existe
    _realtimeSubscription?.cancel();

    try {
      LoggerFactory.info(
          '🎯 UnifiedWatched: Configurando Real-Time Sync para usuario: $userId');

      // ✅ USAR LA MISMA LÓGICA QUE WATCHLIST
      _realtimeSubscription = _syncService.watchUserItems(userId).listen(
        (watchedMovies) {
          LoggerFactory.info(
              '🔄 UnifiedWatched: Real-time update recibido - ${watchedMovies.length} items');

          final newState = <int, SyncableWatchedMovie>{};
          for (final watched in watchedMovies) {
            newState[watched.movieId] = watched;
          }

          final oldCount = state.length;
          final newCount = newState.length;

          if (oldCount != newCount || !_mapsAreEqual(state, newState)) {
            LoggerFactory.info(
                '📝 UnifiedWatched: Actualizando state ($oldCount -> $newCount)');
            state = newState;
            _updateLocalStorage(watchedMovies);
          } else {
            LoggerFactory.debug(
                '⏭️ UnifiedWatched: State sin cambios, skip update');
          }
        },
        onError: (error, stackTrace) {
          LoggerFactory.error('❌ UnifiedWatched: Real-time error: $error');
          LoggerFactory.error('Stack trace: $stackTrace');
        },
        onDone: () {
          LoggerFactory.warning(
              '⚠️ UnifiedWatched: Stream de real-time cerrado');
        },
        cancelOnError: false, // ✅ NO cancelar el stream en caso de error
      );

      LoggerFactory.info('✅ UnifiedWatched: Real-Time Sync listener activo');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ UnifiedWatched: Error configurando Real-Time: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
    }
  }

  bool _mapsAreEqual(Map<int, SyncableWatchedMovie> map1,
      Map<int, SyncableWatchedMovie> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;
      if (map1[key]!.movieId != map2[key]!.movieId) return false;
    }
    return true;
  }

  Future<void> _updateLocalStorage(
      List<SyncableWatchedMovie> watchedMovies) async {
    try {
      // Obtener IDs actuales en Supabase
      final remoteIds = watchedMovies.map((w) => w.movieId).toSet();

      // Obtener IDs locales
      final localWatchedMovies =
          await _localDatasource.loadWatchedMovies(limit: 1000, offset: 0);
      final localIds = localWatchedMovies.map((w) => w.movie.id).toSet();

      // Agregar nuevas películas vistas al local
      for (final watched in watchedMovies) {
        if (!localIds.contains(watched.movieId)) {
          await _localDatasource.markAsWatched(watched.toMovie());
        }
      }

      // Remover películas que ya no están en Supabase
      for (final movieId in localIds) {
        if (!remoteIds.contains(movieId)) {
          await _localDatasource.removeFromWatched(movieId);
        }
      }
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ UnifiedWatched: Error actualizando local storage: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
    }
  }

  /// Toggle watched con sincronización automática
  Future<void> toggleWatched(Movie movie) async {
    final userId = _currentUserId;
    if (userId == null) {
      LoggerFactory.warning('⚠️ UnifiedWatched: No hay usuario autenticado');
      return;
    }

    final isCurrentlyWatched = state.containsKey(movie.id);

    LoggerFactory.info(
        '🔄 UnifiedWatched: Toggle ${movie.title} (actual: $isCurrentlyWatched)');

    // Actualización optimista en UI
    final optimisticState = Map<int, SyncableWatchedMovie>.from(state);
    if (isCurrentlyWatched) {
      optimisticState.remove(movie.id);
    } else {
      final watched = SyncableWatchedMovie.fromMovie(
        userId: userId,
        movie: movie,
      );
      optimisticState[movie.id] = watched;
    }
    state = optimisticState;

    try {
      // Actualizar local
      if (isCurrentlyWatched) {
        await _localDatasource.removeFromWatched(movie.id);
      } else {
        await _localDatasource.markAsWatched(movie);
      }

      // Sincronizar con Supabase
      if (isCurrentlyWatched) {
        await _syncService.removeItem(userId, movie.id);
      } else {
        await _syncService.addOrUpdateItem(userId, movie, {
          'watched_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      LoggerFactory.info(
          '✅ UnifiedWatched: Toggle exitoso para ${movie.title}');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ UnifiedWatched: Error en toggle: $e');
      LoggerFactory.error('Stack trace: $stackTrace');

      // Revertir cambio optimista en caso de error
      if (isCurrentlyWatched) {
        final watched = SyncableWatchedMovie.fromMovie(
          userId: userId,
          movie: movie,
        );
        state = {...state, movie.id: watched};
      } else {
        final revertedState = Map<int, SyncableWatchedMovie>.from(state);
        revertedState.remove(movie.id);
        state = revertedState;
      }

      rethrow;
    }
  }

  /// Verifica si una película está marcada como vista
  bool isWatched(int movieId) {
    return state.containsKey(movieId);
  }

  /// Obtiene todas las películas vistas como lista
  List<Movie> getWatchedMovies() {
    return state.values.map((w) => w.toMovie()).toList();
  }

  /// Obtiene películas vistas como Map de IDs a Movies
  Map<int, Movie> getWatchedMoviesMap() {
    final result = <int, Movie>{};
    for (final entry in state.entries) {
      result[entry.key] = entry.value.toMovie();
    }
    return result;
  }

  /// Refresca datos desde Supabase
  Future<void> refresh() async {
    await _loadInitialData();
  }

  /// Habilita el servicio después del login
  void enableAfterLogin() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.id;
      _loadInitialData();
      _setupRealtimeSync();
    }
  }

  /// Deshabilita el servicio después del logout
  void disableAfterLogout() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _currentUserId = null;
    _isInitialized = false;
    state = {};
    LoggerFactory.info('🚪 UnifiedWatched: Deshabilitado después del logout');
  }

  /// Verifica si el provider está inicializado
  bool get isInitialized => _isInitialized;
}

// ============================================
// PROVIDERS FINALES
// ============================================

final unifiedFavoritesProvider =
    NotifierProvider<UnifiedFavoritesNotifier, Map<int, SyncableFavorite>>(
  UnifiedFavoritesNotifier.new,
);

final unifiedWatchedProvider =
    NotifierProvider<UnifiedWatchedNotifier, Map<int, SyncableWatchedMovie>>(
  UnifiedWatchedNotifier.new,
);
