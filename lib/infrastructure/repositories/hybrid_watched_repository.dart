import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/entities/watched_movie.dart';
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../datasources/watched_movies_hive_datasource.dart';
import '../services/conflict_resolver.dart';
import '../services/persistent_sync_queue.dart';

// Repositorio híbrido que maneja películas vistas localmente y sincroniza con Supabase
class HybridWatchedRepository
    implements SyncableRepository<SyncableWatchedMovie> {
  HybridWatchedRepository({
    required WatchedMoviesHiveDatasource hiveDatasource,
    required Ref ref,
  })  : _hiveDatasource = hiveDatasource,
        _ref = ref {
    _syncQueue.init();
  }
  final WatchedMoviesHiveDatasource _hiveDatasource;
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final PersistentSyncQueue _syncQueue = PersistentSyncQueue();

  // Métodos auxiliares
  Future<void> _checkOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw NetworkException();
    }
  }

  bool _isAuthenticated() {
    final appState = _ref.read(appStateProvider);
    return appState.isAuthenticated && appState.user != null;
  }

  String? _getCurrentUserId() {
    final appState = _ref.read(appStateProvider);
    return appState.user?.id;
  }

  // Obtener películas vistas (local o remoto según el estado)
  Future<List<WatchedMovie>> getWatchedMovies({int limit = 50}) async {
    if (_isAuthenticated()) {
      try {
        await _checkOnline();
        await syncWithSupabase();
      } on SyncException catch (e) {
        print('Error en sincronización automática: $e');
      }
    }

    try {
      return await _hiveDatasource.loadWatchedMovies();
    } catch (e) {
      throw LocalStorageException('Error al cargar las películas vistas: $e');
    }
  }

  // Marcar película como vista
  Future<void> markAsWatched(Movie movie) async {
    try {
      await _hiveDatasource.markAsWatched(movie);
    } catch (e) {
      throw LocalStorageException('Error al marcar la película como vista: $e');
    }

    try {
      await _checkOnline();
      if (_isAuthenticated()) {
        await _syncSingleItem(movie, isWatched: true);
      }
    } on SyncException catch (e) {
      await markForSync('${movie.id}_watched');
      print('Error sincronizando película vista ${movie.id}: $e');
    }
  }

  // Sincronizar un elemento individual
  Future<void> _syncSingleItem(Movie movie, {required bool isWatched}) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    try {
      if (isWatched) {
        // Agregar a películas vistas en Supabase
        await _supabase.from('user_watched_movies').upsert({
          'id': '${userId}_${movie.id}_watched',
          'user_id': userId,
          'movie_id': movie.id,
          'movie_title': movie.title,
          'movie_poster_path': movie.posterPath,
          'movie_backdrop_path': movie.backdropPath,
          'movie_overview': movie.overview,
          'movie_release_date': movie.releaseDate.toIso8601String(),
          'movie_vote_average': movie.voteAverage,
          'watched_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'deleted_at': null, // ✅ Marcar como activo
        });
      } else {
        // ✅ Soft delete en lugar de hard delete
        await _supabase
            .from('user_watched_movies')
            .update({
              'deleted_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('movie_id', movie.id);
      }

      // Limpiar marcador de sincronización
      await clearSyncMarker('${movie.id}_watched');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  // Remover película de vistas
  Future<void> removeFromWatched(int movieId) async {
    try {
      await _hiveDatasource.removeFromWatched(movieId);
    } catch (e) {
      throw LocalStorageException('Error al remover la película de vistas: $e');
    }

    try {
      await _checkOnline();
      if (_isAuthenticated()) {
        // Crear un objeto Movie temporal para la sincronización
        final movie = Movie(
          id: movieId,
          title: '',
          posterPath: '',
          backdropPath: '',
          overview: '',
          releaseDate: DateTime.now(),
          voteAverage: 0.0,
          genreIds: [],
          adult: false,
          originalLanguage: '',
          originalTitle: '',
          popularity: 0.0,
          video: false,
          voteCount: 0,
        );
        await _syncSingleItem(movie, isWatched: false);
      }
    } on SyncException catch (e) {
      await markForSync('${movieId}_unwatched');
      print('Error sincronizando remoción de película vista $movieId: $e');
    }
  }

  // Verificar si una película fue vista
  Future<bool> isMovieWatched(int movieId) async {
    try {
      return await _hiveDatasource.isMovieWatched(movieId);
    } catch (e) {
      throw LocalStorageException(
          'Error al verificar si la película fue vista: $e');
    }
  }

  // Implementación de SyncableRepository
  @override
  Future<List<SyncableWatchedMovie>> getLocalData() async {
    try {
      final watchedMovies = await _hiveDatasource.loadWatchedMovies();
      final userId = _getCurrentUserId() ?? 'guest';

      return watchedMovies
          .map((watchedMovie) =>
              SyncableWatchedMovie.fromWatchedMovie(watchedMovie, userId))
          .toList();
    } catch (e) {
      throw LocalStorageException(
          'Error al obtener los datos locales de películas vistas: $e');
    }
  }

  @override
  Future<List<SyncableWatchedMovie>> getRemoteData() async {
    final userId = _getCurrentUserId();
    if (userId == null) return [];

    try {
      await _checkOnline();
      final response = await _supabase
          .from('user_watched_movies')
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null); // ✅ Solo obtener películas activas

      return (response as List).map((data) => _mapFromSupabase(data)).toList();
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(
          'Error obteniendo películas vistas remotas: $e');
    }
  }

  // Mapear datos de Supabase a SyncableWatchedMovie
  SyncableWatchedMovie _mapFromSupabase(Map<String, dynamic> data) {
    return SyncableWatchedMovie(
      id: data['id'],
      userId: data['user_id'],
      movieId: data['movie_id'],
      movieTitle: data['movie_title'],
      moviePosterPath: data['movie_poster_path'],
      movieBackdropPath: data['movie_backdrop_path'],
      movieOverview: data['movie_overview'],
      movieReleaseDate: data['movie_release_date'] != null
          ? DateTime.parse(data['movie_release_date'])
          : null,
      movieVoteAverage: data['movie_vote_average']?.toDouble(),
      watchedAt: DateTime.parse(data['watched_at']),
      createdAt: DateTime.parse(data['watched_at']),
      updatedAt: DateTime.parse(data['updated_at']),
    );
  }

  // Obtener conteo de películas vistas
  Future<int> getWatchedCount() async {
    final appState = _ref.read(appStateProvider);

    if (appState.isAuthenticated) {
      try {
        await _checkOnline();
        // TODO: Implementar conteo en Supabase
        // return await _authRepository.getWatchedMoviesCount(appState.user!.id);
        final watchedMovies = await _hiveDatasource.loadWatchedMovies();
        return watchedMovies.length;
      } on SyncException catch (e) {
        print('Error obteniendo el conteo de películas vistas: $e');
        final watchedMovies = await _hiveDatasource.loadWatchedMovies();
        return watchedMovies.length;
      } catch (e) {
        throw LocalStorageException(
            'Error al obtener el conteo de películas vistas: $e');
      }
    } else {
      // Modo guest: usar solo datos locales
      try {
        final watchedMovies = await _hiveDatasource.loadWatchedMovies();
        return watchedMovies.length;
      } catch (e) {
        throw LocalStorageException(
            'Error al obtener el conteo de películas vistas: $e');
      }
    }
  }

  @override
  Future<void> syncWithSupabase() async {
    if (!_isAuthenticated()) return;

    try {
      await _checkOnline();
      // 1. Obtener datos locales y remotos
      final localWatched = await getLocalData();
      final remoteWatched = await getRemoteData();

      // 2. Identificar cambios
      final toUpload =
          ConflictResolver.findLocalChanges(localWatched, remoteWatched);
      final toDownload =
          ConflictResolver.findRemoteChanges(localWatched, remoteWatched);

      // 3. Subir cambios locales
      await _uploadToSupabase(toUpload);

      // 4. Descargar cambios remotos
      await _downloadFromSupabase(toDownload);

      // 5. Resolver conflictos
      await resolveConflicts(localWatched, remoteWatched);
    } on SyncException catch (e) {
      print('Error en sincronización de películas vistas: $e');
      rethrow;
    }
  }

  // Subir cambios locales a Supabase
  Future<void> _uploadToSupabase(
      List<SyncableWatchedMovie> watchedMovies) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    for (final watchedMovie in watchedMovies) {
      try {
        await _supabase.from('user_watched_movies').upsert({
          'id': watchedMovie.id,
          'user_id': userId,
          'movie_id': watchedMovie.movieId,
          'movie_title': watchedMovie.movieTitle,
          'movie_poster_path': watchedMovie.moviePosterPath,
          'movie_backdrop_path': watchedMovie.movieBackdropPath,
          'movie_overview': watchedMovie.movieOverview,
          'movie_release_date':
              watchedMovie.movieReleaseDate?.toIso8601String(),
          'movie_vote_average': watchedMovie.movieVoteAverage,
          'watched_at': watchedMovie.watchedAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } on PostgrestException catch (e) {
        throw SupabaseSyncException(
            'Error subiendo película vista ${watchedMovie.movieId}: ${e.message}',
            code: e.code);
      } catch (e) {
        throw SupabaseSyncException(
            'Error subiendo película vista ${watchedMovie.movieId}: $e');
      }
    }
  }

  // Descargar películas vistas remotas y actualizar localmente
  Future<void> _downloadFromSupabase(
      List<SyncableWatchedMovie> watchedMovies) async {
    for (final watchedMovie in watchedMovies) {
      try {
        final movie = Movie(
          id: watchedMovie.movieId,
          title: watchedMovie.movieTitle,
          posterPath: watchedMovie.moviePosterPath ?? '',
          backdropPath: watchedMovie.movieBackdropPath ?? '',
          overview: watchedMovie.movieOverview ?? '',
          releaseDate: watchedMovie.movieReleaseDate ?? DateTime.now(),
          voteAverage: watchedMovie.movieVoteAverage ?? 0.0,
          genreIds: [],
          adult: false,
          originalLanguage: 'en',
          originalTitle: watchedMovie.movieTitle,
          popularity: 0.0,
          video: false,
          voteCount: 0,
        );
        await _hiveDatasource.markAsWatched(movie);
      } catch (e) {
        throw LocalStorageException(
            'Error descargando película vista ${watchedMovie.movieId}: $e');
      }
    }
  }

  @override
  Future<void> resolveConflicts(List<SyncableWatchedMovie> local,
      List<SyncableWatchedMovie> remote) async {
    final conflicts = ConflictResolver.detectConflicts(local, remote);

    for (final conflict in conflicts) {
      try {
        // Resolver usando timestamp (último cambio gana)
        final resolved = ConflictResolver.resolveByTimestamp(
            conflict.local, conflict.remote);

        // Aplicar resolución localmente
        final movie = Movie(
          id: resolved.movieId,
          title: resolved.movieTitle,
          posterPath: resolved.moviePosterPath ?? '',
          backdropPath: resolved.movieBackdropPath ?? '',
          overview: resolved.movieOverview ?? '',
          releaseDate: resolved.movieReleaseDate ?? DateTime.now(),
          voteAverage: resolved.movieVoteAverage ?? 0.0,
          genreIds: [],
          adult: false,
          originalLanguage: 'en',
          originalTitle: resolved.movieTitle,
          popularity: 0.0,
          video: false,
          voteCount: 0,
        );
        await _hiveDatasource.markAsWatched(movie);

        // Aplicar resolución remotamente
        await _supabase.from('user_watched_movies').upsert({
          'id': resolved.id,
          'user_id': resolved.userId,
          'movie_id': resolved.movieId,
          'movie_title': resolved.movieTitle,
          'movie_poster_path': resolved.moviePosterPath,
          'movie_backdrop_path': resolved.movieBackdropPath,
          'movie_overview': resolved.movieOverview,
          'movie_release_date': resolved.movieReleaseDate?.toIso8601String(),
          'movie_vote_average': resolved.movieVoteAverage,
          'watched_at': resolved.watchedAt.toIso8601String(),
          'updated_at': resolved.updatedAt.toIso8601String(),
        });
      } on PostgrestException catch (e) {
        throw SupabaseSyncException(
            'Error resolviendo conflicto para ${conflict.local.id}: ${e.message}',
            code: e.code);
      } catch (e) {
        throw LocalStorageException(
            'Error resolviendo conflicto para ${conflict.local.id}: $e');
      }
    }
  }

  @override
  Future<void> markForSync(String itemId) async {
    await _syncQueue.addItem(itemId);
  }

  @override
  Future<bool> hasPendingSync() async {
    return !(await _syncQueue.isEmpty);
  }

  @override
  Future<List<String>> getPendingSyncItems() async {
    return await _syncQueue.getItems();
  }

  @override
  Future<void> clearSyncMarker(String itemId) async {
    await _syncQueue.removeItem(itemId);
  }

  // Implementación de métodos abstractos faltantes
  @override
  Future<void> upload(List<SyncableWatchedMovie> items) async {
    if (!_isAuthenticated()) return;

    try {
      await _checkOnline();

      for (final item in items) {
        final movie = item.toMovie();
        await _syncSingleItem(movie, isWatched: true);
      }
    } catch (e) {
      throw SyncException('Error subiendo películas vistas: $e');
    }
  }

  @override
  Future<void> download(List<SyncableWatchedMovie> items) async {
    if (!_isAuthenticated()) return;

    try {
      for (final item in items) {
        final movie = item.toMovie();
        await _hiveDatasource.markAsWatched(movie);
      }
    } catch (e) {
      throw SyncException('Error descargando películas vistas: $e');
    }
  }

  // Limpiar datos locales (útil para logout)
  Future<void> clearLocalData() async {
    // Limpiar todas las películas vistas una por una
    final allWatched = await _hiveDatasource.loadWatchedMovies();
    for (final watched in allWatched) {
      await _hiveDatasource.removeFromWatched(watched.movie.id);
    }
    await _syncQueue.clear();
  }
}
