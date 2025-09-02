# Copilot Instructions for peliculas-admob

**ALWAYS** follow these instructions first and only fallback to additional search and context gathering if the information here is incomplete or found to be in error.

## Project Overview

This is a Flutter application for browsing and managing movies with Supabase backend integration, gamification features, and offline capabilities. The project follows domain-driven design patterns and supports cross-platform deployment (Android, iOS, Web, Linux, macOS, Windows).

## Critical Setup Requirements

### Prerequisites Installation

**NEVER** attempt to build without proper Flutter SDK installation. Install Flutter SDK 3.0+ before any development work:

```bash
# Install Flutter SDK (Ubuntu/Linux)
sudo apt-get update -y
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa
git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
export PATH="/opt/flutter/bin:$PATH"
echo 'export PATH="/opt/flutter/bin:$PATH"' >> ~/.bashrc

# Verify installation
flutter doctor
```

### Environment Setup

**ALWAYS** run the setup script first:

```bash
# Clone and setup (first time)
git clone https://github.com/tiagofur/peliculas-admob.git
cd peliculas-admob

# Configure development environment
./scripts/setup_dev.sh
```

**Environment file**: The `.env` file is already configured with API keys. For Supabase integration, add your credentials:
```env
# Add to existing .env file if needed
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_key
```

**Note**: Movie API keys are pre-configured. Do NOT modify existing THE_MOVIEDB_KEY or TRAKT_* keys unless required.

## Build and Development Workflows

### Initial Project Setup (First time - 5-10 minutes)

**NEVER CANCEL**: These commands take time but must complete:

```bash
# Get dependencies - takes 2-5 minutes. Set timeout to 10+ minutes.
flutter pub get

# Verify installation - takes 1-2 minutes
flutter doctor

# Run initial validation - takes 3-5 minutes. Set timeout to 10+ minutes.
./scripts/quality_check.sh
```

### Development Validation (Before every commit - 5-8 minutes)

**CRITICAL**: **NEVER CANCEL** build operations. Set timeouts to 15+ minutes minimum:

```bash
# Complete quality validation - takes 5-8 minutes. NEVER CANCEL.
./scripts/quality_check.sh

# With build validation - takes 8-12 minutes. NEVER CANCEL.
./scripts/quality_check.sh --build
```

### Build Commands

**TIMEOUT REQUIREMENTS**: All builds require long timeouts:

```bash
# Web build - takes 3-8 minutes. Set timeout to 15+ minutes. NEVER CANCEL.
flutter build web --release

# Android APK - takes 5-10 minutes. Set timeout to 20+ minutes. NEVER CANCEL.
flutter build apk --release

# Android Bundle - takes 5-10 minutes. Set timeout to 20+ minutes. NEVER CANCEL.
flutter build appbundle --release
```

### Testing Commands

**NEVER CANCEL**: Tests must run to completion. With 65+ unit tests and 8+ integration tests:

```bash
# Unit tests (65+ tests) - takes 3-8 minutes. Set timeout to 15+ minutes.
flutter test

# Integration tests (8+ tests) - takes 8-15 minutes. Set timeout to 25+ minutes.
flutter test integration_test/

# Comprehensive tests with coverage - takes 15-25 minutes. Set timeout to 35+ minutes.
./scripts/run_comprehensive_tests.sh

# Golden tests - takes 2-3 minutes. Set timeout to 8+ minutes.
flutter test test/golden_tests/ --update-goldens || flutter test test/golden_tests/
```

## Critical Test Coverage and Files

### Test Organization (65+ test files)

**Key Test Categories**:
- **Error Handling**: `test/error_handling_test.dart`, `test/error_reporting_test.dart`
- **Offline Functionality**: `test/offline_functionality_test.dart`, `test/offline_cache_test.dart`
- **Sync Integration**: `test/sync_integration_test.dart`, `test/realtime_sync_complex_test.dart`
- **Authentication**: `test/persistent_auth_basic_test.dart`, `test/user_authentication_flow_test.dart`
- **Repository Pattern**: `test/repository_integration_test.dart`, `test/repository_pattern_test.dart`
- **UI Testing**: `test/accessibility_widgets_test.dart`, `test/theme_system_test.dart`
- **Performance**: `test/realtime_latency_performance_test.dart`

**Integration Tests (8 files)**:
- `integration_test/movie_browsing_flow_test.dart`
- `integration_test/user_authentication_flow_test.dart`
- `integration_test/watchlist_flow_test.dart`
- `integration_test/sharing_functionality_flow_test.dart`

**Golden Tests**: Located in `test/golden_tests/` for UI regression testing.

### Pre-commit Requirements

**ALWAYS** run these before committing:

```bash
# Format code (fast, 10-30 seconds)
dart format .

# Static analysis - takes 30-60 seconds
flutter analyze --fatal-infos --fatal-warnings

# Quick test run - takes 2-5 minutes. Set timeout to 10+ minutes.
flutter test
```

### Quality Standards

- **Format**: Code MUST pass `dart format --set-exit-if-changed .`
- **Analysis**: Zero warnings/errors allowed (`flutter analyze --fatal-infos --fatal-warnings`)
- **Tests**: All tests must pass
- **Build**: Web and Android builds must succeed

### Lint and Security

```bash
# Security audit
dart pub audit

# Dependency check
flutter pub outdated

# Extended quality checks (in CI)
grep -r "TODO\|FIXME\|HACK" lib/ || echo "No issues found"
```

## Validation Scenarios

**ALWAYS** manually validate changes with real user scenarios:

### Critical User Flows to Test

After ANY changes, validate these scenarios (based on integration test coverage):

1. **App Launch Flow** (`movie_browsing_flow_test.dart`):
   - App opens without crashes
   - Splash screen displays correctly
   - Main navigation loads with content

2. **Movie Browsing Flow** (`movie_browsing_flow_test.dart`):
   - Navigate to movie list
   - Search for movies
   - Open movie details
   - Return to list

3. **User Authentication Flow** (`user_authentication_flow_test.dart`):
   - Login/logout functionality
   - Session persistence
   - Authentication error handling

4. **Watchlist Flow** (`watchlist_flow_test.dart`):
   - Add movies to watchlist
   - Remove from watchlist
   - Sync across devices
   - Offline capabilities

5. **Sharing Functionality** (`sharing_functionality_flow_test.dart`):
   - Share movie information
   - Deep linking
   - Social media integration

6. **Navigation Flow**:
   - Test all bottom navigation tabs
   - Test drawer navigation
   - Test back button functionality

### Performance Validation

Verify performance after changes:
- App startup: < 3 seconds
- Navigation transitions: < 500ms  
- Movie list loading: < 2 seconds
- Search results: < 1 second

## Architecture and Navigation

### Project Structure

```
lib/
├── main.dart              # App entry point
├── config/                # App configuration and theme
├── core/                  # Core services and utilities
├── domain/                # Business logic and interfaces
├── infrastructure/        # External integrations (Supabase, etc.)
├── models/                # Data models
├── presentation/          # UI components and providers
└── services/              # Application services
```

### Key Components

- **Domain Layer**: Pure business logic (`lib/domain/`)
- **Infrastructure Layer**: External services (`lib/infrastructure/`)
- **Presentation Layer**: UI and state management (`lib/presentation/`)
- **Services Layer**: Application services (`lib/services/`)

### State Management

- **Riverpod**: Primary state management
- **Providers**: Located in `lib/presentation/providers/`
- **Repository Pattern**: Hybrid local/remote data access

## Common Issues and Troubleshooting

### Build Issues

**Problem**: Dart SDK download fails
**Solution**: Delete `/tmp/flutter` and reinstall Flutter properly using direct download method

**Problem**: "package not found" errors  
**Solution**: Run `flutter clean && flutter pub get`

**Problem**: Build hangs
**Solution**: **NEVER CANCEL** - builds can take 15+ minutes. Wait for completion.

**Problem**: Flutter not found after installation
**Solution**: Ensure PATH is updated: `export PATH="/opt/flutter/bin:$PATH"`

**Problem**: Web build fails with "target not found"
**Solution**: Ensure web support is enabled: `flutter config --enable-web`

### Test Issues

**Problem**: Golden test failures
**Solution**: Run `flutter test test/golden_tests/ --update-goldens` first

**Problem**: Integration test timeouts
**Solution**: Increase timeout values, tests can take 10+ minutes

### Development Workflow Issues

**Problem**: Pre-commit hook blocking commits
**Solution**: Fix issues shown by `./scripts/quality_check.sh`, don't bypass

**Problem**: CI failure
**Solution**: Reproduce locally with same commands in `.github/workflows/ci.yml`

## File Locations and Important Paths

### Critical Files
- `pubspec.yaml` - Dependencies and configuration
- `analysis_options.yaml` - Lint rules and analysis settings
- `.env` - Environment variables (create manually)
- `lib/main.dart` - Application entry point

### Development Scripts
- `scripts/setup_dev.sh` - Development environment setup
- `scripts/quality_check.sh` - Code quality validation  
- `scripts/run_comprehensive_tests.sh` - Full test suite

### Documentation
- `README.md` - Project overview and quick start
- `docs/CI_CD_PIPELINE.md` - Detailed CI/CD documentation
- `docs/QUICK_TESTING_CHECKLIST.md` - Manual testing guide
- `docs/MANUAL_TESTING_EXECUTION_TEMPLATE.md` - Step-by-step testing template
- `docs/TESTING_DOCUMENTATION_INDEX.md` - Complete testing documentation index
- `.github/pull_request_template.md` - PR template

### Configuration Files
- `.github/workflows/` - CI/CD pipeline definitions
- `android/` - Android-specific configuration
- `ios/` - iOS-specific configuration  
- `web/` - Web-specific configuration

## Platform-Specific Notes

### Android Development
- Minimum SDK: Check `android/app/build.gradle`
- Build outputs: `build/app/outputs/`
- Google Mobile Ads integration configured

### Web Development  
- Build output: `build/web/`
- SKIA rendering supported
- Progressive Web App configured

### Desktop Support
- Linux, macOS, Windows supported
- Platform-specific code in respective directories

## Environment and Dependencies

### Flutter Version
- Required: SDK >= 3.0.0 < 4.0.0
- Dart SDK included with Flutter
- Check with: `flutter --version`

### Key Dependencies
- `flutter_riverpod` - State management
- `supabase_flutter` - Backend integration  
- `google_mobile_ads` - Monetization
- `go_router` - Navigation
- `hive` & `isar` - Local storage

### Development Dependencies
- `flutter_test` - Testing framework
- `mockito` - Mocking for tests
- `integration_test` - E2E testing
- `build_runner` - Code generation

**ALWAYS** check `pubspec.yaml` for current dependency versions before making changes.
