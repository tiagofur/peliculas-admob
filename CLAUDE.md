# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter 3.0+ application for browsing and managing movies with comprehensive offline-first architecture, real-time synchronization, and gamification features. The app follows Clean Architecture with Domain-Driven Design patterns and supports cross-platform deployment (Android, iOS, Web, Linux, macOS, Windows).

## Essential Commands

### Development Setup
```bash
# Initial setup (required before any development)
flutter pub get
flutter doctor

# Code generation (run after model changes)
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Quality Assurance (Critical - run before every commit)
```bash
# Format code (required)
dart format .

# Static analysis (zero warnings/errors allowed)
flutter analyze --fatal-infos --fatal-warnings

# Run tests (required)
flutter test

# Run with coverage
flutter test --coverage
```

### Build Commands (Long timeouts required - 15+ minutes)
```bash
# Web build (production)
flutter build web --release

# Android APK
flutter build apk --release

# Android Bundle
flutter build appbundle --release
```

### Testing Commands
```bash
# Unit tests (65+ tests)
flutter test

# Integration tests (8+ tests) 
flutter test integration_test/

# Golden tests (UI regression)
flutter test test/golden_tests/ --update-goldens
flutter test test/golden_tests/
```

## Architecture Overview

### Core Architecture Pattern
- **Clean Architecture** with **Domain-Driven Design**
- **Offline-first** with **hybrid repositories**
- **Real-time synchronization** with conflict resolution
- **Repository pattern** with local/remote data sources

### Key Architectural Layers
```
lib/
├── domain/           # Business logic, entities, repository interfaces
│   ├── entities/     # Core business models (Movie, User, etc.)
│   └── repositories/ # Abstract repository interfaces
├── infrastructure/   # External integrations and concrete implementations
│   ├── datasources/  # Data source implementations (Supabase, Hive, etc.)
│   └── repositories/ # Hybrid repository implementations
├── presentation/     # UI layer with state management
│   ├── providers/    # Riverpod state providers
│   └── views/        # UI screens and widgets
├── core/             # Cross-cutting concerns
│   ├── sync/         # Synchronization and conflict resolution
│   ├── gamification/ # Achievement and challenge systems
│   └── services/     # Application services
└── config/           # App configuration and themes
```

### State Management with Riverpod
- **Primary**: Riverpod for state management
- **Providers**: Located in `lib/presentation/providers/`
- **Pattern**: StateNotifier with typed state classes

### Data Storage Strategy
- **Local Storage**: 
  - Hive (fast cache for simple data)
  - Isar (complex queries and relationships)
- **Remote Storage**: Supabase (PostgreSQL + real-time)
- **Hybrid Repositories**: Combine local and remote with conflict resolution

### Key Architectural Components

#### Hybrid Repository Pattern
Located in `lib/infrastructure/repositories/`, implements offline-first pattern:
- `HybridWatchlistRepository` - Watchlist management with sync
- `HybridFavoritesRepository` - Favorites with conflict resolution
- `BaseHybridRepository` - Common sync functionality

#### Sync System
Located in `lib/core/sync/`:
- Real-time bidirectional synchronization
- Conflict detection and resolution
- Offline operation queuing
- Multi-device consistency

#### Gamification System
Located in `lib/core/gamification/`:
- Achievement tracking
- Challenge system
- Progress notifications
- Leaderboards

## Critical Dependencies

### Core Framework
- `flutter_riverpod: ^2.6.1` - State management
- `supabase_flutter: ^2.9.1` - Backend and real-time sync
- `go_router: ^16.1.0` - Navigation and routing

### Local Storage
- `hive: ^2.2.3` + `hive_flutter: ^1.1.0` - Fast local cache
- `isar: ^3.1.0+1` - Complex queries and relationships
- `shared_preferences: ^2.2.2` - Simple key-value storage

### Code Generation
- `build_runner: ^2.4.13` - Code generation orchestrator
- `hive_generator: ^2.0.1` - Hive adapters
- `isar_generator: ^3.1.0+1` - Isar collections
- `json_serializable: ^6.7.1` - JSON serialization

### External Integrations
- `firebase_core: ^4.1.0` + `firebase_crashlytics: ^5.0.1` - Error reporting
- `google_mobile_ads: ^6.0.0` - Monetization
- `dio: ^5.7.0` - HTTP client for movie data

## Development Workflow

### Code Generation Requirements
Always run after changing entities or models:
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Testing Requirements
- **Coverage Target**: >80% for new code
- **Test Types**: Unit tests, integration tests, golden tests
- **Critical Test Files**:
  - `test/sync_integration_test.dart` - Sync functionality
  - `test/offline_functionality_test.dart` - Offline capabilities
  - `test/repository_integration_test.dart` - Repository pattern

### Quality Gates (CI/CD enforced)
1. **Format**: `dart format --set-exit-if-changed .`
2. **Analysis**: `flutter analyze --fatal-infos --fatal-warnings`
3. **Tests**: All unit and integration tests must pass
4. **Build**: Web and Android builds must succeed

## Key Architectural Patterns

### Entity Pattern
- Entities in `lib/domain/entities/` use Hive annotations
- Generated files (*.g.dart) are auto-created by build_runner
- Example: `Movie` entity with comprehensive fields and methods

### Provider Pattern (Riverpod)
- State providers in `lib/presentation/providers/`
- StateNotifier pattern for complex state
- Example: `MoviesNotifier` with pagination and error handling

### Hybrid Repository Pattern
- Local-first with remote synchronization
- Conflict resolution strategies
- Example: `HybridWatchlistRepository` with real-time sync

### Sync Operation Pattern
- Queue-based operation management
- Retry logic with exponential backoff
- Conflict detection and resolution

## Environment Configuration

### Required Files
- `.env` - Environment variables (pre-configured with API keys)
- Analysis configured in `analysis_options.yaml`

### Platform Support
- **Mobile**: Android (SDK 21+), iOS (12.0+)
- **Web**: Progressive Web App with offline support
- **Desktop**: Windows, macOS, Linux

## Error Handling and Logging

### Error Reporting
- Firebase Crashlytics for production error tracking
- Comprehensive logging with `LoggerFactory`
- Custom exceptions in `lib/core/exceptions/`

### Logging Pattern
```dart
// Use throughout codebase
LoggerFactory.info('✅ Operation completed');
LoggerFactory.error('❌ Operation failed: $error');
```

## Performance Considerations

### Build Performance
- Web builds: 3-8 minutes
- Android builds: 5-10 minutes
- **Never cancel builds** - they require full completion

### Image Caching
- Hybrid image service with adaptive caching
- Network-aware strategies
- Preloading service for performance

### Database Performance
- Hive for fast simple queries
- Isar for complex relational queries
- Offline-first pattern minimizes network dependency

## Important Notes

### Code Style Enforcement
- Single quotes preferred (`prefer_single_quotes: true`)
- Const constructors required (`prefer_const_constructors: true`)
- Return types must be declared (`always_declare_return_types: true`)

### Sync System Critical
- Real-time listeners must be initialized in `main.dart`
- Sync providers must be watched in `MainApp` widget
- Conflict resolution is automatic but logged extensively

### Testing Critical Paths
- Authentication flow
- Movie browsing and search
- Watchlist operations
- Offline/online transitions
- Cross-device synchronization

## Troubleshooting

### Common Issues
- **Build failures**: Run `flutter clean && flutter pub get`
- **Sync issues**: Check Supabase connection and user authentication
- **Code generation**: Run build_runner after entity changes
- **Golden test failures**: Update goldens first, then validate

### Debug Commands
```bash
# Check Flutter installation
flutter doctor -v

# Clear caches
flutter clean

# Reset dependencies
rm -rf .dart_tool && flutter pub get
```