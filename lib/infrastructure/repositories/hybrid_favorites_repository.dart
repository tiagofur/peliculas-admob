import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../services/conflict_resolver.dart';
import '../services/persistent_sync_queue.dart';
import '../services/sync_manager.dart';

// Repositorio híbrido que maneja favoritos localmente y sincroniza con Supabase
class HybridFavoritesRepository
    implements SyncableRepository<SyncableFavorite> {
  HybridFavoritesRepository({
    required LocalStorageDatasource datasource,
    required Ref ref,
  })  : _datasource = datasource,
        _ref = ref {
    _syncQueue.init();
  }
  final LocalStorageDatasource _datasource;
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
      final moviesList = await _datasource.loadMovies();
      return {for (var movie in moviesList) movie.id: movie};
    } catch (e) {
      throw LocalStorageException(
          'Error al cargar las películas favoritas: $e');
    }
  }

  // Agregar/quitar película de favoritos
  Future<void> toggleFavorite(Movie movie) async {
    print('🎬 TOGGLE FAVORITE llamado para: ${movie.title}');

    try {
      // 1. Actualizar localmente primero (Local First)
      print('💾 Actualizando favorito localmente: ${movie.title}');
      await _datasource.toggleFavorite(movie);
      print('✅ Favorito actualizado localmente: ${movie.title}');
    } catch (e) {
      print('❌ Error al actualizar favorito localmente: $e');
      throw LocalStorageException('Error al cambiar el estado de favorito: $e');
    }

    // 2. Marcar para sincronización
    final userId = _getCurrentUserId();
    if (userId != null) {
      print('📝 Marcando para sincronización: ${userId}_${movie.id}');
      await markForSync('${userId}_${movie.id}');
    } else {
      print('❌ No hay usuario para marcar sincronización');
    }

    // 3. Sincronizar si está online y autenticado
    try {
      print('🌐 Verificando conectividad...');
      await _checkOnline();
      if (_isAuthenticated()) {
        print('🔑 Usuario autenticado, iniciando sincronización individual...');
        await _syncSingleItem(movie);
      } else {
        print('❌ Usuario no autenticado, saltando sincronización');
      }
    } on SyncException catch (e) {
      // Si falla, se sincronizará más tarde
      print('❌ Error sincronizando favorito: $e');
    } catch (e) {
      print('❌ Error inesperado en sincronización: $e');
    }

    print('🏁 TOGGLE FAVORITE completado para: ${movie.title}');
  }

  // Sincronizar un elemento individual
  Future<void> _syncSingleItem(Movie movie) async {
    print('🔄 Iniciando sincronización individual de: ${movie.title}');

    final userId = _getCurrentUserId();
    if (userId == null) {
      print('❌ No hay usuario autenticado para sincronizar ${movie.title}');
      return;
    }

    final isFavorite = await _datasource.isMovieFavorite(movie.id);
    final favoriteId = '${userId}_${movie.id}';

    print(
        '📊 Estado de ${movie.title}: ${isFavorite ? "FAVORITO" : "NO FAVORITO"}');

    try {
      if (isFavorite) {
        print('⬆️ Agregando ${movie.title} a Supabase...');
        // Agregar a Supabase - usar upsert basado en user_id y movie_id
        await _supabase.from('user_favorites').upsert({
          'user_id': userId,
          'movie_id': movie.id,
          'movie_title': movie.title,
          'movie_poster_path': movie.posterPath,
          'movie_backdrop_path': movie.backdropPath,
          'movie_overview': movie.overview,
          'movie_release_date':
              movie.releaseDate.toIso8601String().split('T')[0], // Solo fecha
          'movie_vote_average': movie.voteAverage,
          'updated_at': DateTime.now().toIso8601String(),
          'deleted_at': null, // ✅ Marcar como activo (no eliminado)
        }, onConflict: 'user_id,movie_id');
        print('✅ ${movie.title} agregado a Supabase exitosamente');
      } else {
        print('⬇️ Soft delete de ${movie.title} en Supabase...');
        // ✅ Soft delete en lugar de hard delete
        await _supabase
            .from('user_favorites')
            .update({
              'deleted_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('movie_id', movie.id);
        print('✅ ${movie.title} marcado como eliminado en Supabase');
      }

      // Limpiar marcador de sincronización
      await clearSyncMarker(favoriteId);
      print('🧹 Marcador de sincronización limpiado para ${movie.title}');
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
      return await _datasource.isMovieFavorite(movieId);
    } catch (e) {
      throw LocalStorageException(
          'Error al verificar si la película es favorita: $e');
    }
  }

  // Implementación de SyncableRepository
  @override
  Future<List<SyncableFavorite>> getLocalData() async {
    try {
      print('🔍 Obteniendo datos locales...');
      // Obtener TODAS las películas, no solo las primeras 10
      final moviesList = await _datasource.loadMovies(limit: 10000, offset: 0);
      print('🔍 HiveDatasource retornó: ${moviesList.length} películas');

      final userId = _getCurrentUserId();
      if (userId == null) {
        print('❌ No hay usuario para obtener datos locales de favoritos');
        return [];
      }
      print('🔍 Usuario actual: $userId');

      final localFavorites = moviesList
          .map((movie) => SyncableFavorite.fromMovie(
                userId: userId,
                movie: movie,
              ))
          .toList();

      print('📱 Favoritos locales encontrados: ${localFavorites.length}');
      if (localFavorites.isNotEmpty) {
        print('📱 Primeros favoritos locales:');
        for (int i = 0; i < localFavorites.length.clamp(0, 3); i++) {
          final fav = localFavorites[i];
          print('   - ${fav.movieTitle} (ID: ${fav.movieId})');
        }
      }
      return localFavorites;
    } catch (e) {
      print('❌ Error obteniendo favoritos locales: $e');
      throw LocalStorageException(
          'Error al obtener los datos locales de favoritos: $e');
    }
  }

  @override
  Future<List<SyncableFavorite>> getRemoteData() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      print('❌ No hay usuario para obtener datos remotos de favoritos');
      return [];
    }

    try {
      await _checkOnline();
      print('☁️ Obteniendo favoritos remotos para usuario: $userId');

      final response = await _supabase
          .from('user_favorites')
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at',
              null) // ✅ Solo obtener favoritos activos (no eliminados)
          .order('added_at', ascending: false);

      final remoteFavorites =
          (response as List).map((data) => _mapFromSupabase(data)).toList();
      print('☁️ Favoritos remotos encontrados: ${remoteFavorites.length}');

      return remoteFavorites;
    } on PostgrestException catch (e) {
      print(
          '❌ Error PostgreSQL obteniendo favoritos remotos: ${e.message} (${e.code})');
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      print('❌ Error obteniendo favoritos remotos: $e');
      throw SupabaseSyncException('Error obteniendo favoritos remotos: $e');
    }
  }

  // Mapear datos de Supabase a SyncableFavorite
  SyncableFavorite _mapFromSupabase(Map<String, dynamic> data) {
    return SyncableFavorite(
      id: data['id'] ??
          '${data['user_id']}_${data['movie_id']}', // Usar UUID o generar ID
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
    if (!_isAuthenticated()) {
      print('❌ Usuario no autenticado, saltando sincronización de favoritos');
      return;
    }

    print('🔄 Iniciando sincronización de favoritos...');
    final syncManager = SyncManager<SyncableFavorite>(this);
    try {
      final result = await syncManager.sync();
      print('✅ Sincronización de favoritos completada: $result');
    } on SyncException catch (e) {
      print('❌ Error en sincronización de favoritos: $e');
      rethrow;
    }
  }

  @override
  Future<void> upload(List<SyncableFavorite> favorites) async {
    print('⬆️ UPLOAD iniciado para ${favorites.length} favoritos');

    if (favorites.isEmpty) {
      print('⬆️ No hay favoritos para subir');
      return;
    }

    for (final favorite in favorites) {
      try {
        print(
            '⬆️ Subiendo ${favorite.movieTitle} (ID: ${favorite.movieId})...');

        await _supabase.from('user_favorites').upsert({
          'user_id': favorite.userId,
          'movie_id': favorite.movieId,
          'movie_title': favorite.movieTitle,
          'movie_poster_path': favorite.moviePosterPath,
          'movie_backdrop_path': favorite.movieBackdropPath,
          'movie_overview': favorite.movieOverview,
          'movie_release_date':
              favorite.movieReleaseDate?.toIso8601String().split('T')[0],
          'movie_vote_average': favorite.movieVoteAverage,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,movie_id');

        print('✅ ${favorite.movieTitle} subido exitosamente');
      } on PostgrestException catch (e) {
        print(
            '❌ Error PostgreSQL subiendo ${favorite.movieTitle}: ${e.message}');
        throw SupabaseSyncException(
            'Error subiendo favorito ${favorite.movieTitle}: ${e.message}',
            code: e.code);
      } catch (e) {
        print('❌ Error general subiendo ${favorite.movieTitle}: $e');
        throw SupabaseSyncException(
            'Error subiendo favorito ${favorite.movieTitle}: $e');
      }
    }

    print('🎉 Upload de ${favorites.length} favoritos completado');
  }

  @override
  Future<void> download(List<SyncableFavorite> favorites) async {
    for (final favorite in favorites) {
      try {
        final movie = favorite.toMovie();
        await _datasource.toggleFavorite(movie);
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
        await _datasource.toggleFavorite(movie);

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

  // Limpiar datos locales (útil para logout)
  Future<void> clearLocalData() async {
    // Limpiar todas las películas favoritas una por una
    final allFavorites = await _datasource.loadMovies();
    for (final favorite in allFavorites) {
      await _datasource.toggleFavorite(favorite);
    }
    await _syncQueue.clear();
  }
}
