# Project Overview

This is a Flutter application for exploring and managing movies. It uses Supabase for the backend, and features offline synchronization and gamification. The app is built with a Clean Architecture and Domain-Driven Design, and has a high level of code quality.

## Main Technologies

*   **Frontend:** Flutter with Riverpod for state management
*   **Backend:** Supabase (PostgreSQL + Auth + Storage) + Firebase (auxiliary services)
*   **Local Storage:** Hive (fast cache) + Isar (complex queries)
*   **External APIs:** TMDB (movie data), YouTube (trailers)

# Building and Running

To build and run the project, you will need to have the Flutter SDK installed. You will also need to create a `.env` file in the root of the project with the following content:

```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_key
```

Once you have created the `.env` file, you can run the following commands to build and run the project:

```
flutter pub get
flutter run
```

# Development Conventions

The project has a strict set of development conventions, which are enforced by the CI pipeline. These conventions include:

*   **Code formatting:** All code must be formatted with `dart format`.
*   **Static analysis:** The code must not have any warnings or errors from the analyzer.
*   **Testing:** All tests must pass, and the code coverage must be at least 80%.
*   **Build:** The project must build successfully for web and Android.

Before committing any code, you should run the following commands to make sure that your code meets the project's quality standards:

```
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
```