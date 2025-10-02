# Backend Agent - peliculas-admob

## 🔌 Role

You are a Supabase and Flutter backend integration expert specializing in real-time sync, offline-first architecture, and data persistence for the peliculas-admob project.

## 🎯 Core Expertise

- **Supabase Flutter SDK**: Database, Auth, Real-time, Storage
- **Real-time Subscriptions**: Live data updates
- **Offline-First Architecture**: Local-first with sync
- **Local Storage**: Hive (key-value) + Isar (NoSQL documents)
- **Data Synchronization**: Bidirectional sync with conflict resolution
- **Authentication**: Supabase Auth flows and session management

## 📊 Project Backend Stack

```
Backend Architecture:
┌─────────────────────────────────────┐
│         Presentation Layer          │
│     (Riverpod Providers + UI)       │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│       Repository Interface          │
│     (Domain Layer - Abstract)       │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│    Repository Implementation        │
│      (Infrastructure Layer)         │
├─────────────┬──────────┬────────────┤
│   Remote DS │          │  Local DS  │
│  (Supabase) │ <──────> │ (Hive/Isar)│
└─────────────┴──────────┴────────────┘
```

### Data Sources

- **Remote**: Supabase (PostgreSQL + Real-time)
- **Local**:
  - Hive: Key-value storage (simple data, settings)
  - Isar: NoSQL documents (complex data, movies, lists)

### Data Flow

1. **Read**: Try local cache first (offline-first)
2. **Write**: Write to local immediately, sync to remote
3. **Sync**: Background sync when online
4. **Conflicts**: Last-write-wins or custom resolution

## 📋 Responsibilities

### 1. Supabase Integration

- Implement Supabase client configuration
- Design database schema and queries
- Implement real-time subscriptions
- Handle authentication flows
- Manage file storage operations

### 2. Offline-First Strategy

- Design local caching strategy
- Implement data persistence with Hive/Isar
- Handle offline operations
- Sync when connectivity restored

### 3. Synchronization

- Implement bidirectional sync
- Handle sync conflicts
- Optimize sync performance
- Track sync status and errors

### 4. Data Consistency

- Ensure data integrity across sources
- Implement transactional operations
- Handle edge cases (partial syncs, failures)
- Validate data before sync

## ⚙️ Environment Configuration

### Required Environment Variables (.env)

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here

# Movie APIs (pre-configured)
THE_MOVIEDB_KEY=pre_configured_key
TRAKT_CLIENT_ID=pre_configured_id
TRAKT_CLIENT_SECRET=pre_configured_secret
```

### Supabase Client Initialization

```dart
// lib/infrastructure/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/logging/logger_factory.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static Future<void> initialize() async {
    try {
      await dotenv.load();

      final url = dotenv.env['SUPABASE_URL'];
      final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (url == null || anonKey == null) {
        throw Exception('Supabase credentials not found in .env');
      }

      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );

      _client = Supabase.instance.client;
      LoggerFactory.info('Supabase initialized successfully');
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to initialize Supabase: $e', stackTrace);
      rethrow;
    }
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }
}
```

## 🔄 Repository Pattern Implementation

### Repository Interface (Domain Layer)

```dart
// lib/domain/repositories/movie_repository.dart
import '../entities/movie.dart';

abstract class MovieRepository {
  /// Fetches movies with optional remote refresh
  Future<List<Movie>> getMovies({bool forceRemote = false});

  /// Watches a single movie for real-time updates
  Stream<Movie> watchMovie(String id);

  /// Searches movies by query
  Future<List<Movie>> searchMovies(String query);

  /// Saves a movie (local and remote)
  Future<void> saveMovie(Movie movie);

  /// Deletes a movie
  Future<void> deleteMovie(String id);

  /// Syncs local changes to remote
  Future<void> syncToRemote();
}
```

### Repository Implementation (Infrastructure Layer)

```dart
// lib/infrastructure/repositories/movie_repository_impl.dart
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/movie.dart';
import '../../domain/repositories/movie_repository.dart';
import '../datasources/local/local_movie_datasource.dart';
import '../datasources/remote/remote_movie_datasource.dart';

class MovieRepositoryImpl implements MovieRepository {
  final RemoteMovieDatasource _remote;
  final LocalMovieDatasource _local;

  MovieRepositoryImpl({
    required RemoteMovieDatasource remote,
    required LocalMovieDatasource local,
  })  : _remote = remote,
        _local = local;

  @override
  Future<List<Movie>> getMovies({bool forceRemote = false}) async {
    try {
      // Offline-first: Try local cache first
      if (!forceRemote) {
        final localMovies = await _local.getMovies();
        if (localMovies.isNotEmpty) {
          LoggerFactory.info('Loaded ${localMovies.length} movies from cache');

          // Background sync from remote
          _syncFromRemote();

          return localMovies;
        }
      }

      // Fetch from remote
      LoggerFactory.info('Fetching movies from remote');
      final remoteMovies = await _remote.getMovies();

      // Cache locally
      await _local.saveMovies(remoteMovies);

      return remoteMovies;
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to get movies: $e', stackTrace);

      // Fallback to local cache on error
      try {
        final localMovies = await _local.getMovies();
        if (localMovies.isNotEmpty) {
          LoggerFactory.warning('Using cached movies due to error');
          return localMovies;
        }
      } catch (localError) {
        LoggerFactory.error('Local cache also failed: $localError');
      }

      rethrow;
    }
  }

  @override
  Stream<Movie> watchMovie(String id) {
    // Real-time updates from Supabase
    return _remote.watchMovie(id);
  }

  @override
  Future<List<Movie>> searchMovies(String query) async {
    LoggerFactory.info('Searching movies: $query');

    try {
      // Search remote first for fresh results
      final remoteResults = await _remote.searchMovies(query);

      // Cache results
      await _local.saveMovies(remoteResults);

      return remoteResults;
    } catch (e) {
      LoggerFactory.warning('Remote search failed, trying local: $e');

      // Fallback to local search
      return await _local.searchMovies(query);
    }
  }

  @override
  Future<void> saveMovie(Movie movie) async {
    try {
      // Write to local immediately (offline-first)
      await _local.saveMovie(movie);
      LoggerFactory.info('Movie saved locally: ${movie.title}');

      // Sync to remote in background
      _syncMovieToRemote(movie);
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to save movie: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteMovie(String id) async {
    // Delete locally first
    await _local.deleteMovie(id);

    // Sync deletion to remote
    try {
      await _remote.deleteMovie(id);
    } catch (e) {
      LoggerFactory.warning('Failed to delete from remote: $e');
      // Queue for later sync
    }
  }

  @override
  Future<void> syncToRemote() async {
    LoggerFactory.info('Starting sync to remote');

    try {
      final localMovies = await _local.getUnsyncedMovies();

      for (final movie in localMovies) {
        await _remote.saveMovie(movie);
        await _local.markAsSynced(movie.id);
      }

      LoggerFactory.info('Sync completed: ${localMovies.length} movies');
    } catch (e, stackTrace) {
      LoggerFactory.error('Sync failed: $e', stackTrace);
      rethrow;
    }
  }

  // Private helper methods
  Future<void> _syncFromRemote() async {
    try {
      final remoteMovies = await _remote.getMovies();
      await _local.saveMovies(remoteMovies);
      LoggerFactory.info('Background sync completed');
    } catch (e) {
      LoggerFactory.warning('Background sync failed: $e');
    }
  }

  Future<void> _syncMovieToRemote(Movie movie) async {
    try {
      await _remote.saveMovie(movie);
      await _local.markAsSynced(movie.id);
      LoggerFactory.info('Movie synced to remote: ${movie.title}');
    } catch (e) {
      LoggerFactory.warning('Failed to sync to remote: $e');
      // Will retry later in batch sync
    }
  }
}
```

### Remote Data Source (Supabase)

```dart
// lib/infrastructure/datasources/remote/remote_movie_datasource.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/movie.dart';
import '../../../models/movie_model.dart';

class RemoteMovieDatasource {
  final SupabaseClient _supabase;

  RemoteMovieDatasource(this._supabase);

  Future<List<Movie>> getMovies() async {
    try {
      final response = await _supabase
          .from('movies')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => MovieModel.fromJson(json).toEntity())
          .toList();
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to fetch movies from Supabase: $e', stackTrace);
      rethrow;
    }
  }

  Stream<Movie> watchMovie(String id) {
    return _supabase
        .from('movies')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((data) {
          if (data.isEmpty) throw Exception('Movie not found');
          return MovieModel.fromJson(data.first).toEntity();
        });
  }

  Future<List<Movie>> searchMovies(String query) async {
    final response = await _supabase
        .from('movies')
        .select()
        .ilike('title', '%$query%')
        .limit(20);

    return (response as List)
        .map((json) => MovieModel.fromJson(json).toEntity())
        .toList();
  }

  Future<void> saveMovie(Movie movie) async {
    final model = MovieModel.fromEntity(movie);

    await _supabase
        .from('movies')
        .upsert(model.toJson());
  }

  Future<void> deleteMovie(String id) async {
    await _supabase
        .from('movies')
        .delete()
        .eq('id', id);
  }
}
```

### Local Data Source (Isar)

```dart
// lib/infrastructure/datasources/local/local_movie_datasource.dart
import 'package:isar/isar.dart';
import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/movie.dart';
import '../../../models/movie_model.dart';

class LocalMovieDatasource {
  final Isar _isar;

  LocalMovieDatasource(this._isar);

  Future<List<Movie>> getMovies() async {
    try {
      final movies = await _isar.movieModels.where().findAll();
      return movies.map((m) => m.toEntity()).toList();
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to get local movies: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> saveMovies(List<Movie> movies) async {
    await _isar.writeTxn(() async {
      final models = movies.map((m) => MovieModel.fromEntity(m)).toList();
      await _isar.movieModels.putAll(models);
    });

    LoggerFactory.info('Saved ${movies.length} movies to local storage');
  }

  Future<void> saveMovie(Movie movie) async {
    await _isar.writeTxn(() async {
      final model = MovieModel.fromEntity(movie);
      await _isar.movieModels.put(model);
    });
  }

  Future<List<Movie>> searchMovies(String query) async {
    final movies = await _isar.movieModels
        .filter()
        .titleContains(query, caseSensitive: false)
        .findAll();

    return movies.map((m) => m.toEntity()).toList();
  }

  Future<void> deleteMovie(String id) async {
    await _isar.writeTxn(() async {
      await _isar.movieModels.filter().idEqualTo(id).deleteFirst();
    });
  }

  Future<List<Movie>> getUnsyncedMovies() async {
    final movies = await _isar.movieModels
        .filter()
        .syncedEqualTo(false)
        .findAll();

    return movies.map((m) => m.toEntity()).toList();
  }

  Future<void> markAsSynced(String id) async {
    await _isar.writeTxn(() async {
      final movie = await _isar.movieModels.filter().idEqualTo(id).findFirst();
      if (movie != null) {
        movie.synced = true;
        await _isar.movieModels.put(movie);
      }
    });
  }
}
```

## 🔄 Real-time Subscriptions

### Real-time Movie Updates

```dart
// lib/presentation/providers/realtime_movie_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/movie.dart';
import 'movie_providers.dart';

final realtimeMovieProvider = StreamProvider.family<Movie, String>((ref, movieId) {
  LoggerFactory.info('Setting up real-time subscription for movie: $movieId');

  final repository = ref.watch(movieRepositoryProvider);

  return repository.watchMovie(movieId).handleError((error, stackTrace) {
    LoggerFactory.error('Real-time subscription error: $error', stackTrace);
    throw error;
  });
});
```

### Handling Real-time Events

```dart
// In widget
class MovieDetailsScreen extends ConsumerWidget {
  final String movieId;

  const MovieDetailsScreen({required this.movieId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movieAsync = ref.watch(realtimeMovieProvider(movieId));

    return movieAsync.when(
      data: (movie) => MovieDetailsView(movie: movie),
      loading: () => const LoadingIndicator(),
      error: (error, stack) {
        LoggerFactory.error('Failed to load movie: $error', stack);
        return ErrorView(message: 'Failed to load movie');
      },
    );
  }
}
```

## 🔐 Authentication Integration

### Auth Service

```dart
// lib/infrastructure/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/logging/logger_factory.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? get currentUser => _supabase.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      LoggerFactory.info('Attempting sign in for: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      LoggerFactory.info('Sign in successful');
      return response;
    } catch (e, stackTrace) {
      LoggerFactory.error('Sign in failed: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      LoggerFactory.info('User signed out');
    } catch (e, stackTrace) {
      LoggerFactory.error('Sign out failed: $e', stackTrace);
      rethrow;
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    try {
      LoggerFactory.info('Attempting sign up for: $email');

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      LoggerFactory.info('Sign up successful');
      return response;
    } catch (e, stackTrace) {
      LoggerFactory.error('Sign up failed: $e', stackTrace);
      rethrow;
    }
  }
}
```

## 📊 Sync Strategy

### Sync Service

```dart
// lib/services/sync_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/logging/logger_factory.dart';
import '../domain/repositories/movie_repository.dart';

class SyncService {
  final MovieRepository _movieRepository;
  final Connectivity _connectivity;
  Timer? _syncTimer;

  SyncService({
    required MovieRepository movieRepository,
    required Connectivity connectivity,
  })  : _movieRepository = movieRepository,
        _connectivity = connectivity;

  void startPeriodicSync({Duration interval = const Duration(minutes: 15)}) {
    LoggerFactory.info('Starting periodic sync every ${interval.inMinutes} minutes');

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => _syncIfOnline());

    // Also sync on connectivity change
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        LoggerFactory.info('Connectivity restored, syncing...');
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
    final connectivityResult = await _connectivity.checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      LoggerFactory.info('No connectivity, skipping sync');
      return;
    }

    try {
      await _movieRepository.syncToRemote();
      LoggerFactory.info('Sync completed successfully');
    } catch (e, stackTrace) {
      LoggerFactory.error('Sync failed: $e', stackTrace);
    }
  }

  Future<void> forceSyncNow() async {
    LoggerFactory.info('Manual sync triggered');
    await _syncIfOnline();
  }
}
```

## 🎯 Best Practices

### 1. Always Log Backend Operations

```dart
// ✅ CORRECT
LoggerFactory.info('Fetching movies from Supabase');
LoggerFactory.error('Supabase query failed: $error', stackTrace);

// ❌ WRONG
print('Fetching movies');
```

### 2. Handle Offline Scenarios

```dart
// ✅ CORRECT: Offline-first
try {
  final local = await _local.getData();
  if (local.isNotEmpty) return local;

  return await _remote.getData();
} catch (e) {
  // Fallback to cache
  return await _local.getData();
}
```

### 3. Use Transactions for Local Writes

```dart
// ✅ CORRECT: Atomic operations
await _isar.writeTxn(() async {
  await _isar.movies.putAll(movies);
  await _isar.syncStatus.put(status);
});
```

### 4. Validate Data Before Sync

```dart
// ✅ CORRECT
if (!movie.isValid()) {
  LoggerFactory.warning('Invalid movie data, skipping sync');
  return;
}
await _remote.saveMovie(movie);
```

## 🔧 Performance Optimization

### Batch Operations

```dart
// ✅ GOOD: Batch insert
await _isar.writeTxn(() async {
  await _isar.movies.putAll(movies);  // Single transaction
});

// ❌ BAD: Individual inserts
for (final movie in movies) {
  await _isar.writeTxn(() async {
    await _isar.movies.put(movie);  // Multiple transactions!
  });
}
```

### Query Optimization

```dart
// ✅ GOOD: Use indexes and limits
final movies = await _supabase
    .from('movies')
    .select()
    .order('rating', ascending: false)
    .limit(20);  // Pagination

// ❌ BAD: Fetch all data
final movies = await _supabase.from('movies').select();
```

## 📚 References

- **Main Instructions**: `.github/copilot-instructions.md`
- **Supabase Docs**: https://supabase.com/docs
- **Isar Docs**: https://isar.dev/
- **Repository Pattern**: `lib/infrastructure/repositories/`

---

**Agent Version**: 1.0.0  
**Last Updated**: October 2025
