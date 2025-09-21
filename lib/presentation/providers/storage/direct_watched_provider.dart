import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/trigger_free_watched_sync.dart';
import '../../../domain/entities/movie.dart';
import '../achievements/achievements_provider.dart';

/// Provider directo que evita completamente el repositorio híbrido
/// y solo usa TriggerFreeWatchedSync para operaciones de Supabase
final directWatchedMoviesProvider =
    StateNotifierProvider<DirectWatchedNotifier, Map<int, Movie>>((ref) {
  return DirectWatchedNotifier(
    onMovieWatched: (Movie movie) {
      ref.read(achievementsProvider.notifier).trackMovieWatched(movie);
    },
  );
});

class DirectWatchedNotifier extends StateNotifier<Map<int, Movie>> {
  DirectWatchedNotifier({
    required this.onMovieWatched,
  }) : super({}) {
    LoggerFactory.info(
        '🎬 DirectWatchedNotifier: Constructor llamado, inicializando...');
    _initializeWithCurrentUser();
  }

  final Function(Movie movie) onMovieWatched;
  final TriggerFreeWatchedSync _sync = TriggerFreeWatchedSync.instance;
  static RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSubscription;
  String? _currentUserId;
  bool _isInitialized = false;

  void _initializeWithCurrentUser() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.id;
      _isInitialized = true;
      _loadWatchedFromSupabase();
      _setupRealtimeListeners();
    }
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        if (!_isInitialized || _currentUserId != session.user.id) {
          _currentUserId = session.user.id;
          _isInitialized = true;
          _loadWatchedFromSupabase();
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

  Future<void> _loadWatchedFromSupabase() async {
    if (!_isInitialized || _currentUserId == null) return;

    try {
      final movies = await _sync.getUserWatchedMovies(_currentUserId!);
      final moviesMap = {for (final movie in movies) movie.id: movie};
      if (mounted) {
        state = moviesMap;
      }
    } catch (e) {
      LoggerFactory.error('DirectWatched: Error cargando: $e');
      if (mounted) {
        state = {};
      }
    }
  }

  Future<void> toggleWatched(Movie movie) async {
    final isWatched = state.containsKey(movie.id);
    final optimisticState = Map<int, Movie>.from(state);

    if (isWatched) {
      optimisticState.remove(movie.id);
    } else {
      optimisticState[movie.id] = movie;
    }
    state = optimisticState;

    if (_currentUserId == null) return;

    try {
      if (isWatched) {
        await _sync.removeWatchedMovie(_currentUserId!, movie.id);
      } else {
        await _sync.addWatchedMovie(_currentUserId!, movie);
        onMovieWatched(movie);
      }
    } catch (e) {
      LoggerFactory.error('DirectWatched: Error en toggle: $e');
      // Revertir si falla
      if (mounted) {
        _loadWatchedFromSupabase();
      }
    }
  }

  Future<void> refresh() async {
    await _loadWatchedFromSupabase();
  }

  Future<List<Movie>> loadNextPage() async {
    await _loadWatchedFromSupabase();
    return state.values.toList();
  }

  void _setupRealtimeListeners() {
    if (_realtimeChannel != null) return;

    try {
      _realtimeChannel = Supabase.instance.client.channel('public:user_watched_movies').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_watched_movies',
        callback: _handleRealtimeChange,
      );

      _realtimeChannel!.subscribe((status, [error]) {
        if (error != null) {
          LoggerFactory.error('🔊 DirectWatched: Error en canal: $error');
        } else if (status == RealtimeSubscribeStatus.subscribed) {
          LoggerFactory.info('✅ DirectWatched: Canal suscrito exitosamente!');
        }
      });
    } catch (e) {
      LoggerFactory.error('❌ DirectWatched: Error configurando listeners: $e');
    }
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    if (!mounted) return;

    LoggerFactory.info('🔊 DirectWatched: ===== CAMBIO RECIBIDO =====');
    // Simplificado: Recargar todo al recibir cualquier cambio relevante.
    _loadWatchedFromSupabase();
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

/// Provider para verificar si una película está vista usando el provider directo
final directIsWatchedProvider = Provider.family<bool, int>((ref, movieId) {
  return ref.watch(directWatchedMoviesProvider).containsKey(movieId);
});

/// Provider para obtener el conteo de vistas
final directWatchedCountProvider = Provider<int>((ref) {
  return ref.watch(directWatchedMoviesProvider).length;
});
