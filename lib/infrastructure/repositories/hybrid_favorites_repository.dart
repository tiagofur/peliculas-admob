import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../datasources/isar_datasource.dart';
import '../services/conflict_resolver.dart';
import '../services/persistent_sync_queue.dart';
import '../services/sync_manager.dart';

// Repositorio híbrido que maneja favoritos localmente y sincroniza con Supabase
class HybridFavoritesRepository
    implements SyncableRepository<SyncableFavorite> {
  HybridFavoritesRepository({
    required HiveDatasource hiveDatasource,
    required Ref ref,
  })  : _hiveDatasource = hiveDatasource,
        _ref = ref {
    _syncQueue.init();
  }
  final HiveDatasource _hiveDatasource;
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final PersistentSyncQueue _syncQueue = PersistentSyncQueue();

  // Verificar si hay conexión a internet
  Future<void> _checkOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw NetworkException();
    }
  }

  // Verificar si el usuario está autenticado
  bool _isAuthenticated() {
    final appState = _ref.read(appStateProvider);
    return appState.isAuthenticated && appState.user != null;
  }

  // Obtener ID del usuario actual
  String? _getCurrentUserId() {
    final appState = _ref.read(appStateProvider);
    return appState.user?.id;
  }

  // Obtener películas favoritas (local o remoto según el estado)
  Future<Map<int, Movie>> getFavoriteMovies() async {
    if (_isAuthenticated()) {
      try {
        await _checkOnline();
        // Intentar sincronizar primero
        await syncWithSupabase();
      } on SyncException catch (e) {
        // Si falla la sincronización, se puede registrar el error o notificar al usuario
        print(e);
      }
    }

    try {
      // Obtener datos locales
      final moviesList = await _hiveDatasource.loadMovies();
      return {for (var movie in moviesList) movie.id: movie};
    } catch (e) {
      throw LocalStorageException(
          'Error al cargar las películas favoritas: $e');
    }
  }

  // Agregar/quitar película de favoritos
  Future<void> toggleFavorite(Movie movie) async {
    try {
      // 1. Actualizar localmente primero (Local First)
      await _hiveDatasource.toggleFavorite(movie);
    } catch (e) {
      throw LocalStorageException('Error al cambiar el estado de favorito: $e');
    }

    // 2. Marcar para sincronización
    final userId = _getCurrentUserId();
    if (userId != null) {
      await markForSync('${userId}_${movie.id}');
    }

    // 3. Sincronizar si está online y autenticado
    try {
      await _checkOnline();
      if (_isAuthenticated()) {
        await _syncSingleItem(movie);
      }
    } on SyncException catch (e) {
      // Si falla, se sincronizará más tarde
      print('Error sincronizando favorito: $e');
    }
  }

  // Sincronizar un elemento individual
  Future<void> _syncSingleItem(Movie movie) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    final isFavorite = await _hiveDatasource.isMovieFavorite(movie.id);
    final favoriteId = '${userId}_${movie.id}';

    try {
      if (isFavorite) {
        // Agregar a Supabase
        await _supabase.from('user_favorites').upsert({
          'id': favoriteId,
          'user_id': userId,
          'movie_id': movie.id,
          'movie_title': movie.title,
          'movie_poster_path': movie.posterPath,
          'movie_backdrop_path': movie.backdropPath,
          'movie_overview': movie.overview,
          'movie_release_date': movie.releaseDate.toIso8601String(),
          'movie_vote_average': movie.voteAverage,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Remover de Supabase
        await _supabase
            .from('user_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('movie_id', movie.id);
      }

      // Limpiar marcador de sincronización
      await clearSyncMarker(favoriteId);
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  // Verificar si una película es favorita
  Future<bool> isMovieFavorite(int movieId) async {
    // Siempre usar datos locales para respuesta inmediata
    try {
      return await _hiveDatasource.isMovieFavorite(movieId);
    } catch (e) {
      throw LocalStorageException(
          'Error al verificar si la película es favorita: $e');
    }
  }

  // Implementación de SyncableRepository
  @override
  Future<List<SyncableFavorite>> getLocalData() async {
    try {
      final moviesList = await _hiveDatasource.loadMovies();
      final userId = _getCurrentUserId();
      if (userId == null) return [];

      return moviesList
          .map((movie) => SyncableFavorite.fromMovie(
                userId: userId,
                movie: movie,
              ))
          .toList();
    } catch (e) {
      throw LocalStorageException(
          'Error al obtener los datos locales de favoritos: $e');
    }
  }

  @override
  Future<List<SyncableFavorite>> getRemoteData() async {
    final userId = _getCurrentUserId();
    if (userId == null) return [];

    try {
      await _checkOnline();
      final response = await _supabase
          .from('user_favorites')
          .select()
          .eq('user_id', userId)
          .order('added_at', ascending: false);

      return (response as List).map((data) => _mapFromSupabase(data)).toList();
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException('Error obteniendo favoritos remotos: $e');
    }
  }

  // Mapear datos de Supabase a SyncableFavorite
  SyncableFavorite _mapFromSupabase(Map<String, dynamic> data) {
    return SyncableFavorite(
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
      addedAt: DateTime.parse(data['added_at']),
      createdAt: DateTime.parse(data['added_at']),
      updatedAt: DateTime.parse(data['updated_at']),
    );
  }

  @override
  Future<void> syncWithSupabase() async {
    if (!_isAuthenticated()) return;

    final syncManager = SyncManager<SyncableFavorite>(this);
    try {
      final result = await syncManager.sync();
      print('Sincronización de favoritos completada: $result');
    } on SyncException catch (e) {
      print('Error en sincronización de favoritos: $e');
      rethrow;
    }
  }

  @override
  Future<void> upload(List<SyncableFavorite> favorites) async {
    for (final favorite in favorites) {
      try {
        await _supabase.from('user_favorites').upsert({
          'id': favorite.id,
          'user_id': favorite.userId,
          'movie_id': favorite.movieId,
          'movie_title': favorite.movieTitle,
          'movie_poster_path': favorite.moviePosterPath,
          'movie_backdrop_path': favorite.movieBackdropPath,
          'movie_overview': favorite.movieOverview,
          'movie_release_date': favorite.movieReleaseDate?.toIso8601String(),
          'movie_vote_average': favorite.movieVoteAverage,
          'added_at': favorite.addedAt.toIso8601String(),
          'updated_at': favorite.updatedAt.toIso8601String(),
        });
      } on PostgrestException catch (e) {
        throw SupabaseSyncException(
            'Error subiendo favorito ${favorite.id}: ${e.message}',
            code: e.code);
      } catch (e) {
        throw SupabaseSyncException(
            'Error subiendo favorito ${favorite.id}: $e');
      }
    }
  }

  @override
  Future<void> download(List<SyncableFavorite> favorites) async {
    for (final favorite in favorites) {
      try {
        final movie = favorite.toMovie();
        await _hiveDatasource.toggleFavorite(movie);
      } catch (e) {
        throw LocalStorageException(
            'Error descargando favorito ${favorite.id}: $e');
      }
    }
  }

  @override
  Future<void> resolveConflicts(
      List<SyncableFavorite> local, List<SyncableFavorite> remote) async {
    final conflicts = ConflictResolver.detectConflicts(local, remote);

    for (final conflict in conflicts) {
      try {
        // Resolver usando timestamp (último cambio gana)
        final resolved = ConflictResolver.resolveByTimestamp(
            conflict.local, conflict.remote);

        // Aplicar resolución localmente
        final movie = resolved.toMovie();
        await _hiveDatasource.toggleFavorite(movie);

        // Aplicar resolución remotamente
        await _supabase.from('user_favorites').upsert({
          'id': resolved.id,
          'user_id': resolved.userId,
          'movie_id': resolved.movieId,
          'movie_title': resolved.movieTitle,
          'movie_poster_path': resolved.moviePosterPath,
          'movie_backdrop_path': resolved.movieBackdropPath,
          'movie_overview': resolved.movieOverview,
          'movie_release_date': resolved.movieReleaseDate?.toIso8601String(),
          'movie_vote_average': resolved.movieVoteAverage,
          'added_at': resolved.addedAt.toIso8601String(),
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
    return !_syncQueue.isEmpty;
  }

  @override
  Future<List<String>> getPendingSyncItems() async {
    return _syncQueue.getItems();
  }

  @override
  Future<void> clearSyncMarker(String itemId) async {
    await _syncQueue.removeItem(itemId);
  }

  // Limpiar datos locales (útil para logout)
  Future<void> clearLocalData() async {
    // Limpiar todas las películas favoritas una por una
    final allFavorites = await _hiveDatasource.loadMovies();
    for (final favorite in allFavorites) {
      await _hiveDatasource.toggleFavorite(favorite);
    }
    await _syncQueue.clear();
  }
}
