import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/syncable_movie.dart';

abstract class BaseSync {
  Future<List<Map<String, dynamic>>> getUserMovies(String userId);
  Future<void> addMovie(String userId, Movie movie);
  Future<void> removeMovie(String userId, int movieId);
}

abstract class DirectSyncService extends Notifier<Map<int, SyncableMovie>> {
  DirectSyncService({
    required this.onMovieAdded,
    required this.sync,
    required this.logPrefix,
    required this.tableName,
  });
  final Function(Movie movie) onMovieAdded;
  final BaseSync sync;
  final String logPrefix;
  final String tableName;

  RealtimeChannel? _realtimeChannel;
  String? _currentUserId;
  bool _isInitialized = false;
  bool _isLoading = false; // 🐛 FIX: Prevenir cargas simultáneas
  int _loadCounter = 0; // 🐛 DEBUG: Contador de cargas para tracking

  @override
  Map<int, SyncableMovie> build() {
    LoggerFactory.info(
        '🎬 $logPrefix: Constructor llamado, inicialización diferida...');
    _initializeWithCurrentUser();
    return {};
  }

  void _initializeWithCurrentUser() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      LoggerFactory.info(
          '🎬 $logPrefix: Usuario ya autenticado, inicializando...');
      _currentUserId = currentUser.id;
      _loadMoviesFromSupabase();
      _setupRealtimeListeners();
      _isInitialized = true;
    } else {
      LoggerFactory.info(
          '🎬 $logPrefix: Sin usuario, esperando autenticación...');
    }
  }

  Future<void> _loadMoviesFromSupabase() async {
    // 🐛 FIX: Prevenir cargas simultáneas
    if (_isLoading) {
      LoggerFactory.warning(
          '⚠️ $logPrefix: [LOAD #$_loadCounter] Ya hay una carga en progreso, ignorando...');
      return;
    }

    _isLoading = true;
    _loadCounter++;
    final currentLoadId = _loadCounter;

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        state = {};
        _currentUserId = null;
        LoggerFactory.info(
            '🔍 $logPrefix: [LOAD #$currentLoadId] Sin usuario, limpiando estado');
        return;
      }

      _currentUserId = currentUser.id;
      LoggerFactory.info(
          '🔍 $logPrefix: [LOAD #$currentLoadId] Iniciando carga desde Supabase...');

      final moviesData = await sync.getUserMovies(currentUser.id);

      final moviesMap = <int, SyncableMovie>{};
      for (final movieData in moviesData) {
        final syncableMovie = _recordToSyncableMovie(movieData);
        moviesMap[syncableMovie.movie.id] = syncableMovie;
      }

      state = moviesMap;
      LoggerFactory.info(
          '✅ $logPrefix: [LOAD #$currentLoadId] Cargadas ${moviesMap.length} películas desde Supabase');

      // 🐛 FIX: Eliminar reintentos automáticos que causan doble carga
      // Si realmente no hay películas, el usuario simplemente no tiene favoritos
      // No necesitamos reintentar automáticamente
    } catch (e) {
      LoggerFactory.error(
          '❌ $logPrefix: [LOAD #$currentLoadId] Error cargando desde Supabase: $e');
      state = {};

      // 🐛 FIX: Solo reintentar en caso de error de red, no siempre
      // Y solo si no hay otra carga programada
      if (_currentUserId != null && e.toString().contains('network')) {
        LoggerFactory.info(
            '🔄 $logPrefix: [LOAD #$currentLoadId] Error de red, reintentando en 5 segundos...');
        Future.delayed(const Duration(seconds: 5), () {
          if (_currentUserId != null && !_isLoading) {
            _loadMoviesFromSupabase();
          }
        });
      }
    } finally {
      _isLoading = false;
      LoggerFactory.info(
          '🏁 $logPrefix: [LOAD #$currentLoadId] Finalizando carga (isLoading = false)');
    }
  }

  Future<void> toggleMovie(Movie movie) async {
    final isAdded = state[movie.id] != null;
    final currentUser = Supabase.instance.client.auth.currentUser;

    LoggerFactory.debug(
        '$logPrefix: Toggle ${movie.id}:${movie.title} (current: $isAdded)');

    // Actualización optimista de la UI
    if (isAdded) {
      state = Map.from(state)..remove(movie.id);
    } else {
      final syncableMovie = SyncableMovie(
        movie: movie,
        supabaseId: '',
      );
      state = {...state, movie.id: syncableMovie};
    }

    if (currentUser == null) {
      LoggerFactory.info(
          '$logPrefix: No hay usuario logueado, solo cambio local');
      return;
    }

    try {
      if (isAdded) {
        await sync.removeMovie(currentUser.id, movie.id);
        LoggerFactory.info('$logPrefix: Removida: ${movie.title}');
      } else {
        await sync.addMovie(currentUser.id, movie);
        LoggerFactory.info('$logPrefix: Añadida: ${movie.title}');
        onMovieAdded(movie);
      }
    } catch (e) {
      LoggerFactory.error('$logPrefix: Error en toggle: $e');
      // Revertir cambio optimista en caso de error
      if (isAdded) {
        final syncableMovie = SyncableMovie(
          movie: movie,
          supabaseId: '',
        );
        state = {...state, movie.id: syncableMovie};
      } else {
        state = Map.from(state)..remove(movie.id);
      }
      LoggerFactory.warning(
          '$logPrefix: Operación fallida pero estado revertido');
    }
  }

  void enableAfterLogin() {
    LoggerFactory.info(
        '🔐 $logPrefix: [enableAfterLogin] Habilitando después del login...');

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.warning(
          '🔐 $logPrefix: [enableAfterLogin] No hay usuario autenticado, omitiendo inicialización');
      return;
    }

    _currentUserId = currentUser.id;

    // 🐛 FIX: Solo inicializar una vez
    if (!_isInitialized) {
      LoggerFactory.info(
          '🔐 $logPrefix: [enableAfterLogin] Primera inicialización, cargando y configurando listeners...');
      _loadMoviesFromSupabase();
      _setupRealtimeListeners();
      _isInitialized = true;
    } else {
      // 🐛 FIX: Si ya está inicializado, NO recargar automáticamente
      // El usuario puede hacer pull-to-refresh si lo necesita
      LoggerFactory.info(
          '🔐 $logPrefix: [enableAfterLogin] Ya inicializado, no recargando (usa pull-to-refresh si necesitas actualizar)');
    }
  }

  List<Movie> getMovies() {
    return state.values.map((e) => e.movie).toList();
  }

  /// Load next page method for compatibility with pagination patterns
  Future<void> loadNextPage() async {
    // For direct services, we typically load all at once
    // This method is for compatibility with pagination patterns
    await _loadMoviesFromSupabase();
  }

  /// Refresh method to reload data
  Future<void> refresh() async {
    await _loadMoviesFromSupabase();
  }

  void _setupRealtimeListeners() {
    try {
      LoggerFactory.info('🔴 $logPrefix: Configurando listeners...');

      final channelName =
          '${tableName}_realtime_${DateTime.now().millisecondsSinceEpoch}';

      _realtimeChannel =
          Supabase.instance.client.channel(channelName).onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: tableName,
                callback: _handleRealtimeEvent,
              );

      _realtimeChannel!.subscribe((status, [error]) {
        if (error != null) {
          LoggerFactory.error('🔴 $logPrefix: Error en canal: $error');
        } else {
          LoggerFactory.info('🔴 $logPrefix: Estado del canal: $status');
          if (status == RealtimeSubscribeStatus.subscribed) {
            LoggerFactory.info('✅ $logPrefix: Canal suscrito exitosamente!');
          }
        }
      });
    } catch (e) {
      LoggerFactory.error('❌ $logPrefix: Error configurando listeners: $e');
    }
  }

  void _handleRealtimeEvent(PostgresChangePayload payload) {
    try {
      LoggerFactory.info('🔴 $logPrefix: Evento: ${payload.eventType}');

      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;
      final data = newRecord.isNotEmpty ? newRecord : oldRecord;

      final userId = data['user_id'] as String?;
      final movieId = data['movie_id'] as int?;
      final supabaseId = (data['id'] ?? data['supabase_id'])?.toString();

      if (payload.eventType == PostgresChangeEvent.delete) {
        final resolvedMovieId =
            movieId ?? _findMovieIdFromSupabaseId(supabaseId);

        if (resolvedMovieId == null) {
          LoggerFactory.warning(
              '🔊 $logPrefix: Evento delete sin movieId ni supabaseId conocido, ignorando');
          return;
        }

        _handleDelete(oldRecord, resolvedMovieId, supabaseId);
        return;
      }

      if (userId != _currentUserId || movieId == null) {
        // Para insert/update mantenemos validación estricta
        LoggerFactory.info('🔊 $logPrefix: Cambio de otro usuario, ignorando');
        return;
      }

      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          _handleInsert(newRecord);
          break;
        case PostgresChangeEvent.update:
          _handleUpdate(newRecord, oldRecord);
          break;
        case PostgresChangeEvent.all:
          break;
        case PostgresChangeEvent.delete:
          break;
      }
    } catch (e) {
      LoggerFactory.error('❌ $logPrefix: Error manejando evento: $e');
    }
  }

  void _handleInsert(Map<String, dynamic> record) {
    if (record['user_id'] != _currentUserId) return;
    if (record['is_deleted'] ?? false) return;

    final syncableMovie = _recordToSyncableMovie(record);
    final movieId = syncableMovie.movie.id;

    final hadMovie = state.containsKey(movieId);

    state = {...state, movieId: syncableMovie};

    if (hadMovie) {
      LoggerFactory.info(
          '🔄 $logPrefix: Insert reemplazó optimista ${syncableMovie.movie.title}');
    } else {
      LoggerFactory.info(
          '➕ $logPrefix: Insertando ${syncableMovie.movie.title}');
    }
  }

  void _handleUpdate(
      Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord) {
    if (newRecord['user_id'] != _currentUserId) return;

    final movieId = newRecord['movie_id'] as int;

    if (newRecord['is_deleted'] ?? false) {
      state = Map.from(state)..remove(movieId);
      LoggerFactory.info(
          '🗑️ $logPrefix: Actualizando como eliminado ${newRecord['movie_title']}');
    } else {
      final syncableMovie = _recordToSyncableMovie(newRecord);
      state = {...state, movieId: syncableMovie};
      LoggerFactory.info(
          '🔄 $logPrefix: Actualizando ${syncableMovie.movie.title}');
    }
  }

  void _handleDelete(
    Map<String, dynamic> record,
    int movieId,
    String? supabaseId,
  ) {
    if (!state.containsKey(movieId)) {
      final fallbackMovieId = _findMovieIdFromSupabaseId(supabaseId);

      if (fallbackMovieId != null && state.containsKey(fallbackMovieId)) {
        final movie = state[fallbackMovieId];
        state = Map.from(state)..remove(fallbackMovieId);
        LoggerFactory.info(
            '🗑️ $logPrefix: REMOVIDA (fallback): ${movie?.movie.title}');
      } else {
        LoggerFactory.info(
            '🔊 $logPrefix: Delete recibido pero película ya no está en estado');
      }
      return;
    }

    final movie = state[movieId];
    state = Map.from(state)..remove(movieId);
    LoggerFactory.info('🗑️ $logPrefix: REMOVIDA: ${movie?.movie.title}');
  }

  int? _findMovieIdFromSupabaseId(String? supabaseId) {
    if (supabaseId == null || supabaseId.isEmpty) {
      return null;
    }

    for (final entry in state.entries) {
      if (entry.value.supabaseId == supabaseId) {
        return entry.key;
      }
    }

    return null;
  }

  SyncableMovie _recordToSyncableMovie(Map<String, dynamic> record) {
    final movie = Movie(
      id: record['movie_id'] as int,
      title: record['movie_title'] as String,
      overview: record['movie_overview'] as String? ?? '',
      releaseDate: record['movie_release_date'] != null
          ? DateTime.parse(record['movie_release_date'] as String)
          : DateTime.now(),
      adult: false,
      backdropPath: record['movie_backdrop_path'] as String? ?? '',
      genreIds: <int>[],
      originalLanguage: 'en',
      originalTitle: record['movie_title'] as String,
      popularity: 0.0,
      posterPath: record['movie_poster_path'] as String? ?? '',
      video: false,
      voteAverage: (record['movie_vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: 0,
    );

    return SyncableMovie(
      movie: movie,
      supabaseId: record['id']?.toString() ?? '',
    );
  }

  void dispose() {
    LoggerFactory.info('🗑️ $logPrefix: Cerrando listeners...');
    _realtimeChannel?.unsubscribe();
  }
}
