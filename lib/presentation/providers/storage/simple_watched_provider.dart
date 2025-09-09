import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/simple_watched_sync.dart';
import '../../../domain/entities/movie.dart';

/// Simple watched provider that exactly mirrors the favorites pattern
/// This is the EXACT same architecture as favorites for consistency
final simpleWatchedProvider =
    StateNotifierProvider<SimpleWatchedNotifier, Map<int, Movie>>((ref) {
  return SimpleWatchedNotifier(
    onMovieWatched: () {
      // Note: We call achievements tracking from within the provider
      // This matches the favorites pattern exactly
    },
  );
});

/// This follows the EXACT SAME pattern as StorageMoviesNotifier for favorites
/// Same methods, same logic, same simple approach that works perfectly
class SimpleWatchedNotifier extends StateNotifier<Map<int, Movie>> {
  SimpleWatchedNotifier({
    required this.onMovieWatched,
  }) : super({}) {
    // Load existing watched movies on initialization
    _loadExistingWatched();
    // NO auto-refresh to avoid blocking like favorites
  }

  int page = 0;
  final VoidCallback onMovieWatched;
  Timer? _refreshTimer;

  /// Load existing watched movies on initialization (same as favorites)
  Future<void> _loadExistingWatched() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        LoggerFactory.info('ℹ️ No user logged in, keeping watched state empty');
        state = {};
        return;
      }

      final simpleWatchedSync = SimpleWatchedSync.instance;
      final watchedMovies =
          await simpleWatchedSync.performSimpleSync(currentUser.id);

      final watchedMoviesMap = <int, Movie>{};
      for (final movie in watchedMovies) {
        watchedMoviesMap[movie.id] = movie;
      }



      if (watchedMoviesMap.isNotEmpty) {
        state = watchedMoviesMap;
        LoggerFactory.info(
            '✅ Loaded ${watchedMoviesMap.length} watched movies from simple sync');
      } else {
        // Ensure state is empty if no watched movies
        state = {};
        LoggerFactory.info('ℹ️ No watched movies found, state set to empty');
      }
    } catch (e) {
      // If error loading, keep empty state but log the error
      state = {};
      LoggerFactory.error('❌ Error loading existing watched movies: $e');
    }
  }

  Future<List<Movie>> loadNextPage() async {
    // Use the current state for pagination (same as favorites)
    final movies = state.values.toList();

    // Paginate locally (same as favorites)
    final startIndex = page * 10;
    final endIndex = (startIndex + 20).clamp(0, movies.length);
    final paginatedMovies =
        movies.sublist(startIndex.clamp(0, movies.length), endIndex);

    page++;

    final tempMoviesMap = <int, Movie>{};
    for (final movie in paginatedMovies) {
      tempMoviesMap[movie.id] = movie;
    }

    state = {...state, ...tempMoviesMap};

    return paginatedMovies;
  }

  Future<void> toggleWatched(Movie movie) async {
    final isWatched = state[movie.id] != null;

    LoggerFactory.debug(
        '🔍 [WatchedProvider] Toggle ${movie.id}:${movie.title} (current: $isWatched)');

    // Optimistic UI update (EXACT same as favorites)
    if (isWatched) {
      state = Map.from(state)..remove(movie.id);
    } else {
      state = {...state, movie.id: movie};
    }

    try {
      // SIMPLIFIED: Use SimpleWatchedSync directly (same as favorites)
      final simpleWatchedSync = SimpleWatchedSync.instance;
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (currentUser != null) {
        if (isWatched) {
          // Remove from Supabase
          await simpleWatchedSync.removeWatchedMovie(currentUser.id, movie.id);
          LoggerFactory.info('✅ Watched movie removed: ${movie.title}');
        } else {
          // Add to Supabase
          await simpleWatchedSync.addWatchedMovie(currentUser.id, movie);
          LoggerFactory.info('✅ Watched movie added: ${movie.title}');
          // Callback only if added
          onMovieWatched();
        }
      } else {
        LoggerFactory.info('ℹ️ No user logged in, only local change');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error in toggle watched: $e');
      // Revert optimistic change (EXACT same as favorites)
      if (isWatched) {
        state = {...state, movie.id: movie};
      } else {
        state = Map.from(state)..remove(movie.id);
      }
    }
  }

  /// Enable auto-refresh manually (same as favorites)
  void enableAutoRefresh() {
    LoggerFactory.info(
        '🔄 Enabling auto-refresh for watched movies (disabled temporarily like favorites)');
    _setupAutoRefresh();

    // Also start sync from Supabase (non-blocking)
    Timer(const Duration(seconds: 1), () {
      _syncFromSupabaseBackground();
    });
  }

  /// Setup auto-refresh (same as favorites - disabled)
  void _setupAutoRefresh() {
    if (_refreshTimer != null) return; // Already configured


  }

  /// Sync FROM Supabase in background (same as favorites)
  void _syncFromSupabaseBackground() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      LoggerFactory.debug(
          '📥 Starting sync FROM Supabase for watched: ${currentUser.id}');

      final simpleWatchedSync = SimpleWatchedSync.instance;
      final remoteWatched =
          await simpleWatchedSync.performSimpleSync(currentUser.id);

      // Add remote watched to current state (merge, not replace) - same as favorites
      final currentState = Map<int, Movie>.from(state);
      for (final movie in remoteWatched) {
        if (!currentState.containsKey(movie.id)) {
          currentState[movie.id] = movie;
        }
      }

      // Only update state if there are changes
      if (currentState.length != state.length) {
        state = currentState;
        LoggerFactory.info(
            '✅ Sync FROM Supabase completed for watched: ${remoteWatched.length} remote, ${state.length} total');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error in sync FROM Supabase for watched: $e');
    }
  }

  /// Disable auto-refresh (same as favorites)
  void disableAutoRefresh() {
    LoggerFactory.info('🛑 Disabling auto-refresh for watched movies');
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Refresh complete state from remote (same as favorites)
  Future<void> refreshWatched() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final simpleWatchedSync = SimpleWatchedSync.instance;
      final watchedMoviesData =
          await simpleWatchedSync.performSimpleSync(currentUser.id);

      final watchedMoviesMap = <int, Movie>{};
      for (final movie in watchedMoviesData) {
        watchedMoviesMap[movie.id] = movie;
      }

      // Only update if there are real changes to avoid rebuilds (same as favorites)
      if (!_mapsEqual(state, watchedMoviesMap)) {
        final oldCount = state.length;
        state = watchedMoviesMap;

        final newCount = watchedMoviesMap.length;
        if (newCount > oldCount) {
          LoggerFactory.info(
              '✅ Watched movies updated: +${newCount - oldCount} new watched');
        } else if (newCount < oldCount) {
          LoggerFactory.info(
              '🔄 Watched movies updated: -${oldCount - newCount} watched removed');
        } else {
          LoggerFactory.info('🔄 Watched movies refreshed from simple sync');
        }
      }
    } catch (e) {
      LoggerFactory.error('❌ Error refreshing watched movies: $e');
    }
  }

  /// Check if two maps are equal (same as favorites)
  bool _mapsEqual(Map<int, Movie> map1, Map<int, Movie> map2) {
    if (map1.length != map2.length) return false;

    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;
      if (map1[key]?.id != map2[key]?.id) return false;
    }

    return true;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
