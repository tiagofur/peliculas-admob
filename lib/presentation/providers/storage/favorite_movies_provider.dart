import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }

  int page = 0;
  final FavoritesRepository favoritesRepository;
  final VoidCallback onMovieFavorited;
  
  /// Cargar favoritos existentes al inicializar el provider
  Future<void> _loadExistingFavorites() async {
    try {
      final favoriteMoviesMap = await favoritesRepository.getFavoriteMovies();
      if (favoriteMoviesMap.isNotEmpty) {
        state = favoriteMoviesMap;
        if (kDebugMode) {
          print('✅ Cargados ${favoriteMoviesMap.length} favoritos desde el repositorio híbrido');
        }
      }
    } catch (e) {
      // Si hay error cargando, mantener estado vacío pero registrar el error
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

    // Actualización optimista de la UI
    if (isFavorite) {
      state = Map.from(state)..remove(movie.id);
    } else {
      state = {...state, movie.id: movie};
    }

    try {
      // Llamada al repositorio híbrido en segundo plano - maneja sync automáticamente
      await favoritesRepository.toggleFavorite(movie);
      
      // Opcional: Llamar al callback si la operación fue exitosa
      if (!isFavorite) {
        onMovieFavorited();
      }

      if (kDebugMode) {
        print('✅ [FavoriteMoviesProvider] Toggle favorite exitoso para: ${movie.title}');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ [FavoriteMoviesProvider] Error toggling favorite: $e');
      }
      // Si falla, revertir la actualización optimista
      if (isFavorite) {
        state = {...state, movie.id: movie};
      } else {
        state = Map.from(state)..remove(movie.id);
      }
    }
  }

  /// Refrescar el estado completo de favoritos (útil después de sync)
  Future<void> refreshFavorites() async {
    try {
      final favoriteMoviesMap = await favoritesRepository.getFavoriteMovies();
      state = favoriteMoviesMap;
      if (kDebugMode) {
        print('🔄 Favoritos refrescados desde repositorio híbrido');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refrescando favoritos: $e');
      }
    }
  }

  @override
  void dispose() {
    // Limpiar recursos si es necesario
    super.dispose();
  }
}
