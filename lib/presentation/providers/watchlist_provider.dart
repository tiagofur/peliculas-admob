import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_movie.dart';
import '../../infrastructure/repositories/hybrid_watchlist_repository.dart';
import 'hybrid_repositories_provider.dart';

/// Estado de la watchlist
class WatchlistState {
  const WatchlistState({
    this.movies = const [],
    this.isLoading = false,
    this.error,
    this.totalCount = 0,
  });
  final List<WatchlistMovie> movies;
  final bool isLoading;
  final String? error;
  final int totalCount;

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
class WatchlistNotifier extends Notifier<WatchlistState> {
  WatchlistNotifier() {
    // Constructor sin parámetros para Riverpod 3.0
  }

  @override
  WatchlistState build() {
    // Inicializar dependencias usando ref
    _initializeWatchlist();
    return const WatchlistState();
  }

  HybridWatchlistRepository get _repository =>
      ref.read(hybridWatchlistRepositoryProvider);

  /// Inicializar watchlist cargando todos los datos existentes
  Future<void> _initializeWatchlist() async {
    try {
      // Cargar toda la watchlist al inicio para tener el estado completo
      await loadWatchlist(limit: 1000, refresh: true);
      LoggerFactory.info(
          '✅ Watchlist inicializada correctamente con ${state.movies.length} películas');
    } catch (e) {
      state = state.copyWith(error: 'Error inicializando watchlist: $e');
      LoggerFactory.error('❌ Error inicializando watchlist: $e');
    }
  }

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

  /// Alternar película en watchlist (agregar o remover)
  Future<void> toggleWatchlist(Movie movie,
      {WatchlistPriority priority = WatchlistPriority.normal}) async {
    final isInWatchlist = state.movies.any((m) => m.movieId == movie.id);
    final previousState = state;

    // Actualización optimista de la UI
    if (isInWatchlist) {
      final updatedMovies =
          state.movies.where((m) => m.movieId != movie.id).toList();
      state = state.copyWith(
        movies: updatedMovies,
        totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
      );
    } else {
      // Crear un WatchlistMovie temporal para la UI
      final newWatchlistMovie = WatchlistMovie(
        id: 'temp_${movie.id}', // ID temporal
        movieId: movie.id,
        movieTitle: movie.title,
        moviePosterPath: movie.posterPath,
        movieBackdropPath: movie.backdropPath,
        movieOverview: movie.overview,
        movieReleaseDate: movie.releaseDate,
        movieVoteAverage: movie.voteAverage,
        addedAt: DateTime.now(),
        priority: priority,
        lastModifiedAt: DateTime.now(),
      );
      state = state.copyWith(
        movies: [...state.movies, newWatchlistMovie],
        totalCount: state.totalCount + 1,
      );
    }

    // Realizar la operación real en segundo plano
    try {
      if (isInWatchlist) {
        await _repository.removeFromWatchlist(movie.id);
      } else {
        await _repository.addToWatchlistWithPriority(movie, priority);
      }
    } catch (e) {
      // Revertir el estado en caso de error
      state = previousState;
      // Opcional: se podría añadir un manejo de error más explícito para el usuario
    }
  }

  /// Remover película de watchlist
  Future<void> removeFromWatchlist(int movieId) async {
    final previousState = state;

    // Actualización optimista de la UI
    final updatedMovies =
        state.movies.where((m) => m.movieId != movieId).toList();
    state = state.copyWith(
      movies: updatedMovies,
      totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
    );

    // Realizar la operación real en segundo plano
    try {
      await _repository.removeFromWatchlist(movieId);
    } catch (e) {
      // Revertir el estado en caso de error
      state = previousState;
      state = state.copyWith(error: 'Error al remover de watchlist: $e');
    }
  }

  /// Actualizar prioridad de película en watchlist
  Future<void> updatePriority(
      int movieId, WatchlistPriority newPriority) async {
    try {
      await _repository.updateWatchlistPriority(movieId, newPriority);

      // Actualizar en la lista local inmediatamente
      final updatedMovies = state.movies.map((movie) {
        if (movie.movieId == movieId) {
          return movie.copyWith(
            priority: newPriority,
            lastModifiedAt: DateTime.now(),
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

  /// ✅ FIX: En Riverpod 3.0 Notifier no tiene dispose, usar ref.onDispose en build
  // No override dispose - no existe en Notifier<T>
}

/// Provider principal de watchlist
final watchlistProvider = NotifierProvider<WatchlistNotifier, WatchlistState>(
  () => WatchlistNotifier(),
);

/// Provider para verificar si una película específica está en watchlist
final isMovieInWatchlistProvider =
    Provider.family.autoDispose<AsyncValue<bool>, int>((ref, movieId) {
  final watchlistState = ref.watch(watchlistProvider);

  if (watchlistState.isLoading) {
    return const AsyncValue.loading();
  }

  if (watchlistState.error != null) {
    return AsyncValue.error(watchlistState.error!, StackTrace.current);
  }

  final isInWatchlist =
      watchlistState.movies.any((movie) => movie.movieId == movieId);
  return AsyncValue.data(isInWatchlist);
});

/// Provider para obtener una película específica de watchlist
final watchlistMovieProvider = Provider.family
    .autoDispose<AsyncValue<WatchlistMovie?>, int>((ref, movieId) {
  final watchlistState = ref.watch(watchlistProvider);

  if (watchlistState.isLoading) {
    return const AsyncValue.loading();
  }

  if (watchlistState.error != null) {
    return AsyncValue.error(watchlistState.error!, StackTrace.current);
  }

  try {
    final movie =
        watchlistState.movies.firstWhere((movie) => movie.movieId == movieId);
    return AsyncValue.data(movie);
  } catch (e) {
    return const AsyncValue.data(null);
  }
});

/// Provider para conteo total de watchlist
final watchlistCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(hybridWatchlistRepositoryProvider);
  return await repository.getWatchlistCount();
});

/// Provider para watchlist filtrada por prioridad
final watchlistByPriorityProvider =
    FutureProvider.family<List<WatchlistMovie>, WatchlistPriority?>(
        (ref, priority) async {
  final repository = ref.watch(hybridWatchlistRepositoryProvider);
  return await repository.loadWatchlistMovies(
    limit: 100, // Cargar todas para mostrar
    priority: priority,
  );
});
