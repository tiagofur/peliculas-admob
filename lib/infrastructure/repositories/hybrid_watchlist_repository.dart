import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../core/sync/conflict_resolution/conflict_detector.dart';
import '../../core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';
import '../../core/sync/conflict_resolution/soft_delete_manager.dart';
import '../../core/sync/conflict_resolution/strategies/watchlist_conflict_strategy.dart';
import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/entities/syncable_watchlist_movie.dart';
import '../../domain/entities/watchlist_movie.dart';
import '../sync/conflict_statistics_service.dart';
import 'base_hybrid_repository.dart';

/// Repositorio híbrido que maneja watchlist localmente y sincroniza con Supabase
class HybridWatchlistRepository
    extends BaseHybridRepository<SyncableWatchlistMovie> {
  HybridWatchlistRepository({
    required LocalStorageDatasource datasource,
    required super.ref,
  }) : _datasource = datasource {
    _initializeComponents();
  }

  final LocalStorageDatasource _datasource;
  late final SoftDeleteManager _softDeleteManager;
  late final ConflictDetector _conflictDetector;
  late final MultiplataformConflictResolver _conflictResolver;

  static const _uuid = Uuid();

  Future<void> _initializeComponents() async {
    _softDeleteManager = SoftDeleteManager();
    _conflictDetector =
        ConflictDetector(_softDeleteManager, ConflictStatisticsService());
    _conflictResolver = MultiplataformConflictResolver();

    _conflictResolver.registerStrategy<SyncableWatchlistMovie>(
      WatchlistConflictStrategy(),
    );
  }

  /// Agregar película a watchlist con prioridad especificada
  Future<void> addToWatchlist(Movie movie, WatchlistPriority priority) async {
    LoggerFactory.info(
        '🎬 AGREGAR A WATCHLIST llamado para: ${movie.title} con prioridad: ${priority.displayName}');

    try {
      // 1. Actualizar localmente primero (Local First)
      LoggerFactory.info('💾 Agregando a watchlist localmente: ${movie.title}');
      await _datasource.addToWatchlist(movie, priority);
      LoggerFactory.info('✅ Agregado a watchlist localmente: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ Error al agregar a watchlist localmente: $e');
      throw LocalStorageException('Error al agregar a watchlist: $e');
    }

    // 2. Agregar operación a la cola de sincronización
    final userId = getCurrentUserId();
    if (userId != null) {
      final operation = SyncOperationFactory.addToWatchlist(
        movieId: movie.id,
        userId: userId,
        priority: priority.value,
      );
      await syncQueue.addItem(operation.id);

      LoggerFactory.info(
          '📝 Operación agregada a la cola: ${operation.type.name} para ${movie.title}');

      // 3. Intentar sincronización inmediata si hay conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        LoggerFactory.info(
            '🌐 Conectividad disponible, sincronizando ${movie.title}...');
        await _syncSingleItem(movie, priority: priority);
      } else {
        LoggerFactory.info(
            '📡 Sin conectividad, ${movie.title} se sincronizará más tarde');
      }
    } else {
      LoggerFactory.warning(
          '❌ No hay usuario autenticado para sincronizar ${movie.title}');
    }

    LoggerFactory.info(
        '🏁 AGREGAR A WATCHLIST completado para: ${movie.title}');
  }

  /// Remover película de watchlist
  Future<void> removeFromWatchlist(int movieId) async {
    LoggerFactory.info(
        '🗑️ REMOVER DE WATCHLIST llamado para movieId: $movieId');

    try {
      // 1. Actualizar localmente primero
      LoggerFactory.info('💾 Removiendo de watchlist localmente: $movieId');
      await _datasource.removeFromWatchlist(movieId);
      LoggerFactory.info('✅ Removido de watchlist localmente: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ Error al remover de watchlist localmente: $e');
      throw LocalStorageException('Error al remover de watchlist: $e');
    }

    // 2. Agregar operación a la cola de sincronización
    final userId = getCurrentUserId();
    if (userId != null) {
      // Marcar para sincronización (la sincronización se maneja automáticamente por el sistema de BaseHybridRepository)

      LoggerFactory.info(
          '📤 Operación de sincronización creada para remover $movieId');

      // 3. Intentar sincronización inmediata si hay conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        LoggerFactory.info(
            '🌐 Conectividad disponible, sincronizando eliminación de $movieId...');
        await _syncRemoval(movieId);
      }
    }

    LoggerFactory.info('🏁 REMOVER DE WATCHLIST completado para: $movieId');
  }

  /// Actualizar prioridad de película en watchlist
  Future<void> updateWatchlistPriority(
      int movieId, WatchlistPriority priority) async {
    LoggerFactory.info(
        '🔄 ACTUALIZAR PRIORIDAD llamado para movieId: $movieId, nueva prioridad: ${priority.displayName}');

    try {
      // 1. Actualizar localmente primero
      await _datasource.updateWatchlistPriority(movieId, priority);
      LoggerFactory.info('✅ Prioridad actualizada localmente para: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ Error al actualizar prioridad localmente: $e');
      throw LocalStorageException('Error al actualizar prioridad: $e');
    }

    // 2. Sincronizar si hay usuario autenticado
    final userId = getCurrentUserId();
    if (userId != null) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        LoggerFactory.info(
            '🌐 Sincronizando actualización de prioridad para $movieId...');
        // Obtener la película actualizada y sincronizar
        final watchlistMovie = await _datasource.getWatchlistMovie(movieId);
        if (watchlistMovie != null) {
          await _syncUpdatePriority(watchlistMovie);
        }
      }
    }

    LoggerFactory.info('🏁 ACTUALIZAR PRIORIDAD completado para: $movieId');
  }

  /// Verificar si una película está en watchlist
  Future<bool> isMovieInWatchlist(int movieId) async {
    try {
      return await _datasource.isMovieInWatchlist(movieId);
    } catch (e) {
      LoggerFactory.error(
          '❌ Error al verificar si película está en watchlist: $e');
      return false;
    }
  }

  /// Obtener película específica de watchlist
  Future<WatchlistMovie?> getWatchlistMovie(int movieId) async {
    try {
      return await _datasource.getWatchlistMovie(movieId);
    } catch (e) {
      LoggerFactory.error('❌ Error al obtener película de watchlist: $e');
      return null;
    }
  }

  /// Cargar películas de watchlist con filtros
  Future<List<WatchlistMovie>> loadWatchlistMovies({
    int limit = 10,
    int offset = 0,
    WatchlistPriority? priority,
  }) async {
    try {
      return await _datasource.loadWatchlistMovies(
        limit: limit,
        offset: offset,
        priority: priority,
      );
    } catch (e) {
      LoggerFactory.error('❌ Error al cargar películas de watchlist: $e');
      return [];
    }
  }

  /// Obtener conteo total de watchlist
  Future<int> getWatchlistCount() async {
    try {
      return await _datasource.getWatchlistCount();
    } catch (e) {
      LoggerFactory.error('❌ Error al obtener conteo de watchlist: $e');
      return 0;
    }
  }

  /// Obtiene todas las películas de la watchlist
  Future<List<WatchlistMovie>> getAllWatchlistMovies() async {
    try {
      return await _datasource.getAllWatchlistMovies();
    } catch (e) {
      LoggerFactory.error(
          '❌ Error al obtener todas las películas de watchlist: $e');
      return [];
    }
  }

  // Sincronizar un elemento individual
  Future<void> _syncSingleItem(Movie movie,
      {required WatchlistPriority priority}) async {
    LoggerFactory.info(
        '🔄 Iniciando sincronización individual de: ${movie.title}');

    final userId = getCurrentUserId();
    if (userId == null) {
      LoggerFactory.warning(
          '❌ No hay usuario autenticado para sincronizar ${movie.title}');
      return;
    }

    try {
      LoggerFactory.info('⬆️ Agregando ${movie.title} a Supabase...');

      await supabase.from('user_watchlist').upsert({
        'id': _uuid.v4(),
        'user_id': userId,
        'movie_id': movie.id,
        'movie_title': movie.title,
        'movie_poster_path': movie.posterPath,
        'movie_backdrop_path': movie.backdropPath,
        'movie_overview': movie.overview,
        'movie_release_date':
            movie.releaseDate.toIso8601String().split('T')[0], // Solo fecha
        'movie_vote_average': movie.voteAverage,
        'priority': priority.value,
        'added_at': DateTime.now().toIso8601String(),
        'last_modified_at': DateTime.now().toIso8601String(),
        'deleted_at': null,
      }, onConflict: 'user_id,movie_id');

      LoggerFactory.info('✅ ${movie.title} agregado a Supabase');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }

    LoggerFactory.info(
        '✅ Sincronización individual completada para ${movie.title}');
  }

  // Sincronizar eliminación
  Future<void> _syncRemoval(int movieId) async {
    final userId = getCurrentUserId();
    if (userId == null) return;

    try {
      // Soft delete en lugar de hard delete
      await supabase
          .from('user_watchlist')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'last_modified_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('movie_id', movieId);

      LoggerFactory.info(
          '✅ Película $movieId marcada como eliminada en Supabase');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  // Sincronizar actualización de prioridad
  Future<void> _syncUpdatePriority(WatchlistMovie movie) async {
    final userId = getCurrentUserId();
    if (userId == null) return;

    try {
      await supabase
          .from('user_watchlist')
          .update({
            'priority': movie.priority.value,
            'last_modified_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('movie_id', movie.movieId);

      LoggerFactory.info(
          '✅ Prioridad de ${movie.movieTitle} actualizada en Supabase');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  // Implementación de métodos de SyncableRepository
  @override
  Future<void> syncWithSupabase() async {
    LoggerFactory.info('🔄 Iniciando sincronización completa de watchlist...');
    final userId = getCurrentUserId();
    if (userId == null) {
      LoggerFactory.warning(
          '❌ No hay usuario autenticado para sincronizar watchlist');
      return;
    }

    try {
      // Usar el método de sincronización genérico de la clase base
      await syncWithSupabase();
      LoggerFactory.info('✅ Sincronización completa de watchlist completada');
    } on SyncException catch (e) {
      LoggerFactory.error(
          '❌ Error de sincronización en watchlist: ${e.message}');
      // No relanzar para no interrumpir la app, pero se podría manejar diferente
    } catch (e) {
      LoggerFactory.error(
          '❌ Error inesperado en sincronización de watchlist: $e');
      rethrow; // Relanzar errores inesperados
    }
  }

  @override
  Future<List<SyncableWatchlistMovie>> getLocalData() async {
    try {
      LoggerFactory.info('🔍 Obteniendo watchlist local...');
      final moviesList = await _datasource.getAllWatchlistMovies();
      LoggerFactory.info(
          '🔍 Datasource retornó: ${moviesList.length} películas en watchlist');

      final userId = getCurrentUserId();
      if (userId == null) {
        LoggerFactory.warning(
            '❌ No hay usuario para obtener datos locales de watchlist');
        return [];
      }

      final localWatchlist = moviesList
          .map((movie) => SyncableWatchlistMovie.fromWatchlistMovie(
                movie,
                userId,
              ))
          .toList();

      LoggerFactory.info(
          '📱 Watchlist local encontrada: ${localWatchlist.length}');
      return localWatchlist;
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo watchlist local: $e');
      throw LocalStorageException(
          'Error al obtener los datos locales de watchlist: $e');
    }
  }

  @override
  Future<List<SyncableWatchlistMovie>> getRemoteData() async {
    final userId = getCurrentUserId();
    if (userId == null) {
      LoggerFactory.warning(
          '❌ No hay usuario para obtener datos remotos de watchlist');
      return [];
    }

    try {
      await checkOnline();
      LoggerFactory.info(
          '☁️ Obteniendo watchlist remota para usuario: $userId');

      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null);

      final remoteWatchlist =
          (response as List).map((data) => mapFromSupabase(data)).toList();
      LoggerFactory.info(
          '☁️ Watchlist remota encontrada: ${remoteWatchlist.length}');

      return remoteWatchlist;
    } on PostgrestException catch (e) {
      LoggerFactory.error(
          '❌ Error PostgreSQL obteniendo watchlist remota: ${e.message} (${e.code})');
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo watchlist remota: $e');
      throw SupabaseSyncException('Error obteniendo watchlist remota: $e');
    }
  }

  @override
  Future<void> upload(List<SyncableWatchlistMovie> items) async {
    LoggerFactory.info(
        '⬆️ UPLOAD iniciado para ${items.length} items de watchlist');
    if (items.isEmpty) {
      return;
    }

    for (final item in items) {
      try {
        await supabase
            .from(tableName)
            .upsert(mapToSupabase(item), onConflict: 'user_id,movie_id');
      } on PostgrestException catch (e) {
        throw SupabaseSyncException(
            'Error subiendo item de watchlist ${item.movieTitle}: ${e.message}',
            code: e.code);
      } catch (e) {
        throw SupabaseSyncException(
            'Error subiendo item de watchlist ${item.movieTitle}: $e');
      }
    }
    LoggerFactory.info(
        '🎉 Upload de ${items.length} items de watchlist completado');
  }

  @override
  Future<void> download(List<SyncableWatchlistMovie> items) async {
    LoggerFactory.info(
        '⬇️ DOWNLOAD iniciado para ${items.length} items de watchlist');
    if (items.isEmpty) {
      return;
    }
    for (final item in items) {
      try {
        final movie = Movie(
          id: item.movieId,
          title: item.movieTitle,
          overview: item.movieOverview ?? '',
          posterPath: item.moviePosterPath ?? '',
          backdropPath: item.movieBackdropPath ?? '',
          releaseDate: item.movieReleaseDate ?? DateTime(1900),
          voteAverage: item.movieVoteAverage ?? 0.0,
          genreIds: const [],
          adult: false,
          originalLanguage: 'en',
          originalTitle: item.movieTitle,
          popularity: 0.0,
          video: false,
          voteCount: 0,
        );
        await _datasource.addToWatchlist(movie, item.priority);
      } catch (e) {
        throw LocalStorageException(
            'Error descargando item de watchlist ${item.id}: $e');
      }
    }
    LoggerFactory.info(
        '🎉 Download de ${items.length} items de watchlist completado');
  }

  @override
  Future<void> resolveConflicts(List<SyncableWatchlistMovie> local,
      List<SyncableWatchlistMovie> remote) async {
    LoggerFactory.info(
        '🔧 Iniciando resolución de conflictos para watchlist: ${local.length} locales y ${remote.length} remotos');

    final conflicts = _conflictDetector.detectBatchConflicts(local, remote);
    LoggerFactory.info(
        '⚠️ Conflictos de watchlist detectados: ${conflicts.length}');

    for (final conflict in conflicts) {
      try {
        final resolution = _conflictResolver.resolveConflict(
          conflict.localItem,
          conflict.remoteItem,
          conflict.type,
        );

        final resolvedItem = resolution.resolvedItem;
        LoggerFactory.info(
            '✅ Conflicto de watchlist resuelto: ${resolution.resolution}');

        // Aplicar resolución
        if (resolvedItem.isDeleted) {
          await _datasource.removeFromWatchlist(resolvedItem.movieId);
          await _syncRemoval(resolvedItem.movieId);
        } else {
          final movie = Movie(
            id: resolvedItem.movieId,
            title: resolvedItem.movieTitle,
            overview: resolvedItem.movieOverview ?? '',
            posterPath: resolvedItem.moviePosterPath ?? '',
            backdropPath: resolvedItem.movieBackdropPath ?? '',
            releaseDate: resolvedItem.movieReleaseDate ?? DateTime(1900),
            voteAverage: resolvedItem.movieVoteAverage ?? 0.0,
            genreIds: const [],
            adult: false,
            originalLanguage: 'en',
            originalTitle: resolvedItem.movieTitle,
            popularity: 0.0,
            video: false,
            voteCount: 0,
          );
          await _datasource.addToWatchlist(movie, resolvedItem.priority);
          await upload([resolvedItem]);
        }
      } catch (e) {
        LoggerFactory.error(
            '❌ Error resolviendo conflicto de watchlist para ${conflict.localItem.id}: $e');
        // Considerar una estrategia de fallback o reintento
      }
    }
  }


  @override
  Future<bool> hasPendingSync() async {
    return !await syncQueue.isEmpty;
  }

  @override
  Future<List<String>> getPendingSyncItems() async {
    return await syncQueue.getItems();
  }


  // Implementación de métodos abstractos de BaseHybridRepository
  @override
  Future<void> clearRepositoryData() async {
    await _datasource.clearAll();
  }

  @override
  String get tableName => 'user_watchlist';

  @override
  SyncableWatchlistMovie mapFromSupabase(Map<String, dynamic> data) {
    return SyncableWatchlistMovie(
      id: data['id'] as String? ?? '',
      userId: data['user_id'] as String? ?? '',
      movieId: data['movie_id'] as int? ?? 0,
      movieTitle: data['movie_title'] as String? ?? '',
      moviePosterPath: data['movie_poster_path'] as String?,
      movieBackdropPath: data['movie_backdrop_path'] as String?,
      movieOverview: data['movie_overview'] as String?,
      movieReleaseDate: data['movie_release_date'] != null
          ? DateTime.tryParse(data['movie_release_date'] as String) ??
              DateTime(1900)
          : DateTime(1900),
      movieVoteAverage: (data['movie_vote_average'] as num?)?.toDouble() ?? 0.0,
      priority:
          WatchlistPriority.fromValue(data['priority'] as String? ?? 'medium'),
      addedAt: data['added_at'] != null
          ? DateTime.tryParse(data['added_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: data['last_modified_at'] != null
          ? DateTime.tryParse(data['last_modified_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      deletedAt: data['deleted_at'] != null
          ? DateTime.tryParse(data['deleted_at'] as String)
          : null,
    );
  }

  @override
  Map<String, dynamic> mapToSupabase(SyncableWatchlistMovie item) {
    return {
      'id': item.id,
      'user_id': item.userId,
      'movie_id': item.movieId,
      'movie_title': item.movieTitle,
      'movie_poster_path': item.moviePosterPath,
      'movie_backdrop_path': item.movieBackdropPath,
      'movie_overview': item.movieOverview,
      'movie_release_date':
          item.movieReleaseDate?.toIso8601String().split('T')[0] ??
              '1900-01-01',
      'movie_vote_average': item.movieVoteAverage,
      'priority': item.priority.value,
      'added_at': item.addedAt.toIso8601String(),
      'is_deleted': item.deletedAt != null,
      'last_modified_at': item.updatedAt.toIso8601String(),
      'deleted_at': item.deletedAt?.toIso8601String(),
    };
  }
}
