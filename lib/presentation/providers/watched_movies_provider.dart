import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sync/simple_watched_sync.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/watched_movies_repository.dart';
import '../../infrastructure/datasources/watched_movies_hive_datasource.dart';
import '../../infrastructure/datasources/watched_movies_shared_preferences_datasource.dart';
import '../../infrastructure/repositories/watched_movies_repository_impl.dart';
import 'achievements/achievements_provider.dart';

// Provider del repositorio
final watchedMoviesRepositoryProvider =
    Provider<WatchedMoviesRepository>((ref) {
  // Usar SharedPreferences en web, Hive en otras plataformas
  if (kIsWeb) {
    final datasource = WatchedMoviesSharedPreferencesDatasource();
    return WatchedMoviesRepositoryImpl(datasource, ref);
  } else {
    final datasource = WatchedMoviesHiveDatasource();
    return WatchedMoviesRepositoryImpl(datasource, ref);
  }
});

// Provider para verificar si una película está vista
final isMovieWatchedProvider =
    FutureProvider.family<bool, int>((ref, movieId) async {
  final repository = ref.watch(watchedMoviesRepositoryProvider);
  return repository.isMovieWatched(movieId);
});

// Provider para la lista de películas vistas
final watchedMoviesProvider =
    StateNotifierProvider<WatchedMoviesNotifier, WatchedMoviesState>((ref) {
  final repository = ref.watch(watchedMoviesRepositoryProvider);
  return WatchedMoviesNotifier(
    repository: repository,
    onMovieWatched: (Movie movie) async {
      // Manejar el callback aquí, dentro del provider
      await ref.read(achievementsProvider.notifier).trackMovieWatched(movie);
    },
  );
});

// Estado para las películas vistas
class WatchedMoviesState {
  const WatchedMoviesState({
    this.movies = const [],
    this.isLoading = false,
    this.isLastPage = false,
    this.currentPage = 0,
  });

  final List<WatchedMovie> movies;
  final bool isLoading;
  final bool isLastPage;
  final int currentPage;

  WatchedMoviesState copyWith({
    List<WatchedMovie>? movies,
    bool? isLoading,
    bool? isLastPage,
    int? currentPage,
  }) {
    return WatchedMoviesState(
      movies: movies ?? this.movies,
      isLoading: isLoading ?? this.isLoading,
      isLastPage: isLastPage ?? this.isLastPage,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

// Notifier para gestionar las películas vistas
class WatchedMoviesNotifier extends StateNotifier<WatchedMoviesState> {
  WatchedMoviesNotifier({
    required this.repository,
    required this.onMovieWatched,
  }) : super(const WatchedMoviesState()) {
    loadNextPage();
  }

  final WatchedMoviesRepository repository;
  final Future<void> Function(Movie) onMovieWatched;
  static const int _limit = 20;

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLastPage) return;

    state = state.copyWith(isLoading: true);

    final movies = await repository.loadWatchedMovies(
      limit: _limit,
      offset: state.currentPage * _limit,
    );

    if (movies.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        isLastPage: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      movies: [...state.movies, ...movies],
      currentPage: state.currentPage + 1,
      isLastPage: movies.length < _limit,
    );
  }

  Future<void> markAsWatched(Movie movie) async {
    try {
      // 1. Guardar localmente primero
      await repository.markAsWatched(movie);
      
      // 2. Sincronizar con Supabase
      final simpleWatchedSync = SimpleWatchedSync.instance;
      final currentUser = Supabase.instance.client.auth.currentUser;
      
      if (currentUser != null) {
        await simpleWatchedSync.addWatchedMovie(currentUser.id, movie);
        if (kDebugMode) {
          print('✅ Película marcada como vista en Supabase: ${movie.title}');
        }
      }

      // 3. Track logros usando callback en lugar de ref directo
      await onMovieWatched(movie);

      // 4. Recargar la lista
      await _reloadMovies();
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marcando película como vista: $e');
      }
      rethrow;
    }
  }

  Future<void> removeFromWatched(int movieId) async {
    try {
      // 1. Remover localmente primero
      await repository.removeFromWatched(movieId);
      
      // 2. Sincronizar con Supabase
      final simpleWatchedSync = SimpleWatchedSync.instance;
      final currentUser = Supabase.instance.client.auth.currentUser;
      
      if (currentUser != null) {
        await simpleWatchedSync.removeWatchedMovie(currentUser.id, movieId);
        if (kDebugMode) {
          print('✅ Película removida de vistas en Supabase: $movieId');
        }
      }
      
      // 3. Recargar la lista
      await _reloadMovies();
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removiendo película de vistas: $e');
      }
      rethrow;
    }
  }

  Future<void> _reloadMovies() async {
    state = const WatchedMoviesState();
    await loadNextPage();
  }

  Future<void> refresh() async {
    await _reloadMovies();
  }

  @override
  void dispose() {
    // Limpiar recursos si es necesario
    super.dispose();
  }
}
