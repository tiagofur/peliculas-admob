import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_movie.dart';

/// Estado de la watchlist simplificado
class WatchlistStateSimple {
  const WatchlistStateSimple({
    this.movies = const [],
    this.isLoading = false,
    this.error,
  });
  
  final List<WatchlistMovie> movies;
  final bool isLoading;
  final String? error;

  WatchlistStateSimple copyWith({
    List<WatchlistMovie>? movies,
    bool? isLoading,
    String? error,
  }) {
    return WatchlistStateSimple(
      movies: movies ?? this.movies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier simplificado para watchlist usando SharedPreferences
class WatchlistNotifierSimple extends StateNotifier<WatchlistStateSimple> {
  WatchlistNotifierSimple() : super(const WatchlistStateSimple()) {
    _loadExistingWatchlist();
  }

  static const String _watchlistKey = 'watchlist_movies';
  
  /// Cargar watchlist existente al inicializar el provider
  Future<void> _loadExistingWatchlist() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final watchlistJson = prefs.getStringList(_watchlistKey) ?? [];
      
      final List<WatchlistMovie> watchlistMovies = [];
      for (final movieJson in watchlistJson) {
        try {
          final movieData = jsonDecode(movieJson);
          final watchlistMovie = WatchlistMovie.fromJson(movieData);
          watchlistMovies.add(watchlistMovie);
        } catch (e) {
          if (kDebugMode) {
            print('Error deserializando película de watchlist: $e');
          }
        }
      }
      
      state = state.copyWith(movies: watchlistMovies, isLoading: false);
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando watchlist existente: $e');
      }
      state = state.copyWith(isLoading: false, error: 'Error cargando watchlist: $e');
    }
  }

  /// Alternar película en watchlist
  Future<void> toggleWatchlist(Movie movie, {WatchlistPriority priority = WatchlistPriority.normal}) async {
    final isInWatchlist = state.movies.any((m) => m.movieId == movie.id);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final watchlistJson = prefs.getStringList(_watchlistKey) ?? [];

      if (isInWatchlist) {
        // Remover de watchlist
        watchlistJson.removeWhere((movieJson) {
          final movieData = jsonDecode(movieJson);
          return movieData['movieId'] == movie.id;
        });
        
        final updatedMovies = state.movies.where((m) => m.movieId != movie.id).toList();
        state = state.copyWith(movies: updatedMovies);
      } else {
        // Agregar a watchlist
        final newWatchlistMovie = WatchlistMovie(
          id: 'local_${movie.id}_${DateTime.now().millisecondsSinceEpoch}',
          movieId: movie.id,
          movieTitle: movie.title,
          moviePosterPath: movie.posterPath,
          movieBackdropPath: movie.backdropPath,
          movieOverview: movie.overview,
          movieReleaseDate: movie.releaseDate,
          movieVoteAverage: movie.voteAverage,
          addedAt: DateTime.now(),
          priority: priority,
          lastModifiedAt: DateTime.now(),
        );
        
        watchlistJson.add(jsonEncode(newWatchlistMovie.toJson()));
        
        final updatedMovies = [...state.movies, newWatchlistMovie];
        state = state.copyWith(movies: updatedMovies);
      }

      // Guardar en SharedPreferences
      await prefs.setStringList(_watchlistKey, watchlistJson);

    } catch (e) {
      if (kDebugMode) {
        print('❌ [WatchlistProvider] Error toggling watchlist: $e');
      }
      // Recargar desde SharedPreferences para asegurar consistencia
      await _loadExistingWatchlist();
    }
  }

  /// Verificar si una película está en watchlist
  bool isMovieInWatchlist(int movieId) {
    return state.movies.any((movie) => movie.movieId == movieId);
  }

  /// Refresh completo de la watchlist
  Future<void> refresh() async {
    await _loadExistingWatchlist();
  }
}

/// Provider simplificado de watchlist
final watchlistProviderSimple =
    StateNotifierProvider<WatchlistNotifierSimple, WatchlistStateSimple>((ref) {
  return WatchlistNotifierSimple();
});

/// Provider para verificar si una película específica está en watchlist
final isMovieInWatchlistProviderSimple =
    Provider.family.autoDispose<bool, int>((ref, movieId) {
  final watchlistState = ref.watch(watchlistProviderSimple);
  return watchlistState.movies.any((movie) => movie.movieId == movieId);
});

/// Provider para obtener una película específica de watchlist
final watchlistMovieProviderSimple = Provider.family
    .autoDispose<WatchlistMovie?, int>((ref, movieId) {
  final watchlistState = ref.watch(watchlistProviderSimple);
  
  try {
    return watchlistState.movies.firstWhere((movie) => movie.movieId == movieId);
  } catch (e) {
    return null;
  }
});