import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/trigger_free_favorites_sync.dart';
import '../../../domain/entities/movie.dart';
import '../achievements/achievements_provider.dart';

/// Provider directo que evita completamente el repositorio híbrido
/// y solo usa SimpleFavoritesSync para operaciones de Supabase
final directFavoriteMoviesProvider =
    StateNotifierProvider<DirectFavoritesNotifier, Map<int, Movie>>((ref) {
  return DirectFavoritesNotifier(
    onMovieFavorited: () {
      ref.read(achievementsProvider.notifier).trackMovieFavorited();
    },
  );
});

class DirectFavoritesNotifier extends StateNotifier<Map<int, Movie>> {
  DirectFavoritesNotifier({
    required this.onMovieFavorited,
  }) : super({}) {
    LoggerFactory.info(
        '🎬 DirectFavoritesNotifier: Constructor llamado, inicialización diferida...');
    _initializeWithCurrentUser();
  }

  final VoidCallback onMovieFavorited;
  final TriggerFreeFavoritesSync _sync = TriggerFreeFavoritesSync.instance;
  static RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSubscription;
  String? _currentUserId;
  bool _isInitialized = false;

  void _initializeWithCurrentUser() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.id;
      _isInitialized = true;
      _loadFavoritesFromSupabase();
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
          _loadFavoritesFromSupabase();
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

  Future<void> _loadFavoritesFromSupabase() async {
    if (!_isInitialized || _currentUserId == null) return;

    try {
      final movies = await _sync.getUserFavorites(_currentUserId!);
      final moviesMap = {for (final movie in movies) movie.id: movie};
      if (mounted) {
        state = moviesMap;
      }
    } catch (e) {
      LoggerFactory.error('DirectFavorites: Error cargando: $e');
      if (mounted) {
        state = {};
      }
    }
  }

  Future<void> toggleFavorite(Movie movie) async {
    final isFavorite = state.containsKey(movie.id);
    final optimisticState = Map<int, Movie>.from(state);

    if (isFavorite) {
      optimisticState.remove(movie.id);
    } else {
      optimisticState[movie.id] = movie;
    }
    state = optimisticState;

    if (_currentUserId == null) return;

    try {
      if (isFavorite) {
        await _sync.removeFavorite(_currentUserId!, movie.id);
      } else {
        await _sync.addFavorite(_currentUserId!, movie);
        onMovieFavorited();
      }
    } catch (e) {
      LoggerFactory.error('DirectFavorites: Error en toggle: $e');
      // Revertir si falla
      if (mounted) {
        _loadFavoritesFromSupabase();
      }
    }
  }

  Future<void> refresh() async {
    await _loadFavoritesFromSupabase();
  }

  Future<List<Movie>> loadNextPage() async {
    await _loadFavoritesFromSupabase();
    return state.values.toList();
  }

  void _setupRealtimeListeners() {
    if (_realtimeChannel != null) return;

    try {
      _realtimeChannel = Supabase.instance.client.channel('public:user_favorites').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_favorites',
        callback: _handleRealtimeEvent,
      );

      _realtimeChannel!.subscribe((status, [error]) {
        if (error != null) {
          LoggerFactory.error('🔊 DirectFavorites: Error en canal: $error');
        } else if (status == RealtimeSubscribeStatus.subscribed) {
          LoggerFactory.info('✅ DirectFavorites: Canal suscrito exitosamente!');
        }
      });
    } catch (e) {
      LoggerFactory.error('❌ DirectFavorites: Error configurando listeners: $e');
    }
  }

  void _handleRealtimeEvent(PostgresChangePayload payload) {
    if (!mounted) return;

    LoggerFactory.info('🔊 DirectFavorites: ===== CAMBIO RECIBIDO =====');
    // Simplificado: Recargar todo al recibir cualquier cambio relevante.
    // Se podría optimizar para no recargar si el cambio es de otro usuario,
    // pero la recarga es más robusta contra estados inconsistentes.
    _loadFavoritesFromSupabase();
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

/// Provider para verificar si una película es favorita usando el provider directo
final directIsFavoriteProvider = Provider.family<bool, int>((ref, movieId) {
  return ref.watch(directFavoriteMoviesProvider).containsKey(movieId);
});

/// Provider para obtener el conteo de favoritos
final directFavoritesCountProvider = Provider<int>((ref) {
  return ref.watch(directFavoriteMoviesProvider).length;
});
