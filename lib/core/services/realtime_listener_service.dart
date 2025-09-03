import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/syncable_custom_list.dart';
import '../../domain/entities/syncable_favorite_movie.dart';
import '../../domain/entities/syncable_user_movie_rating.dart';
import '../../domain/entities/syncable_watched_movie.dart';
import '../../domain/entities/syncable_watchlist_movie.dart';
import '../../infrastructure/services/multiplatform_sync_manager.dart';
import '../config/supabase_config.dart';
import 'realtime_throttle_service.dart';

class RealtimeListenerService {
  factory RealtimeListenerService() => _instance;
  RealtimeListenerService._internal();
  static final RealtimeListenerService _instance =
      RealtimeListenerService._internal();

  final MultiplataformSyncManager _syncManager =
      MultiplataformSyncManager.instance;
  final RealtimeThrottleService _throttleService = RealtimeThrottleService();
  final Map<String, RealtimeChannel> _channels = {};

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _baseReconnectDelay = Duration(seconds: 2);

  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// Inicializa todos los listeners de tiempo real
  Future<void> initialize() async {
    try {
      _updateConnectionState(false); // connecting

      await _setupFavoritesListener();
      await _setupWatchedMoviesListener();
      await _setupCustomListsListener();
      await _setupWatchlistListener();
      await _setupRatingsListener();

      _updateConnectionState(true); // connected
      _reconnectAttempts = 0;

      developer.log('RealtimeListenerService initialized successfully',
          name: 'RealtimeService');
    } catch (e) {
      developer.log('Error initializing RealtimeListenerService: $e',
          name: 'RealtimeService');
      _updateConnectionState(false); // error
      _syncManager.handleRealtimeError(
        e.toString(),
        operation: 'initialize_realtime_listeners',
      );
      _scheduleReconnect();
    }
  }

  /// Configura el listener para la tabla favorites
  Future<void> _setupFavoritesListener() async {
    final channel = SupabaseConfig.client
        .channel('favorites_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'favorites',
          callback: (payload) => _handleFavoriteChange(payload),
        )
        .subscribe();

    _channels['favorites'] = channel;
    developer.log('Favorites listener configured', name: 'RealtimeService');
  }

  /// Configura el listener para la tabla watched_movies
  Future<void> _setupWatchedMoviesListener() async {
    final channel = SupabaseConfig.client
        .channel('watched_movies_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'watched_movies',
          callback: (payload) => _handleWatchedMovieChange(payload),
        )
        .subscribe();

    _channels['watched_movies'] = channel;
    developer.log('Watched movies listener configured',
        name: 'RealtimeService');
  }

  /// Configura el listener para la tabla custom_lists
  Future<void> _setupCustomListsListener() async {
    final channel = SupabaseConfig.client
        .channel('custom_lists_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'custom_lists',
          callback: (payload) => _handleCustomListChange(payload),
        )
        .subscribe();

    _channels['custom_lists'] = channel;
    developer.log('Custom lists listener configured', name: 'RealtimeService');
  }

  /// Configura el listener para la tabla user_watchlist
  Future<void> _setupWatchlistListener() async {
    final channel = SupabaseConfig.client
        .channel('watchlist_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_watchlist',
          callback: (payload) => _handleWatchlistChange(payload),
        )
        .subscribe();

    _channels['user_watchlist'] = channel;
    developer.log('Watchlist listener configured', name: 'RealtimeService');
  }

  /// Configura el listener para la tabla user_movie_ratings
  Future<void> _setupRatingsListener() async {
    final channel = SupabaseConfig.client
        .channel('ratings_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_movie_ratings',
          callback: (payload) => _handleRatingsChange(payload),
        )
        .subscribe();

    _channels['user_movie_ratings'] = channel;
    developer.log('Ratings listener configured', name: 'RealtimeService');
  }

  /// Maneja cambios en la tabla favorites
  void _handleFavoriteChange(PostgresChangePayload payload) {
    try {
      developer.log('Favorite change detected: ${payload.eventType}',
          name: 'RealtimeService');

      final eventKey = 'favorites_${payload.eventType.name}';

      _throttleService.smartThrottle(
        eventKey,
        () {
          switch (payload.eventType) {
            case PostgresChangeEvent.insert:
              final favorite =
                  SyncableFavoriteMovie.fromJson(payload.newRecord);
              _syncManager.handleRealtimeInsert('favorites', favorite.toJson());
              break;
            case PostgresChangeEvent.update:
              final favorite =
                  SyncableFavoriteMovie.fromJson(payload.newRecord);
              _syncManager.handleRealtimeUpdate('favorites', favorite.toJson());
              break;
            case PostgresChangeEvent.delete:
              final favoriteId = payload.oldRecord['id'];
              _syncManager.handleRealtimeDelete('favorites', favoriteId);
              break;
            case PostgresChangeEvent.all:
              // Caso para eventos combinados - no se maneja específicamente
              break;
          }
        },
        debounceDelay: const Duration(milliseconds: 300),
        throttleInterval: const Duration(seconds: 1),
        maxEvents: 3,
      );
    } catch (e) {
      developer.log('Error handling favorite change: $e',
          name: 'RealtimeService');
      _syncManager.handleRealtimeError(
        e.toString(),
        operation: 'handle_favorite_change',
        tableName: 'favorites',
      );
    }
  }

  /// Maneja cambios en la tabla watched_movies
  void _handleWatchedMovieChange(PostgresChangePayload payload) {
    try {
      developer.log('Watched movie change detected: ${payload.eventType}',
          name: 'RealtimeService');

      final eventKey = 'watched_movies_${payload.eventType.name}';

      _throttleService.smartThrottle(
        eventKey,
        () {
          switch (payload.eventType) {
            case PostgresChangeEvent.insert:
              final watchedMovie =
                  SyncableWatchedMovie.fromJson(payload.newRecord);
              _syncManager.handleRealtimeInsert(
                  'watched_movies', watchedMovie.toJson());
              break;
            case PostgresChangeEvent.update:
              final watchedMovie =
                  SyncableWatchedMovie.fromJson(payload.newRecord);
              _syncManager.handleRealtimeUpdate(
                  'watched_movies', watchedMovie.toJson());
              break;
            case PostgresChangeEvent.delete:
              final watchedMovieId = payload.oldRecord['id'];
              _syncManager.handleRealtimeDelete(
                  'watched_movies', watchedMovieId);
              break;
            case PostgresChangeEvent.all:
              // Caso para eventos combinados - no se maneja específicamente
              break;
          }
        },
        debounceDelay: const Duration(milliseconds: 300),
        throttleInterval: const Duration(seconds: 1),
        maxEvents: 3,
      );
    } catch (e) {
      developer.log('Error handling watched movie change: $e',
          name: 'RealtimeService');
      _syncManager.handleRealtimeError(
        e.toString(),
        operation: 'handle_watched_movie_change',
        tableName: 'watched_movies',
      );
    }
  }

  /// Maneja cambios en la tabla custom_lists
  void _handleCustomListChange(PostgresChangePayload payload) {
    try {
      developer.log('Custom list change detected: ${payload.eventType}',
          name: 'RealtimeService');

      final eventKey = 'custom_lists_${payload.eventType.name}';

      _throttleService.smartThrottle(
        eventKey,
        () {
          switch (payload.eventType) {
            case PostgresChangeEvent.insert:
              final customList = SyncableCustomList.fromJson(payload.newRecord);
              _syncManager.handleRealtimeInsert(
                  'custom_lists', customList.toJson());
              break;
            case PostgresChangeEvent.update:
              final customList = SyncableCustomList.fromJson(payload.newRecord);
              _syncManager.handleRealtimeUpdate(
                  'custom_lists', customList.toJson());
              break;
            case PostgresChangeEvent.delete:
              final customListId = payload.oldRecord['id'];
              _syncManager.handleRealtimeDelete('custom_lists', customListId);
              break;
            case PostgresChangeEvent.all:
              // Caso para eventos combinados - no se maneja específicamente
              break;
          }
        },
        debounceDelay: const Duration(milliseconds: 300),
        throttleInterval: const Duration(seconds: 1),
        maxEvents: 3,
      );
    } catch (e) {
      developer.log('Error handling custom list change: $e',
          name: 'RealtimeService');
      _syncManager.handleRealtimeError(
        e.toString(),
        operation: 'handle_custom_list_change',
        tableName: 'custom_lists',
      );
    }
  }

  /// Maneja cambios en la tabla user_watchlist
  void _handleWatchlistChange(PostgresChangePayload payload) {
    try {
      developer.log('Watchlist change detected: ${payload.eventType}',
          name: 'RealtimeService');

      final eventKey = 'user_watchlist_${payload.eventType.name}';

      _throttleService.smartThrottle(
        eventKey,
        () {
          switch (payload.eventType) {
            case PostgresChangeEvent.insert:
              final watchlistMovie =
                  SyncableWatchlistMovie.fromSupabase(payload.newRecord);
              _syncManager.handleRealtimeInsert(
                  'user_watchlist', watchlistMovie.toSupabase());
              break;
            case PostgresChangeEvent.update:
              final watchlistMovie =
                  SyncableWatchlistMovie.fromSupabase(payload.newRecord);
              _syncManager.handleRealtimeUpdate(
                  'user_watchlist', watchlistMovie.toSupabase());
              break;
            case PostgresChangeEvent.delete:
              final watchlistMovieId = payload.oldRecord['id'];
              _syncManager.handleRealtimeDelete(
                  'user_watchlist', watchlistMovieId);
              break;
            case PostgresChangeEvent.all:
              // Caso para eventos combinados - no se maneja específicamente
              break;
          }
        },
        debounceDelay: const Duration(milliseconds: 300),
        throttleInterval: const Duration(seconds: 1),
        maxEvents: 3,
      );
    } catch (e) {
      developer.log('Error handling watchlist change: $e',
          name: 'RealtimeService');
      _syncManager.handleRealtimeError(
        e.toString(),
        operation: 'handle_watchlist_change',
        tableName: 'user_watchlist',
      );
    }
  }

  /// Maneja cambios en la tabla user_movie_ratings
  void _handleRatingsChange(PostgresChangePayload payload) {
    try {
      developer.log('Rating change detected: ${payload.eventType}',
          name: 'RealtimeService');

      final eventKey = 'user_movie_ratings_${payload.eventType.name}';

      _throttleService.smartThrottle(
        eventKey,
        () {
          switch (payload.eventType) {
            case PostgresChangeEvent.insert:
              final rating =
                  SyncableUserMovieRating.fromSupabase(payload.newRecord);
              _syncManager.handleRealtimeInsert(
                  'user_movie_ratings', rating.toSupabase());
              break;
            case PostgresChangeEvent.update:
              final rating =
                  SyncableUserMovieRating.fromSupabase(payload.newRecord);
              _syncManager.handleRealtimeUpdate(
                  'user_movie_ratings', rating.toSupabase());
              break;
            case PostgresChangeEvent.delete:
              final ratingId = payload.oldRecord['id'];
              _syncManager.handleRealtimeDelete('user_movie_ratings', ratingId);
              break;
            case PostgresChangeEvent.all:
              // Caso para eventos combinados - no se maneja específicamente
              break;
          }
        },
        debounceDelay: const Duration(milliseconds: 300),
        throttleInterval: const Duration(seconds: 1),
        maxEvents: 3,
      );
    } catch (e) {
      developer.log('Error handling rating change: $e',
          name: 'RealtimeService');
      _syncManager.handleRealtimeError(
        e.toString(),
        operation: 'handle_rating_change',
        tableName: 'user_movie_ratings',
      );
    }
  }

  /// Actualiza el estado de conexión
  void _updateConnectionState(bool isConnected) {
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      developer.log(
          'Connection state changed to: ${isConnected ? "connected" : "disconnected"}',
          name: 'RealtimeService');
    }
  }

  /// Programa un intento de reconexión con backoff exponencial
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      developer.log('Max reconnect attempts reached', name: 'RealtimeService');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(
      seconds: _baseReconnectDelay.inSeconds * (1 << (_reconnectAttempts - 1)),
    );

    developer.log(
        'Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s',
        name: 'RealtimeService');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      initialize();
    });
  }

  /// Desconecta todos los listeners
  Future<void> disconnect() async {
    try {
      _reconnectTimer?.cancel();

      for (final channel in _channels.values) {
        await channel.unsubscribe();
      }

      _channels.clear();
      _updateConnectionState(false);

      developer.log('RealtimeListenerService disconnected',
          name: 'RealtimeService');
    } catch (e) {
      developer.log('Error disconnecting RealtimeListenerService: $e',
          name: 'RealtimeService');
      _syncManager.handleRealtimeError(
        e.toString(),
        operation: 'disconnect_realtime_listeners',
      );
    }
  }

  /// Reconecta todos los listeners
  Future<void> reconnect() async {
    await disconnect();
    _reconnectAttempts = 0;
    await initialize();
  }

  /// Libera recursos
  void dispose() {
    disconnect();
  }
}
