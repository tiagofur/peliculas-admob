import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_movie.dart';
import '../../infrastructure/repositories/hybrid_watchlist_repository.dart';
import 'hybrid_repositories_provider.dart';

/// Estado de la watchlist
class WatchlistState {
  final List<WatchlistMovie> movies;
  final bool isLoading;
  final String? error;
  final int totalCount;

  const WatchlistState({
    this.movies = const [],
    this.isLoading = false,
    this.error,
    this.totalCount = 0,
  });

  WatchlistState copyWith({
    List<WatchlistMovie>? movies,
    bool? isLoading,
    String? error,
    int? totalCount,
  }) {
    return WatchlistState(
      movies: movies ?? this.movies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

/// Notifier para la gestión de watchlist
class WatchlistNotifier extends StateNotifier<WatchlistState> {
  WatchlistNotifier(this._repository) : super(const WatchlistState()) {
    loadWatchlist();
  }

  final HybridWatchlistRepository _repository;

  /// Cargar watchlist con filtros opcionales
  Future<void> loadWatchlist({
    int limit = 20,
    int offset = 0,
    WatchlistPriority? priority,
    bool refresh = false,
  }) async {
    if (refresh || offset == 0) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final movies = await _repository.loadWatchlistMovies(
        limit: limit,
        offset: offset,
        priority: priority,
      );

      final totalCount = await _repository.getWatchlistCount();

      if (offset == 0 || refresh) {
        // Primera carga o refresh completo
        state = state.copyWith(
          movies: movies,
          isLoading: false,
          totalCount: totalCount,
        );
      } else {
        // Cargar más elementos (paginación)
        final currentMovies = List<WatchlistMovie>.from(state.movies);
        currentMovies.addAll(movies);
        state = state.copyWith(
          movies: currentMovies,
          isLoading: false,
          totalCount: totalCount,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar watchlist: $e',
      );
    }
  }

  /// Agregar película a watchlist
  Future<void> addToWatchlist(Movie movie, WatchlistPriority priority) async {
    try {
      await _repository.addToWatchlist(movie, priority);
      // Recargar la lista para reflejar los cambios
      await loadWatchlist(refresh: true);
    } catch (e) {
      state = state.copyWith(error: 'Error al agregar a watchlist: $e');
    }
  }

  /// Remover película de watchlist
  Future<void> removeFromWatchlist(int movieId) async {
    try {
      await _repository.removeFromWatchlist(movieId);
      // Remover de la lista local inmediatamente para mejor UX
      final updatedMovies = state.movies.where((movie) => movie.movieId != movieId).toList();
      state = state.copyWith(
        movies: updatedMovies,
        totalCount: state.totalCount - 1,
      );
    } catch (e) {
      state = state.copyWith(error: 'Error al remover de watchlist: $e');
      // Recargar en caso de error para mantener consistencia
      await loadWatchlist(refresh: true);
    }
  }

  /// Actualizar prioridad de película en watchlist
  Future<void> updatePriority(int movieId, WatchlistPriority newPriority) async {
    try {
      await _repository.updateWatchlistPriority(movieId, newPriority);
      
      // Actualizar en la lista local inmediatamente
      final updatedMovies = state.movies.map((movie) {
        if (movie.movieId == movieId) {
          return movie.copyWith(
            priority: newPriority,
            updatedAt: DateTime.now(),
          );
        }
        return movie;
      }).toList();

      // Reordenar la lista según las nuevas prioridades
      updatedMovies.sort((a, b) {
        final priorityOrder = {'alta': 0, 'normal': 1, 'baja': 2};
        final aPriorityIndex = priorityOrder[a.priority.value] ?? 1;
        final bPriorityIndex = priorityOrder[b.priority.value] ?? 1;
        
        if (aPriorityIndex != bPriorityIndex) {
          return aPriorityIndex.compareTo(bPriorityIndex);
        }
        
        return b.addedAt.compareTo(a.addedAt);
      });

      state = state.copyWith(movies: updatedMovies);
    } catch (e) {
      state = state.copyWith(error: 'Error al actualizar prioridad: $e');
      // Recargar en caso de error
      await loadWatchlist(refresh: true);
    }
  }

  /// Verificar si una película está en watchlist
  Future<bool> isMovieInWatchlist(int movieId) async {
    try {
      return await _repository.isMovieInWatchlist(movieId);
    } catch (e) {
      return false;
    }
  }

  /// Filtrar por prioridad
  Future<void> filterByPriority(WatchlistPriority? priority) async {
    await loadWatchlist(priority: priority, refresh: true);
  }

  /// Limpiar errores
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Refresh completo de la watchlist
  Future<void> refresh() async {
    await loadWatchlist(refresh: true);
  }
}

/// Provider principal de watchlist
final watchlistProvider = StateNotifierProvider<WatchlistNotifier, WatchlistState>((ref) {
  final repository = ref.watch(hybridWatchlistRepositoryProvider);
  return WatchlistNotifier(repository);
});

/// Provider para verificar si una película específica está en watchlist
final isMovieInWatchlistProvider = FutureProvider.family<bool, int>((ref, movieId) async {
  final repository = ref.watch(hybridWatchlistRepositoryProvider);
  return await repository.isMovieInWatchlist(movieId);
});

/// Provider para obtener una película específica de watchlist
final watchlistMovieProvider = FutureProvider.family<WatchlistMovie?, int>((ref, movieId) async {
  final repository = ref.watch(hybridWatchlistRepositoryProvider);
  return await repository.getWatchlistMovie(movieId);
});

/// Provider para conteo total de watchlist
final watchlistCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(hybridWatchlistRepositoryProvider);
  return await repository.getWatchlistCount();
});

/// Provider para watchlist filtrada por prioridad
final watchlistByPriorityProvider = FutureProvider.family<List<WatchlistMovie>, WatchlistPriority?>((ref, priority) async {
  final repository = ref.watch(hybridWatchlistRepositoryProvider);
  return await repository.loadWatchlistMovies(
    limit: 100, // Cargar todas para mostrar
    priority: priority,
  );
});