# Unified Repository Pattern Documentation

## Overview

The unified repository pattern implementation consolidates data access across the application, providing a clean separation between business logic and data storage while supporting both local storage and remote synchronization.

## Architecture

### Core Components

1. **Repository Interfaces** (`lib/domain/repositories/`)
   - `FavoritesRepository` - Manages user's favorite movies
   - `WatchedMoviesRepository` - Manages watched movies tracking  
   - `CustomListsRepository` - Manages user-created movie lists
   - `WatchlistRepository` - Manages movies to watch later
   - `SyncableRepository<T>` - Base interface for sync-enabled repositories

2. **Base Implementation** (`lib/infrastructure/repositories/`)
   - `BaseHybridRepository<T>` - Abstract base class providing common sync functionality
   - Hybrid implementations extending the base class

3. **Provider Configuration** (`lib/presentation/providers/`)
   - Interface-based providers for dependency injection
   - Legacy provider aliases for backward compatibility

## Key Benefits

### 1. Clean Separation of Concerns
- **Domain Layer**: Pure business logic and interfaces
- **Infrastructure Layer**: Implementation details and external dependencies
- **Presentation Layer**: UI components depend only on interfaces

### 2. Consistent Sync Patterns
- All repositories follow the same sync workflow
- Common error handling and logging
- Centralized connectivity and authentication checks

### 3. Improved Testability
- Interface-based dependency injection
- Easy mocking and stubbing for unit tests
- Consistent test patterns across repositories

### 4. Reduced Code Duplication
- Common functionality centralized in `BaseHybridRepository`
- Consistent method signatures and error handling
- Shared utilities for sync operations

## Usage Examples

### Basic Repository Usage

```dart
// Favorites Repository
final favoritesRepo = ref.read(favoritesRepositoryProvider);

// Add to favorites
await favoritesRepo.toggleFavorite(movie);

// Check if movie is favorite
final isFavorite = await favoritesRepo.isMovieFavorite(movieId);

// Get all favorites
final favorites = await favoritesRepo.getFavoriteMovies();
```

### Watched Movies Repository

```dart
// Watched Movies Repository
final watchedRepo = ref.read(watchedMoviesRepositoryProvider);

// Mark as watched
await watchedRepo.markAsWatched(movie);

// Check if watched
final isWatched = await watchedRepo.isMovieWatched(movieId);

// Load watched movies
final watchedMovies = await watchedRepo.loadWatchedMovies(limit: 20);
```

### Sync Operations

```dart
// Manual sync
await favoritesRepo.syncWithRemote();

// Check sync status
final hasPendingSync = await favoritesRepo.hasPendingSync();

// Clear local data (logout)
await favoritesRepo.clearLocalData();
```

## Migration Guide

### From Legacy Providers

The old concrete providers are still available for backward compatibility:

```dart
// Old way (still works)
final legacyRepo = ref.read(hybridFavoritesRepositoryProvider);

// New way (recommended)
final newRepo = ref.read(favoritesRepositoryProvider);
```

### Provider Updates

When updating code to use the new pattern:

1. Replace concrete type dependencies with interface types
2. Use new provider names for cleaner code
3. Leverage interface methods for consistent operations

```dart
// Before
class MovieScreen extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final hybridRepo = ref.read(hybridFavoritesRepositoryProvider);
    // ...
  }
}

// After  
class MovieScreen extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesRepo = ref.read(favoritesRepositoryProvider);
    // ...
  }
}
```

## Testing

### Unit Tests

```dart
test('favorites repository operations', () async {
  final container = ProviderContainer();
  final repo = container.read(favoritesRepositoryProvider);
  
  expect(repo, isA<FavoritesRepository>());
  
  // Test interface compliance
  expect(repo.toggleFavorite, isA<Function>());
  expect(repo.getFavoriteMovies(), isA<Future<Map<int, Movie>>>());
  
  container.dispose();
});
```

### Integration Tests

See `test/repository_integration_test.dart` for comprehensive integration test examples.

## Error Handling

All repositories use consistent error types:

- `LocalStorageException` - Local storage errors
- `SupabaseSyncException` - Remote sync errors  
- `NetworkException` - Connectivity issues
- `SyncException` - General sync problems

## Best Practices

### 1. Use Interface Types
Always depend on repository interfaces, not concrete implementations:

```dart
// Good
final FavoritesRepository repo = ref.read(favoritesRepositoryProvider);

// Avoid
final HybridFavoritesRepository repo = ref.read(hybridFavoritesRepositoryProvider);
```

### 2. Handle Async Operations
All repository methods are async and should be properly awaited:

```dart
try {
  await repo.toggleFavorite(movie);
  // Handle success
} on LocalStorageException catch (e) {
  // Handle local storage error
} on SyncException catch (e) {
  // Handle sync error
}
```

### 3. Leverage Sync Methods
Use built-in sync methods for data consistency:

```dart
// Repositories automatically sync when online and authenticated
await repo.toggleFavorite(movie); // Syncs automatically

// Manual sync when needed
await repo.syncWithRemote();
```

## Future Enhancements

1. **Conflict Resolution**: Enhanced conflict resolution strategies
2. **Offline Support**: Improved offline-first capabilities  
3. **Performance**: Query optimization and caching improvements
4. **Analytics**: Repository usage metrics and monitoring

## Files Modified

- `lib/domain/repositories/` - New repository interfaces
- `lib/infrastructure/repositories/base_hybrid_repository.dart` - Base implementation
- `lib/infrastructure/repositories/hybrid_*_repository.dart` - Updated implementations  
- `lib/presentation/providers/hybrid_repositories_provider.dart` - Updated providers
- `test/repository_*.dart` - Test coverage

This unified approach provides a solid foundation for maintainable, testable, and scalable data access patterns throughout the application.