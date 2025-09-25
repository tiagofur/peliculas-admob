import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/simple_favorites_sync.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/repositories/favorites_repository.dart';
import '../achievements/achievements_provider.dart';
import '../hybrid_repositories_provider.dart';

/// Service para gestionar películas favoritas con respaldo local/remoto
class FavoriteMoviesService extends Notifier<Map<int, Movie>> {
  late FavoritesRepository _favoritesRepository;
  Timer? _refreshTimer;
  int page = 0;

  @override
  Map<int, Movie> build() {
    // Obtener repositorio inyectado
    _favoritesRepository = ref.watch(favoritesRepositoryProvider);
    
    // Cargar favoritos existentes al inicializar
    _loadExistingFavorites();
    
    // NO configurar auto-refresh automáticamente para evitar bloqueos
    // _setupAutoRefresh(); // Se habilitará manualmente cuando sea necesario
    
    return {};
  }

  /// Getter para compatibilidad con código existente
  FavoritesRepository get favoritesRepository => _favoritesRepository;

  /// Callback para películas favoritas
  void onMovieFavorited() {
    // Manejar el callback aquí, dentro del servicio
    ref.read(achievementsProvider.notifier).trackMovieFavorited();
  }

  /// Cargar favoritos existentes al inicializar el provider
  Future<void> _loadExistingFavorites() async {
    try {
      final favoriteMoviesMap = await _favoritesRepository.getFavoriteMovies();

      if (favoriteMoviesMap.isNotEmpty) {
        state = favoriteMoviesMap;
        LoggerFactory.info(
            '✅ Cargados ${favoriteMoviesMap.length} favoritos desde el repositorio híbrido');
      } else {
        // Ensure state is empty if no favorites
        state = {};
        LoggerFactory.info('ℹ️ No hay favoritos guardados');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error cargando favoritos existentes: $e');
      state = {};
    }
  }

  /// Añade la siguiente página de películas favoritas (SIMULADO - no implementado)
  Future<void> loadNextPage() async {
    // Esta funcionalidad no está implementada en el repositorio actual
    // Mantener método para compatibilidad con UI existente
    LoggerFactory.info('ℹ️ loadNextPage: Funcionalidad no implementada');
  }

  /// Toggle favorito con persistencia híbrida y actualización optimista de UI
  Future<void> toggleFavorite(Movie movie) async {
    final isFavorite = state[movie.id] != null;

    LoggerFactory.info(
        'ℹ️ Toggle favorito: ${movie.title} (actual: $isFavorite)');

    // Actualización optimista de la UI
    if (isFavorite) {
      state = Map.from(state)..remove(movie.id);
    } else {
      state = {...state, movie.id: movie};
    }

    try {
      // SIMPLIFICADO: Solo usar SimpleFavoritesSync directamente
      final simpleFavoritesSync = SimpleFavoritesSync.instance;
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (currentUser != null) {
        if (isFavorite) {
          // Remover de Supabase
          await simpleFavoritesSync.removeFavorite(currentUser.id, movie.id);
          LoggerFactory.info('✅ Favorito removido: ${movie.title}');
        } else {
          // Agregar a Supabase
          await simpleFavoritesSync.addFavorite(currentUser.id, movie);
          LoggerFactory.info('✅ Favorito añadido: ${movie.title}');
          // Callback solo si se agregó
          onMovieFavorited();
        }
      } else {
        LoggerFactory.info('ℹ️ No hay usuario logueado, solo cambio local');
      }
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

  /// Configura el auto-refresh para detectar cambios en tiempo real
  void _setupAutoRefresh() {
    if (_refreshTimer != null) return; // Ya está configurado

    LoggerFactory.info('ℹ️ Auto-refresh desactivado para evitar conflictos');
  }

  /// Habilita el auto-refresh manualmente (cuando el usuario se autentica)
  void enableAutoRefresh() {
    LoggerFactory.info(
        '🔄 Habilitando auto-refresh de favoritos (desactivado temporalmente)');
    _setupAutoRefresh();

    // DESACTIVADO: También iniciar sync desde Supabase (no bloqueante)
    // Timer(const Duration(seconds: 1), () {
    //   _syncFromSupabaseBackground();
    // });
  }

  /// Deshabilita el auto-refresh
  void disableAutoRefresh() {
    LoggerFactory.info('🛑 Deshabilitando auto-refresh de favoritos');
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Refrescar el estado completo de favoritos (útil después de sync)
  Future<void> refreshFavorites() async {
    try {
      final favoriteMoviesMap = await _favoritesRepository.getFavoriteMovies();

      // Solo actualizar si hay cambios reales para evitar rebuilds innecesarios
      if (!_mapsEqual(state, favoriteMoviesMap)) {
        final oldCount = state.length;
        state = favoriteMoviesMap;

        final newCount = favoriteMoviesMap.length;
        if (newCount > oldCount) {
          LoggerFactory.info(
              '✅ Favoritos actualizados: +${newCount - oldCount} nuevos favoritos');
        } else if (newCount < oldCount) {
          LoggerFactory.info(
              '🔄 Favoritos actualizados: -${oldCount - newCount} favoritos removidos');
        } else {
          LoggerFactory.info(
              '🔄 Favoritos refrescados desde repositorio híbrido');
        }
      }
    } catch (e) {
      LoggerFactory.error('❌ Error refrescando favoritos: $e');
    }
  }

  /// Verifica si dos mapas son iguales
  bool _mapsEqual(Map<int, Movie> map1, Map<int, Movie> map2) {
    if (map1.length != map2.length) return false;

    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;
      if (map1[key]?.id != map2[key]?.id) return false;
    }

    return true;
  }
}

/// Provider modernizado para películas favoritas
final favoriteMoviesProvider = NotifierProvider<FavoriteMoviesService, Map<int, Movie>>(
  () => FavoriteMoviesService(),
);

/// Compatibilidad: Provider legacy para transición gradual
final storageMoviesNotifierProvider = favoriteMoviesProvider;