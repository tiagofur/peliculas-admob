import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/trigger_free_watchlist_sync.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/watchlist_movie.dart';

/// Provider directo que evita completamente el repositorio híbrido
/// y solo usa TriggerFreeWatchlistSync para operaciones de Supabase
final directWatchlistMoviesProvider =
    StateNotifierProvider<DirectWatchlistNotifier, Map<int, WatchlistMovie>>(
        (ref) {
  return DirectWatchlistNotifier(
    onMovieAddedToWatchlist: (Movie movie) {
      // Opcional: trackear añadidos a watchlist para achievements
    },
  );
});

class DirectWatchlistNotifier extends StateNotifier<Map<int, WatchlistMovie>> {
  DirectWatchlistNotifier({
    required this.onMovieAddedToWatchlist,
  }) : super({}) {
    LoggerFactory.info(
        '📝 DirectWatchlistNotifier: Constructor llamado, inicialización diferida...');
    _initializeWithCurrentUser();
  }

  final Function(Movie movie) onMovieAddedToWatchlist;
  final TriggerFreeWatchlistSync _sync = TriggerFreeWatchlistSync.instance;
  static RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSubscription;
  String? _currentUserId;
  bool _isInitialized = false;

  void _initializeWithCurrentUser() {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        _currentUserId = currentUser.id;
        _isInitialized = true;
        // Use Future.microtask to avoid blocking the UI thread
        Future.microtask(() {
          _loadWatchlistFromSupabase();
          _setupRealtimeListeners();
        });
      }
      _listenToAuthChanges();
    } catch (e) {
      LoggerFactory.error('DirectWatchlist: Error initializing: $e');
      // Set safe state to prevent UI freeze
      if (mounted) {
        state = {};
      }
    }
  }

  void _listenToAuthChanges() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        if (!_isInitialized || _currentUserId != session.user.id) {
          _currentUserId = session.user.id;
          _isInitialized = true;
          _loadWatchlistFromSupabase();
          _setupRealtimeListeners();
        }
      } else {
        _isInitialized = false;
        _currentUserId = null;
        state = {};
        _unsubscribeFromRealtime();
      }
    });
  }

  Future<void> _loadWatchlistFromSupabase() async {
    if (!_isInitialized || _currentUserId == null) return;

    try {
      // Add timeout to prevent hanging
      final watchlistMovies = await _sync
          .getUserWatchlist(_currentUserId!)
          .timeout(const Duration(seconds: 10));
      final watchlistMap = {
        for (final movie in watchlistMovies) movie.movieId: movie
      };
      if (mounted) {
        state = watchlistMap;
      }
    } catch (e) {
      LoggerFactory.error('DirectWatchlist: Error cargando: $e');
      if (mounted) {
        state = {};
      }
    }
  }

  Future<void> toggleWatchlist(Movie movie,
      {WatchlistPriority priority = WatchlistPriority.normal}) async {
    final isInWatchlist = state.containsKey(movie.id);
    final optimisticState = Map<int, WatchlistMovie>.from(state);

    if (isInWatchlist) {
      optimisticState.remove(movie.id);
    } else {
      final watchlistMovie = _movieToWatchlistMovie(movie, priority);
      optimisticState[movie.id] = watchlistMovie;
    }
    state = optimisticState;

    if (_currentUserId == null) return;

    try {
      if (isInWatchlist) {
        await _sync.removeFromWatchlist(_currentUserId!, movie.id);
      } else {
        await _sync.addToWatchlist(_currentUserId!, movie, priority: priority);
        onMovieAddedToWatchlist(movie);
      }
    } catch (e) {
      LoggerFactory.error('DirectWatchlist: Error en toggle: $e');
      if (mounted) {
        _loadWatchlistFromSupabase();
      }
    }
  }

  Future<void> changePriority(
      int movieId, WatchlistPriority newPriority) async {
    if (_currentUserId == null) return;

    final currentMovie = state[movieId];
    if (currentMovie == null) return;

    final updatedMovie = currentMovie.copyWith(priority: newPriority);
    final optimisticState = {...state, movieId: updatedMovie};
    state = optimisticState;

    try {
      await _sync.changePriority(_currentUserId!, movieId, newPriority);
    } catch (e) {
      LoggerFactory.error('DirectWatchlist: Error cambiando prioridad: $e');
      if (mounted) {
        _loadWatchlistFromSupabase();
      }
    }
  }

  Future<void> refresh() async {
    await _loadWatchlistFromSupabase();
  }

  void _setupRealtimeListeners() {
    if (_realtimeChannel != null) return;

    try {
      // Use Future.microtask to avoid blocking the main thread
      Future.microtask(() async {
        try {
          _realtimeChannel = Supabase.instance.client
              .channel('public:user_watchlist_$_currentUserId')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'user_watchlist',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'user_id',
                  value: _currentUserId!,
                ),
                callback: _handleRealtimeEvent,
              );

          _realtimeChannel!.subscribe((status, [error]) {
            if (error != null) {
              LoggerFactory.error('🔴 DirectWatchlist: Error en canal: $error');
              // Don't crash on realtime errors, just log them
            } else if (status == RealtimeSubscribeStatus.subscribed) {
              LoggerFactory.info(
                  '✅ DirectWatchlist: Canal suscrito exitosamente!');
            }
          });
        } catch (e) {
          LoggerFactory.error(
              '❌ DirectWatchlist: Error configurando canal: $e');
          // Continue without realtime if it fails
        }
      });
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectWatchlist: Error configurando listeners: $e');
      // Continue without realtime if setup fails
    }
  }

  void _handleRealtimeEvent(PostgresChangePayload payload) {
    if (!mounted) return;
    LoggerFactory.info(
        '🔴 DirectWatchlist: Evento en tiempo real: ${payload.eventType}');
    _loadWatchlistFromSupabase();
  }

  WatchlistMovie _movieToWatchlistMovie(
      Movie movie, WatchlistPriority priority) {
    final now = DateTime.now();
    return WatchlistMovie(
      id: '',
      movieId: movie.id,
      movieTitle: movie.title,
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      priority: priority,
      addedAt: now,
      lastModifiedAt: now,
    );
  }

  void _unsubscribeFromRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _unsubscribeFromRealtime();
    super.dispose();
  }
}
