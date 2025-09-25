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
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        state = {};
        _currentUserId = null;
        return;
      }

      _currentUserId = currentUser.id;
      LoggerFactory.info('$logPrefix: Cargando desde Supabase...');

      final moviesData = await sync.getUserMovies(currentUser.id);

      final moviesMap = <int, SyncableMovie>{};
      for (final movieData in moviesData) {
        final syncableMovie = _recordToSyncableMovie(movieData);
        moviesMap[syncableMovie.movie.id] = syncableMovie;
      }

      state = moviesMap;
      LoggerFactory.info(
          '$logPrefix: Cargadas ${moviesMap.length} películas desde Supabase');
    } catch (e) {
      LoggerFactory.error('$logPrefix: Error cargando desde Supabase: $e');
      state = {};
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
    LoggerFactory.info('🔐 $logPrefix: Habilitando después del login...');

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.warning(
          '🔐 $logPrefix: No hay usuario autenticado, omitiendo inicialización');
      return;
    }

    _currentUserId = currentUser.id;

    if (!_isInitialized) {
      _loadMoviesFromSupabase();
      _setupRealtimeListeners();
      _isInitialized = true;
    } else {
      LoggerFactory.info('🔐 $logPrefix: Ya inicializado, solo recargando...');
      _loadMoviesFromSupabase();
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

      if (userId != _currentUserId || movieId == null) {
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
        case PostgresChangeEvent.delete:
          _handleDelete(oldRecord);
          break;
        case PostgresChangeEvent.all:
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

    if (!state.containsKey(movieId)) {
      state = {...state, movieId: syncableMovie};
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

  void _handleDelete(Map<String, dynamic> record) {
    if (record['user_id'] != _currentUserId) return;

    final movieId = record['movie_id'] as int;
    if (state.containsKey(movieId)) {
      final movie = state[movieId];
      state = Map.from(state)..remove(movieId);
      LoggerFactory.info('🗑️ $logPrefix: REMOVIDA: ${movie?.movie.title}');
    }
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
      genreIds: <String>[],
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
