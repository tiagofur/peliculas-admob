# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Commands

### Development Commands
```bash
# Install dependencies
flutter pub get

# Run code generation (for Hive models and JSON serialization)
flutter packages pub run build_runner build

# Format code
dart format --set-exit-if-changed .

# Analyze code
flutter analyze --fatal-infos --fatal-warnings

# Run tests
flutter test

# Run specific test
flutter test test/services/conflict_resolution_comprehensive_test.dart

# Generate test coverage
flutter test --coverage

# Build for different platforms
flutter run                    # Debug mode
flutter build web --release    # Web production build
flutter build apk --release    # Android production build
```

### Quality Gates (Run before commits)
```bash
# Complete validation pipeline (matches CI)
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Architecture Overview

This is a **Flutter 3.0+ movies application** following **Clean Architecture with Domain-Driven Design**, featuring comprehensive offline-first functionality with real-time synchronization.

### Core Architecture Layers

- **Domain Layer** (`lib/domain/`): Entities, repositories interfaces, and business logic
- **Infrastructure Layer** (`lib/infrastructure/`): Repository implementations, data sources, and external services
- **Presentation Layer** (`lib/presentation/`): UI screens, widgets, and state management with Riverpod
- **Core Services** (`lib/core/`): Cross-cutting concerns like sync, caching, logging, gamification

### Key Technologies & Patterns

- **State Management**: Flutter Riverpod with StateNotifier pattern
- **Backend**: Supabase (PostgreSQL + Auth + Real-time) + Firebase (auxiliary services)
- **Local Storage**: Hive (primary cache) + Isar (complex queries, currently disabled)
- **External APIs**: TMDB API (movies data), YouTube API (trailers)
- **Offline-First**: Comprehensive sync system with conflict resolution
- **Real-time Sync**: WebSocket-based synchronization using Supabase Realtime

### Hybrid Repository Pattern

The app uses a sophisticated **Hybrid Repository Pattern** for offline-first functionality:

```dart
// Example: HybridFavoritesRepository combines local + remote data
class HybridFavoritesRepository extends BaseHybridRepository<FavoriteMovie> {
  // Automatically handles:
  // - Local-first reads for performance
  // - Background sync with Supabase
  // - Conflict resolution
  // - Offline operation queuing
}
```

Key hybrid repositories:
- `HybridFavoritesRepository` - Favorite movies
- `HybridWatchlistRepository` - Watch later movies
- `HybridWatchedRepository` - Watched movies
- `HybridCustomListsRepository` - User-created lists
- `HybridMovieRatingsRepository` - User ratings

### Synchronization System

Multi-layered sync architecture:

1. **ComprehensiveSyncService** - Orchestrates all entity synchronization
2. **Entity-Specific Sync Managers** - Handle individual data types (favorites, watchlist, etc.)
3. **RealtimeSyncManager** - Real-time WebSocket synchronization
4. **SyncCoordinator** - Manages sync triggers and scheduling
5. **ConflictResolver** - Handles data conflicts between devices

### Provider Architecture

State management follows this pattern:

```dart
// Direct providers for real-time data binding
final directFavoriteMoviesProvider = StateNotifierProvider<...>();

// Hybrid repository providers
final hybridFavoritesRepositoryProvider = Provider<HybridFavoritesRepository>();

// UI-specific providers
final nowPlayingMoviesProvider = StateNotifierProvider<MoviesNotifier, MoviesStateData>();
```

### Gamification System

Comprehensive gamification with:
- **Achievement System** - User accomplishments and badges
- **Challenge System** - Time-limited challenges
- **Level System** - User progression
- **Leaderboards** - Social competition

## Critical Development Notes

### Sync System Integration

When modifying user data (favorites, watchlist, ratings):

1. **Always use hybrid repositories** - Never bypass the sync system
2. **Operations are automatically queued** when offline
3. **Conflicts are resolved automatically** using last-write-wins with metadata
4. **Real-time updates** propagate immediately when online

### Provider Initialization

The app has complex provider dependency chains. Key initialization happens in `main.dart`:

```dart
// Critical: These providers must be watched to initialize real-time sync
ref.watch(directFavoriteMoviesProvider);
ref.watch(directWatchedMoviesProvider);
ref.watch(directWatchlistMoviesProvider);
```

### Error Reporting

Firebase Crashlytics integration with custom error reporting:

```dart
// Report errors with context
await ErrorReportingService.instance.reportError(
  error,
  stackTrace,
  reason: 'Operation context',
  fatal: false,
);
```

### Testing Architecture

Test structure:
- `test/` - Unit and widget tests
- `integration_test/` - End-to-end tests
- **Target coverage**: >80%
- **Focus areas**: Sync system, conflict resolution, offline functionality

### Platform Considerations

- **Web**: Uses `MaterialApp.router` (no PiP support)
- **Mobile**: Uses `PiPMaterialApp.router` for Picture-in-Picture
- **Cross-platform services** initialized via `CrossPlatformInitService`

### Code Generation

The app uses code generation for:
- **Hive TypeAdapters**: `@HiveType()` annotations on entities
- **JSON Serialization**: `@JsonSerializable()` for API models
- **Build runner required** after modifying annotated classes

### Supabase Integration

Real-time subscriptions pattern:
```dart
// Subscribe to real-time changes
final subscription = supabase
  .from('favorite_movies')
  .stream(primaryKey: ['id'])
  .eq('user_id', userId)
  .listen((data) {
    // Handle real-time updates
  });
```

### Performance Considerations

- **Image caching** via `HybridImageService`
- **Adaptive cache configuration** based on device capabilities
- **Lazy provider initialization** - providers load only when needed
- **Incremental sync** - only sync changes, not full datasets

### AdMob Integration

- **Mobile only** - Web version disabled
- **Frequency controlled** - Prevents ad spam
- **Context-aware placement** - Integrated into movie grids and lists

### Environment Configuration

Required `.env` file:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_key
```

## Common Debugging

- **Sync issues**: Check `LoggerFactory` output for sync events
- **Provider errors**: Ensure proper initialization order in `main.dart`
- **Offline data**: Verify hybrid repositories are being used
- **Real-time updates**: Confirm WebSocket connection in network logs

## Key Files to Understand

- `lib/main.dart` - App initialization and provider setup
- `lib/infrastructure/services/comprehensive_sync_service.dart` - Sync orchestration
- `lib/core/sync/` - Core synchronization logic
- `lib/infrastructure/repositories/hybrid_*_repository.dart` - Offline-first data access
- `lib/presentation/providers/storage/direct_*_provider.dart` - Real-time UI providers