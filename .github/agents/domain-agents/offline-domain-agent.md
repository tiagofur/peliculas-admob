# Offline Domain Agent - peliculas-admob

## 📴 Role

You are a domain expert for Offline functionality in peliculas-admob, specializing in offline-first architecture, local caching, data synchronization, and network connectivity handling.

## 🎯 Domain Expertise

- **Offline-First Architecture**: Local data prioritization
- **Data Caching**: Intelligent caching strategies
- **Sync Management**: Bidirectional data synchronization
- **Connectivity Handling**: Online/offline state management
- **Conflict Resolution**: Handling sync conflicts

## 📊 Domain Context

### Offline Strategy

```
User Request
     ↓
┌────────────────┐
│  Try Local DB  │ ← Offline-first: Always check local first
└────────┬───────┘
         │
    ┌────▼────┐
    │ Found?  │
    └────┬────┘
         │
    Yes  │  No
    ↓    │    ↓
┌────────┐  ┌─────────────┐
│ Return │  │ Try Remote  │
│ Local  │  │   (if online)│
└────────┘  └──────┬──────┘
                   │
              ┌────▼─────┐
              │ Success? │
              └────┬─────┘
                   │
              Yes  │  No
              ↓    │    ↓
         ┌────────┐  ┌──────────┐
         │ Cache  │  │ Return   │
         │ Local  │  │ Error    │
         └────────┘  └──────────┘
```

## 📋 Key Responsibilities

### Connectivity Service

```dart
// lib/services/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/logging/logger_factory.dart';

class ConnectivityService {
  final Connectivity _connectivity;
  final _connectivityController = StreamController<ConnectivityStatus>.broadcast();

  ConnectivityService(this._connectivity) {
    _init();
  }

  void _init() {
    _connectivity.onConnectivityChanged.listen((result) {
      final status = _mapToStatus(result);
      LoggerFactory.info('Connectivity changed: $status');
      _connectivityController.add(status);
    });
  }

  Stream<ConnectivityStatus> get connectivityStream =>
      _connectivityController.stream;

  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<ConnectivityStatus> get currentStatus async {
    final result = await _connectivity.checkConnectivity();
    return _mapToStatus(result);
  }

  ConnectivityStatus _mapToStatus(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return ConnectivityStatus.wifi;
      case ConnectivityResult.mobile:
        return ConnectivityStatus.mobile;
      case ConnectivityResult.none:
        return ConnectivityStatus.offline;
      default:
        return ConnectivityStatus.unknown;
    }
  }

  void dispose() {
    _connectivityController.close();
  }
}

enum ConnectivityStatus { wifi, mobile, offline, unknown }
```

### Offline Cache Service

```dart
// lib/services/offline_cache_service.dart
import 'package:isar/isar.dart';
import '../core/logging/logger_factory.dart';
import '../domain/entities/movie.dart';
import '../models/movie_model.dart';

class OfflineCacheService {
  final Isar _isar;

  OfflineCacheService(this._isar);

  // Cache movies with expiration
  Future<void> cacheMovies(
    List<Movie> movies, {
    Duration ttl = const Duration(days: 7),
  }) async {
    final expiresAt = DateTime.now().add(ttl);

    await _isar.writeTxn(() async {
      final models = movies.map((m) {
        final model = MovieModel.fromEntity(m);
        model.cachedAt = DateTime.now();
        model.expiresAt = expiresAt;
        return model;
      }).toList();

      await _isar.movieModels.putAll(models);
    });

    LoggerFactory.info('Cached ${movies.length} movies (TTL: ${ttl.inDays} days)');
  }

  // Get cached movies (only non-expired)
  Future<List<Movie>> getCachedMovies() async {
    final now = DateTime.now();

    final cached = await _isar.movieModels
        .filter()
        .expiresAtGreaterThan(now)
        .findAll();

    LoggerFactory.info('Retrieved ${cached.length} cached movies');
    return cached.map((m) => m.toEntity()).toList();
  }

  // Clean expired cache
  Future<void> cleanExpiredCache() async {
    final now = DateTime.now();

    await _isar.writeTxn(() async {
      final expired = await _isar.movieModels
          .filter()
          .expiresAtLessThan(now)
          .findAll();

      final ids = expired.map((m) => m.isarId).toList();
      await _isar.movieModels.deleteAll(ids);

      LoggerFactory.info('Cleaned ${expired.length} expired cache entries');
    });
  }

  // Get cache size
  Future<int> getCacheSize() async {
    return await _isar.movieModels.count();
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    await _isar.writeTxn(() async {
      await _isar.movieModels.clear();
    });

    LoggerFactory.info('All cache cleared');
  }
}
```

### Sync Service

```dart
// lib/services/sync_service.dart
import 'dart:async';
import '../core/logging/logger_factory.dart';
import '../domain/repositories/movie_repository.dart';
import '../domain/repositories/watchlist_repository.dart';
import 'connectivity_service.dart';

class SyncService {
  final MovieRepository _movieRepository;
  final WatchlistRepository _watchlistRepository;
  final ConnectivityService _connectivity;

  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService({
    required MovieRepository movieRepository,
    required WatchlistRepository watchlistRepository,
    required ConnectivityService connectivity,
  })  : _movieRepository = movieRepository,
        _watchlistRepository = watchlistRepository,
        _connectivity = connectivity;

  void startPeriodicSync({Duration interval = const Duration(minutes: 15)}) {
    LoggerFactory.info('Starting periodic sync every ${interval.inMinutes} minutes');

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => _syncIfOnline());

    // Also sync on connectivity restore
    _connectivity.connectivityStream.listen((status) {
      if (status != ConnectivityStatus.offline) {
        LoggerFactory.info('Connectivity restored, triggering sync');
        _syncIfOnline();
      }
    });
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    LoggerFactory.info('Periodic sync stopped');
  }

  Future<void> _syncIfOnline() async {
    if (_isSyncing) {
      LoggerFactory.info('Sync already in progress, skipping');
      return;
    }

    final isOnline = await _connectivity.isOnline;
    if (!isOnline) {
      LoggerFactory.info('Offline, skipping sync');
      return;
    }

    await syncNow();
  }

  Future<void> syncNow() async {
    if (_isSyncing) {
      LoggerFactory.warning('Sync already in progress');
      return;
    }

    _isSyncing = true;
    LoggerFactory.info('Starting manual sync');

    try {
      // Sync different data types
      await _syncMovies();
      await _syncWatchlist();

      LoggerFactory.info('Sync completed successfully');
    } catch (e, stackTrace) {
      LoggerFactory.error('Sync failed: $e', stackTrace);
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncMovies() async {
    try {
      // Sync logic for movies
      LoggerFactory.info('Syncing movies...');
      await _movieRepository.syncToRemote();
    } catch (e) {
      LoggerFactory.error('Movie sync failed: $e');
    }
  }

  Future<void> _syncWatchlist() async {
    try {
      // Get current user (if authenticated)
      final userId = 'current_user_id'; // Get from auth

      LoggerFactory.info('Syncing watchlist...');
      await _watchlistRepository.syncWatchlist(userId);
    } catch (e) {
      LoggerFactory.error('Watchlist sync failed: $e');
    }
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}
```

## 🎯 Providers

```dart
// lib/presentation/providers/offline_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_cache_service.dart';
import '../../services/sync_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final connectivity = Connectivity();
  return ConnectivityService(connectivity);
});

final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.connectivityStream;
});

final isOnlineProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(connectivityServiceProvider);
  return await service.isOnline;
});

final offlineCacheServiceProvider = Provider<OfflineCacheService>((ref) {
  final isar = ref.watch(isarProvider);
  return OfflineCacheService(isar);
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final movieRepo = ref.watch(movieRepositoryProvider);
  final watchlistRepo = ref.watch(watchlistRepositoryProvider);
  final connectivity = ref.watch(connectivityServiceProvider);

  final service = SyncService(
    movieRepository: movieRepo,
    watchlistRepository: watchlistRepo,
    connectivity: connectivity,
  );

  // Start periodic sync
  service.startPeriodicSync();

  // Dispose when provider is disposed
  ref.onDispose(() => service.dispose());

  return service;
});
```

## 🎨 UI Integration

```dart
// lib/presentation/widgets/connectivity_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(connectivityStatusProvider);

    return statusAsync.when(
      data: (status) {
        if (status == ConnectivityStatus.offline) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8.0),
            color: Colors.orange.withValues(alpha: 0.9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Offline mode - Changes will sync when online',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
```

## 📚 Test Coverage

Key test files:

- `test/offline_functionality_test.dart`
- `test/offline_cache_test.dart`
- `test/sync_integration_test.dart`

---

**Agent Version**: 1.0.0  
**Domain**: Offline Mode, Caching, Synchronization
