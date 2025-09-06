import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/sync/simple_favorites_sync.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/repositories/favorites_repository.dart';
import '../achievements/achievements_provider.dart';
import '../hybrid_repositories_provider.dart';

final favoriteMoviesProvider =
    StateNotifierProvider<StorageMoviesNotifier, Map<int, Movie>>((ref) {
  final favoritesRepository = ref.watch(favoritesRepositoryProvider);
  return StorageMoviesNotifier(
    favoritesRepository: favoritesRepository,
    onMovieFavorited: () {
      // Manejar el callback aquí, dentro del provider
      ref.read(achievementsProvider.notifier).trackMovieFavorited();
    },
  );
});

/*
  {
    1234: Movie,
    1645: Movie,
    6523: Movie,
  }

*/

class StorageMoviesNotifier extends StateNotifier<Map<int, Movie>> {
  StorageMoviesNotifier({
    required this.favoritesRepository,
    required this.onMovieFavorited,
  }) : super({}) {
    // Cargar favoritos existentes al inicializar
    _loadExistingFavorites();
    // NO configurar auto-refresh automáticamente para evitar bloqueos
    // _setupAutoRefresh(); // Se habilitará manualmente cuando sea necesario
  }

  int page = 0;
  final FavoritesRepository favoritesRepository;
  final VoidCallback onMovieFavorited;
  Timer? _refreshTimer;
  
  /// Cargar favoritos existentes al inicializar el provider
  Future<void> _loadExistingFavorites() async {
    try {
      final favoriteMoviesMap = await favoritesRepository.getFavoriteMovies();
      
      // 🐛 DEBUG: Log what we're loading initially
      if (kDebugMode) {
        print('🔍 [FavoriteProvider] _loadExistingFavorites got ${favoriteMoviesMap.length} favorites');
        print('🔍 [FavoriteProvider] Favorite IDs: ${favoriteMoviesMap.keys.toList()}');
      }
      
      if (favoriteMoviesMap.isNotEmpty) {
        state = favoriteMoviesMap;
        if (kDebugMode) {
          print('✅ Cargados ${favoriteMoviesMap.length} favoritos desde el repositorio híbrido');
        }
      } else {
        // Ensure state is empty if no favorites
        state = {};
        if (kDebugMode) {
          print('ℹ️ No favorites found, state set to empty');
        }
      }
    } catch (e) {
      // Si hay error cargando, mantener estado vacío pero registrar el error
      state = {};
      if (kDebugMode) {
        print('❌ Error cargando favoritos existentes: $e');
      }
    }
  }

  Future<List<Movie>> loadNextPage() async {
    // Usar getFavoriteMovies del repositorio híbrido
    final favoriteMoviesMap = await favoritesRepository.getFavoriteMovies();
    final movies = favoriteMoviesMap.values.toList();
    
    // Paginar los resultados localmente
    final startIndex = page * 10;
    final endIndex = (startIndex + 20).clamp(0, movies.length);
    final paginatedMovies = movies.sublist(startIndex.clamp(0, movies.length), endIndex);
    
    page++;

    final tempMoviesMap = <int, Movie>{};
    for (final movie in paginatedMovies) {
      tempMoviesMap[movie.id] = movie;
    }

    state = {...state, ...tempMoviesMap};

    return paginatedMovies;
  }

  Future<void> toggleFavorite(Movie movie) async {
    final isFavorite = state[movie.id] != null;

    if (kDebugMode) {
      print('🔍 [FavoriteProvider] Toggle ${movie.id}:${movie.title} (current: $isFavorite)');
    }

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
          if (kDebugMode) {
            print('✅ Favorito removido: ${movie.title}');
          }
        } else {
          // Agregar a Supabase
          await simpleFavoritesSync.addFavorite(currentUser.id, movie);
          if (kDebugMode) {
            print('✅ Favorito añadido: ${movie.title}');
          }
          // Callback solo si se agregó
          onMovieFavorited();
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ No hay usuario logueado, solo cambio local');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en toggle favorito: $e');
      }
      // Revertir cambio optimista
      if (isFavorite) {
        state = {...state, movie.id: movie};
      } else {
        state = Map.from(state)..remove(movie.id);
      }
    }
  }

  /// Sincroniza con Supabase en segundo plano sin bloquear UI
  void _syncToSupabaseBackground(Movie movie, bool isAdding) async {
    try {
      if (kDebugMode) {
        print('🔄 Sync to Supabase: ${isAdding ? 'adding' : 'removing'} ${movie.title}');
      }
      
      // Usar SimpleFavoritesSync para envío a Supabase
      final simpleFavoritesSync = SimpleFavoritesSync.instance;
      final currentUser = Supabase.instance.client.auth.currentUser;
      
      if (currentUser != null) {
        if (isAdding) {
          await simpleFavoritesSync.addFavorite(currentUser.id, movie);
        } else {
          await simpleFavoritesSync.removeFavorite(currentUser.id, movie.id);
        }
        
        if (kDebugMode) {
          print('✅ Supabase sync completed: ${movie.title}');
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ No user logged in, skipping Supabase sync');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error syncing to Supabase: $e');
      }
      // No revertir UI - el usuario ya ve el cambio local
      // La sync se puede reintentar más tarde
    }
  }

  /// Configura el auto-refresh para detectar cambios en tiempo real
  void _setupAutoRefresh() {
    if (_refreshTimer != null) return; // Ya está configurado
    
    // DESACTIVADO TEMPORALMENTE: Causaba conflictos con cambios manuales
    // Configurar un timer que verifica cambios cada 2 segundos durante sync
    // _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
    //   refreshFavorites();
    // });
    
    if (kDebugMode) {
      print('ℹ️ Auto-refresh desactivado para evitar conflictos');
    }
  }

  /// Habilita el auto-refresh manualmente (cuando el usuario se autentica)
  void enableAutoRefresh() {
    if (kDebugMode) {
      print('🔄 Habilitando auto-refresh de favoritos (desactivado temporalmente)');
    }
    _setupAutoRefresh();
    
    // DESACTIVADO: También iniciar sync desde Supabase (no bloqueante)
    // Timer(const Duration(seconds: 1), () {
    //   _syncFromSupabaseBackground();
    // });
  }

  /// Sincroniza FROM Supabase en segundo plano (para cuando haces login)
  void _syncFromSupabaseBackground() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      
      if (kDebugMode) {
        print('📥 Iniciando sync FROM Supabase para: ${currentUser.id}');
      }
      
      final simpleFavoritesSync = SimpleFavoritesSync.instance;
      final remoteFavorites = await simpleFavoritesSync.performSimpleSync(currentUser.id);
      
      // Agregar favoritos remotos al estado actual (merge, no replace)
      final currentState = Map<int, Movie>.from(state);
      for (final movie in remoteFavorites) {
        if (!currentState.containsKey(movie.id)) {
          currentState[movie.id] = movie;
        }
      }
      
      // Solo actualizar estado si hay cambios
      if (currentState.length != state.length) {
        state = currentState;
        if (kDebugMode) {
          print('✅ Sync FROM Supabase completado: ${remoteFavorites.length} remotos, ${state.length} total');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en sync FROM Supabase: $e');
      }
    }
  }

  /// Deshabilita el auto-refresh
  void disableAutoRefresh() {
    if (kDebugMode) {
      print('🛑 Deshabilitando auto-refresh de favoritos');
    }
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Refrescar el estado completo de favoritos (útil después de sync)
  Future<void> refreshFavorites() async {
    try {
      final favoriteMoviesMap = await favoritesRepository.getFavoriteMovies();
      
      // Solo actualizar si hay cambios reales para evitar rebuilds innecesarios
      if (!_mapsEqual(state, favoriteMoviesMap)) {
        final oldCount = state.length;
        state = favoriteMoviesMap;
        
        if (kDebugMode) {
          final newCount = favoriteMoviesMap.length;
          if (newCount > oldCount) {
            print('✅ Favoritos actualizados: +${newCount - oldCount} nuevos favoritos');
          } else if (newCount < oldCount) {
            print('🔄 Favoritos actualizados: -${oldCount - newCount} favoritos removidos');
          } else {
            print('🔄 Favoritos refrescados desde repositorio híbrido');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refrescando favoritos: $e');
      }
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

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
