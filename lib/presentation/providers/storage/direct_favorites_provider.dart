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
    // No inicializar inmediatamente - esperar hasta que haya usuario autenticado
    _initializeWithCurrentUser();
  }

  final VoidCallback onMovieFavorited;
  final TriggerFreeFavoritesSync _sync = TriggerFreeFavoritesSync.instance;
  RealtimeChannel? _realtimeChannel;
  String? _currentUserId;
  bool _isInitialized = false;

  /// Inicializa con el usuario actual si existe
  void _initializeWithCurrentUser() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      LoggerFactory.info(
          '🎬 DirectFavoritesNotifier: Usuario ya autenticado, inicializando...');
      _currentUserId = currentUser.id;
      _loadFavoritesFromSupabase();
      _setupRealtimeListeners();
      _isInitialized = true;
    } else {
      LoggerFactory.info(
          '🎬 DirectFavoritesNotifier: Sin usuario, esperando autenticación...');
    }
  }

  /// Cargar favoritos directamente desde Supabase
  Future<void> _loadFavoritesFromSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      LoggerFactory.info(
          '🔑 DirectFavorites: currentUser = ${currentUser?.id}');

      if (currentUser == null) {
        LoggerFactory.info('⚠️ DirectFavorites: No hay usuario logueado');
        state = {};
        _currentUserId = null;
        return;
      }

      _currentUserId = currentUser.id;
      LoggerFactory.info(
          '🔑 DirectFavorites: Usuario logueado: $_currentUserId');

      LoggerFactory.debug(
          'DirectFavorites: Cargando favoritos directos desde Supabase...');

      final movies = await _sync.getUserFavorites(currentUser.id);

      final moviesMap = <int, Movie>{};
      for (final movie in movies) {
        moviesMap[movie.id] = movie;
      }

      state = moviesMap;

      LoggerFactory.debug(
          'DirectFavorites: Cargados ${movies.length} favoritos directos');
      LoggerFactory.debug('DirectFavorites: IDs: ${moviesMap.keys.toList()}');
    } catch (e) {
      LoggerFactory.error('DirectFavorites: Error cargando: $e');
      state = {};
    }
  }

  /// Toggle favorito usando solo operaciones directas
  Future<void> toggleFavorite(Movie movie) async {
    final isFavorite = state[movie.id] != null;
    final currentUser = Supabase.instance.client.auth.currentUser;

    LoggerFactory.debug(
        'DirectFavorites: Toggle ${movie.id}:${movie.title} (current: $isFavorite)');

    // Actualización optimista de la UI
    if (isFavorite) {
      state = Map.from(state)..remove(movie.id);
    } else {
      state = {...state, movie.id: movie};
    }

    if (currentUser == null) {
      LoggerFactory.info(
          'DirectFavorites: No hay usuario logueado, solo cambio local');
      return;
    }

    try {
      if (isFavorite) {
        // Remover de Supabase (usando DELETE)
        await _sync.removeFavorite(currentUser.id, movie.id);
        LoggerFactory.info(
            'DirectFavorites: Favorito removido: ${movie.title}');
      } else {
        // Agregar a Supabase (usando INSERT)
        await _sync.addFavorite(currentUser.id, movie);
        LoggerFactory.info('DirectFavorites: Favorito añadido: ${movie.title}');
        onMovieFavorited();
      }
    } catch (e) {
      LoggerFactory.error('DirectFavorites: Error en toggle: $e');

      // Revertir cambio optimista en caso de error
      if (isFavorite) {
        state = {...state, movie.id: movie};
      } else {
        state = Map.from(state)..remove(movie.id);
      }

      // No rethrow para evitar errores en UI - el cambio optimista ya se revirtió
      LoggerFactory.warning(
          'DirectFavorites: Operación fallida pero estado revertido');
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
          '🔊 DirectFavorites: Configurando listeners de tiempo real...');

      // Crear canal de tiempo real para la tabla user_favorites
      // Usar un canal único con timestamp para evitar conflictos
      final channelName =
          'favorites_realtime_${DateTime.now().millisecondsSinceEpoch}';
      LoggerFactory.info('🔊 DirectFavorites: Creando canal: $channelName');

      _realtimeChannel =
          Supabase.instance.client.channel(channelName).onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'user_favorites',
                callback: _handleRealtimeEvent,
              );

      // Suscribir al canal con logging mejorado
      _realtimeChannel!.subscribe((status, [error]) {
        if (error != null) {
          LoggerFactory.error('🔊 DirectFavorites: Error en canal: $error');
        } else {
          LoggerFactory.info('🔊 DirectFavorites: Estado del canal: $status');
          if (status == RealtimeSubscribeStatus.subscribed) {
            LoggerFactory.info(
                '✅ DirectFavorites: Canal suscrito exitosamente!');
          }
        }
      });
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectFavorites: Error configurando listeners: $e');
    }
  }

  /// Manejar cambios de tiempo real desde Supabase
  void _handleRealtimeEvent(PostgresChangePayload payload) {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectFavorites: Provider disposed, ignorando evento real-time');
      return;
    }

    try {
      LoggerFactory.info('🔊 DirectFavorites: ===== CAMBIO RECIBIDO =====');
      LoggerFactory.info(
          '🔊 DirectFavorites: Tipo de evento: ${payload.eventType}');
      LoggerFactory.info('🔍 DirectFavorites: newRecord: ${payload.newRecord}');
      LoggerFactory.info('🔍 DirectFavorites: oldRecord: ${payload.oldRecord}');

      // Para eventos DELETE, newRecord estará vacío y oldRecord tendrá los datos
      final data =
          payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;

      LoggerFactory.info('🔍 DirectFavorites: Datos a procesar: $data');

      final userId = data['user_id'] as String?;
      final movieId = data['movie_id'] as int?;
      final supabaseRecordId = data['id']?.toString();

      LoggerFactory.info('🔍 DirectFavorites: user_id del evento: $userId');
      LoggerFactory.info('🔍 DirectFavorites: user_id actual: $_currentUserId');
      LoggerFactory.info('🔍 DirectFavorites: movie_id del evento: $movieId');
      LoggerFactory.info(
          '🔍 DirectFavorites: supabase_id del evento: $supabaseRecordId');

      // Si no tenemos user_id pero tenemos supabase record_id, intentar manejar DELETE
      if (userId == null &&
          payload.eventType == PostgresChangeEvent.delete &&
          supabaseRecordId != null) {
        LoggerFactory.info(
            '🔍 DirectFavorites: DELETE sin user_id, intentando por record_id');
        _handleDeleteBySupabaseId(supabaseRecordId);
        return;
      }

      if (userId != _currentUserId) {
        LoggerFactory.info(
            '🔊 DirectFavorites: Cambio de otro usuario, ignorando');
        return;
      }

      // Si no tenemos movie_id pero es un DELETE, intentar buscar por supabase record_id
      if (movieId == null &&
          payload.eventType == PostgresChangeEvent.delete &&
          supabaseRecordId != null) {
        LoggerFactory.info(
            '🔍 DirectFavorites: DELETE sin movie_id, buscando por record_id');
        _handleDeleteBySupabaseId(supabaseRecordId);
        return;
      }

      if (movieId == null) {
        LoggerFactory.error(
            '❌ DirectFavorites: movie_id es null, ignorando evento');
        return;
      }

      LoggerFactory.info(
          '🔊 DirectFavorites: ✅ Procesando cambio del usuario actual');

      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          LoggerFactory.info(
              '➕ DirectFavorites: Procesando INSERT para movie: $movieId');
          _handleRemoteInsert(data);
          break;
        case PostgresChangeEvent.delete:
          LoggerFactory.info(
              '🗑️ DirectFavorites: ===== PROCESANDO DELETE =====');
          LoggerFactory.info(
              '🗑️ DirectFavorites: Movie ID a eliminar: $movieId');
          LoggerFactory.info(
              '🗑️ DirectFavorites: Estado actual antes del DELETE: ${state.keys.toList()}');

          // Procesar DELETE inmediatamente sin delay
          _handleRemoteDelete(movieId);
          break;
        case PostgresChangeEvent.update:
          LoggerFactory.info(
              '🔄 DirectFavorites: Procesando UPDATE para movie: $movieId');
          _handleRemoteUpdate(data);
          break;
        case PostgresChangeEvent.all:
          LoggerFactory.info('🔄 DirectFavorites: Procesando evento genérico');
          _handleGenericRealtimeEvent(payload, data, movieId);
          break;
      }
    } catch (e) {
      LoggerFactory.error('❌ DirectFavorites: Error procesando cambio: $e');
      LoggerFactory.error(
          '❌ DirectFavorites: Stack trace: ${StackTrace.current}');
    }
  }

  /// Manejar inserción remota (otro dispositivo agregó favorito)
  void _handleRemoteInsert(Map<String, dynamic> data) {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectFavorites: Provider disposed, ignorando inserción remota');
      return;
    }

    try {
      final movieId = data['movie_id'] as int;
      final isDeleted = data['is_deleted'] as bool? ?? false;

      if (!isDeleted && !state.containsKey(movieId)) {
        final movie = _recordToMovie(data);
        state = {...state, movieId: movie};

        LoggerFactory.info(
            '✅ DirectFavorites: Favorito agregado remotamente: ${movie.title}');
      }
    } catch (e) {
      LoggerFactory.error('❌ DirectFavorites: Error en inserción remota: $e');
    }
  }

  /// Manejar eliminación remota (otro dispositivo removió favorito)
  void _handleRemoteDelete(int movieId) {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectFavorites: Provider disposed, ignorando eliminación remota');
      return;
    }

    try {
      LoggerFactory.info(
          '🗑️ DirectFavorites: ===== _handleRemoteDelete INICIADO =====');
      LoggerFactory.info('🗑️ DirectFavorites: Movie ID a procesar: $movieId');
      LoggerFactory.info(
          '🗑️ DirectFavorites: Estado actual keys: ${state.keys.toList()}');
      LoggerFactory.info(
          '🗑️ DirectFavorites: Estado actual contiene $movieId? ${state.containsKey(movieId)}');

      if (state.containsKey(movieId)) {
        final movie = state[movieId];
        final oldState = Map<int, Movie>.from(state);

        LoggerFactory.info(
            '🗑️ DirectFavorites: Movie a eliminar: ${movie?.title} (ID: $movieId)');
        LoggerFactory.info(
            '🗑️ DirectFavorites: Estado antes de eliminar: ${oldState.keys.length} favoritos');

        state = Map.from(state)..remove(movieId);

        LoggerFactory.info(
            '🗑️ DirectFavorites: Estado después de eliminar: ${state.keys.length} favoritos');
        LoggerFactory.info(
            '✅ DirectFavorites: 🎉 FAVORITO REMOVIDO REMOTAMENTE: ${movie?.title} (ID: $movieId)');
        LoggerFactory.info(
            '🗑️ DirectFavorites: Nuevas keys del estado: ${state.keys.toList()}');
      } else {
        LoggerFactory.warning(
            '⚠️ DirectFavorites: Intento de remover favorito que no existe localmente: $movieId');
        LoggerFactory.info(
            '🗑️ DirectFavorites: Favoritos actuales en estado: ${state.keys.toList()}');
      }
    } catch (e) {
      LoggerFactory.error('❌ DirectFavorites: Error en eliminación remota: $e');
      LoggerFactory.error(
          '❌ DirectFavorites: Stack trace: ${StackTrace.current}');
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
          '❌ DirectFavorites: Error en actualización remota: $e');
    }
  }

  /// Convierte un record de Supabase a Movie
  Movie _recordToMovie(Map<String, dynamic> record) {
    return Movie(
      id: record['movie_id'] as int,
      title: record['movie_title'] as String,
      posterPath: record['movie_poster_path'] as String? ?? '',
      backdropPath: record['movie_backdrop_path'] as String? ?? '',
      overview: record['movie_overview'] as String? ?? '',
      releaseDate: record['movie_release_date'] != null
          ? (DateTime.tryParse(record['movie_release_date'] as String) ??
              DateTime.now())
          : DateTime.now(),
      voteAverage: (record['movie_vote_average'] as num?)?.toDouble() ?? 0.0,
      genreIds: [],
      adult: false,
      originalLanguage: 'en',
      originalTitle: record['movie_title'] as String,
      popularity: 0.0,
      video: false,
      voteCount: 0,
    );
  }

  /// Habilitar cuando el usuario se autentica
  Future<void> enableAfterLogin() async {
    LoggerFactory.info('🔐 DirectFavorites: Habilitando después del login...');

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.warning(
          '🔐 DirectFavorites: No hay usuario autenticado, omitiendo inicialización');
      return;
    }

    _currentUserId = currentUser.id;

    // Solo inicializar si no se ha hecho antes
    if (!_isInitialized) {
      await _loadFavoritesFromSupabase();
      _setupRealtimeListeners();
      _isInitialized = true;
    } else {
      LoggerFactory.info(
          '🔐 DirectFavorites: Ya inicializado, solo recargando datos...');
      await _loadFavoritesFromSupabase();
    }

    LoggerFactory.info(
        '✅ DirectFavorites: Favoritos habilitados correctamente');
  }

  /// Manejar eliminación usando el ID de Supabase cuando no tenemos movie_id
  void _handleDeleteBySupabaseId(String supabaseRecordId) async {
    try {
      LoggerFactory.info(
          '🗑️ DirectFavorites: ===== _handleDeleteBySupabaseId INICIADO =====');
      LoggerFactory.info(
          '🗑️ DirectFavorites: Supabase record ID: $supabaseRecordId');
      LoggerFactory.info(
          '🗑️ DirectFavorites: Estado actual keys: ${state.keys.toList()}');

      // Opción: Forzar un refresh completo desde Supabase
      LoggerFactory.info(
          '🔄 DirectFavorites: Forzando refresh completo para detectar cambios');
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (currentUser != null) {
        final remoteFavorites = await _sync.getUserFavorites(currentUser.id);
        final remoteFavoritesMap = <int, Movie>{};
        for (final movie in remoteFavorites) {
          remoteFavoritesMap[movie.id] = movie;
        }

        // Comparar con el estado actual para detectar qué se eliminó
        final currentMovieIds = state.keys.toSet();
        final remoteMovieIds = remoteFavoritesMap.keys.toSet();
        final deletedMovieIds = currentMovieIds.difference(remoteMovieIds);

        if (deletedMovieIds.isNotEmpty) {
          LoggerFactory.info(
              '🗑️ DirectFavorites: Detected deleted movies: $deletedMovieIds');

          // Eliminar las películas que ya no están en el remoto
          final newState = Map<int, Movie>.from(state);
          for (final deletedId in deletedMovieIds) {
            final deletedMovie = newState.remove(deletedId);
            LoggerFactory.info(
                '✅ DirectFavorites: Removed movie: ${deletedMovie?.title} (ID: $deletedId)');
          }

          state = newState;
          LoggerFactory.info(
              '🗑️ DirectFavorites: State updated after comparison');
        } else {
          LoggerFactory.info(
              '🔍 DirectFavorites: No differences found in comparison');
        }
      } else {
        LoggerFactory.warning(
            '⚠️ DirectFavorites: No current user for refresh');
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectFavorites: Error en eliminación por Supabase ID: $e');
      LoggerFactory.error(
          '❌ DirectFavorites: Stack trace: ${StackTrace.current}');
    }
  }

  /// Manejar evento genérico de tiempo real (PostgresChangeEvent.all)
  void _handleGenericRealtimeEvent(
      PostgresChangePayload payload, Map<String, dynamic> data, int? movieId) {
    try {
      LoggerFactory.info('🔄 DirectFavorites: Manejando evento genérico');

      // Determinar el tipo de operación basado en los datos
      final isDeleted = data['is_deleted'] as bool? ?? false;

      if (isDeleted && movieId != null) {
        LoggerFactory.info('🗑️ DirectFavorites: Evento genérico -> DELETE');
        _handleRemoteDelete(movieId);
      } else if (!isDeleted && movieId != null) {
        LoggerFactory.info(
            '➕ DirectFavorites: Evento genérico -> INSERT/UPDATE');
        _handleRemoteInsert(data);
      }
    } catch (e) {
      LoggerFactory.error('❌ DirectFavorites: Error en evento genérico: $e');
    }
  }

  @override
  void dispose() {
    LoggerFactory.info(
        '🔊 DirectFavorites: Cerrando listeners de tiempo real...');
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
