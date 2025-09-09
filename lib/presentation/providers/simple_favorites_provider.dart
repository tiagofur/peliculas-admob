import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/simple_favorites_sync.dart';
import '../../domain/entities/movie.dart';
import '../../infrastructure/datasources/favorite_movies_hive_datasource.dart';

/// Provider simplificado para favoritos - solo para debugging
class SimpleFavoritesNotifier extends StateNotifier<Map<int, Movie>> {
  SimpleFavoritesNotifier() : super({}) {
    _initializeService();
  }

  final SimpleFavoritesSync _syncService = SimpleFavoritesSync.instance;
  final FavoriteMoviesHiveDatasource _localDatasource =
      FavoriteMoviesHiveDatasource();
  StreamSubscription<AuthState>? _authSubscription;
  String? _currentUserId;

  void _initializeService() {
    LoggerFactory.info('🚀 Inicializando SimpleFavoritesProvider');

    // Cargar favoritos locales primero
    _loadLocalFavorites();

    // Escuchar cambios de autenticación
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (authState) {
        String? userId;
        if (authState.session?.user != null) {
          userId = authState.session!.user!.id;
        }
        if (userId != null && userId != _currentUserId) {
          _currentUserId = userId;
          _performPostLoginSync(userId);
        } else if (userId == null) {
          _currentUserId = null;
          // Solo mantener favoritos locales cuando no hay usuario
        }
      },
    );

    // Si ya hay usuario autenticado, sincronizar
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.id;
      _performPostLoginSync(currentUser.id);
    }
  }

  /// Carga favoritos locales
  Future<void> _loadLocalFavorites() async {
    try {
      LoggerFactory.info('📱 Cargando favoritos locales...');

      final movies = await _localDatasource.loadMovies(limit: 1000, offset: 0);
      final favoriteMap = {for (var movie in movies) movie.id: movie};

      state = favoriteMap;

      LoggerFactory.info('✅ Cargados ${movies.length} favoritos locales');
    } catch (e) {
      LoggerFactory.error('❌ Error cargando favoritos locales: $e');
      state = {};
    }
  }

  /// Realiza sincronización después del login con delay
  void _performPostLoginSync(String userId) {
    LoggerFactory.info('🔐 Usuario autenticado, iniciando sync: $userId');

    // Delay para evitar bloquear el login
    Timer(const Duration(seconds: 1), () async {
      await _performSync(userId);
    });
  }

  /// Sincronización principal
  Future<void> _performSync(String userId) async {
    try {
      LoggerFactory.info('🔄 Iniciando sincronización para: $userId');

      // 1. Test de conexión
      final isConnected = await _syncService.testConnection();
      if (!isConnected) {
        LoggerFactory.error('❌ No hay conexión a Supabase');
        return;
      }

      // 2. Sincronizar favoritos
      final remoteFavorites = await _syncService.performSimpleSync(userId);

      // 3. Actualizar estado local progresivamente
      await _updateLocalFavoritesProgresively(remoteFavorites);

      LoggerFactory.info('✅ Sincronización completada exitosamente');
    } catch (e) {
      LoggerFactory.error('❌ Error en sincronización: $e');
    }
  }

  /// Actualiza favoritos locales progresivamente
  Future<void> _updateLocalFavoritesProgresively(
      List<Movie> remoteFavorites) async {
    LoggerFactory.info(
        '📝 Actualizando ${remoteFavorites.length} favoritos progresivamente...');

    for (int i = 0; i < remoteFavorites.length; i++) {
      final movie = remoteFavorites[i];

      try {
        // Verificar si ya existe localmente
        final isAlreadyLocal = await _localDatasource.isMovieFavorite(movie.id);

        if (!isAlreadyLocal) {
          // Agregar a local storage
          await _localDatasource.toggleFavorite(movie);

          // Actualizar estado UI inmediatamente
          state = {...state, movie.id: movie};

          LoggerFactory.info(
              '➕ Agregado favorito (${i + 1}/${remoteFavorites.length}): ${movie.title}');
        } else {
          LoggerFactory.debug('⏭️ Favorito ya existe: ${movie.title}');
        }

        // Small delay para no bloquear UI
        if (i < remoteFavorites.length - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } catch (e) {
        LoggerFactory.error('❌ Error agregando favorito ${movie.title}: $e');
      }
    }

    LoggerFactory.info('✅ Actualización progresiva completada');
  }

  /// Toggle favorito (versión simplificada)
  Future<void> toggleFavorite(Movie movie) async {
    final isFavorite = state[movie.id] != null;

    LoggerFactory.info(
        '🔄 Toggle favorito: ${movie.title} (actual: $isFavorite)');

    // Actualización optimista de UI
    if (isFavorite) {
      state = Map.from(state)..remove(movie.id);
    } else {
      state = {...state, movie.id: movie};
    }

    try {
      // Actualizar local storage
      await _localDatasource.toggleFavorite(movie);

      // Si hay usuario, sincronizar con remoto
      if (_currentUserId != null) {
        if (isFavorite) {
          await _syncService.removeFavorite(_currentUserId!, movie.id);
        } else {
          await _syncService.addFavorite(_currentUserId!, movie);
        }
      }

      LoggerFactory.info('✅ Toggle favorito exitoso: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ Error en toggle favorito: $e');

      // Revertir cambio optimista
      if (isFavorite) {
        state = {...state, movie.id: movie};
      } else {
        state = Map.from(state)..remove(movie.id);
      }
    }
  }

  /// Fuerza una sincronización manual
  Future<void> forceSync() async {
    if (_currentUserId != null) {
      await _performSync(_currentUserId!);
    } else {
      LoggerFactory.info('ℹ️ No hay usuario autenticado para sincronizar');
    }
  }

  /// Verifica si una película es favorita
  bool isFavorite(int movieId) {
    return state.containsKey(movieId);
  }

  /// Obtiene la cantidad de favoritos
  int get favoritesCount => state.length;

  /// Obtiene todos los favoritos como lista
  List<Movie> get favoritesList => state.values.toList();

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Provider principal simplificado
final simpleFavoritesProvider =
    StateNotifierProvider<SimpleFavoritesNotifier, Map<int, Movie>>((ref) {
  return SimpleFavoritesNotifier();
});

/// Providers de utilidad
final isFavoriteProvider = Provider.family<bool, int>((ref, movieId) {
  return ref.watch(simpleFavoritesProvider).containsKey(movieId);
});

final favoritesCountProvider = Provider<int>((ref) {
  return ref.watch(simpleFavoritesProvider).length;
});
