import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/trigger_free_ratings_sync.dart';
import '../../../domain/entities/user_movie_rating.dart';
import '../../../infrastructure/datasources/ratings_hive_datasource.dart';
import '../auth_provider.dart';

/// Provider para el DirectRatingsProvider
final directRatingsProvider = StateNotifierProvider.autoDispose<
    DirectRatingsProvider, DirectRatingsState>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.when(
    data: (user) => user?.id,
    loading: () => null,
    error: (_, __) => null,
  );

  if (userId == null) {
    return DirectRatingsProvider.empty();
  }

  return DirectRatingsProvider(userId: userId);
});

/// Estado para las calificaciones
class DirectRatingsState {
  const DirectRatingsState({
    this.ratings = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.isInitialized = false,
  });

  final List<UserMovieRating> ratings;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final bool isInitialized;

  DirectRatingsState copyWith({
    List<UserMovieRating>? ratings,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    bool? isInitialized,
  }) {
    return DirectRatingsState(
      ratings: ratings ?? this.ratings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  bool isMovieRated(int movieId) {
    return ratings.any((rating) => rating.movieId == movieId);
  }

  UserMovieRating? getRatingForMovie(int movieId) {
    try {
      return ratings.firstWhere((rating) => rating.movieId == movieId);
    } catch (e) {
      return null;
    }
  }

  double? getRatingValueForMovie(int movieId) {
    final rating = getRatingForMovie(movieId);
    return rating?.rating;
  }

  String? getReviewForMovie(int movieId) {
    final rating = getRatingForMovie(movieId);
    return rating?.review;
  }
}

/// Provider directo para ratings que maneja local storage y real-time sync
class DirectRatingsProvider extends StateNotifier<DirectRatingsState> {
  factory DirectRatingsProvider({required String userId}) {
    return DirectRatingsProvider._(userId: userId);
  }
  DirectRatingsProvider._({
    required this.userId,
  }) : super(const DirectRatingsState()) {
    _init();
  }

  factory DirectRatingsProvider.empty() {
    return DirectRatingsProvider._(userId: '');
  }

  final String userId;
  late final RatingsHiveDatasource _localDatasource;
  late final TriggerFreeRatingsSync _syncService;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;

  /// Inicializa el provider
  Future<void> _init() async {
    if (userId.isEmpty) return;

    try {
      LoggerFactory.info(
          '🎬 [DirectRatings] Inicializando provider para user: $userId');

      // Inicializar servicios
      _localDatasource = RatingsHiveDatasource();
      _syncService = TriggerFreeRatingsSync.instance;

      // Cargar datos iniciales del storage local
      await _loadInitialData();

      // Configurar suscripción a tiempo real
      await _setupRealTimeSync();

      state = state.copyWith(isInitialized: true);

      LoggerFactory.info(
          '✅ [DirectRatings] Provider inicializado correctamente');
    } catch (e) {
      LoggerFactory.error('❌ [DirectRatings] Error inicializando provider: $e');
      state = state.copyWith(error: 'Error inicializando ratings: $e');
    }
  }

  /// Carga datos iniciales del storage local
  Future<void> _loadInitialData() async {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 [DirectRatings] Provider disposed, ignorando _loadInitialData');
      return;
    }

    try {
      final localRatings = await _localDatasource.getAllRatings(userId);
      LoggerFactory.info(
          '📱 [DirectRatings] Cargados ${localRatings.length} ratings del storage local');

      // Verificar mounted antes de actualizar estado
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante carga inicial, ignorando actualización');
        return;
      }

      state = state.copyWith(
        ratings: localRatings,
        lastUpdated: DateTime.now(),
      );

      // Sincronizar con servidor en background
      _syncWithServer();
    } catch (e) {
      LoggerFactory.error('❌ [DirectRatings] Error cargando datos locales: $e');

      // Verificar mounted antes de actualizar estado de error
      if (mounted) {
        state = state.copyWith(error: 'Error cargando datos locales: $e');
      }
    }
  }

  /// Sincroniza con el servidor
  Future<void> _syncWithServer() async {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 [DirectRatings] Provider disposed, ignorando _syncWithServer');
      return;
    }

    try {
      final serverRatings = await _syncService.getUserRatings(userId);
      LoggerFactory.info(
          '☁️ [DirectRatings] Obtenidos ${serverRatings.length} ratings del servidor');

      // Verificar mounted antes de acceder al estado
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante obtención de ratings del servidor');
        return;
      }

      // Combinar y deduplicar ratings
      final combinedRatings = _mergeRatings(state.ratings, serverRatings);

      // Actualizar storage local
      for (final rating in serverRatings) {
        await _localDatasource.saveRating(rating);
      }

      // Verificar mounted antes de actualizar estado
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante guardado en local storage');
        return;
      }

      state = state.copyWith(
        ratings: combinedRatings,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      LoggerFactory.error(
          '❌ [DirectRatings] Error sincronizando con servidor: $e');
    }
  }

  /// Combina y deduplicar ratings manteniendo las versiones más recientes
  List<UserMovieRating> _mergeRatings(
      List<UserMovieRating> local, List<UserMovieRating> server) {
    // Verificar si el provider aún está activo antes de procesar
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 [DirectRatings] Provider disposed, retornando lista local sin merge');
      return local;
    }

    final Map<int, UserMovieRating> ratingsMap = {};

    // Agregar ratings locales primero
    for (final rating in local) {
      ratingsMap[rating.movieId] = rating;
    }

    // Sobrescribir con ratings del servidor si son más recientes
    for (final rating in server) {
      final existing = ratingsMap[rating.movieId];
      if (existing == null || rating.updatedAt.isAfter(existing.updatedAt)) {
        ratingsMap[rating.movieId] = rating;
      }
    }

    final result = ratingsMap.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// Configura la suscripción a tiempo real
  Future<void> _setupRealTimeSync() async {
    try {
      LoggerFactory.info('🔄 [DirectRatings] Configurando real-time sync');

      final supabase = Supabase.instance.client;

      _realtimeSubscription = supabase
          .from('user_movie_ratings')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .listen(
            (List<Map<String, dynamic>> data) {
              _handleRealtimeEvent(data);
            },
            onError: (error) {
              LoggerFactory.error(
                  '❌ [DirectRatings] Error en real-time sync: $error');
            },
          );

      LoggerFactory.info('✅ [DirectRatings] Real-time sync configurado');
    } catch (e) {
      LoggerFactory.error('❌ [DirectRatings] Error configurando real-time: $e');
    }
  }

  /// Maneja eventos de tiempo real
  void _handleRealtimeEvent(List<Map<String, dynamic>> data) {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 [DirectRatings] Provider disposed, ignorando evento real-time');
      return;
    }

    try {
      LoggerFactory.info(
          '📡 [DirectRatings] Evento real-time recibido: ${data.length} ratings');

      if (data.isEmpty) {
        LoggerFactory.info(
            '📭 [DirectRatings] Sin ratings en el evento, manteniendo estado actual');
        return;
      }

      final serverRatings =
          data.map((json) => UserMovieRating.fromJson(json)).toList();
      final currentRatings = List<UserMovieRating>.from(state.ratings);

      // Crear mapa para actualizaciones eficientes
      final ratingsMap = <int, UserMovieRating>{};
      for (final rating in currentRatings) {
        ratingsMap[rating.movieId] = rating;
      }

      // Actualizar con datos del servidor
      for (final serverRating in serverRatings) {
        ratingsMap[serverRating.movieId] = serverRating;
        // Guardar en local storage
        _localDatasource.saveRating(serverRating).catchError((e) {
          LoggerFactory.error('❌ [DirectRatings] Error guardando en local: $e');
        });
      }

      final updatedRatings = ratingsMap.values.toList();
      updatedRatings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Verificar nuevamente antes de actualizar el estado
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante procesamiento, ignorando actualización de estado');
        return;
      }

      state = state.copyWith(
        ratings: updatedRatings,
        lastUpdated: DateTime.now(),
      );

      LoggerFactory.info(
          '✅ [DirectRatings] Estado actualizado con real-time data');
    } catch (e) {
      LoggerFactory.error(
          '❌ [DirectRatings] Error procesando evento real-time: $e');
      // Verificar si aún está mounted antes de actualizar estado de error
      if (mounted) {
        state = state.copyWith(error: 'Error procesando actualización: $e');
      }
    }
  }

  /// Califica una película
  Future<void> rateMovie({
    required int movieId,
    required String movieTitle,
    required double rating,
    String? review,
    String? moviePosterPath,
  }) async {
    if (rating < 1.0 || rating > 10.0) {
      throw ArgumentError('Rating debe estar entre 1.0 y 10.0');
    }

    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 [DirectRatings] Provider disposed, ignorando rateMovie');
      return;
    }

    try {
      LoggerFactory.info(
          '⭐ [DirectRatings] Calificando película: $movieTitle ($rating/10)');

      // Actualización optimista
      final tempRating = UserMovieRating(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        movieId: movieId,
        movieTitle: movieTitle,
        moviePosterPath: moviePosterPath,
        rating: rating,
        review: review,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final currentRatings = List<UserMovieRating>.from(state.ratings);
      final existingIndex =
          currentRatings.indexWhere((r) => r.movieId == movieId);

      if (existingIndex != -1) {
        currentRatings[existingIndex] = tempRating;
      } else {
        currentRatings.insert(0, tempRating);
      }

      // Verificar mounted antes de actualizar estado
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante rateMovie, ignorando actualización');
        return;
      }

      state = state.copyWith(ratings: currentRatings);

      // Guardar en servidor
      final savedRating = await _syncService.saveRating(
        userId,
        movieId,
        movieTitle,
        rating,
        review: review,
        moviePosterPath: moviePosterPath,
      );

      if (savedRating != null) {
        // Verificar mounted antes de actualizar estado final
        if (!mounted) {
          LoggerFactory.debug(
              '🚫 [DirectRatings] Provider disposed durante guardado en servidor, ignorando actualización final');
          return;
        }

        // Actualizar con datos reales del servidor
        final finalRatings = List<UserMovieRating>.from(state.ratings);
        final finalIndex = finalRatings.indexWhere((r) => r.movieId == movieId);

        if (finalIndex != -1) {
          finalRatings[finalIndex] = savedRating;
        } else {
          finalRatings.insert(0, savedRating);
        }

        state = state.copyWith(ratings: finalRatings);

        // Guardar en storage local
        await _localDatasource.saveRating(savedRating);

        LoggerFactory.info('✅ [DirectRatings] Rating guardado correctamente');
      } else {
        throw Exception('No se pudo guardar el rating en el servidor');
      }
    } catch (e) {
      LoggerFactory.error('❌ [DirectRatings] Error calificando película: $e');

      // Verificar mounted antes de revertir
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante error, ignorando revert');
        return;
      }

      // Revertir actualización optimista
      await _loadInitialData();

      state = state.copyWith(error: 'Error calificando película: $e');
      rethrow;
    }
  }

  /// Actualiza solo el comentario de un rating
  Future<void> updateReview({
    required int movieId,
    required String? review,
  }) async {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 [DirectRatings] Provider disposed, ignorando updateReview');
      return;
    }

    try {
      LoggerFactory.info(
          '📝 [DirectRatings] Actualizando comentario para película: $movieId');

      // Actualización optimista
      final currentRatings = List<UserMovieRating>.from(state.ratings);
      final existingIndex =
          currentRatings.indexWhere((r) => r.movieId == movieId);

      if (existingIndex == -1) {
        throw Exception('La película no tiene rating para actualizar');
      }

      final updatedRating = currentRatings[existingIndex].copyWith(
        review: review,
        updatedAt: DateTime.now(),
      );
      currentRatings[existingIndex] = updatedRating;

      // Verificar mounted antes de actualizar estado
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante updateReview, ignorando actualización');
        return;
      }

      state = state.copyWith(ratings: currentRatings);

      // Actualizar en servidor
      final serverRating =
          await _syncService.updateReview(userId, movieId, review);

      if (serverRating != null) {
        // Verificar mounted antes de actualizar estado final
        if (!mounted) {
          LoggerFactory.debug(
              '🚫 [DirectRatings] Provider disposed durante guardado en servidor, ignorando actualización final');
          return;
        }

        // Actualizar con datos del servidor
        final finalRatings = List<UserMovieRating>.from(state.ratings);
        final finalIndex = finalRatings.indexWhere((r) => r.movieId == movieId);
        if (finalIndex != -1) {
          finalRatings[finalIndex] = serverRating;
          state = state.copyWith(ratings: finalRatings);
        }

        // Guardar en storage local
        await _localDatasource.saveRating(serverRating);

        LoggerFactory.info(
            '✅ [DirectRatings] Comentario actualizado correctamente');
      } else {
        throw Exception('No se pudo actualizar el comentario en el servidor');
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ [DirectRatings] Error actualizando comentario: $e');

      // Verificar mounted antes de revertir
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante error, ignorando revert');
        return;
      }

      // Revertir actualización optimista
      await _loadInitialData();

      state = state.copyWith(error: 'Error actualizando comentario: $e');
      rethrow;
    }
  }

  /// Elimina un rating
  Future<void> removeRating(int movieId) async {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 [DirectRatings] Provider disposed, ignorando removeRating');
      return;
    }

    try {
      LoggerFactory.info(
          '🗑️ [DirectRatings] Eliminando rating para película: $movieId');

      final currentRatings = List<UserMovieRating>.from(state.ratings);
      final ratingToRemove =
          currentRatings.where((r) => r.movieId == movieId).firstOrNull;

      if (ratingToRemove == null) {
        LoggerFactory.info('ℹ️ [DirectRatings] No hay rating para eliminar');
        return;
      }

      // Actualización optimista
      final updatedRatings =
          currentRatings.where((r) => r.movieId != movieId).toList();

      // Verificar mounted antes de actualizar estado
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante removeRating, ignorando actualización');
        return;
      }

      state = state.copyWith(ratings: updatedRatings);

      // Eliminar del servidor
      await _syncService.deleteRating(userId, movieId);

      // Eliminar del storage local
      await _localDatasource.removeRating(movieId, userId);

      LoggerFactory.info('✅ [DirectRatings] Rating eliminado correctamente');
    } catch (e) {
      LoggerFactory.error('❌ [DirectRatings] Error eliminando rating: $e');

      // Verificar mounted antes de revertir
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante error, ignorando revert');
        return;
      }

      // Revertir actualización optimista
      await _loadInitialData();

      state = state.copyWith(error: 'Error eliminando rating: $e');
      rethrow;
    }
  }

  /// Obtiene estadísticas de ratings
  Future<Map<String, dynamic>> getRatingStats() async {
    try {
      // Primero intentar obtener del servidor
      final serverStats = await _syncService.getUserRatingStats(userId);
      return serverStats;
    } catch (e) {
      LoggerFactory.error(
          '❌ [DirectRatings] Error obteniendo estadísticas: $e');

      // Fallback a estadísticas locales
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed, retornando estadísticas vacías');
        return {
          'totalRatings': 0,
          'averageRating': 0.0,
          'highestRating': 0.0,
          'lowestRating': 0.0,
          'ratingsWithReview': 0,
          'recentRatingsCount': 0,
        };
      }

      final ratings = state.ratings;
      if (ratings.isEmpty) {
        return {
          'totalRatings': 0,
          'averageRating': 0.0,
          'highestRating': 0.0,
          'lowestRating': 0.0,
          'ratingsWithReview': 0,
          'recentRatingsCount': 0,
        };
      }

      final totalRatings = ratings.length;
      final averageRating =
          ratings.map((r) => r.rating).reduce((a, b) => a + b) / totalRatings;
      final highestRating =
          ratings.map((r) => r.rating).reduce((a, b) => a > b ? a : b);
      final lowestRating =
          ratings.map((r) => r.rating).reduce((a, b) => a < b ? a : b);
      final ratingsWithReview =
          ratings.where((r) => r.review != null && r.review!.isNotEmpty).length;

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentRatingsCount =
          ratings.where((r) => r.createdAt.isAfter(thirtyDaysAgo)).length;

      return {
        'totalRatings': totalRatings,
        'averageRating': double.parse(averageRating.toStringAsFixed(1)),
        'highestRating': highestRating,
        'lowestRating': lowestRating,
        'ratingsWithReview': ratingsWithReview,
        'recentRatingsCount': recentRatingsCount,
      };
    }
  }

  /// Busca ratings por título
  Future<List<UserMovieRating>> searchRatingsByTitle(String query) async {
    try {
      if (query.isEmpty) {
        if (!mounted) {
          LoggerFactory.debug(
              '🚫 [DirectRatings] Provider disposed, retornando lista vacía');
          return [];
        }
        return state.ratings;
      }

      // Buscar en servidor
      final serverResults =
          await _syncService.searchRatingsByTitle(userId, query);
      return serverResults;
    } catch (e) {
      LoggerFactory.error('❌ [DirectRatings] Error buscando ratings: $e');

      // Fallback a búsqueda local
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed, retornando lista vacía');
        return [];
      }

      final queryLower = query.toLowerCase();
      return state.ratings.where((rating) {
        return rating.movieTitle.toLowerCase().contains(queryLower);
      }).toList();
    }
  }

  /// Obtiene ratings recientes
  Future<List<UserMovieRating>> getRecentRatings({int limit = 20}) async {
    try {
      final serverResults =
          await _syncService.getRecentRatings(userId, limit: limit);
      return serverResults;
    } catch (e) {
      LoggerFactory.error(
          '❌ [DirectRatings] Error obteniendo ratings recientes: $e');

      // Fallback a datos locales
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed, retornando lista vacía');
        return [];
      }

      final recentRatings = List<UserMovieRating>.from(state.ratings);
      recentRatings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return recentRatings.take(limit).toList();
    }
  }

  /// Obtiene top ratings
  Future<List<UserMovieRating>> getTopRatedMovies({int limit = 20}) async {
    try {
      final serverResults =
          await _syncService.getTopRatedMovies(userId, limit: limit);
      return serverResults;
    } catch (e) {
      LoggerFactory.error('❌ [DirectRatings] Error obteniendo top ratings: $e');

      // Fallback a datos locales
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed, retornando lista vacía');
        return [];
      }

      final topRatings = List<UserMovieRating>.from(state.ratings);
      topRatings.sort((a, b) {
        final ratingComparison = b.rating.compareTo(a.rating);
        return ratingComparison != 0
            ? ratingComparison
            : b.createdAt.compareTo(a.createdAt);
      });
      return topRatings.take(limit).toList();
    }
  }

  /// Refresca datos desde el servidor
  Future<void> refresh() async {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 [DirectRatings] Provider disposed, ignorando refresh');
      return;
    }

    try {
      LoggerFactory.info('🔄 [DirectRatings] Refrescando datos...');
      state = state.copyWith(isLoading: true, error: null);

      await _syncWithServer();

      // Verificar mounted antes de actualizar estado final
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante refresh, ignorando actualización final');
        return;
      }

      state = state.copyWith(isLoading: false);
      LoggerFactory.info('✅ [DirectRatings] Datos refrescados correctamente');
    } catch (e) {
      LoggerFactory.error('❌ [DirectRatings] Error refrescando datos: $e');

      // Verificar mounted antes de actualizar estado de error
      if (!mounted) {
        LoggerFactory.debug(
            '🚫 [DirectRatings] Provider disposed durante error de refresh, ignorando actualización de error');
        return;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Error refrescando datos: $e',
      );
    }
  }

  /// Limpia error del estado
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    LoggerFactory.info('🔧 [DirectRatings] Limpiando provider...');

    // Cancelar suscripción real-time de forma segura
    if (_realtimeSubscription != null) {
      try {
        _realtimeSubscription!.cancel();
        LoggerFactory.debug(
            '✅ [DirectRatings] Suscripción real-time cancelada');
      } catch (e) {
        LoggerFactory.error(
            '❌ [DirectRatings] Error cancelando suscripción: $e');
      }
      _realtimeSubscription = null;
    }

    super.dispose();
    LoggerFactory.info('✅ [DirectRatings] Provider limpiado correctamente');
  }
}
