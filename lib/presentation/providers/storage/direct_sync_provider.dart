import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/syncable_movie.dart';

abstract class BaseSync {
  Future<List<Map<String, dynamic>>> getUserMovies(String userId);
  Future<void> addMovie(String userId, Movie movie);
  Future<void> removeMovie(String userId, int movieId);
}

abstract class DirectSyncNotifier
    extends StateNotifier<Map<int, SyncableMovie>> {
  DirectSyncNotifier({
    required this.onMovieAdded,
    required this.sync,
    required this.logPrefix,
    required this.tableName,
  }) : super({}) {
    LoggerFactory.info(
        '🎬 $logPrefix: Constructor llamado, inicialización diferida...');
    _initializeWithCurrentUser();
  }

  final Function(Movie movie) onMovieAdded;
  final BaseSync sync;
  final String logPrefix;
  final String tableName;

  RealtimeChannel? _realtimeChannel;
  String? _currentUserId;
  bool _isInitialized = false;

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
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 $logPrefix: Provider disposed, ignorando carga inicial');
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
      LoggerFactory.info('$logPrefix: Cargando películas desde Supabase...');
      final moviesData = await sync.getUserMovies(currentUser.id);
      final moviesMap = <int, SyncableMovie>{};
      for (final movieData in moviesData) {
        final syncableMovie = _dataToSyncableMovie(movieData);
        moviesMap[syncableMovie.movie.id] = syncableMovie;
      }
      state = moviesMap;
      LoggerFactory.info('$logPrefix: Cargadas ${moviesMap.length} películas');
    } catch (e) {
      LoggerFactory.error('$logPrefix: Error cargando: $e');
      state = {};
    }
  }

  Future<void> toggleMovie(Movie movie) async {
    if (!mounted) {
      LoggerFactory.debug('🚫 $logPrefix: Provider disposed, ignorando toggle');
      return;
    }
    final isAdded = state[movie.id] != null;
    final currentUser = Supabase.instance.client.auth.currentUser;

    LoggerFactory.debug(
        '$logPrefix: Toggle ${movie.id}:${movie.title} (current: $isAdded)');

    if (isAdded) {
      // Optimistic update for removal
      state = Map.from(state)..remove(movie.id);
    } else {
      // No optimistic update for adding, wait for realtime event
    }

    if (currentUser == null) {
      LoggerFactory.info(
          '$logPrefix: No hay usuario logueado, solo cambio local');
      return;
    }

    try {
      if (isAdded) {
        await sync.removeMovie(currentUser.id, movie.id);
        LoggerFactory.info('$logPrefix: Película removida: ${movie.title}');
      } else {
        await sync.addMovie(currentUser.id, movie);
        LoggerFactory.info('$logPrefix: Película añadida: ${movie.title}');
        onMovieAdded(movie);
      }
    } catch (e) {
      LoggerFactory.error('$logPrefix: Error en toggle: $e');
      if (isAdded) {
        // Revert optimistic update
        // This part is tricky because we don't have the SyncableMovie object anymore
        // A full refresh might be needed in case of error
        refresh();
      } else {
        // No need to revert anything since we didn't do an optimistic update
      }
    }
  }

  Future<void> refresh() async {
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 $logPrefix: Provider disposed, ignorando refresh');
      return;
    }
    await _loadMoviesFromSupabase();
  }

  Future<List<Movie>> loadNextPage() async {
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 $logPrefix: Provider disposed, ignorando loadNextPage');
      return [];
    }
    await _loadMoviesFromSupabase();
    return state.values.map((e) => e.movie).toList();
  }

  void _setupRealtimeListeners() {
    try {
      LoggerFactory.info(
          '🔊 $logPrefix: Configurando listeners de tiempo real...');
      final channelName =
          '${tableName}_realtime_${DateTime.now().millisecondsSinceEpoch}';
      LoggerFactory.info('🔊 $logPrefix: Creando canal: $channelName');

      _realtimeChannel =
          Supabase.instance.client.channel(channelName).onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: tableName,
                callback: _handleRealtimeChange,
              );

      _realtimeChannel!.subscribe((status, [error]) {
        if (error != null) {
          LoggerFactory.error('🔊 $logPrefix: Error en canal: $error');
        } else {
          LoggerFactory.info('🔊 $logPrefix: Estado del canal: $status');
          if (status == RealtimeSubscribeStatus.subscribed) {
            LoggerFactory.info('✅ $logPrefix: Canal suscrito exitosamente!');
          }
        }
      });
    } catch (e) {
      LoggerFactory.error('❌ $logPrefix: Error configurando listeners: $e');
    }
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 $logPrefix: Provider disposed, ignorando evento real-time');
      return;
    }
    try {
      LoggerFactory.info('🔊 $logPrefix: ===== CAMBIO RECIBIDO =====');
      final data =
          payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      final userId = data['user_id'] as String?;
      final movieId = data['movie_id'] as int?;
      final supabaseId = data['id'] as String?;

      if (userId != _currentUserId) {
        LoggerFactory.info('🔊 $logPrefix: Cambio de otro usuario, ignorando');
        return;
      }

      if (payload.eventType == PostgresChangeEvent.delete) {
        if (supabaseId != null) {
          _handleRemoteDeleteBySupabaseId(supabaseId);
        } else if (movieId != null) {
          _handleRemoteDelete(movieId);
        }
        return;
      }

      if (movieId == null) {
        LoggerFactory.error('❌ $logPrefix: movie_id es null, ignorando evento');
        return;
      }

      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          _handleRemoteInsert(data);
          break;
        case PostgresChangeEvent.update:
          _handleRemoteUpdate(data);
          break;
        case PostgresChangeEvent.delete:
          // Este caso ya se maneja antes del switch
          break;
        case PostgresChangeEvent.all:
          // Handle generic event
          break;
      }
    } catch (e) {
      LoggerFactory.error('❌ $logPrefix: Error procesando cambio: $e');
    }
  }

  void _handleRemoteInsert(Map<String, dynamic> data) {
    if (!mounted) return;
    try {
      final syncableMovie = _dataToSyncableMovie(data);
      if (!state.containsKey(syncableMovie.movie.id)) {
        state = {...state, syncableMovie.movie.id: syncableMovie};
        LoggerFactory.info(
            '✅ $logPrefix: Película agregada remotamente: ${syncableMovie.movie.title}');
      }
    } catch (e) {
      LoggerFactory.error('❌ $logPrefix: Error en inserción remota: $e');
    }
  }

  void _handleRemoteDelete(int movieId) {
    if (!mounted) return;
    try {
      if (state.containsKey(movieId)) {
        final movie = state[movieId];
        state = Map.from(state)..remove(movieId);
        LoggerFactory.info(
            '✅ $logPrefix: Película removida remotamente: ${movie?.movie.title}');
      }
    } catch (e) {
      LoggerFactory.error('❌ $logPrefix: Error en eliminación remota: $e');
    }
  }

  void _handleRemoteDeleteBySupabaseId(String supabaseId) {
    if (!mounted) return;
    try {
      int? movieIdToRemove;
      for (final entry in state.entries) {
        if (entry.value.supabaseId == supabaseId) {
          movieIdToRemove = entry.key;
          break;
        }
      }
      if (movieIdToRemove != null) {
        _handleRemoteDelete(movieIdToRemove);
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ $logPrefix: Error en eliminación remota por supabaseId: $e');
    }
  }

  void _handleRemoteUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    try {
      final isDeleted = data['is_deleted'] as bool? ?? false;
      if (isDeleted) {
        final movieId = data['movie_id'] as int?;
        if (movieId != null) {
          _handleRemoteDelete(movieId);
        }
      } else {
        _handleRemoteInsert(data);
      }
    } catch (e) {
      LoggerFactory.error('❌ $logPrefix: Error en actualización remota: $e');
    }
  }

  SyncableMovie _dataToSyncableMovie(Map<String, dynamic> data) {
    return SyncableMovie(
      supabaseId: data['id'] as String,
      movie: Movie(
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
        genreIds: (data['genre_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        adult: data['adult'] as bool? ?? false,
        originalLanguage: data['original_language'] as String? ?? '',
        originalTitle: data['original_title'] as String? ?? '',
        popularity: (data['popularity'] as num?)?.toDouble() ?? 0.0,
        video: data['video'] as bool? ?? false,
        voteCount: data['vote_count'] as int? ?? 0,
      ),
    );
  }

  Future<void> enableAfterLogin() async {
    if (!mounted) {
      LoggerFactory.debug(
          '🚫 $logPrefix: Provider disposed, ignorando enableAfterLogin');
      return;
    }
    LoggerFactory.info('🔐 $logPrefix: Habilitando después del login...');
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.warning(
          '🔐 $logPrefix: No hay usuario autenticado, omitiendo inicialización');
      return;
    }
    _currentUserId = currentUser.id;
    if (!_isInitialized) {
      await _loadMoviesFromSupabase();
      _setupRealtimeListeners();
      _isInitialized = true;
    } else {
      await _loadMoviesFromSupabase();
    }
    LoggerFactory.info('✅ $logPrefix: Habilitado correctamente');
  }

  @override
  void dispose() {
    LoggerFactory.info('🔊 $logPrefix: Cerrando listeners de tiempo real...');
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
