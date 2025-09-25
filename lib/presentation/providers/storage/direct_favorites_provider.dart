import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/sync/trigger_free_favorites_sync.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/syncable_movie.dart';
import '../achievements/achievements_provider.dart';
import 'direct_sync_provider.dart';

class DirectFavoritesService extends Notifier<Map<int, SyncableMovie>> {
  late BaseSync _sync;
  late Function(Movie movie) _onMovieAdded;
  bool _isInitialized = false;

  @override
  Map<int, SyncableMovie> build() {
    // Configurar dependencias
    _sync = TriggerFreeFavoritesSync.instance;
    _onMovieAdded = (Movie movie) {
      ref.read(achievementsProvider.notifier).trackMovieFavorited();
    };

    _initializeWithCurrentUser();
    return {};
  }

  void _initializeWithCurrentUser() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _loadMoviesFromSupabase();
      _isInitialized = true;
    }
  }

  Future<void> _loadMoviesFromSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        state = {};
        return;
      }

      final moviesData = await _sync.getUserMovies(currentUser.id);

      final moviesMap = <int, SyncableMovie>{};
      for (final movieData in moviesData) {
        final syncableMovie = _recordToSyncableMovie(movieData);
        moviesMap[syncableMovie.movie.id] = syncableMovie;
      }

      state = moviesMap;
    } catch (e) {
      state = {};
    }
  }

  Future<void> toggleMovie(Movie movie) async {
    final isAdded = state[movie.id] != null;
    final currentUser = Supabase.instance.client.auth.currentUser;

    // Actualización optimista
    if (isAdded) {
      state = Map.from(state)..remove(movie.id);
    } else {
      final syncableMovie = SyncableMovie(movie: movie, supabaseId: '');
      state = {...state, movie.id: syncableMovie};
    }

    if (currentUser != null) {
      try {
        if (isAdded) {
          await _sync.removeMovie(currentUser.id, movie.id);
        } else {
          await _sync.addMovie(currentUser.id, movie);
          _onMovieAdded(movie);
        }
      } catch (e) {
        // Revertir en caso de error
        if (isAdded) {
          final syncableMovie = SyncableMovie(movie: movie, supabaseId: '');
          state = {...state, movie.id: syncableMovie};
        } else {
          state = Map.from(state)..remove(movie.id);
        }
      }
    }
  }

  /// Alias para toggleMovie
  Future<void> toggleFavorite(Movie movie) async {
    await toggleMovie(movie);
  }

  void enableAfterLogin() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    if (!_isInitialized) {
      _loadMoviesFromSupabase();
      _isInitialized = true;
    } else {
      _loadMoviesFromSupabase();
    }
  }

  List<Movie> getMovies() {
    return state.values.map((e) => e.movie).toList();
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
}

final directFavoriteMoviesProvider =
    NotifierProvider<DirectFavoritesService, Map<int, SyncableMovie>>(
  () => DirectFavoritesService(),
);

final directIsFavoriteProvider = Provider.family<bool, int>((ref, movieId) {
  return ref.watch(directFavoriteMoviesProvider).containsKey(movieId);
});

final directFavoritesCountProvider = Provider<int>((ref) {
  return ref.watch(directFavoriteMoviesProvider).length;
});
