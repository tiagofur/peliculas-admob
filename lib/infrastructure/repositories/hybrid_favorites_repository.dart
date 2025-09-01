import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../core/services/persistent_sync_queue.dart';
import '../../core/sync/conflict_resolution/conflict_detector.dart';
import '../../core/sync/conflict_resolution/conflict_metrics_service.dart';
import '../../core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';
import '../../core/sync/conflict_resolution/soft_delete_manager.dart';
import '../../core/sync/conflict_resolution/strategies/favorites_conflict_strategy.dart';
import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/entities/syncable_favorite_movie.dart';
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../services/sync_manager.dart';
// Removed unused import
import '../sync/conflict_statistics_service.dart';

// Repositorio híbrido que maneja favoritos localmente y sincroniza con Supabase
class HybridFavoritesRepository
    implements SyncableRepository<SyncableFavorite> {
  HybridFavoritesRepository({
    required LocalStorageDatasource datasource,
    required Ref ref,
  })  : _datasource = datasource,
        _ref = ref {
    _syncQueue = PersistentSyncQueue();
    _softDeleteManager = SoftDeleteManager();
    // Removed unused _severityClassifier
    _statisticsService = ConflictStatisticsService();
    _metricsService = ConflictMetricsService();
    _conflictDetector = ConflictDetector(
      _softDeleteManager,
      _statisticsService,
    );
    _conflictResolver = MultiplataformConflictResolver();
    _initializeComponents();
  }

  Future<void> _initializeComponents() async {
    await _syncQueue.initialize();

    // Registrar estrategia de resolución para favoritos
    _conflictResolver.registerStrategy<SyncableFavoriteMovie>(
      FavoritesConflictStrategy(),
    );

    // Iniciar sesión de métricas
    _metricsService.startSession('favorites_sync');
  }

  final LocalStorageDatasource _datasource;
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  late final PersistentSyncQueue _syncQueue;
  late final SoftDeleteManager _softDeleteManager;
  // Removed unused _severityClassifier
  late final ConflictStatisticsService _statisticsService;
  late final ConflictMetricsService _metricsService;
  late final ConflictDetector _conflictDetector;
  late final MultiplataformConflictResolver _conflictResolver;

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
        LoggerFactory.error('Error en sincronización automática: $e');
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
    LoggerFactory.info('🎬 TOGGLE FAVORITE llamado para: ${movie.title}');

    try {
      // 1. Actualizar localmente primero (Local First)
      LoggerFactory.info('💾 Actualizando favorito localmente: ${movie.title}');
      await _datasource.toggleFavorite(movie);
      LoggerFactory.info('✅ Favorito actualizado localmente: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ Error al actualizar favorito localmente: $e');
      throw LocalStorageException('Error al cambiar el estado de favorito: $e');
    }

    // 2. Agregar operación a la cola de sincronización
    final userId = _getCurrentUserId();
    if (userId != null) {
      final isFavorite = await _datasource.isMovieFavorite(movie.id);
      final operation = isFavorite
          ? SyncOperationFactory.addFavorite(userId: userId, movieId: movie.id)
          : SyncOperationFactory.removeFavorite(
              userId: userId, movieId: movie.id);

      LoggerFactory.info(
          '📝 Agregando operación a la cola: ${operation.type.name} para ${movie.title}');
      await _syncQueue.enqueue(operation);
    } else {
      LoggerFactory.warning(
          '❌ No hay usuario para agregar a la cola de sincronización');
    }

    // 3. Sincronizar si está online y autenticado
    try {
      LoggerFactory.info('🌐 Verificando conectividad...');
      await _checkOnline();
      if (_isAuthenticated()) {
        LoggerFactory.info(
            '🔑 Usuario autenticado, iniciando sincronización individual...');
        await _syncSingleItem(movie);
      } else {
        LoggerFactory.warning(
            '❌ Usuario no autenticado, saltando sincronización');
      }
    } on SyncException catch (e) {
      // Si falla, se sincronizará más tarde
      LoggerFactory.error('❌ Error sincronizando favorito: $e');
    } catch (e) {
      LoggerFactory.error('❌ Error inesperado en sincronización: $e');
    }

    LoggerFactory.info('🏁 TOGGLE FAVORITE completado para: ${movie.title}');
  }

  // Sincronizar un elemento individual
  Future<void> _syncSingleItem(Movie movie) async {
    LoggerFactory.info(
        '🔄 Iniciando sincronización individual de: ${movie.title}');

    final userId = _getCurrentUserId();
    if (userId == null) {
      LoggerFactory.warning(
          '❌ No hay usuario autenticado para sincronizar ${movie.title}');
      return;
    }

    final isFavorite = await _datasource.isMovieFavorite(movie.id);

    LoggerFactory.info(
        '📊 Estado de ${movie.title}: ${isFavorite ? "FAVORITO" : "NO FAVORITO"}');

    try {
      if (isFavorite) {
        LoggerFactory.info('⬆️ Agregando ${movie.title} a Supabase...');
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
        LoggerFactory.info('✅ ${movie.title} agregado a Supabase exitosamente');
      } else {
        LoggerFactory.info('⬇️ Soft delete de ${movie.title} en Supabase...');
        // ✅ Soft delete en lugar de hard delete
        await _supabase
            .from('user_favorites')
            .update({
              'deleted_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('movie_id', movie.id);
        LoggerFactory.info(
            '✅ ${movie.title} marcado como eliminado en Supabase');
      }

      LoggerFactory.info(
          '✅ Sincronización individual completada para ${movie.title}');
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
      LoggerFactory.info('🔍 Obteniendo datos locales...');
      // Obtener TODAS las películas, no solo las primeras 10
      final moviesList = await _datasource.loadMovies(limit: 10000, offset: 0);
      LoggerFactory.info(
          '🔍 HiveDatasource retornó: ${moviesList.length} películas');

      final userId = _getCurrentUserId();
      if (userId == null) {
        LoggerFactory.warning(
            '❌ No hay usuario para obtener datos locales de favoritos');
        return [];
      }
      LoggerFactory.info('🔍 Usuario actual: $userId');

      final localFavorites = moviesList
          .map((movie) => SyncableFavorite.fromMovie(
                userId: userId,
                movie: movie,
              ))
          .toList();

      LoggerFactory.info(
          '📱 Favoritos locales encontrados: ${localFavorites.length}');
      if (localFavorites.isNotEmpty) {
        LoggerFactory.info('📱 Primeros favoritos locales:');
        for (int i = 0; i < localFavorites.length.clamp(0, 3); i++) {
          final fav = localFavorites[i];
          LoggerFactory.info('   - ${fav.movieTitle} (ID: ${fav.movieId})');
        }
      }
      return localFavorites;
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo favoritos locales: $e');
      throw LocalStorageException(
          'Error al obtener los datos locales de favoritos: $e');
    }
  }

  @override
  Future<List<SyncableFavorite>> getRemoteData() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      LoggerFactory.warning(
          '❌ No hay usuario para obtener datos remotos de favoritos');
      return [];
    }

    try {
      await _checkOnline();
      LoggerFactory.info(
          '☁️ Obteniendo favoritos remotos para usuario: $userId');

      final response = await _supabase
          .from('user_favorites')
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at',
              null) // ✅ Solo obtener favoritos activos (no eliminados)
          .order('added_at', ascending: false);

      final remoteFavorites =
          (response as List).map((data) => _mapFromSupabase(data)).toList();
      LoggerFactory.info(
          '☁️ Favoritos remotos encontrados: ${remoteFavorites.length}');

      return remoteFavorites;
    } on PostgrestException catch (e) {
      LoggerFactory.error(
          '❌ Error PostgreSQL obteniendo favoritos remotos: ${e.message} (${e.code})');
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo favoritos remotos: $e');
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
      traktId: null, // No usar Trakt ID
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
      LoggerFactory.warning(
          '❌ Usuario no autenticado, saltando sincronización de favoritos');
      return;
    }

    LoggerFactory.info('🔄 Iniciando sincronización de favoritos...');
    final syncManager = SyncManager<SyncableFavorite>(this);
    try {
      final result = await syncManager.sync();
      LoggerFactory.info('✅ Sincronización de favoritos completada: $result');
    } on SyncException catch (e) {
      LoggerFactory.error('❌ Error en sincronización de favoritos: $e');
      rethrow;
    }
  }

  @override
  Future<void> upload(List<SyncableFavorite> favorites) async {
    LoggerFactory.info('⬆️ UPLOAD iniciado para ${favorites.length} favoritos');

    if (favorites.isEmpty) {
      LoggerFactory.info('⬆️ No hay favoritos para subir');
      return;
    }

    for (final favorite in favorites) {
      try {
        LoggerFactory.info(
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

        LoggerFactory.info('✅ ${favorite.movieTitle} subido exitosamente');
      } on PostgrestException catch (e) {
        LoggerFactory.error(
            '❌ Error PostgreSQL subiendo ${favorite.movieTitle}: ${e.message}');
        throw SupabaseSyncException(
            'Error subiendo favorito ${favorite.movieTitle}: ${e.message}',
            code: e.code);
      } catch (e) {
        LoggerFactory.error(
            '❌ Error general subiendo ${favorite.movieTitle}: $e');
        throw SupabaseSyncException(
            'Error subiendo favorito ${favorite.movieTitle}: $e');
      }
    }

    LoggerFactory.info('🎉 Upload de ${favorites.length} favoritos completado');
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
    LoggerFactory.info(
        '🔧 Iniciando resolución de conflictos para ${local.length} locales y ${remote.length} remotos');

    // Convertir a SyncableFavoriteMovie para el resolver
    final localFavoriteMovies = local
        .map((f) => SyncableFavoriteMovie(
              id: f.id,
              userId: f.userId,
              movieId: f.movieId,
              movieTitle: f.movieTitle,
              moviePosterPath: f.moviePosterPath,
              movieBackdropPath: f.movieBackdropPath,
              movieOverview: f.movieOverview,
              movieReleaseDate: f.movieReleaseDate,
              movieVoteAverage: f.movieVoteAverage,
              addedAt: f.addedAt,
              createdAt: f.createdAt,
              updatedAt: f.updatedAt,
              isDeleted: false, // Determinar basado en soft delete
            ))
        .toList();

    final remoteFavoriteMovies = remote
        .map((f) => SyncableFavoriteMovie(
              id: f.id,
              userId: f.userId,
              movieId: f.movieId,
              movieTitle: f.movieTitle,
              moviePosterPath: f.moviePosterPath,
              movieBackdropPath: f.movieBackdropPath,
              movieOverview: f.movieOverview,
              movieReleaseDate: f.movieReleaseDate,
              movieVoteAverage: f.movieVoteAverage,
              addedAt: f.addedAt,
              createdAt: f.createdAt,
              updatedAt: f.updatedAt,
              isDeleted: false, // Determinar basado en soft delete
            ))
        .toList();

    // Detectar conflictos usando el nuevo detector
    final conflicts = _conflictDetector.detectBatchConflicts(
      localFavoriteMovies,
      remoteFavoriteMovies,
    );

    LoggerFactory.info('⚠️ Conflictos detectados: ${conflicts.length}');

    for (final conflict in conflicts) {
      try {
        LoggerFactory.info(
            '🔧 Resolviendo conflicto ${conflict.type.name} para item ${conflict.localItem.id}');

        // Resolver usando el MultiplataformConflictResolver
        final resolutionResult = _conflictResolver.resolveConflict(
          conflict.localItem,
          conflict.remoteItem,
          conflict.type,
        );

        if (resolutionResult.dataLoss ||
            resolutionResult.severity == ConflictSeverity.high) {
          LoggerFactory.warning(
              '⚠️ Conflicto de alta severidad o con pérdida de datos: ${resolutionResult.resolution}');
          // Por ahora, usar la resolución automática disponible
        }

        final resolved = resolutionResult.resolvedItem;
        LoggerFactory.info(
            '✅ Conflicto resuelto: ${resolutionResult.resolution}');

        // Aplicar resolución localmente
        final movie = _favoriteMovieToMovie(resolved);
        await _datasource.toggleFavorite(movie);

        // Aplicar resolución remotamente si no está eliminado
        if (!resolved.isDeleted) {
          await _supabase.from('user_favorites').upsert({
            'id': resolved.id,
            'user_id': resolved.userId,
            'movie_id': resolved.movieId,
            'movie_title': resolved.movieTitle,
            'movie_poster_path': resolved.moviePosterPath,
            'movie_backdrop_path': resolved.movieBackdropPath,
            'movie_overview': resolved.movieOverview,
            'movie_release_date':
                resolved.movieReleaseDate?.toIso8601String().split('T')[0],
            'movie_vote_average': resolved.movieVoteAverage,
            'added_at': resolved.addedAt.toIso8601String(),
            'updated_at': resolved.updatedAt.toIso8601String(),
            'deleted_at': null,
          }, onConflict: 'user_id,movie_id');
        } else {
          // Aplicar soft delete
          _softDeleteManager.markAsDeleted(
            resolved,
            reason: 'Conflict resolution - deletion won',
          );

          await _supabase
              .from('user_favorites')
              .update({
                'deleted_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', resolved.userId)
              .eq('movie_id', resolved.movieId);
        }

        // Registrar métricas del conflicto
        LoggerFactory.info(
            '📊 Conflicto resuelto - Tipo: ${conflict.type.name}, Severidad: ${conflict.severity.name}');
      } on PostgrestException catch (e) {
        LoggerFactory.error(
            '❌ Error PostgreSQL resolviendo conflicto: ${e.message}');
        throw SupabaseSyncException(
            'Error resolviendo conflicto para ${conflict.localItem.id}: ${e.message}',
            code: e.code);
      } catch (e) {
        LoggerFactory.error('❌ Error general resolviendo conflicto: $e');
        throw LocalStorageException(
            'Error resolviendo conflicto para ${conflict.localItem.id}: $e');
      }
    }

    // Obtener estadísticas de resolución
    final resolverStats = _conflictResolver.getConflictStats();
    final detectorStats = _conflictDetector.getDetectionStats();

    LoggerFactory.info('📊 Estadísticas de resolución: $resolverStats');
    LoggerFactory.info('📊 Estadísticas de detección: $detectorStats');
  }

  /// Convierte SyncableFavoriteMovie a Movie
  Movie _favoriteMovieToMovie(SyncableFavoriteMovie favoriteMovie) {
    return Movie(
      id: favoriteMovie.movieId,
      title: favoriteMovie.movieTitle,
      posterPath: favoriteMovie.moviePosterPath ?? '',
      backdropPath: favoriteMovie.movieBackdropPath ?? '',
      overview: favoriteMovie.movieOverview ?? '',
      releaseDate: favoriteMovie.movieReleaseDate ?? DateTime.now(),
      voteAverage: favoriteMovie.movieVoteAverage ?? 0.0,
      genreIds: [],
      adult: false,
      originalLanguage: 'en',
      originalTitle: favoriteMovie.movieTitle,
      popularity: 0.0,
      video: false,
      voteCount: 0,
    );
  }

  @override
  Future<void> markForSync(String itemId) async {
    // Método legacy - ahora se usa enqueue con SyncOperation
    LoggerFactory.warning('markForSync legacy method called for: $itemId');
  }

  @override
  Future<bool> hasPendingSync() async {
    final stats = _syncQueue.getStats();
    return stats.pendingOperations > 0;
  }

  @override
  Future<List<String>> getPendingSyncItems() async {
    final operations = _syncQueue.getPendingOperations();
    return operations.map((op) => op.id).toList();
  }

  @override
  Future<void> clearSyncMarker(String itemId) async {
    // Método legacy - las operaciones se limpian automáticamente al completarse
    LoggerFactory.info('clearSyncMarker legacy method called for: $itemId');
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
