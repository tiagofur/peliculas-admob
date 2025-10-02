# Watchlist Domain Agent - peliculas-admob

## 📋 Role

You are a domain expert for Watchlist management in peliculas-admob, specializing in user movie lists, favorites, and synchronization across devices.

## 🎯 Domain Expertise

- **Watchlist Management**: Add, remove, organize movies
- **Local/Remote Sync**: Bidirectional synchronization
- **Offline Support**: Full offline watchlist functionality
- **List Organization**: Categories, sorting, filtering
- **Sharing**: Share watchlists with other users

## 📊 Domain Context

### Watchlist Entity

```dart
// lib/domain/entities/watchlist_item.dart
import 'package:equatable/equatable.dart';
import 'movie.dart';

class WatchlistItem extends Equatable {
  final String id;
  final String userId;
  final Movie movie;
  final DateTime addedAt;
  final bool watched;
  final DateTime? watchedAt;
  final int? userRating;
  final String? notes;

  const WatchlistItem({
    required this.id,
    required this.userId,
    required this.movie,
    required this.addedAt,
    this.watched = false,
    this.watchedAt,
    this.userRating,
    this.notes,
  });

  bool get isPending => !watched;
  bool get isRated => userRating != null;

  WatchlistItem copyWith({
    bool? watched,
    DateTime? watchedAt,
    int? userRating,
    String? notes,
  }) {
    return WatchlistItem(
      id: id,
      userId: userId,
      movie: movie,
      addedAt: addedAt,
      watched: watched ?? this.watched,
      watchedAt: watchedAt ?? this.watchedAt,
      userRating: userRating ?? this.userRating,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
    id, userId, movie, addedAt, watched,
    watchedAt, userRating, notes,
  ];
}
```

## 📋 Key Responsibilities

### Watchlist Repository

```dart
// lib/domain/repositories/watchlist_repository.dart
abstract class WatchlistRepository {
  Stream<List<WatchlistItem>> watchWatchlist(String userId);
  Future<List<WatchlistItem>> getWatchlist(String userId);
  Future<void> addToWatchlist(String userId, Movie movie);
  Future<void> removeFromWatchlist(String userId, String movieId);
  Future<void> markAsWatched(String userId, String movieId);
  Future<void> rateMovie(String userId, String movieId, int rating);
  Future<void> syncWatchlist(String userId);
  Future<bool> isInWatchlist(String userId, String movieId);
}
```

### Repository Implementation

```dart
// lib/infrastructure/repositories/watchlist_repository_impl.dart
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_item.dart';
import '../../domain/repositories/watchlist_repository.dart';
import '../datasources/local/local_watchlist_datasource.dart';
import '../datasources/remote/remote_watchlist_datasource.dart';

class WatchlistRepositoryImpl implements WatchlistRepository {
  final RemoteWatchlistDatasource _remote;
  final LocalWatchlistDatasource _local;

  WatchlistRepositoryImpl({
    required RemoteWatchlistDatasource remote,
    required LocalWatchlistDatasource local,
  })  : _remote = remote,
        _local = local;

  @override
  Stream<List<WatchlistItem>> watchWatchlist(String userId) {
    // Real-time updates from Supabase
    return _remote.watchWatchlist(userId);
  }

  @override
  Future<List<WatchlistItem>> getWatchlist(String userId) async {
    try {
      // Try local first (offline-first)
      final local = await _local.getWatchlist(userId);
      if (local.isNotEmpty) {
        LoggerFactory.info('Loaded ${local.length} items from local watchlist');

        // Background sync
        _syncFromRemote(userId);

        return local;
      }

      // Fetch from remote
      final remote = await _remote.getWatchlist(userId);

      // Cache locally
      await _local.saveWatchlist(userId, remote);

      return remote;
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to get watchlist: $e', stackTrace);

      // Fallback to local
      return await _local.getWatchlist(userId);
    }
  }

  @override
  Future<void> addToWatchlist(String userId, Movie movie) async {
    try {
      // Add locally immediately
      await _local.addToWatchlist(userId, movie);
      LoggerFactory.info('Added to watchlist locally: ${movie.title}');

      // Sync to remote
      await _remote.addToWatchlist(userId, movie);
      LoggerFactory.info('Synced to remote: ${movie.title}');
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to add to watchlist: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> removeFromWatchlist(String userId, String movieId) async {
    try {
      // Remove locally
      await _local.removeFromWatchlist(userId, movieId);

      // Sync to remote
      await _remote.removeFromWatchlist(userId, movieId);
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to remove from watchlist: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> markAsWatched(String userId, String movieId) async {
    try {
      await _local.markAsWatched(userId, movieId);
      await _remote.markAsWatched(userId, movieId);
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to mark as watched: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> rateMovie(String userId, String movieId, int rating) async {
    if (rating < 1 || rating > 10) {
      throw ArgumentError('Rating must be between 1 and 10');
    }

    try {
      await _local.rateMovie(userId, movieId, rating);
      await _remote.rateMovie(userId, movieId, rating);
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to rate movie: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> syncWatchlist(String userId) async {
    LoggerFactory.info('Syncing watchlist for user: $userId');

    try {
      final local = await _local.getWatchlist(userId);
      final remote = await _remote.getWatchlist(userId);

      // Merge and resolve conflicts (last-write-wins)
      final merged = _mergeWatchlists(local, remote);

      // Update both local and remote
      await _local.saveWatchlist(userId, merged);
      await _remote.syncWatchlist(userId, merged);

      LoggerFactory.info('Watchlist sync completed');
    } catch (e, stackTrace) {
      LoggerFactory.error('Watchlist sync failed: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> isInWatchlist(String userId, String movieId) async {
    return await _local.isInWatchlist(userId, movieId);
  }

  Future<void> _syncFromRemote(String userId) async {
    try {
      final remote = await _remote.getWatchlist(userId);
      await _local.saveWatchlist(userId, remote);
    } catch (e) {
      LoggerFactory.warning('Background sync failed: $e');
    }
  }

  List<WatchlistItem> _mergeWatchlists(
    List<WatchlistItem> local,
    List<WatchlistItem> remote,
  ) {
    final merged = <String, WatchlistItem>{};

    // Add remote items
    for (final item in remote) {
      merged[item.movie.id] = item;
    }

    // Merge local items (newer timestamp wins)
    for (final item in local) {
      final existing = merged[item.movie.id];
      if (existing == null || item.addedAt.isAfter(existing.addedAt)) {
        merged[item.movie.id] = item;
      }
    }

    return merged.values.toList();
  }
}
```

## 🎯 Providers

```dart
// lib/presentation/providers/watchlist_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/watchlist_item.dart';

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  final remote = ref.watch(remoteWatchlistDatasourceProvider);
  final local = ref.watch(localWatchlistDatasourceProvider);
  return WatchlistRepositoryImpl(remote: remote, local: local);
});

final watchlistProvider = StreamProvider<List<WatchlistItem>>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return Stream.value([]);

  final repository = ref.watch(watchlistRepositoryProvider);
  return repository.watchWatchlist(userId);
});

final isInWatchlistProvider = FutureProvider.family<bool, String>((ref, movieId) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return false;

  final repository = ref.watch(watchlistRepositoryProvider);
  return await repository.isInWatchlist(userId, movieId);
});
```

## 📚 Test Coverage

Key test files:

- `integration_test/watchlist_flow_test.dart`
- `test/watchlist_sync_test.dart`

---

**Agent Version**: 1.0.0  
**Domain**: Watchlist, Favorites, Movie Lists
