import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/trigger_free_watchlist_sync.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/watchlist_movie.dart';

/// Service directo que evita completamente el repositorio híbrido
/// y solo usa TriggerFreeWatchlistSync para operaciones de Supabase
class DirectWatchlistService extends Notifier<Map<int, WatchlistMovie>> {
  final TriggerFreeWatchlistSync _sync = TriggerFreeWatchlistSync.instance;
  RealtimeChannel? _realtimeChannel;
  String? _currentUserId;
  bool _isInitialized = false;

  @override
  Map<int, WatchlistMovie> build() {
    LoggerFactory.info(
        '📝 DirectWatchlistService: Constructor llamado, inicialización diferida...');
    // No inicializar inmediatamente - esperar hasta que haya usuario autenticado
    _initializeWithCurrentUser();
    return {};
  }

  /// Inicializa con el usuario actual si existe
  void _initializeWithCurrentUser() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      LoggerFactory.info(
          '📝 DirectWatchlistService: Usuario ya autenticado, inicializando...');
      _currentUserId = currentUser.id;
      _loadWatchlistFromSupabase();
      _setupRealtimeListeners();
      _isInitialized = true;
    } else {
      LoggerFactory.info(
          '📝 DirectWatchlistService: Sin usuario, esperando autenticación...');
    }
  }

  /// Cargar watchlist directamente desde Supabase
  Future<void> _loadWatchlistFromSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        state = {};
        _currentUserId = null;
        return;
      }

      _currentUserId = currentUser.id;

      LoggerFactory.info(
          'DirectWatchlist: Cargando watchlist directa desde Supabase...');

      final watchlistMovies = await _sync.getUserWatchlist(currentUser.id);

      final watchlistMap = <int, WatchlistMovie>{};
      for (final watchlistMovie in watchlistMovies) {
        watchlistMap[watchlistMovie.movieId] = watchlistMovie;
      }

      state = watchlistMap;

      LoggerFactory.info(
          'DirectWatchlist: Cargados ${watchlistMovies.length} items en watchlist directa');
      LoggerFactory.debug(
          'DirectWatchlist: IDs: ${watchlistMap.keys.toList()}');
    } catch (e) {
      LoggerFactory.error('DirectWatchlist: Error cargando: $e');
      state = {};
    }
  }

  /// Toggle watchlist usando solo operaciones directas
  Future<void> toggleWatchlist(Movie movie,
      {WatchlistPriority priority = WatchlistPriority.normal}) async {
    final isInWatchlist = state[movie.id] != null;
    final currentUser = Supabase.instance.client.auth.currentUser;

    LoggerFactory.debug(
        'DirectWatchlist: Toggle ${movie.id}:${movie.title} (current: $isInWatchlist)');

    // Actualización optimista de la UI
    if (isInWatchlist) {
      state = Map.from(state)..remove(movie.id);
    } else {
      final watchlistMovie = _movieToWatchlistMovie(movie, priority);
      state = {...state, movie.id: watchlistMovie};
    }

    if (currentUser == null) {
      LoggerFactory.info(
          'DirectWatchlist: No hay usuario logueado, solo cambio local');
      return;
    }

    try {
      if (isInWatchlist) {
        // Remover de Supabase (usando DELETE)
        await _sync.removeFromWatchlist(currentUser.id, movie.id);
        LoggerFactory.info(
            'DirectWatchlist: Removido de watchlist: ${movie.title}');
      } else {
        // Agregar a Supabase (usando INSERT)
        await _sync.addToWatchlist(currentUser.id, movie, priority: priority);
        LoggerFactory.info(
            'DirectWatchlist: Añadido a watchlist: ${movie.title}');
      }
    } catch (e) {
      LoggerFactory.error('DirectWatchlist: Error en toggle: $e');

      // Revertir cambio optimista en caso de error
      if (isInWatchlist) {
        final watchlistMovie = _movieToWatchlistMovie(movie, priority);
        state = {...state, movie.id: watchlistMovie};
      } else {
        state = Map.from(state)..remove(movie.id);
      }

      // No rethrow para evitar errores en UI - el cambio optimista ya se revirtió
      LoggerFactory.warning(
          'DirectWatchlist: Operación fallida pero estado revertido');
    }
  }

  /// Cambia la prioridad de una película en la watchlist
  Future<void> changePriority(
      int movieId, WatchlistPriority newPriority) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final currentWatchlistMovie = state[movieId];
    if (currentWatchlistMovie == null) return;

    LoggerFactory.debug(
        'DirectWatchlist: Cambiando prioridad ${currentWatchlistMovie.movieTitle} -> ${newPriority.displayName}');

    // Actualización optimista de la UI
    final updatedWatchlistMovie =
        currentWatchlistMovie.copyWith(priority: newPriority);
    state = {...state, movieId: updatedWatchlistMovie};

    try {
      await _sync.changePriority(currentUser.id, movieId, newPriority);
      LoggerFactory.info(
          'DirectWatchlist: Prioridad cambiada: ${currentWatchlistMovie.movieTitle}');
    } catch (e) {
      LoggerFactory.error('DirectWatchlist: Error cambiando prioridad: $e');

      // Revertir cambio optimista en caso de error
      state = {...state, movieId: currentWatchlistMovie};
      // No rethrow para evitar errores en UI
      LoggerFactory.warning(
          'DirectWatchlist: Cambio de prioridad fallido pero estado revertido');
    }
  }

  /// Configurar listeners de tiempo real
  void _setupRealtimeListeners() {
    try {
      LoggerFactory.info(
          '🔴 DirectWatchlist: Configurando listeners de tiempo real...');

      // Crear canal único para evitar conflictos
      final channelName =
          'watchlist_realtime_${DateTime.now().millisecondsSinceEpoch}';

      _realtimeChannel =
          Supabase.instance.client.channel(channelName).onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'user_watchlist',
                callback: _handleRealtimeEvent,
              );

      _realtimeChannel!.subscribe((status, [error]) {
        if (error != null) {
          LoggerFactory.error('🔴 DirectWatchlist: Error en canal: $error');
        } else {
          LoggerFactory.info('🔴 DirectWatchlist: Estado del canal: $status');
          if (status == RealtimeSubscribeStatus.subscribed) {
            LoggerFactory.info(
                '✅ DirectWatchlist: Canal suscrito exitosamente!');
          }
        }
      });
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectWatchlist: Error configurando listeners: $e');
    }
  }

  /// Convierte Movie a WatchlistMovie
  WatchlistMovie _movieToWatchlistMovie(
      Movie movie, WatchlistPriority priority) {
    final now = DateTime.now();
    return WatchlistMovie(
      id: '', // Se generará en el servidor
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

  /// Maneja eventos de tiempo real
  void _handleRealtimeEvent(PostgresChangePayload payload) {
    try {
      LoggerFactory.info(
          '🔴 DirectWatchlist: Evento en tiempo real: ${payload.eventType}');
      LoggerFactory.debug('🔴 DirectWatchlist: Payload: ${payload.newRecord}');

      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;
      final data = newRecord.isNotEmpty
          ? newRecord
          : (oldRecord.isNotEmpty ? oldRecord : <String, dynamic>{});

      final userId = data['user_id'] as String?;
      final movieId = data['movie_id'] as int?;
      final supabaseRecordId = data['id']?.toString();

      LoggerFactory.info('🔍 DirectWatchlist: user_id del evento: $userId');
      LoggerFactory.info('🔍 DirectWatchlist: user_id actual: $_currentUserId');
      LoggerFactory.info('🔍 DirectWatchlist: movie_id del evento: $movieId');
      LoggerFactory.info(
          '🔍 DirectWatchlist: supabase_id del evento: $supabaseRecordId');

      // Si no tenemos user_id pero tenemos supabase record_id, intentar manejar DELETE
      if (userId == null &&
          payload.eventType == PostgresChangeEvent.delete &&
          supabaseRecordId != null) {
        LoggerFactory.info(
            '🔍 DirectWatchlist: DELETE sin user_id, intentando por record_id');
        _handleDeleteBySupabaseId(supabaseRecordId);
        return;
      }

      if (userId != _currentUserId) {
        LoggerFactory.info(
            '🔊 DirectWatchlist: Cambio de otro usuario, ignorando');
        return;
      }

      // Si no tenemos movie_id pero es un DELETE, intentar buscar por supabase record_id
      if (movieId == null &&
          payload.eventType == PostgresChangeEvent.delete &&
          supabaseRecordId != null) {
        LoggerFactory.info(
            '🔍 DirectWatchlist: DELETE sin movie_id, buscando por record_id');
        _handleDeleteBySupabaseId(supabaseRecordId);
        return;
      }

      if (movieId == null) {
        LoggerFactory.error(
            '❌ DirectWatchlist: movie_id es null, ignorando evento');
        return;
      }

      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          _handleInsert(newRecord);
          break;
        case PostgresChangeEvent.update:
          _handleUpdate(newRecord, oldRecord);
          break;
        case PostgresChangeEvent.delete:
          LoggerFactory.info(
              '🗑️ DirectWatchlist: ===== PROCESANDO DELETE =====');
          LoggerFactory.info(
              '🗑️ DirectWatchlist: Movie ID a eliminar: $movieId');
          LoggerFactory.info(
              '🗑️ DirectWatchlist: Estado actual antes del DELETE: ${state.keys.toList()}');

          // Procesar DELETE inmediatamente sin delay
          _handleDelete(oldRecord);
          break;
        case PostgresChangeEvent.all:
          // No debería llegarnos este caso específico en eventos individuales
          break;
      }
    } catch (e) {
      LoggerFactory.error('❌ DirectWatchlist: Error manejando evento: $e');
      LoggerFactory.error(
          '❌ DirectWatchlist: Stack trace: ${StackTrace.current}');
    }
  }

  /// Maneja eliminaciones por Supabase record ID cuando no tenemos movie_id
  void _handleDeleteBySupabaseId(String supabaseRecordId) {
    try {
      LoggerFactory.info(
          '🔍 DirectWatchlist: Buscando película por supabase_id: $supabaseRecordId');

      // Buscar en el estado actual por el ID de Supabase
      WatchlistMovie? movieToDelete;
      int? movieIdToDelete;

      for (final entry in state.entries) {
        if (entry.value.id == supabaseRecordId) {
          movieToDelete = entry.value;
          movieIdToDelete = entry.key;
          break;
        }
      }

      if (movieToDelete != null && movieIdToDelete != null) {
        LoggerFactory.info(
            '✅ DirectWatchlist: Encontrada película por supabase_id: ${movieToDelete.movieTitle} (movie_id: $movieIdToDelete)');

        state = Map.from(state)..remove(movieIdToDelete);

        LoggerFactory.info(
            '🎉 DirectWatchlist: PELÍCULA REMOVIDA por supabase_id: ${movieToDelete.movieTitle}');
      } else {
        LoggerFactory.warning(
            '⚠️ DirectWatchlist: No se encontró película con supabase_id: $supabaseRecordId');
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectWatchlist: Error eliminando por supabase_id: $e');
    }
  }

  /// Maneja inserciones de tiempo real
  void _handleInsert(Map<String, dynamic> record) {
    if (record['user_id'] != _currentUserId) return;
    if (record['is_deleted'] ?? false) return;

    final movieId = record['movie_id'] as int;

    // Evitar loops - si ya existe localmente, no actualizar
    if (state.containsKey(movieId)) {
      LoggerFactory.debug(
          '➕ DirectWatchlist: Movie $movieId ya existe, ignorando inserción');
      return;
    }

    final watchlistMovie = _recordToWatchlistMovie(record);
    LoggerFactory.info(
        '➕ DirectWatchlist: Insertando ${watchlistMovie.movieTitle}');

    state = {...state, movieId: watchlistMovie};
  }

  /// Maneja actualizaciones de tiempo real
  void _handleUpdate(
      Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord) {
    if (newRecord['user_id'] != _currentUserId) return;

    final movieId = newRecord['movie_id'] as int;

    if (newRecord['is_deleted'] ?? false) {
      LoggerFactory.info(
          '🗑️ DirectWatchlist: Actualizando como eliminado ${newRecord['movie_title']}');
      state = Map.from(state)..remove(movieId);
    } else {
      final watchlistMovie = _recordToWatchlistMovie(newRecord);
      LoggerFactory.info(
          '🔄 DirectWatchlist: Actualizando ${watchlistMovie.movieTitle}');
      state = {...state, movieId: watchlistMovie};
    }
  }

  /// Maneja eliminaciones de tiempo real
  void _handleDelete(Map<String, dynamic> record) {
    if (record['user_id'] != _currentUserId) return;

    final movieId = record['movie_id'] as int;

    try {
      LoggerFactory.info(
          '🗑️ DirectWatchlist: ===== _handleDelete INICIADO =====');
      LoggerFactory.info('🗑️ DirectWatchlist: Movie ID a procesar: $movieId');
      LoggerFactory.info(
          '🗑️ DirectWatchlist: Estado actual keys: ${state.keys.toList()}');
      LoggerFactory.info(
          '🗑️ DirectWatchlist: Estado actual contiene $movieId? ${state.containsKey(movieId)}');

      if (state.containsKey(movieId)) {
        final movie = state[movieId];
        final oldState = Map<int, WatchlistMovie>.from(state);

        LoggerFactory.info(
            '🗑️ DirectWatchlist: Movie a eliminar: ${movie?.movieTitle} (ID: $movieId)');
        LoggerFactory.info(
            '🗑️ DirectWatchlist: Estado antes de eliminar: ${oldState.keys.length} películas');

        state = Map.from(state)..remove(movieId);

        LoggerFactory.info(
            '🗑️ DirectWatchlist: Estado después de eliminar: ${state.keys.length} películas');
        LoggerFactory.info(
            '✅ DirectWatchlist: 🎉 PELÍCULA REMOVIDA REMOTAMENTE: ${movie?.movieTitle} (ID: $movieId)');
        LoggerFactory.info(
            '🗑️ DirectWatchlist: Nuevas keys del estado: ${state.keys.toList()}');
      } else {
        LoggerFactory.warning(
            '⚠️ DirectWatchlist: Intento de remover película que no existe localmente: $movieId');
        LoggerFactory.info(
            '🗑️ DirectWatchlist: Películas actuales en estado: ${state.keys.toList()}');
      }
    } catch (e) {
      LoggerFactory.error('❌ DirectWatchlist: Error en eliminación remota: $e');
      LoggerFactory.error(
          '❌ DirectWatchlist: Stack trace: ${StackTrace.current}');
    }
  }

  /// Convierte un record de Supabase a WatchlistMovie
  WatchlistMovie _recordToWatchlistMovie(Map<String, dynamic> record) {
    return WatchlistMovie(
      id: record['id']?.toString() ?? '',
      movieId: record['movie_id'] as int,
      movieTitle: record['movie_title'] as String,
      moviePosterPath: record['movie_poster_path'] as String?,
      movieBackdropPath: record['movie_backdrop_path'] as String?,
      movieOverview: record['movie_overview'] as String?,
      movieReleaseDate: record['movie_release_date'] != null
          ? DateTime.parse(record['movie_release_date'] as String)
          : null,
      movieVoteAverage: (record['movie_vote_average'] as num?)?.toDouble(),
      priority: _parsePriority(record['priority'] as String?),
      addedAt: DateTime.parse(record['added_at'] as String),
      lastModifiedAt: DateTime.parse(record['last_modified_at'] as String? ??
          record['added_at'] as String),
    );
  }

  /// Parsea la prioridad desde string
  WatchlistPriority _parsePriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'alta':
        return WatchlistPriority.alta;
      case 'baja':
        return WatchlistPriority.baja;
      case 'normal':
      default:
        return WatchlistPriority.normal;
    }
  }

  /// Habilita el provider después del login
  void enableAfterLogin() {
    LoggerFactory.info('🔐 DirectWatchlist: Habilitando después del login...');

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.warning(
          '🔐 DirectWatchlist: No hay usuario autenticado, omitiendo inicialización');
      return;
    }

    _currentUserId = currentUser.id;

    // Solo inicializar si no se ha hecho antes
    if (!_isInitialized) {
      _loadWatchlistFromSupabase();
      _setupRealtimeListeners();
      _isInitialized = true;
    } else {
      LoggerFactory.info(
          '🔐 DirectWatchlist: Ya inicializado, solo recargando datos...');
      _loadWatchlistFromSupabase();
    }
  }

  /// Verifica si una película está en la watchlist
  bool isInWatchlist(int movieId) {
    return state.containsKey(movieId);
  }

  /// Obtiene la prioridad de una película en la watchlist
  WatchlistPriority? getMoviePriority(int movieId) {
    return state[movieId]?.priority;
  }

  /// Obtiene todas las películas de la watchlist como lista
  List<WatchlistMovie> get watchlistMovies => state.values.toList();

  /// Obtiene películas por prioridad
  List<WatchlistMovie> getMoviesByPriority(WatchlistPriority priority) {
    return state.values.where((movie) => movie.priority == priority).toList();
  }
}

/// Provider modernizado para watchlist directa
final directWatchlistMoviesProvider =
    NotifierProvider<DirectWatchlistService, Map<int, WatchlistMovie>>(
  () => DirectWatchlistService(),
);

/// Compatibilidad: Provider legacy para transición gradual
final directWatchlistProvider = directWatchlistMoviesProvider;
