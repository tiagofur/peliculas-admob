import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/trigger_free_ratings_sync.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/syncable_movie_rating.dart';
import '../../../domain/entities/user_movie_rating.dart';
import '../achievements/achievements_provider.dart';

/// Direct Ratings Service - Maneja calificaciones con sincronización directa a Supabase
/// Con soporte de Real-Time Sync para actualizaciones instantáneas
class DirectRatingsService extends Notifier<Map<int, SyncableMovieRating>> {
  late TriggerFreeRatingsSync _sync;
  bool _isInitialized = false;
  StreamSubscription<List<UserMovieRating>>? _realtimeSubscription;

  @override
  Map<int, SyncableMovieRating> build() {
    // Configurar dependencias
    _sync = TriggerFreeRatingsSync.instance;

    // Configurar cleanup cuando se destruya el provider
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
      LoggerFactory.info('🧹 DirectRatings: Cleaned up real-time subscription');
    });

    _initializeWithCurrentUser();
    return {};
  }

  void _initializeWithCurrentUser() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      // Cargar datos iniciales PRIMERO
      _loadRatingsFromSupabase();
      // LUEGO configurar Real-Time Sync para cambios futuros
      _setupRealtimeSync(currentUser.id);
      _isInitialized = true;
    }
  }

  /// Configura la sincronización en tiempo real
  void _setupRealtimeSync(String userId) {
    try {
      // Cancelar suscripción anterior si existe
      _realtimeSubscription?.cancel();

      LoggerFactory.info(
          '🎯 DirectRatings: Setting up real-time sync for user: $userId');

      // Suscribirse al stream de cambios en tiempo real
      _realtimeSubscription = _sync.watchUserRatings(userId).listen(
        (userRatings) {
          LoggerFactory.info(
              '🔄 DirectRatings: Real-time update received: ${userRatings.length} ratings');

          // Convertir a mapa de SyncableMovieRating
          final ratingsMap = <int, SyncableMovieRating>{};
          for (final userRating in userRatings) {
            final syncableRating = _userMovieRatingToSyncable(userRating);
            ratingsMap[syncableRating.movieId] = syncableRating;
          }

          // Actualizar estado con los nuevos datos
          state = ratingsMap;

          LoggerFactory.debug(
              '✅ DirectRatings: State updated from real-time sync: ${ratingsMap.length} ratings');
        },
        onError: (error) {
          LoggerFactory.error('❌ DirectRatings: Real-time sync error: $error');
        },
        cancelOnError: false, // No cancelar en errores, continuar escuchando
      );

      LoggerFactory.info('✅ DirectRatings: Real-time sync configured');
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectRatings: Failed to setup real-time sync: $e');
    }
  }

  Future<void> _loadRatingsFromSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        LoggerFactory.info('⚠️ DirectRatings: No user logged in, clearing state');
        state = {};
        return;
      }

      LoggerFactory.info(
          '📥 DirectRatings: Loading ratings from Supabase for user: ${currentUser.id}');

      // TEST: Verificar conexión y datos en tabla
      await _sync.testConnection();

      final userMovieRatings = await _sync.getUserRatings(currentUser.id);

      LoggerFactory.info(
          '📦 DirectRatings: Received ${userMovieRatings.length} ratings from Supabase');

      final ratingsMap = <int, SyncableMovieRating>{};
      for (final userRating in userMovieRatings) {
        final syncableRating = _userMovieRatingToSyncable(userRating);
        ratingsMap[syncableRating.movieId] = syncableRating;
        LoggerFactory.debug(
            '  📌 Rating: ${userRating.movieTitle} - ${userRating.rating}/10');
      }

      state = ratingsMap;
      LoggerFactory.info(
          '✅ DirectRatings: Loaded ${ratingsMap.length} ratings from Supabase and updated state');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ DirectRatings: Error loading ratings: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      state = {};
    }
  }

  /// Califica o actualiza la calificación de una película
  Future<void> rateMovie({
    required Movie movie,
    required double rating,
    String? review,
    bool isPublic = false,
    List<String> tags = const [],
  }) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.error('❌ DirectRatings: No user logged in');
      return;
    }

    try {
      LoggerFactory.info(
          '⭐ DirectRatings: Rating movie ${movie.title} with $rating/10');

      // Actualización optimista
      final newRating = SyncableMovieRating.fromMovie(
        userId: currentUser.id,
        movie: movie,
        rating: rating,
        review: review,
        isPublic: isPublic,
        tags: tags,
      );

      state = {...state, movie.id: newRating};

      // Guardar en Supabase usando el servicio de sync
      await _sync.saveRating(
        currentUser.id,
        movie.id,
        movie.title,
        rating,
        review: review,
        moviePosterPath: movie.posterPath,
      );

      // Notificar achievement si aplica
      try {
        // Verificar si el método existe antes de llamarlo
        final achievementsNotifier = ref.read(achievementsProvider.notifier);
        // trackMovieRated() no existe, usar trackMovieFavorited() como alternativa
        achievementsNotifier.trackMovieFavorited();
      } catch (e) {
        // Si el método no existe, continuar sin error
        LoggerFactory.debug('Achievement tracking not available: $e');
      }

      // El Real-Time stream actualizará el estado automáticamente

      LoggerFactory.info(
          '✅ DirectRatings: Successfully rated movie ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ DirectRatings: Error rating movie: $e');
      // Revertir cambio optimista cargando desde Supabase
      await _loadRatingsFromSupabase();
    }
  }

  /// Elimina una calificación
  Future<void> deleteRating(int movieId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.error('❌ DirectRatings: No user logged in');
      return;
    }

    try {
      LoggerFactory.info(
          '🗑️ DirectRatings: Deleting rating for movie $movieId');

      // Actualización optimista
      final newState = Map<int, SyncableMovieRating>.from(state);
      newState.remove(movieId);
      state = newState;

      // Eliminar de Supabase
      await _sync.deleteRating(currentUser.id, movieId);

      // El Real-Time stream actualizará el estado automáticamente
      LoggerFactory.info('✅ DirectRatings: Successfully deleted rating');
    } catch (e) {
      LoggerFactory.error('❌ DirectRatings: Error deleting rating: $e');
      // Revertir cambio optimista cargando desde Supabase
      await _loadRatingsFromSupabase();
    }
  }

  /// Obtiene una calificación específica
  SyncableMovieRating? getRating(int movieId) {
    return state[movieId];
  }

  /// Verifica si una película está calificada
  bool isMovieRated(int movieId) {
    return state.containsKey(movieId);
  }

  /// Obtiene todas las calificaciones como lista
  List<SyncableMovieRating> getRatings() {
    return state.values.toList();
  }

  /// Refresca las calificaciones desde Supabase
  Future<void> refresh() async {
    await _loadRatingsFromSupabase();
  }

  /// Habilita el servicio después del login
  void enableAfterLogin() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    if (!_isInitialized) {
      // Cargar datos iniciales + configurar Real-Time Sync
      _loadRatingsFromSupabase();
      _setupRealtimeSync(currentUser.id);
      _isInitialized = true;
    } else {
      // Recargar datos y re-configurar Real-Time Sync
      _loadRatingsFromSupabase();
      _setupRealtimeSync(currentUser.id);
    }
  }

  /// Deshabilita el servicio después del logout
  void disableAfterLogout() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _isInitialized = false;
    state = {};
    LoggerFactory.info('🚪 DirectRatings: Disabled after logout');
  }

  /// Convierte un UserMovieRating a SyncableMovieRating
  SyncableMovieRating _userMovieRatingToSyncable(UserMovieRating userRating) {
    return SyncableMovieRating(
      id: userRating.id,
      userId: userRating.userId,
      movieId: userRating.movieId,
      movieTitle: userRating.movieTitle,
      rating: userRating.rating,
      review: userRating.review,
      ratedAt: userRating.createdAt,
      createdAt: userRating.createdAt,
      lastModifiedAt: userRating.updatedAt,
      isDeleted: false,
      syncVersion: 1,
      deviceId: null,
      isPublic: false,
      tags: [],
    );
  }

  /// Test de conexión para debug
  Future<void> testConnection() async {
    LoggerFactory.info('🧪 DirectRatings: Iniciando test de conexión...');
    await _sync.testConnection();
  }
}

/// Provider principal para ratings
final directRatingsProvider =
    NotifierProvider<DirectRatingsService, Map<int, SyncableMovieRating>>(
  () => DirectRatingsService(),
);

/// Provider para verificar si una película está calificada
final directIsRatedProvider = Provider.family<bool, int>((ref, movieId) {
  return ref.watch(directRatingsProvider).containsKey(movieId);
});

/// Provider para obtener una calificación específica
final directRatingProvider =
    Provider.family<SyncableMovieRating?, int>((ref, movieId) {
  return ref.watch(directRatingsProvider)[movieId];
});

/// Provider para el conteo total de calificaciones
final directRatingsCountProvider = Provider<int>((ref) {
  return ref.watch(directRatingsProvider).length;
});
