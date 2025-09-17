import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_favorite.dart';
import '../../infrastructure/datasources/favorite_movies_hive_datasource.dart';
import '../logging/logger_factory.dart';

/// Servicio de sincronización silenciosa de favoritos que:
/// - Se ejecuta en segundo plano sin bloquear la UI
/// - Actualiza progresivamente la UI conforme va sincronizando
/// - Permite interacción del usuario mientras sincroniza
class SilentFavoritesSyncService {
  SilentFavoritesSyncService._internal();

  static final SilentFavoritesSyncService _instance =
      SilentFavoritesSyncService._internal();
  static SilentFavoritesSyncService get instance => _instance;

  final FavoriteMoviesHiveDatasource _localDatasource =
      FavoriteMoviesHiveDatasource();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream para notificar cambios progresivos
  final StreamController<SyncProgressUpdate> _syncProgressController =
      StreamController<SyncProgressUpdate>.broadcast();

  Stream<SyncProgressUpdate> get syncProgress => _syncProgressController.stream;

  bool _isCurrentlySyncing = false;
  String? _currentUserId;

  /// Inicia la sincronización silenciosa de favoritos
  Future<void> startSilentSync(String userId) async {
    if (_isCurrentlySyncing) {
      LoggerFactory.info('🔄 Silent sync already in progress, skipping...');
      return;
    }

    _currentUserId = userId;
    _isCurrentlySyncing = true;

    LoggerFactory.info('🔄 Starting silent favorites sync for user: $userId');
    _notifyProgress(
        SyncProgressType.started, 'Iniciando sincronización silenciosa...');

    try {
      await _performSilentSync(userId);
    } catch (e) {
      LoggerFactory.error('❌ Silent sync failed: $e');
      _notifyProgress(SyncProgressType.error, 'Error en sincronización: $e');
    } finally {
      _isCurrentlySyncing = false;
      _notifyProgress(SyncProgressType.completed, 'Sincronización completada');
    }
  }

  /// Realiza la sincronización en lotes pequeños
  Future<void> _performSilentSync(String userId) async {
    try {
      // 1. Obtener favoritos remotos por lotes
      final remoteFavorites = await _fetchRemoteFavoritesBatches(userId);

      if (remoteFavorites.isEmpty) {
        LoggerFactory.info('📱 No remote favorites found');
        _notifyProgress(SyncProgressType.noData, 'No hay favoritos remotos');
        return;
      }

      LoggerFactory.info(
          '📥 Found ${remoteFavorites.length} remote favorites to sync');

      // 2. Sincronizar de uno en uno para no bloquear UI
      for (int i = 0; i < remoteFavorites.length; i++) {
        if (!_isCurrentlySyncing) break; // Allow cancellation

        final syncableFavorite = remoteFavorites[i];
        await _syncSingleFavorite(
            syncableFavorite, i + 1, remoteFavorites.length);

        // Small delay to prevent UI blocking
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      LoggerFactory.error('❌ Error in silent sync: $e');
      rethrow;
    }
  }

  /// Obtiene favoritos remotos en lotes pequeños
  Future<List<SyncableFavorite>> _fetchRemoteFavoritesBatches(
      String userId) async {
    const int batchSize = 10; // Lotes pequeños
    final List<SyncableFavorite> allFavorites = [];
    int offset = 0;
    bool hasMore = true;

    while (hasMore && _isCurrentlySyncing) {
      try {
        _notifyProgress(SyncProgressType.fetching,
            'Obteniendo favoritos remotos (${allFavorites.length})...');

        final response = await _supabase
            .from('user_favorites')
            .select()
            .eq('user_id', userId)
            .order('last_modified_at', ascending: false)
            .range(offset, offset + batchSize - 1);

        final List<dynamic> data = response as List<dynamic>;

        if (data.isEmpty) {
          hasMore = false;
          break;
        }

        final favorites = data
            .map((item) =>
                SyncableFavorite.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        allFavorites.addAll(favorites);
        offset += batchSize;

        // Si obtuvimos menos elementos que el tamaño del lote, ya no hay más
        hasMore = data.length == batchSize;

        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        LoggerFactory.error('❌ Error fetching remote favorites batch: $e');
        hasMore = false;
      }
    }

    return allFavorites;
  }

  /// Sincroniza un solo favorito y notifica progreso
  Future<void> _syncSingleFavorite(
      SyncableFavorite syncableFavorite, int current, int total) async {
    try {
      // Convertir SyncableFavorite a Movie para el datasource local
      final movie = _syncableFavoriteToMovie(syncableFavorite);

      // Verificar si ya existe localmente
      final isAlreadyLocal = await _localDatasource.isMovieFavorite(movie.id);

      if (!isAlreadyLocal) {
        // Agregar a favoritos locales
        await _localDatasource.toggleFavorite(movie);

        LoggerFactory.info(
            '✅ Synced favorite ($current/$total): ${movie.title}');

        _notifyProgress(
          SyncProgressType.itemSynced,
          'Sincronizado: ${movie.title}',
          syncedMovie: movie,
          progress: current / total,
        );
      } else {
        LoggerFactory.debug(
            '⏭️ Favorite already exists locally ($current/$total): ${movie.title}');

        _notifyProgress(
          SyncProgressType.itemSkipped,
          'Ya existe: ${movie.title}',
          progress: current / total,
        );
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ Error syncing favorite ${syncableFavorite.movieTitle}: $e');
      _notifyProgress(
        SyncProgressType.itemError,
        'Error: ${syncableFavorite.movieTitle}',
      );
    }
  }

  /// Convierte un SyncableFavorite a Movie
  Movie _syncableFavoriteToMovie(SyncableFavorite syncableFavorite) {
    return Movie(
      adult: false,
      backdropPath: syncableFavorite.movieBackdropPath ?? '',
      genreIds: [],
      id: syncableFavorite.movieId,
      originalLanguage: 'en', // No disponible en SyncableFavorite
      originalTitle: syncableFavorite.movieTitle, // Usar título como fallback
      overview: syncableFavorite.movieOverview ?? '',
      popularity: 0.0, // No disponible en SyncableFavorite
      posterPath: syncableFavorite.moviePosterPath ?? '',
      releaseDate: syncableFavorite.movieReleaseDate ?? DateTime.now(),
      title: syncableFavorite.movieTitle,
      video: false,
      voteAverage: syncableFavorite.movieVoteAverage ?? 0.0,
      voteCount: 0, // No disponible en SyncableFavorite
    );
  }

  /// Notifica progreso a los listeners
  void _notifyProgress(
    SyncProgressType type,
    String message, {
    Movie? syncedMovie,
    double? progress,
  }) {
    final update = SyncProgressUpdate(
      type: type,
      message: message,
      syncedMovie: syncedMovie,
      progress: progress,
      timestamp: DateTime.now(),
    );

    if (!_syncProgressController.isClosed) {
      _syncProgressController.add(update);
    }

    if (kDebugMode) {
      LoggerFactory.info('🔄 Sync Progress: ${type.name} - $message');
    }
  }

  /// Detiene la sincronización actual
  void stopSync() {
    if (_isCurrentlySyncing) {
      _isCurrentlySyncing = false;
      LoggerFactory.info('🛑 Silent sync stopped by user');
      _notifyProgress(SyncProgressType.stopped, 'Sincronización detenida');
    }
  }

  /// Verifica si hay una sincronización en curso
  bool get isSyncing => _isCurrentlySyncing;

  /// Obtiene el ID del usuario actual
  String? get currentUserId => _currentUserId;

  /// Cierra el servicio
  void dispose() {
    _isCurrentlySyncing = false;
    if (!_syncProgressController.isClosed) {
      _syncProgressController.close();
    }
  }
}

/// Tipos de progreso de sincronización
enum SyncProgressType {
  started,
  fetching,
  itemSynced,
  itemSkipped,
  itemError,
  completed,
  stopped,
  error,
  noData,
}

/// Actualización de progreso de sincronización
class SyncProgressUpdate {
  SyncProgressUpdate({
    required this.type,
    required this.message,
    this.syncedMovie,
    this.progress,
    required this.timestamp,
  });

  final SyncProgressType type;
  final String message;
  final Movie? syncedMovie;
  final double? progress;
  final DateTime timestamp;

  @override
  String toString() {
    return 'SyncProgressUpdate(type: $type, message: $message, progress: $progress)';
  }
}
