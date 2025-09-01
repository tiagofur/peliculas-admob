import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../core/sync/conflict_resolution/conflict_detector.dart';
import '../../core/sync/conflict_resolution/conflict_metrics_service.dart';
import '../../core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';
import '../../core/sync/conflict_resolution/soft_delete_manager.dart';
import '../../core/sync/conflict_resolution/strategies/watched_movies_conflict_strategy.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/entities/syncable_watched_movie.dart';
import '../../domain/entities/watched_movie.dart';
import '../../domain/repositories/watched_movies_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../datasources/watched_movies_hive_datasource.dart';
import '../sync/conflict_statistics_service.dart';
import 'base_hybrid_repository.dart';

// Repositorio híbrido que maneja películas vistas localmente y sincroniza con Supabase
class HybridWatchedRepository extends BaseHybridRepository<SyncableWatchedMovie>
    implements WatchedMoviesRepository {
  HybridWatchedRepository({
    required WatchedMoviesHiveDatasource hiveDatasource,
    required Ref ref,
  })  : _hiveDatasource = hiveDatasource,
        super(ref: ref) {
    _conflictResolver = MultiplataformConflictResolver();
    _statisticsService = ConflictStatisticsService();
    _softDeleteManager = SoftDeleteManager();
    _conflictDetector = ConflictDetector(
      _softDeleteManager,
      _statisticsService,
    );
    _metricsService = ConflictMetricsService();
    _initializeWatchedComponents();
  }

  Future<void> _initializeWatchedComponents() async {
    // Registrar estrategia de resolución para películas vistas
    _conflictResolver.registerStrategy<SyncableWatchedMovie>(
      WatchedMoviesConflictStrategy(),
    );

    // Iniciar sesión de métricas
    _metricsService.startSession();
  }

  final WatchedMoviesHiveDatasource _hiveDatasource;
  late final MultiplataformConflictResolver _conflictResolver;
  late final ConflictStatisticsService _statisticsService;
  late final ConflictDetector _conflictDetector;
  late final SoftDeleteManager _softDeleteManager;
  late final ConflictMetricsService _metricsService;

  // Implements BaseHybridRepository abstract methods
  @override
  String get tableName => 'user_watched_movies';

  @override
  SyncableWatchedMovie mapFromSupabase(Map<String, dynamic> data) {
    return SyncableWatchedMovie(
      id: data['id'] ?? '${data['user_id']}_${data['movie_id']}_watched',
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
      createdAt: DateTime.parse(data['created_at']),
      updatedAt: DateTime.parse(data['updated_at']),
      rating: data['rating']?.toDouble(),
      review: data['review'],
      traktId: data['trakt_id'],
    );
  }

  @override
  Map<String, dynamic> mapToSupabase(SyncableWatchedMovie watchedMovie) {
    return {
      'user_id': watchedMovie.userId,
      'movie_id': watchedMovie.movieId,
      'movie_title': watchedMovie.movieTitle,
      'movie_poster_path': watchedMovie.moviePosterPath,
      'movie_backdrop_path': watchedMovie.movieBackdropPath,
      'movie_overview': watchedMovie.movieOverview,
      'movie_release_date':
          watchedMovie.movieReleaseDate?.toIso8601String().split('T')[0],
      'movie_vote_average': watchedMovie.movieVoteAverage,
      'watched_at': watchedMovie.watchedAt.toIso8601String(),
      'rating': watchedMovie.rating,
      'review': watchedMovie.review,
      'trakt_id': watchedMovie.traktId,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> clearRepositoryData() async {
    await _hiveDatasource.clearAll();
  }

  // Implements WatchedMoviesRepository interface
  @override
  Future<void> markAsWatched(Movie movie) async {
    LoggerFactory.info('🎬 MARK AS WATCHED llamado para: ${movie.title}');

    try {
      // 1. Actualizar localmente primero (Local First)
      LoggerFactory.info('💾 Marcando como vista localmente: ${movie.title}');
      await _hiveDatasource.markAsWatched(movie);
      LoggerFactory.info('✅ Película marcada como vista localmente: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ Error al marcar como vista localmente: $e');
      throw LocalStorageException('Error al marcar película como vista: $e');
    }

    // 2. Agregar operación a la cola de sincronización
    final userId = _getCurrentUserId();
    if (userId != null) {
      final operation = SyncOperationFactory.addWatched(
        userId: userId, 
        movieId: movie.id
      );
      
      LoggerFactory.info(
          '📝 Agregando operación a la cola: ${operation.type.name} para ${movie.title}');
      await syncQueue.enqueue(operation);
    }

    // 3. Sincronizar si está online y autenticado
    try {
      LoggerFactory.info('🌐 Verificando conectividad...');
      await _checkOnline();
      if (_isAuthenticated()) {
        LoggerFactory.info(
            '🔑 Usuario autenticado, iniciando sincronización individual...');
        await _syncSingleWatchedItem(movie);
      }
    } on SyncException catch (e) {
      LoggerFactory.error('❌ Error sincronizando película vista: $e');
    } catch (e) {
      LoggerFactory.error('❌ Error inesperado en sincronización: $e');
    }

    LoggerFactory.info('🏁 MARK AS WATCHED completado para: ${movie.title}');
  }

  @override
  Future<void> removeFromWatched(int movieId) async {
    LoggerFactory.info('🗑️ REMOVE FROM WATCHED llamado para movie ID: $movieId');
    
    try {
      await _hiveDatasource.removeFromWatched(movieId);
      LoggerFactory.info('✅ Película removida de vistas localmente');
    } catch (e) {
      LoggerFactory.error('❌ Error al remover de vistas localmente: $e');
      throw LocalStorageException('Error al remover película de vistas: $e');
    }

    // Sincronizar si está autenticado
    final userId = _getCurrentUserId();
    if (userId != null) {
      final operation = SyncOperationFactory.removeWatched(
        userId: userId, 
        movieId: movieId
      );
      await syncQueue.enqueue(operation);

      if (_isAuthenticated()) {
        try {
          await _checkOnline();
          await _syncSingleWatchedRemoval(movieId);
        } on SyncException catch (e) {
          LoggerFactory.error('❌ Error sincronizando remoción: $e');
        }
      }
    }
  }

  @override
  Future<bool> isMovieWatched(int movieId) async {
    try {
      return await _hiveDatasource.isMovieWatched(movieId);
    } catch (e) {
      throw LocalStorageException('Error al verificar si la película fue vista: $e');
    }
  }

  @override
  Future<List<WatchedMovie>> loadWatchedMovies({int limit = 10, int offset = 0}) async {
    if (_isAuthenticated()) {
      try {
        await _checkOnline();
        await syncWithSupabase();
      } on SyncException catch (e) {
        LoggerFactory.error('Error en sincronización automática: $e');
      }
    }

    try {
      return await _hiveDatasource.loadWatchedMovies();
    } catch (e) {
      throw LocalStorageException('Error al cargar las películas vistas: $e');
    }
  }

  // Helper methods for sync operations
  Future<void> _syncSingleWatchedItem(Movie movie) async {
    LoggerFactory.info('🔄 Iniciando sincronización individual de película vista: ${movie.title}');

    final userId = _getCurrentUserId();
    if (userId == null) {
      LoggerFactory.warning('❌ No hay usuario autenticado para sincronizar ${movie.title}');
      return;
    }

    try {
      // Agregar a Supabase - usar upsert basado en user_id y movie_id
      await supabase.from('user_watched_movies').upsert({
        'user_id': userId,
        'movie_id': movie.id,
        'movie_title': movie.title,
        'movie_poster_path': movie.posterPath,
        'movie_backdrop_path': movie.backdropPath,
        'movie_overview': movie.overview,
        'movie_release_date': movie.releaseDate.toIso8601String().split('T')[0],
        'movie_vote_average': movie.voteAverage,
        'watched_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'deleted_at': null,
      }, onConflict: 'user_id,movie_id');
      
      LoggerFactory.info('✅ ${movie.title} agregada a películas vistas en Supabase');
    } catch (e) {
      LoggerFactory.error('❌ Error sincronizando película vista: $e');
      throw SupabaseSyncException('Error sincronizando película vista ${movie.title}: $e');
    }
  }

  Future<void> _syncSingleWatchedRemoval(int movieId) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    try {
      // Soft delete en Supabase
      await supabase
          .from('user_watched_movies')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('movie_id', movieId);
          
      LoggerFactory.info('✅ Película ID $movieId marcada como eliminada en Supabase');
    } catch (e) {
      LoggerFactory.error('❌ Error en soft delete: $e');
      throw SupabaseSyncException('Error removiendo película vista $movieId: $e');
    }
  }

  // Implements SyncableRepository methods
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
      // Agregar operación de remoción a la cola
      final userId = _getCurrentUserId();
      if (userId != null) {
        final operation = SyncOperationFactory.unmarkWatched(
            userId: userId, movieId: movieId);
        await _syncQueue.enqueue(operation);
      }
      LoggerFactory.error(
          'Error sincronizando remoción de película vista $movieId: $e');
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
      traktId: null, // No usar Trakt ID
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
        LoggerFactory.error(
            'Error obteniendo el conteo de películas vistas: $e');
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

      LoggerFactory.info('🔄 Iniciando sincronización de películas vistas');

      // 1. Obtener datos locales y remotos
      final localWatched = await getLocalData();
      final remoteWatched = await getRemoteData();

      LoggerFactory.info(
          '📊 Local: ${localWatched.length}, Remoto: ${remoteWatched.length}');

      // 2. Detectar conflictos usando el nuevo sistema
      final conflicts = _conflictDetector.detectConflicts(
        localWatched,
        remoteWatched,
      );

      if (conflicts.isNotEmpty) {
        LoggerFactory.info('⚠️ Detectados ${conflicts.length} conflictos');

        // 3. Resolver conflictos uno por uno
        for (final conflict in conflicts) {
          _metricsService.logConflictDetected(conflict);

          try {
            // Detectar tipo de conflicto
            final conflictType = _conflictResolver.detectConflictType(
              conflict.localItem,
              conflict.remoteItem,
              conflict.localItem.deletedAt != null,
              conflict.remoteItem.deletedAt != null,
              conflict.localItem.updatedAt,
              conflict.remoteItem.updatedAt,
            );

            final resolution = _conflictResolver.resolveConflict(
              conflict.localItem,
              conflict.remoteItem,
              conflictType,
            );

            // Aplicar resolución
            await _applyResolution(conflict, resolution);

            _metricsService.logConflictResolved(
              conflict,
              resolution,
              beforeState: {
                'local': conflict.localItem,
                'remote': conflict.remoteItem
              },
              afterState: {'resolved': resolution.resolvedItem},
            );

            LoggerFactory.info(
                '✅ Conflicto resuelto: ${resolution.resolution}');
          } catch (e, stackTrace) {
            _metricsService.logConflictResolutionError(conflict, e, stackTrace);
            LoggerFactory.error('❌ Error resolviendo conflicto: $e');
            rethrow;
          }
        }
      }

      // 4. Sincronizar elementos sin conflictos
      await _syncNonConflictingItems(localWatched, remoteWatched, conflicts);

      // 5. Obtener estadísticas de conflictos
      final stats = _conflictResolver.getConflictStats();
      LoggerFactory.info(
          '📈 Estadísticas de conflictos: ${stats['totalConflicts']} total, ${stats['resolvedConflicts'] ?? 0} resueltos');
    } on SyncException catch (e) {
      LoggerFactory.error('Error en sincronización de películas vistas: $e');
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

  /// Aplica la resolución de un conflicto tanto local como remotamente
  Future<void> _applyResolution<T>(
    ConflictInfo<T> conflict,
    ConflictResolutionResult<T> resolution,
  ) async {
    final resolvedItem = resolution.resolvedItem as SyncableWatchedMovie;

    try {
      // Manejar soft deletes
      if (resolution.dataLoss) {
        _softDeleteManager.markAsDeleted<SyncableWatchedMovie>(resolvedItem);

        // Aplicar soft delete remotamente
        await _supabase.from('user_watched_movies').update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', resolvedItem.id);

        // Remover localmente
        await _hiveDatasource.removeFromWatched(resolvedItem.movieId);

        LoggerFactory.info(
            '🗑️ Soft delete aplicado para ${resolvedItem.movieTitle}');
        return;
      }

      // Aplicar resolución localmente
      final movie = Movie(
        id: resolvedItem.movieId,
        title: resolvedItem.movieTitle,
        posterPath: resolvedItem.moviePosterPath ?? '',
        backdropPath: resolvedItem.movieBackdropPath ?? '',
        overview: resolvedItem.movieOverview ?? '',
        releaseDate: resolvedItem.movieReleaseDate ?? DateTime.now(),
        voteAverage: resolvedItem.movieVoteAverage ?? 0.0,
        genreIds: [],
        adult: false,
        originalLanguage: 'en',
        originalTitle: resolvedItem.movieTitle,
        popularity: 0.0,
        video: false,
        voteCount: 0,
      );
      await _hiveDatasource.markAsWatched(movie);

      // Aplicar resolución remotamente
      await _supabase.from('user_watched_movies').upsert({
        'id': resolvedItem.id,
        'user_id': resolvedItem.userId,
        'movie_id': resolvedItem.movieId,
        'movie_title': resolvedItem.movieTitle,
        'movie_poster_path': resolvedItem.moviePosterPath,
        'movie_backdrop_path': resolvedItem.movieBackdropPath,
        'movie_overview': resolvedItem.movieOverview,
        'movie_release_date': resolvedItem.movieReleaseDate?.toIso8601String(),
        'movie_vote_average': resolvedItem.movieVoteAverage,
        'watched_at': resolvedItem.watchedAt.toIso8601String(),
        'updated_at': resolvedItem.updatedAt.toIso8601String(),
        'deleted_at': null, // Asegurar que no esté marcado como eliminado
      });

      LoggerFactory.info(
          '💾 Resolución aplicada para ${resolvedItem.movieTitle}');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(
          'Error aplicando resolución para ${resolvedItem.id}: ${e.message}',
          code: e.code);
    } catch (e) {
      throw LocalStorageException(
          'Error aplicando resolución para ${resolvedItem.id}: $e');
    }
  }

  /// Sincroniza elementos que no tienen conflictos
  Future<void> _syncNonConflictingItems(
    List<SyncableWatchedMovie> localItems,
    List<SyncableWatchedMovie> remoteItems,
    List<ConflictInfo<SyncableWatchedMovie>> conflicts,
  ) async {
    // Obtener IDs de elementos en conflicto
    final conflictIds =
        conflicts.expand((c) => [c.localItem.id, c.remoteItem.id]).toSet();

    // Elementos locales sin conflictos para subir
    final localToUpload = localItems
        .where((item) => !conflictIds.contains(item.id))
        .where((local) => !remoteItems.any((remote) => remote.id == local.id))
        .toList();

    // Elementos remotos sin conflictos para descargar
    final remoteToDownload = remoteItems
        .where((item) => !conflictIds.contains(item.id))
        .where((remote) => !localItems.any((local) => local.id == remote.id))
        .toList();

    LoggerFactory.info(
        '⬆️ Subiendo ${localToUpload.length} elementos sin conflictos');
    LoggerFactory.info(
        '⬇️ Descargando ${remoteToDownload.length} elementos sin conflictos');

    // Subir elementos locales
    if (localToUpload.isNotEmpty) {
      await _uploadToSupabase(localToUpload);
    }

    // Descargar elementos remotos
    if (remoteToDownload.isNotEmpty) {
      await _downloadFromSupabase(remoteToDownload);
    }
  }

  @override
  Future<void> resolveConflicts(List<SyncableWatchedMovie> local,
      List<SyncableWatchedMovie> remote) async {
    // Este método se mantiene por compatibilidad pero ahora usa el nuevo sistema
    LoggerFactory.info(
        '⚠️ Usando método de resolución de conflictos legacy - considera usar syncWithSupabase()');

    final conflicts =
        _conflictDetector.detectConflicts<SyncableWatchedMovie>(local, remote);

    for (final conflict in conflicts) {
      try {
        // Detectar tipo de conflicto
        final conflictType = _conflictResolver.detectConflictType(
          conflict.localItem,
          conflict.remoteItem,
          conflict.localItem.deletedAt != null,
          conflict.remoteItem.deletedAt != null,
          conflict.localItem.updatedAt,
          conflict.remoteItem.updatedAt,
        );

        final resolution = _conflictResolver.resolveConflict(
          conflict.localItem,
          conflict.remoteItem,
          conflictType,
        );
        await _applyResolution(conflict, resolution);
      } catch (e) {
        LoggerFactory.error('Error en resolución legacy: $e');
        rethrow;
      }
    }
  }

  @override
  Future<void> markForSync(String itemId) async {
    await _syncQueue.addItem(
      'mark_watched',
      {'movieId': itemId},
      priority: 1,
    );
  }

  @override
  Future<bool> hasPendingSync() async {
    final stats = _syncQueue.getStats();
    return stats.pendingOperations > 0;
  }

  @override
  Future<List<String>> getPendingSyncItems() async {
    final operations = _syncQueue.getPendingOperations();
    return operations
        .map((op) => '${op.data['movieId']}_${op.type.name}')
        .toList();
  }

  @override
  Future<void> clearSyncMarker(String itemId) async {
    // Las operaciones se limpian automáticamente por la cola
    LoggerFactory.info(
        '🧹 Marcador de sincronización limpiado automáticamente: $itemId');
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
