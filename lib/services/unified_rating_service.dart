import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/logger_factory.dart';
import '../domain/entities/movie.dart';
import '../domain/entities/syncable_movie_rating.dart';

/// Servicio unificado de calificaciones con sincronización real-time
///
/// Este servicio reemplaza DirectRatingsProvider, MovieRatingsProvider
/// y UserMovieRatingsProvider con una implementación simple y directa.
///
/// Características:
/// - ✅ Sincronización real-time con Supabase
/// - ✅ Cache local de ratings
/// - ✅ Actualización optimista
/// - ✅ Recuperación automática de errores
class UnifiedRatingService {
  UnifiedRatingService._();

  static final UnifiedRatingService _instance = UnifiedRatingService._();
  static UnifiedRatingService get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;

  // Cache local de ratings: movieId -> SyncableMovieRating
  final Map<int, SyncableMovieRating> _ratingsCache = {};

  // Stream controller para notificar cambios
  final _ratingsStreamController =
      StreamController<Map<int, SyncableMovieRating>>.broadcast();

  /// Stream de cambios en los ratings
  Stream<Map<int, SyncableMovieRating>> get ratingsStream =>
      _ratingsStreamController.stream;

  /// Ratings actuales (inmutable)
  Map<int, SyncableMovieRating> get currentRatings =>
      Map.unmodifiable(_ratingsCache);

  /// Inicializa el servicio y carga datos
  Future<void> initialize() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      LoggerFactory.warning('⚠️ UnifiedRatingService: No user logged in');
      _clearData();
      return;
    }

    LoggerFactory.info(
        '🚀 UnifiedRatingService: Initializing for user ${user.id}');

    try {
      // 1. Cargar ratings existentes desde Supabase
      await _loadRatingsFromSupabase(user.id);

      // 2. Configurar real-time sync
      _setupRealtimeSync(user.id);

      LoggerFactory.info(
          '✅ UnifiedRatingService: Initialized successfully with ${_ratingsCache.length} ratings');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ UnifiedRatingService: Initialization failed: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      // No lanzar error, mantener servicio disponible
    }
  }

  /// Carga ratings desde Supabase
  Future<void> _loadRatingsFromSupabase(String userId) async {
    try {
      LoggerFactory.info(
          '📥 UnifiedRatingService: Loading ratings from Supabase...');

      final response = await _supabase
          .from('user_movie_ratings')
          .select('*')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('rated_at', ascending: false);

      _ratingsCache.clear();

      for (final data in response as List<dynamic>) {
        try {
          final rating = SyncableMovieRating.fromJson(data);
          _ratingsCache[rating.movieId] = rating;
        } catch (e) {
          LoggerFactory.error('❌ Error parsing rating: $e');
          LoggerFactory.debug('Problematic data: $data');
        }
      }

      // Notificar cambios
      _ratingsStreamController.add(_ratingsCache);

      LoggerFactory.info(
          '✅ Loaded ${_ratingsCache.length} ratings from Supabase');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Failed to load ratings from Supabase: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Configura sincronización real-time
  void _setupRealtimeSync(String userId) {
    try {
      // Cancelar suscripción anterior
      _realtimeSubscription?.cancel();

      LoggerFactory.info(
          '🔄 UnifiedRatingService: Setting up real-time sync...');

      // Suscribirse a cambios en tiempo real
      _realtimeSubscription = _supabase
          .from('user_movie_ratings')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .listen(
            (List<Map<String, dynamic>> data) {
              LoggerFactory.debug(
                  '🔄 Real-time update received: ${data.length} ratings');

              // Actualizar cache
              _ratingsCache.clear();
              for (final item in data) {
                if (item['is_deleted'] != true) {
                  try {
                    final rating = SyncableMovieRating.fromJson(item);
                    _ratingsCache[rating.movieId] = rating;
                  } catch (e) {
                    LoggerFactory.error('❌ Error parsing real-time rating: $e');
                  }
                }
              }

              // Notificar cambios
              _ratingsStreamController.add(_ratingsCache);

              LoggerFactory.debug(
                  '✅ Cache updated with ${_ratingsCache.length} ratings');
            },
            onError: (error) {
              LoggerFactory.error('❌ Real-time sync error: $error');
            },
            cancelOnError: false, // Continuar escuchando después de errores
          );

      LoggerFactory.info('✅ Real-time sync configured successfully');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Failed to setup real-time sync: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
    }
  }

  /// Califica una película
  Future<void> rateMovie({
    required Movie movie,
    required double rating,
    String? review,
    bool isPublic = false,
    List<String> tags = const [],
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      LoggerFactory.info('⭐ Rating movie: ${movie.title} with $rating/10');

      // Validar rating (1.0-10.0)
      final validatedRating = rating.clamp(1.0, 10.0);

      if (rating != validatedRating) {
        LoggerFactory.warning(
            '⚠️ Rating clamped from $rating to $validatedRating');
      }

      final movieRating = SyncableMovieRating.fromMovie(
        userId: user.id,
        movie: movie,
        rating: validatedRating,
        review: review,
        isPublic: isPublic,
        tags: tags,
      );

      // Actualización optimista
      _ratingsCache[movie.id] = movieRating;
      _ratingsStreamController.add(_ratingsCache);

      LoggerFactory.debug('✅ Optimistic update applied');

      // Guardar en Supabase
      await _supabase
          .from('user_movie_ratings')
          .upsert(movieRating.toSupabaseJson());

      LoggerFactory.info('✅ Movie rated successfully in Supabase');

      // Real-time sync actualizará automáticamente si hay diferencias
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Failed to rate movie: $e');
      LoggerFactory.error('Stack trace: $stackTrace');

      // Revertir cambio optimista
      await _reloadFromSupabase();
      rethrow;
    }
  }

  /// Actualiza una calificación existente
  Future<void> updateRating({
    required int movieId,
    required double rating,
    String? review,
    bool? isPublic,
    List<String>? tags,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final existingRating = _ratingsCache[movieId];
    if (existingRating == null) {
      throw Exception('Rating not found for movie $movieId');
    }

    try {
      LoggerFactory.info('📝 Updating rating for movie $movieId');

      // Validar rating
      final validatedRating = rating.clamp(1.0, 10.0);

      // Crear rating actualizado
      final updatedRating = existingRating.copyWithData(
        rating: validatedRating,
        review: review ?? existingRating.review,
        isPublic: isPublic ?? existingRating.isPublic,
        tags: tags ?? existingRating.tags,
        lastModifiedAt: DateTime.now().toUtc(),
      );

      // Actualización optimista
      _ratingsCache[movieId] = updatedRating;
      _ratingsStreamController.add(_ratingsCache);

      // Guardar en Supabase
      await _supabase
          .from('user_movie_ratings')
          .update(updatedRating.toSupabaseJson())
          .eq('user_id', user.id)
          .eq('movie_id', movieId);

      LoggerFactory.info('✅ Rating updated successfully');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Failed to update rating: $e');
      LoggerFactory.error('Stack trace: $stackTrace');

      // Revertir cambio optimista
      await _reloadFromSupabase();
      rethrow;
    }
  }

  /// Elimina una calificación
  Future<void> deleteRating(int movieId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      LoggerFactory.info('🗑️ Deleting rating for movie $movieId');

      // Actualización optimista
      _ratingsCache.remove(movieId);
      _ratingsStreamController.add(_ratingsCache);

      // Marcar como eliminado en Supabase (soft delete)
      await _supabase
          .from('user_movie_ratings')
          .update({
            'is_deleted': true,
            'last_modified_at': DateTime.now().toUtc().toIso8601String()
          })
          .eq('user_id', user.id)
          .eq('movie_id', movieId);

      LoggerFactory.info('✅ Rating deleted successfully');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Failed to delete rating: $e');
      LoggerFactory.error('Stack trace: $stackTrace');

      // Revertir cambio optimista
      await _reloadFromSupabase();
      rethrow;
    }
  }

  /// Obtiene rating de una película
  SyncableMovieRating? getRating(int movieId) {
    return _ratingsCache[movieId];
  }

  /// Verifica si una película está calificada
  bool isMovieRated(int movieId) {
    return _ratingsCache.containsKey(movieId);
  }

  /// Obtiene todas las calificaciones
  List<SyncableMovieRating> getAllRatings() {
    return _ratingsCache.values.toList();
  }

  /// Obtiene estadísticas de ratings
  Map<String, dynamic> getStats() {
    if (_ratingsCache.isEmpty) {
      return {
        'total': 0,
        'average': 0.0,
        'highest': 0.0,
        'lowest': 0.0,
      };
    }

    final ratings = _ratingsCache.values.map((r) => r.rating).toList();
    final total = ratings.length;
    final sum = ratings.reduce((a, b) => a + b);
    final average = sum / total;
    final highest = ratings.reduce((a, b) => a > b ? a : b);
    final lowest = ratings.reduce((a, b) => a < b ? a : b);

    return {
      'total': total,
      'average': average,
      'highest': highest,
      'lowest': lowest,
      'with_review': _ratingsCache.values.where((r) => r.hasReview).length,
    };
  }

  /// Recarga desde Supabase (útil para recuperación de errores)
  Future<void> _reloadFromSupabase() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _loadRatingsFromSupabase(user.id);
    }
  }

  /// Limpia todos los datos (útil para logout)
  void _clearData() {
    _realtimeSubscription?.cancel();
    _ratingsCache.clear();
    _ratingsStreamController.add({});
  }

  /// Limpia el servicio al hacer logout
  void dispose() {
    LoggerFactory.info('🧹 UnifiedRatingService: Disposing...');
    _clearData();
    LoggerFactory.info('✅ UnifiedRatingService: Disposed');
  }
}
