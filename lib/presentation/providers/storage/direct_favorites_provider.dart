import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    _loadFavoritesFromSupabase();
    _setupRealtimeListeners();
  }

  final VoidCallback onMovieFavorited;
  final TriggerFreeFavoritesSync _sync = TriggerFreeFavoritesSync.instance;
  RealtimeChannel? _realtimeChannel;
  String? _currentUserId;

  /// Cargar favoritos directamente desde Supabase
  Future<void> _loadFavoritesFromSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        state = {};
        _currentUserId = null;
        return;
      }

      _currentUserId = currentUser.id;

      if (kDebugMode) {
        print(
            '🔄 [DirectFavorites] Cargando favoritos directos desde Supabase...');
      }

      final movies = await _sync.getUserFavorites(currentUser.id);

      final moviesMap = <int, Movie>{};
      for (final movie in movies) {
        moviesMap[movie.id] = movie;
      }

      state = moviesMap;

      if (kDebugMode) {
        print(
            '✅ [DirectFavorites] Cargados ${movies.length} favoritos directos');
        print('🔍 [DirectFavorites] IDs: ${moviesMap.keys.toList()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [DirectFavorites] Error cargando: $e');
      }
      state = {};
    }
  }

  /// Toggle favorito usando solo operaciones directas
  Future<void> toggleFavorite(Movie movie) async {
    final isFavorite = state[movie.id] != null;
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (kDebugMode) {
      print(
          '🔍 [DirectFavorites] Toggle ${movie.id}:${movie.title} (current: $isFavorite)');
    }

    // Actualización optimista de la UI
    if (isFavorite) {
      state = Map.from(state)..remove(movie.id);
    } else {
      state = {...state, movie.id: movie};
    }

    if (currentUser == null) {
      if (kDebugMode) {
        print(
            'ℹ️ [DirectFavorites] No hay usuario logueado, solo cambio local');
      }
      return;
    }

    try {
      if (isFavorite) {
        // Remover de Supabase (usando DELETE)
        await _sync.removeFavorite(currentUser.id, movie.id);
        if (kDebugMode) {
          print('✅ [DirectFavorites] Favorito removido: ${movie.title}');
        }
      } else {
        // Agregar a Supabase (usando INSERT)
        await _sync.addFavorite(currentUser.id, movie);
        if (kDebugMode) {
          print('✅ [DirectFavorites] Favorito añadido: ${movie.title}');
        }
        onMovieFavorited();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [DirectFavorites] Error en toggle: $e');
      }

      // Revertir cambio optimista
      if (isFavorite) {
        state = {...state, movie.id: movie};
      } else {
        state = Map.from(state)..remove(movie.id);
      }

      // Si el error es de trigger, mostrar mensaje específico
      if (e.toString().contains('updated_at')) {
        if (kDebugMode) {
          print('🔧 [DirectFavorites] Error de trigger PostgreSQL detectado');
        }
      }
    }
  }

  /// Refresh manual de favoritos
  Future<void> refresh() async {
    await _loadFavoritesFromSupabase();
  }

  /// Método de compatibilidad para widgets que usan loadNextPage
  Future<List<Movie>> loadNextPage() async {
    await _loadFavoritesFromSupabase();
    return state.values.toList();
  }

  /// Configurar listeners de tiempo real para Supabase
  void _setupRealtimeListeners() {
    try {
      LoggerFactory.info(
          '🔊 [DirectFavorites] Configurando listeners de tiempo real...');

      // Crear canal de tiempo real para la tabla user_favorites
      _realtimeChannel = Supabase.instance.client
          .channel('favorites_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_favorites',
            callback: _handleRealtimeChange,
          );

      // Suscribir al canal
      _realtimeChannel!.subscribe((status, [error]) {
        if (error != null) {
          LoggerFactory.error('🔊 [DirectFavorites] Error en canal: $error');
        } else {
          LoggerFactory.info('🔊 [DirectFavorites] Estado del canal: $status');
        }
      });
    } catch (e) {
      LoggerFactory.error(
          '❌ [DirectFavorites] Error configurando listeners: $e');
    }
  }

  /// Manejar cambios de tiempo real desde Supabase
  void _handleRealtimeChange(PostgresChangePayload payload) {
    try {
      LoggerFactory.info(
          '🔊 [DirectFavorites] Cambio recibido: ${payload.eventType}');

      // Solo procesar cambios de otros dispositivos (no el nuestro)
      final data = payload.newRecord;

      final userId = data['user_id'] as String?;
      if (userId != _currentUserId) {
        LoggerFactory.info(
            '🔊 [DirectFavorites] Cambio de otro usuario, ignorando');
        return;
      }

      final movieId = data['movie_id'] as int?;
      if (movieId == null) return;

      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          _handleRemoteInsert(data);
          break;
        case PostgresChangeEvent.delete:
          _handleRemoteDelete(movieId);
          break;
        case PostgresChangeEvent.update:
          _handleRemoteUpdate(data);
          break;
        case PostgresChangeEvent.all:
          // Manejar cualquier tipo de evento analizando el payload
          _handleGenericRealtimeEvent(payload, data, movieId);
          break;
      }
    } catch (e) {
      LoggerFactory.error('❌ [DirectFavorites] Error procesando cambio: $e');
    }
  }

  /// Manejar inserción remota (otro dispositivo agregó favorito)
  void _handleRemoteInsert(Map<String, dynamic> data) {
    try {
      final movieId = data['movie_id'] as int;
      final isDeleted = data['is_deleted'] as bool? ?? false;

      if (!isDeleted && !state.containsKey(movieId)) {
        final movie = _dataToMovie(data);
        state = {...state, movieId: movie};

        LoggerFactory.info(
            '✅ [DirectFavorites] Favorito agregado remotamente: ${movie.title}');

        if (kDebugMode) {
          print(
              '🔊 [DirectFavorites] Nuevo favorito desde otro dispositivo: ${movie.title}');
        }
      }
    } catch (e) {
      LoggerFactory.error('❌ [DirectFavorites] Error en inserción remota: $e');
    }
  }

  /// Manejar eliminación remota (otro dispositivo removió favorito)
  void _handleRemoteDelete(int movieId) {
    try {
      if (state.containsKey(movieId)) {
        final movie = state[movieId];
        state = Map.from(state)..remove(movieId);

        LoggerFactory.info(
            '🗑️ [DirectFavorites] Favorito removido remotamente: $movieId');

        if (kDebugMode) {
          print(
              '🔊 [DirectFavorites] Favorito removido desde otro dispositivo: ${movie?.title}');
        }
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ [DirectFavorites] Error en eliminación remota: $e');
    }
  }

  /// Manejar actualización remota
  void _handleRemoteUpdate(Map<String, dynamic> data) {
    try {
      final movieId = data['movie_id'] as int;
      final isDeleted = data['is_deleted'] as bool? ?? false;

      if (isDeleted && state.containsKey(movieId)) {
        // Favorito marcado como eliminado
        _handleRemoteDelete(movieId);
      } else if (!isDeleted && !state.containsKey(movieId)) {
        // Favorito restaurado
        _handleRemoteInsert(data);
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ [DirectFavorites] Error en actualización remota: $e');
    }
  }

  /// Manejar evento genérico de tiempo real (PostgresChangeEvent.all)
  void _handleGenericRealtimeEvent(
      PostgresChangePayload payload, 
      Map<String, dynamic>? data, 
      int? movieId) {
    try {
      LoggerFactory.info(
          '🔄 [DirectFavorites] Procesando evento genérico: ${payload.eventType}');

      // Si no hay datos, intentar usar oldRecord para eliminaciones
      final eventData = data ?? payload.oldRecord;
      
      if (eventData == null) {
        LoggerFactory.warning(
            '⚠️ [DirectFavorites] No hay datos disponibles en el payload');
        return;
      }

      final eventMovieId = movieId ?? eventData['movie_id'] as int?;
      if (eventMovieId == null) {
        LoggerFactory.warning(
            '⚠️ [DirectFavorites] No se pudo obtener movie_id del evento');
        return;
      }

      // Determinar el tipo de acción basándose en los datos disponibles
      final isDeleted = eventData['is_deleted'] as bool? ?? false;
      final hasNewRecord = payload.newRecord != null;
      final hasOldRecord = payload.oldRecord != null;

      if (hasNewRecord && !hasOldRecord) {
        // Nuevo registro creado - INSERT
        LoggerFactory.info(
            '➕ [DirectFavorites] Detectado INSERT genérico para movie: $eventMovieId');
        if (!isDeleted) {
          _handleRemoteInsert(payload.newRecord!);
        }
      } else if (!hasNewRecord && hasOldRecord) {
        // Registro eliminado - DELETE
        LoggerFactory.info(
            '🗑️ [DirectFavorites] Detectado DELETE genérico para movie: $eventMovieId');
        _handleRemoteDelete(eventMovieId);
      } else if (hasNewRecord && hasOldRecord) {
        // Registro actualizado - UPDATE
        LoggerFactory.info(
            '🔄 [DirectFavorites] Detectado UPDATE genérico para movie: $eventMovieId');
        _handleRemoteUpdate(payload.newRecord!);
      } else {
        // Caso fallback: usar is_deleted para determinar acción
        LoggerFactory.info(
            '🔍 [DirectFavorites] Usando is_deleted para determinar acción: $isDeleted');
        if (isDeleted) {
          _handleRemoteDelete(eventMovieId);
        } else {
          _handleRemoteInsert(eventData);
        }
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ [DirectFavorites] Error procesando evento genérico: $e');
    }
  }

  /// Convertir data de Supabase a Movie
  Movie _dataToMovie(Map<String, dynamic> data) {
    return Movie(
      id: data['movie_id'] as int,
      title: data['movie_title'] as String,
      posterPath: data['movie_poster_path'] as String? ?? '',
      backdropPath: data['movie_backdrop_path'] as String? ?? '',
      overview: data['movie_overview'] as String? ?? '',
      releaseDate: data['movie_release_date'] != null
          ? (DateTime.tryParse(data['movie_release_date'] as String) ??
              DateTime.now())
          : DateTime.now(),
      voteAverage: (data['movie_vote_average'] as num?)?.toDouble() ?? 0.0,
      genreIds: [],
      adult: false,
      originalLanguage: 'en',
      originalTitle: data['movie_title'] as String,
      popularity: 0.0,
      video: false,
      voteCount: 0,
    );
  }

  /// Habilitar cuando el usuario se autentica
  Future<void> enableAfterLogin() async {
    if (kDebugMode) {
      print('🔓 [DirectFavorites] Usuario autenticado, cargando favoritos...');
    }
    await _loadFavoritesFromSupabase();
  }

  @override
  void dispose() {
    LoggerFactory.info(
        '🔊 [DirectFavorites] Cerrando listeners de tiempo real...');
    _realtimeChannel?.unsubscribe();
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
