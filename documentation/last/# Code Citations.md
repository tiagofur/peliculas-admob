# Code Citations and Attributions

## Project License

This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.

## Third-Party Code Attributions

### Flutter Framework & Packages

All Flutter packages used in this project are licensed under their respective licenses as specified in `pubspec.yaml`. Key dependencies include:

- **Flutter SDK** - BSD-3-Clause License
- **Riverpod** - MIT License
- **Supabase Flutter** - MIT License
- **Google Mobile Ads** - Google Play Services License

### Code References and Inspirations

#### Android Permissions Configuration

Some permission configurations were referenced from standard Android development patterns:

- Standard INTERNET and NETWORK_STATE permissions
- Camera and external storage permissions following Android guidelines

#### Genre Mapping

Movie genre ID to name mapping follows TMDB standard genre definitions:

- Genre IDs and names are standardized by The Movie Database API
- Implementation follows common patterns found in movie applications

#### macOS Entitlements

App sandbox and network client configurations follow Apple's developer guidelines:

- Standard app sandbox entitlements
- Network client access permissions
- File system access permissions as per Apple recommendations

## Data Sources

### Movie Data

- **The Movie Database (TMDB)** - Movie metadata, images, and genre information
- **Trakt.tv** - User tracking and social features (planned integration)

### Images and Assets

- Movie posters and backdrops provided by TMDB API
- App icons and UI assets created specifically for this project

## Attribution Requirements

When using or referencing this codebase:

1. Maintain this attribution file
2. Include proper license headers in derivative works
3. Credit TMDB for movie data usage
4. Follow individual package license requirements

## External Libraries and Dependencies

### State Management

- **flutter_riverpod** - MIT License - State management solution
- **hooks_riverpod** - MIT License - React hooks-style state management

### Backend Integration

- **supabase_flutter** - MIT License - Supabase client for Flutter
- **supabase** - MIT License - Core Supabase functionality

### UI/UX Components

- **go_router** - BSD-3-Clause - Declarative routing
- **flutter_native_splash** - MIT License - Native splash screen
- **google_mobile_ads** - Google Play Services - Advertisement integration

### Data Storage

- **hive** - Apache 2.0 - NoSQL database for Flutter
- **isar** - Apache 2.0 - High-performance database
- **shared_preferences** - BSD-3-Clause - Key-value storage

### Networking & APIs

- **http** - BSD-3-Clause - HTTP client
- **dio** - MIT License - HTTP client with interceptors
- **connectivity_plus** - BSD-3-Clause - Network connectivity

### Utilities

- **intl** - BSD-3-Clause - Internationalization
- **image_picker** - Apache 2.0 - Image selection
- **share_plus** - BSD-3-Clause - Sharing functionality

---

**Note**: This file provides proper attribution for all third-party code and libraries used in the project. All external dependencies are used under their respective open-source licenses.
