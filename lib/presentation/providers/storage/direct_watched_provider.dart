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
    _loadWatchedFromSupabase();
    _setupRealtimeListeners();
    LoggerFactory.info('🎬 DirectWatchedNotifier: Inicialización completada');
  }

  final Function(Movie movie) onMovieWatched;
  final TriggerFreeWatchedSync _sync = TriggerFreeWatchedSync.instance;
  RealtimeChannel? _realtimeChannel;
  String? _currentUserId;

  /// Cargar películas vistas directamente desde Supabase
  Future<void> _loadWatchedFromSupabase() async {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectWatched: Provider disposed, ignorando carga inicial');
      return;
    }

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        state = {};
        _currentUserId = null;
        return;
      }

      _currentUserId = currentUser.id;

      LoggerFactory.info(
          'DirectWatched: Cargando vistas directas desde Supabase...');

      final movies = await _sync.getUserWatchedMovies(currentUser.id);

      final moviesMap = <int, Movie>{};
      for (final movie in movies) {
        moviesMap[movie.id] = movie;
      }

      state = moviesMap;

      LoggerFactory.info(
          'DirectWatched: Cargadas ${movies.length} vistas directas');
      LoggerFactory.debug('DirectWatched: IDs: ${moviesMap.keys.toList()}');
    } catch (e) {
      LoggerFactory.error('DirectWatched: Error cargando: $e');
      state = {};
    }
  }

  /// Toggle watched usando solo operaciones directas
  Future<void> toggleWatched(Movie movie) async {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectWatched: Provider disposed, ignorando toggle');
      return;
    }

    final isWatched = state[movie.id] != null;
    final currentUser = Supabase.instance.client.auth.currentUser;

    LoggerFactory.debug(
        'DirectWatched: Toggle ${movie.id}:${movie.title} (current: $isWatched)');

    // Actualización optimista de la UI
    if (isWatched) {
      state = Map.from(state)..remove(movie.id);
    } else {
      state = {...state, movie.id: movie};
    }

    if (currentUser == null) {
      LoggerFactory.info(
          'DirectWatched: No hay usuario logueado, solo cambio local');
      return;
    }

    try {
      if (isWatched) {
        // Remover de Supabase (usando DELETE)
        await _sync.removeWatchedMovie(currentUser.id, movie.id);
        LoggerFactory.info('DirectWatched: Vista removida: ${movie.title}');
      } else {
        // Agregar a Supabase (usando INSERT)
        await _sync.addWatchedMovie(currentUser.id, movie);
        LoggerFactory.info('DirectWatched: Vista añadida: ${movie.title}');
        onMovieWatched(movie);
      }
    } catch (e) {
      LoggerFactory.error('DirectWatched: Error en toggle: $e');

      // Revertir cambio optimista
      if (isWatched) {
        state = {...state, movie.id: movie};
      } else {
        state = Map.from(state)..remove(movie.id);
      }

      // Si el error es de trigger, mostrar mensaje específico
      if (e.toString().contains('updated_at')) {
        LoggerFactory.warning(
            'DirectWatched: Error de trigger PostgreSQL detectado');
      }
    }
  }

  /// Refresh manual de vistas
  Future<void> refresh() async {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectWatched: Provider disposed, ignorando refresh');
      return;
    }

    await _loadWatchedFromSupabase();
  }

  /// Método de compatibilidad para widgets que usan loadNextPage
  Future<List<Movie>> loadNextPage() async {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectWatched: Provider disposed, ignorando loadNextPage');
      return [];
    }

    await _loadWatchedFromSupabase();
    return state.values.toList();
  }

  /// Configurar listeners de tiempo real para Supabase
  void _setupRealtimeListeners() {
    try {
      LoggerFactory.info(
          '🔊 DirectWatched: Configurando listeners de tiempo real...');

      // Crear canal de tiempo real para la tabla user_watched_movies
      // Usar un canal único con timestamp para evitar conflictos
      final channelName =
          'watched_realtime_${DateTime.now().millisecondsSinceEpoch}';
      LoggerFactory.info('🔊 DirectWatched: Creando canal: $channelName');

      _realtimeChannel =
          Supabase.instance.client.channel(channelName).onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'user_watched_movies',
                callback: _handleRealtimeChange,
              );

      // Suscribir al canal con logging mejorado
      _realtimeChannel!.subscribe((status, [error]) {
        if (error != null) {
          LoggerFactory.error('🔊 DirectWatched: Error en canal: $error');
        } else {
          LoggerFactory.info('🔊 DirectWatched: Estado del canal: $status');
          if (status == RealtimeSubscribeStatus.subscribed) {
            LoggerFactory.info('✅ DirectWatched: Canal suscrito exitosamente!');
          }
        }
      });
    } catch (e) {
      LoggerFactory.error('❌ DirectWatched: Error configurando listeners: $e');
    }
  }

  /// Manejar cambios de tiempo real desde Supabase
  void _handleRealtimeChange(PostgresChangePayload payload) {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectWatched: Provider disposed, ignorando evento real-time');
      return;
    }

    try {
      LoggerFactory.info('🔊 DirectWatched: ===== CAMBIO RECIBIDO =====');
      LoggerFactory.info(
          '🔊 DirectWatched: Tipo de evento: ${payload.eventType}');
      LoggerFactory.info('🔍 DirectWatched: newRecord: ${payload.newRecord}');
      LoggerFactory.info('🔍 DirectWatched: oldRecord: ${payload.oldRecord}');

      // Para eventos DELETE, newRecord estará vacío y oldRecord tendrá los datos
      final data =
          payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;

      LoggerFactory.info('🔍 DirectWatched: Datos a procesar: $data');

      final userId = data['user_id'] as String?;
      final movieId = data['movie_id'] as int?;
      final supabaseRecordId = data['id'] as String?;

      LoggerFactory.info('🔍 DirectWatched: user_id del evento: $userId');
      LoggerFactory.info('🔍 DirectWatched: user_id actual: $_currentUserId');
      LoggerFactory.info('🔍 DirectWatched: movie_id del evento: $movieId');
      LoggerFactory.info(
          '🔍 DirectWatched: supabase record_id: $supabaseRecordId');

      // Si no tenemos user_id pero es un DELETE y tenemos supabase record_id,
      // podemos intentar encontrar la película por el estado actual
      if (userId == null &&
          payload.eventType == PostgresChangeEvent.delete &&
          supabaseRecordId != null) {
        LoggerFactory.info(
            '🔍 DirectWatched: DELETE sin user_id, buscando por record_id en estado actual');
        _handleDeleteBySupabaseId(supabaseRecordId);
        return;
      }

      if (userId != _currentUserId) {
        LoggerFactory.info(
            '🔊 DirectWatched: Cambio de otro usuario, ignorando');
        return;
      }

      // Si no tenemos movie_id pero es un DELETE, intentar buscar por supabase record_id
      if (movieId == null &&
          payload.eventType == PostgresChangeEvent.delete &&
          supabaseRecordId != null) {
        LoggerFactory.info(
            '🔍 DirectWatched: DELETE sin movie_id, buscando por record_id');
        _handleDeleteBySupabaseId(supabaseRecordId);
        return;
      }

      if (movieId == null) {
        LoggerFactory.error(
            '❌ DirectWatched: movie_id es null, ignorando evento');
        return;
      }

      LoggerFactory.info(
          '🔊 DirectWatched: ✅ Procesando cambio del usuario actual');

      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          LoggerFactory.info(
              '➕ DirectWatched: Procesando INSERT para movie: $movieId');
          _handleRemoteInsert(data);
          break;
        case PostgresChangeEvent.delete:
          LoggerFactory.info(
              '🗑️ DirectWatched: ===== PROCESANDO DELETE =====');
          LoggerFactory.info(
              '🗑️ DirectWatched: Movie ID a eliminar: $movieId');
          LoggerFactory.info(
              '🗑️ DirectWatched: Estado actual antes del DELETE: ${state.keys.toList()}');

          // Procesar DELETE inmediatamente sin delay
          _handleRemoteDelete(movieId);
          break;
        case PostgresChangeEvent.update:
          LoggerFactory.info(
              '🔄 DirectWatched: Procesando UPDATE para movie: $movieId');
          _handleRemoteUpdate(data);
          break;
        case PostgresChangeEvent.all:
          LoggerFactory.info('🔄 DirectWatched: Procesando evento genérico');
          _handleGenericRealtimeEvent(payload, data, movieId);
          break;
      }
    } catch (e) {
      LoggerFactory.error('❌ DirectWatched: Error procesando cambio: $e');
      LoggerFactory.error(
          '❌ DirectWatched: Stack trace: ${StackTrace.current}');
    }
  }

  /// Manejar inserción remota (otro dispositivo agregó vista)
  void _handleRemoteInsert(Map<String, dynamic> data) {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectWatched: Provider disposed, ignorando inserción remota');
      return;
    }

    try {
      final movieId = data['movie_id'] as int;
      final isDeleted = data['is_deleted'] as bool? ?? false;

      if (!isDeleted && !state.containsKey(movieId)) {
        final movie = _dataToMovie(data);
        state = {...state, movieId: movie};

        LoggerFactory.info(
            '✅ DirectWatched: Vista agregada remotamente: ${movie.title}');

        LoggerFactory.debug(
            'DirectWatched: Nueva vista desde otro dispositivo: ${movie.title}');
      }
    } catch (e) {
      LoggerFactory.error('❌ DirectWatched: Error en inserción remota: $e');
    }
  }

  /// Manejar eliminación remota (otro dispositivo removió vista)
  void _handleRemoteDelete(int movieId) {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectWatched: Provider disposed, ignorando eliminación remota');
      return;
    }

    try {
      LoggerFactory.info(
          '🗑️ DirectWatched: ===== _handleRemoteDelete INICIADO =====');
      LoggerFactory.info('🗑️ DirectWatched: Movie ID a procesar: $movieId');
      LoggerFactory.info(
          '🗑️ DirectWatched: Estado actual keys: ${state.keys.toList()}');
      LoggerFactory.info(
          '🗑️ DirectWatched: Estado actual contiene $movieId? ${state.containsKey(movieId)}');

      if (state.containsKey(movieId)) {
        final movie = state[movieId];
        final oldState = Map<int, Movie>.from(state);

        LoggerFactory.info(
            '🗑️ DirectWatched: Movie a eliminar: ${movie?.title} (ID: $movieId)');
        LoggerFactory.info(
            '🗑️ DirectWatched: Estado antes de eliminar: ${oldState.keys.length} vistas');

        state = Map.from(state)..remove(movieId);

        LoggerFactory.info(
            '🗑️ DirectWatched: Estado después de eliminar: ${state.keys.length} vistas');
        LoggerFactory.info(
            '✅ DirectWatched: 🎉 VISTA REMOVIDA REMOTAMENTE: ${movie?.title} (ID: $movieId)');
        LoggerFactory.info(
            '🗑️ DirectWatched: Nuevas keys del estado: ${state.keys.toList()}');
      } else {
        LoggerFactory.warning(
            '⚠️ DirectWatched: Intento de remover vista que no existe localmente: $movieId');
        LoggerFactory.info(
            '🗑️ DirectWatched: Vistas actuales en estado: ${state.keys.toList()}');
      }
    } catch (e) {
      LoggerFactory.error('❌ DirectWatched: Error en eliminación remota: $e');
      LoggerFactory.error(
          '❌ DirectWatched: Stack trace: ${StackTrace.current}');
    }
  }

  /// Manejar eliminación usando el ID de Supabase cuando no tenemos movie_id
  void _handleDeleteBySupabaseId(String supabaseRecordId) async {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectWatched: Provider disposed, ignorando eliminación por Supabase ID');
      return;
    }

    try {
      LoggerFactory.info(
          '🗑️ DirectWatched: ===== _handleDeleteBySupabaseId INICIADO =====');
      LoggerFactory.info(
          '🗑️ DirectWatched: Supabase record ID: $supabaseRecordId');
      LoggerFactory.info(
          '🗑️ DirectWatched: Estado actual keys: ${state.keys.toList()}');

      // Opción: Forzar un refresh completo desde Supabase
      LoggerFactory.info(
          '🔄 DirectWatched: Forzando refresh completo para detectar cambios');
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (currentUser != null) {
        final remoteWatched = await _sync.getUserWatchedMovies(currentUser.id);
        final remoteMoviesMap = <int, Movie>{};
        for (final movie in remoteWatched) {
          remoteMoviesMap[movie.id] = movie;
        }

        // Comparar con el estado actual para detectar qué se eliminó
        final currentMovieIds = state.keys.toSet();
        final remoteMovieIds = remoteMoviesMap.keys.toSet();
        final deletedMovieIds = currentMovieIds.difference(remoteMovieIds);

        if (deletedMovieIds.isNotEmpty) {
          LoggerFactory.info(
              '🗑️ DirectWatched: Detected deleted movies: $deletedMovieIds');

          // Eliminar las películas que ya no están en el remoto
          final newState = Map<int, Movie>.from(state);
          for (final deletedId in deletedMovieIds) {
            final deletedMovie = newState.remove(deletedId);
            LoggerFactory.info(
                '✅ DirectWatched: Removed movie: ${deletedMovie?.title} (ID: $deletedId)');
          }

          state = newState;
          LoggerFactory.info(
              '🗑️ DirectWatched: State updated after comparison');
        } else {
          LoggerFactory.info(
              '🔍 DirectWatched: No differences found in comparison');
        }
      } else {
        LoggerFactory.warning('⚠️ DirectWatched: No current user for refresh');
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectWatched: Error en eliminación por Supabase ID: $e');
      LoggerFactory.error(
          '❌ DirectWatched: Stack trace: ${StackTrace.current}');
    }
  }

  /// Manejar actualización remota
  void _handleRemoteUpdate(Map<String, dynamic> data) {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectWatched: Provider disposed, ignorando actualización remota');
      return;
    }

    try {
      final movieId = data['movie_id'] as int;
      final isDeleted = data['is_deleted'] as bool? ?? false;

      if (isDeleted && state.containsKey(movieId)) {
        // Vista marcada como eliminada
        _handleRemoteDelete(movieId);
      } else if (!isDeleted && !state.containsKey(movieId)) {
        // Vista restaurada
        _handleRemoteInsert(data);
      }
    } catch (e) {
      LoggerFactory.error('❌ DirectWatched: Error en actualización remota: $e');
    }
  }

  /// Manejar evento genérico de tiempo real (PostgresChangeEvent.all)
  void _handleGenericRealtimeEvent(
      PostgresChangePayload payload, Map<String, dynamic>? data, int? movieId) {
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectWatched: Provider disposed, ignorando evento genérico');
      return;
    }

    try {
      LoggerFactory.info(
          '🔄 DirectWatched: Procesando evento genérico: ${payload.eventType}');

      // Si no hay datos, intentar usar oldRecord para eliminaciones (mismo que favoritos)
      final eventData =
          (data != null && data.isNotEmpty) ? data : payload.oldRecord;

      final eventMovieId = movieId ?? eventData['movie_id'] as int?;
      if (eventMovieId == null) {
        LoggerFactory.warning(
            '⚠️ DirectWatched: No se pudo obtener movie_id del evento');
        return;
      }

      // Determinar el tipo de acción basándose en los datos disponibles
      final isDeleted = eventData['is_deleted'] as bool? ?? false;
      final hasNewRecord = payload.newRecord.isNotEmpty;
      final hasOldRecord = payload.oldRecord.isNotEmpty;

      if (hasNewRecord && !hasOldRecord) {
        // Nuevo registro creado - INSERT
        LoggerFactory.info(
            '➕ DirectWatched: Detectado INSERT genérico para movie: $eventMovieId');
        if (!isDeleted) {
          _handleRemoteInsert(payload.newRecord);
        }
      } else if (!hasNewRecord && hasOldRecord) {
        // Registro eliminado - DELETE
        LoggerFactory.info(
            '🗑️ DirectWatched: Detectado DELETE genérico para movie: $eventMovieId');
        _handleRemoteDelete(eventMovieId);
      } else if (hasNewRecord && hasOldRecord) {
        // Registro actualizado - UPDATE
        LoggerFactory.info(
            '🔄 DirectWatched: Detectado UPDATE genérico para movie: $eventMovieId');
        _handleRemoteUpdate(payload.newRecord);
      } else {
        // Caso fallback: usar is_deleted para determinar acción
        LoggerFactory.info(
            '🔍 DirectWatched: Usando is_deleted para determinar acción: $isDeleted');
        if (isDeleted) {
          _handleRemoteDelete(eventMovieId);
        } else {
          _handleRemoteInsert(eventData);
        }
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectWatched: Error procesando evento genérico: $e');
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
    // Verificar si el provider aún está activo
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 DirectWatched: Provider disposed, ignorando enableAfterLogin');
      return;
    }

    LoggerFactory.info(
        'DirectWatched: Usuario autenticado, cargando vistas...');

    // Reconfigurar realtime listeners para el usuario recién autenticado
    await _realtimeChannel?.unsubscribe();
    _setupRealtimeListeners();

    // Cargar datos desde Supabase
    await _loadWatchedFromSupabase();

    LoggerFactory.info(
        '✅ DirectWatched: Vistas cargadas y listeners reconfigurados');
  }

  @override
  void dispose() {
    LoggerFactory.info(
        '🔊 DirectWatched: Cerrando listeners de tiempo real...');
    _realtimeChannel?.unsubscribe();
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
