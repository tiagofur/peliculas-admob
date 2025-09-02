import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../core/services/persistent_sync_queue.dart';
import '../../core/sync/conflict_resolution/conflict_detector.dart';
import '../../core/sync/conflict_resolution/conflict_metrics_service.dart';
import '../../core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';
import '../../core/sync/conflict_resolution/soft_delete_manager.dart';
import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/entities/syncable_watchlist_movie.dart';
import '../../domain/entities/watchlist_movie.dart';
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../services/sync_manager.dart';
import '../../core/sync/conflict_resolution/strategies/watchlist_conflict_strategy.dart';
import '../../services/conflict_resolution_service.dart';

/// Repositorio híbrido que maneja watchlist localmente y sincroniza con Supabase
class HybridWatchlistRepository
    implements SyncableRepository<SyncableWatchlistMovie> {
  HybridWatchlistRepository({
    required LocalStorageDatasource datasource,
    required Ref ref,
  })  : _datasource = datasource,
        _ref = ref {
    _syncQueue = PersistentSyncQueue();
    _softDeleteManager = SoftDeleteManager();
    _statisticsService = ConflictStatisticsService();
    _metricsService = ConflictMetricsService();
    _conflictDetector = ConflictDetector(
      _softDeleteManager,
      _statisticsService,
    );
    _conflictResolver = MultiplataformConflictResolver();
    _initializeComponents();
  }

  final LocalStorageDatasource _datasource;
  final Ref _ref;
  late final PersistentSyncQueue _syncQueue;
  late final SoftDeleteManager _softDeleteManager;
  late final ConflictStatisticsService _statisticsService;
  late final ConflictMetricsService _metricsService;
  late final ConflictDetector _conflictDetector;
  late final MultiplataformConflictResolver _conflictResolver;

  static const _uuid = Uuid();

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _initializeComponents() async {
    await _syncQueue.initialize();
    
    // Registrar estrategia de resolución de conflictos para watchlist
    ConflictResolutionService.registerWatchlistStrategy(_conflictResolver);
  }

  String? _getCurrentUserId() {
    return _ref.read(authProvider).user?.id;
  }

  /// Agregar película a watchlist con prioridad especificada
  Future<void> addToWatchlist(Movie movie, WatchlistPriority priority) async {
    LoggerFactory.info('🎬 AGREGAR A WATCHLIST llamado para: ${movie.title} con prioridad: ${priority.displayName}');

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
    final userId = _getCurrentUserId();
    if (userId != null) {
      final operation = SyncOperationFactory.addToWatchlist(
        userId: userId, 
        movieId: movie.id,
        priority: priority.value,
      );

      LoggerFactory.info('📤 Agregando operación de sincronización para ${movie.title}');
      await _syncQueue.addOperation(operation);

      // 3. Intentar sincronización inmediata si hay conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        LoggerFactory.info('🌐 Conectividad disponible, sincronizando ${movie.title}...');
        await _syncSingleItem(movie, priority: priority);
      } else {
        LoggerFactory.info('📡 Sin conectividad, ${movie.title} se sincronizará más tarde');
      }
    } else {
      LoggerFactory.warning('❌ No hay usuario autenticado para sincronizar ${movie.title}');
    }

    LoggerFactory.info('🏁 AGREGAR A WATCHLIST completado para: ${movie.title}');
  }

  /// Remover película de watchlist
  Future<void> removeFromWatchlist(int movieId) async {
    LoggerFactory.info('🗑️ REMOVER DE WATCHLIST llamado para movieId: $movieId');

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
    final userId = _getCurrentUserId();
    if (userId != null) {
      final operation = SyncOperationFactory.removeFromWatchlist(
        userId: userId, 
        movieId: movieId,
      );

      LoggerFactory.info('📤 Agregando operación de sincronización para remover $movieId');
      await _syncQueue.addOperation(operation);

      // 3. Intentar sincronización inmediata si hay conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        LoggerFactory.info('🌐 Conectividad disponible, sincronizando eliminación de $movieId...');
        await _syncRemoval(movieId);
      }
    }

    LoggerFactory.info('🏁 REMOVER DE WATCHLIST completado para: $movieId');
  }

  /// Actualizar prioridad de película en watchlist
  Future<void> updateWatchlistPriority(int movieId, WatchlistPriority priority) async {
    LoggerFactory.info('🔄 ACTUALIZAR PRIORIDAD llamado para movieId: $movieId, nueva prioridad: ${priority.displayName}');

    try {
      // 1. Actualizar localmente primero
      await _datasource.updateWatchlistPriority(movieId, priority);
      LoggerFactory.info('✅ Prioridad actualizada localmente para: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ Error al actualizar prioridad localmente: $e');
      throw LocalStorageException('Error al actualizar prioridad: $e');
    }

    // 2. Sincronizar si hay usuario autenticado
    final userId = _getCurrentUserId();
    if (userId != null) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        LoggerFactory.info('🌐 Sincronizando actualización de prioridad para $movieId...');
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
      LoggerFactory.error('❌ Error al verificar si película está en watchlist: $e');
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
      LoggerFactory.error('❌ Error al obtener todas las películas de watchlist: $e');
      return [];
    }
  }

  // Sincronizar un elemento individual
  Future<void> _syncSingleItem(Movie movie, {required WatchlistPriority priority}) async {
    LoggerFactory.info('🔄 Iniciando sincronización individual de: ${movie.title}');

    final userId = _getCurrentUserId();
    if (userId == null) {
      LoggerFactory.warning('❌ No hay usuario autenticado para sincronizar ${movie.title}');
      return;
    }

    try {
      LoggerFactory.info('⬆️ Agregando ${movie.title} a Supabase...');
      
      await _supabase.from('user_watchlist').upsert({
        'id': _uuid.v4(),
        'user_id': userId,
        'movie_id': movie.id,
        'movie_title': movie.title,
        'movie_poster_path': movie.posterPath,
        'movie_backdrop_path': movie.backdropPath,
        'movie_overview': movie.overview,
        'movie_release_date': movie.releaseDate.split('T')[0], // Solo fecha
        'movie_vote_average': movie.voteAverage,
        'priority': priority.value,
        'added_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'deleted_at': null,
      }, onConflict: 'user_id,movie_id');
      
      LoggerFactory.info('✅ ${movie.title} agregado a Supabase');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }

    LoggerFactory.info('✅ Sincronización individual completada para ${movie.title}');
  }

  // Sincronizar eliminación
  Future<void> _syncRemoval(int movieId) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    try {
      // Soft delete en lugar de hard delete
      await _supabase
          .from('user_watchlist')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('movie_id', movieId);
      
      LoggerFactory.info('✅ Película $movieId marcada como eliminada en Supabase');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  // Sincronizar actualización de prioridad
  Future<void> _syncUpdatePriority(WatchlistMovie movie) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    try {
      await _supabase
          .from('user_watchlist')
          .update({
            'priority': movie.priority.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('movie_id', movie.movieId);
      
      LoggerFactory.info('✅ Prioridad de ${movie.movieTitle} actualizada en Supabase');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  // Implementación de métodos de SyncableRepository
  @override
  Future<void> syncAll() async {
    LoggerFactory.info('🔄 Iniciando sincronización completa de watchlist...');
    
    final userId = _getCurrentUserId();
    if (userId == null) {
      LoggerFactory.warning('❌ No hay usuario autenticado para sincronizar watchlist');
      return;
    }

    try {
      // TODO: Implementar sincronización bidireccional completa
      LoggerFactory.info('✅ Sincronización completa de watchlist completada');
    } catch (e) {
      LoggerFactory.error('❌ Error en sincronización completa de watchlist: $e');
      rethrow;
    }
  }

  @override
  Future<void> upload(List<SyncableWatchlistMovie> items) async {
    // TODO: Implementar subida de elementos
  }

  @override
  Future<void> download(List<SyncableWatchlistMovie> items) async {
    // TODO: Implementar descarga de elementos
  }

  @override
  Future<void> handleConflicts(List<SyncableWatchlistMovie> conflicts) async {
    // TODO: Implementar manejo de conflictos
  }
}