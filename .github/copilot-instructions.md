# Copilot Instructions for peliculas-admob

## Project Overview
This is a Flutter application for browsing and managing movies. The codebase is organized for cross-platform support (Android, iOS, Linux, macOS, Windows, Web).

## Architecture & Key Components
- **lib/**: Main source code. Subfolders:
  - `main.dart`: App entry point, sets up navigation and global providers.
  - `config/`, `core/`, `domain/`, `infrastructure/`, `models/`, `presentation/`, `services/`: Follow domain-driven design. Business logic is separated from UI and infrastructure.
- **assets/**: Images, loaders, and other static resources.
- **test/**: Integration and widget tests. Use Flutter's test framework.
- **android/**, **ios/**, **linux/**, **macos/**, **windows/**, **web/**: Platform-specific code and build configs.
- **supabase/**: Database migrations and backend integration.

## Developer Workflows
- **Build**: Use `flutter build <platform>` (e.g., `flutter build apk`, `flutter build web`).
- **Run**: Use `flutter run` for local development.
- **Test**: Run `flutter test` for all tests in `test/`. Tests cover error handling, offline functionality, sync, and widgets.
- **Assets**: Add images to `assets/images/` and reference in `pubspec.yaml`.
- **Supabase**: Database migrations in `supabase/migrations/`.

## Patterns & Conventions
- **Domain-driven design**: Business logic in `domain/`, infrastructure in `infrastructure/`, UI in `presentation/`.
- **Service Layer**: Shared logic in `services/`.
- **Config**: App-wide settings in `config/`.
- **Error Handling**: See `test/error_handling_test.dart` for patterns.
- **Offline & Sync**: See `test/offline_functionality_test.dart` and `test/sync_integration_test.dart`.
- **Widget Testing**: See `test/widget_test.dart`.
- **Platform Assets**: Customize launch screens in platform-specific asset folders (see `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`).

## External Dependencies
- **Supabase**: Backend integration.
- **Google Mobile Ads**: Ad integration (see `android/` and related configs).
- **Flutter Plugins**: Various plugins for connectivity, notifications, image handling, etc.

## Example: Adding a New Feature
1. Define models in `lib/models/`.
2. Add business logic in `lib/domain/` and/or `lib/services/`.
3. Update UI in `lib/presentation/`.
4. Add tests in `test/`.
5. Register assets in `pubspec.yaml` if needed.

## References
- Main entry: `lib/main.dart`
- Tests: `test/`
- Assets: `assets/`
- Platform configs: `android/`, `ios/`, etc.
- Supabase: `supabase/`

---

If any section is unclear or missing, please provide feedback to improve these instructions.
