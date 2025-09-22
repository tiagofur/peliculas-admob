# 🚨 Critical Fixes Required

## P0 - Beta Blockers

### 1. Custom Lists System ❌

**Status**: BROKEN
**Impact**: Core functionality unusable

#### Current Issues:

- Movies not saving to local storage (Hive/SharedPreferences)
- Supabase sync not working (`user_list_items` table)
- Real-time subscriptions not triggering
- State management issues in `DirectCustomListsProvider`

#### Root Causes:

```dart
// File: lib/presentation/providers/storage/direct_custom_lists_provider.dart
// Line 357-380: addMovieToList has authentication checks but sync fails
```

#### Required Fixes:

1. **Local Storage**:

   - Fix Hive box initialization for list items
   - Ensure proper serialization of `ListItem` objects
   - Add offline queue for pending operations

2. **Supabase Integration**:

   ```sql
   -- Verify table structure
   CREATE TABLE IF NOT EXISTS user_list_items (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     list_id UUID REFERENCES user_lists(id) ON DELETE CASCADE,
     movie_id INTEGER NOT NULL,
     movie_title VARCHAR(255),
     movie_poster_path TEXT,
     position INTEGER DEFAULT 0,
     added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
     updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );

   -- Add missing indexes
   CREATE INDEX IF NOT EXISTS idx_list_items_sync
   ON user_list_items(list_id, updated_at DESC);
   ```

3. **Real-Time Sync**:
   - Enable real-time on Supabase tables
   - Fix subscription channels in provider
   - Add conflict resolution logic

#### Testing Checklist:

- [ ] Add movie to custom list - saves locally
- [ ] Add movie to custom list - syncs to Supabase
- [ ] Remove movie from list - updates both stores
- [ ] Multi-device sync works in real-time
- [ ] Offline changes sync when online

---

### 2. System Permissions Configuration ❌

**Status**: NOT CONFIGURED
**Impact**: Features may crash on real devices

#### Android Permissions

```xml
<!-- File: android/app/src/main/AndroidManifest.xml -->
<!-- Add these permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
                 android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<!-- For image picker -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- For notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.VIBRATE" />
```

#### iOS Permissions

```xml
<!-- File: ios/Runner/Info.plist -->
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photo library for profile pictures</string>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for profile pictures</string>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

#### macOS Permissions

```xml
<!-- File: macos/Runner/Info.plist -->
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photo library for profile pictures</string>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

---

### 3. Movie Details Data Issues ❌

**Status**: PARTIALLY BROKEN
**Impact**: Poor user experience

#### Current Problems:

1. **Genre IDs instead of names**

   - Showing: "28, 12, 878"
   - Should show: "Action, Adventure, Sci-Fi"

2. **Missing technical details**:

   - Runtime
   - Original language
   - Production companies
   - Budget/Revenue

3. **Streaming platforms broken**:
   - Hardcoded providers
   - No region detection
   - Broken affiliate links

#### Required Fixes:

```dart
// File: lib/infrastructure/mappers/movie_mapper.dart
// Add genre mapping
class MovieMapper {
  static final Map<int, String> genreMap = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Science Fiction',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western'
  };

  static String getGenreNames(List<int> genreIds) {
    return genreIds
        .map((id) => genreMap[id] ?? 'Unknown')
        .join(', ');
  }
}
```

---

## P1 - High Priority

### 4. TMDB → Trakt Migration 🟠

**Status**: PLANNED
**Impact**: API dependency change

#### Migration Strategy:

1. **Phase 1**: Add Trakt service alongside TMDB
2. **Phase 2**: Route new requests through Trakt
3. **Phase 3**: Migrate existing data
4. **Phase 4**: Remove TMDB dependency

#### Implementation Files:

```dart
// New service needed
// File: lib/infrastructure/services/trakt_service.dart
class TraktService {
  static const String clientId = 'YOUR_TRAKT_CLIENT_ID';
  static const String apiUrl = 'https://api.trakt.tv';

  // Implement API methods
}
```

---

### 5. Streaming Platforms Fix 🟠

**Status**: BROKEN LINKS
**Impact**: Revenue loss from affiliates

#### Current Implementation Issues:

- Hardcoded provider list
- No JustWatch API integration
- Missing region detection
- Broken deeplinks

#### Solution:

```dart
// File: lib/infrastructure/services/streaming_service.dart
class StreamingService {
  // Integrate JustWatch API for real availability
  Future<List<StreamingProvider>> getAvailability(
    int movieId,
    String countryCode
  ) async {
    // Implementation needed
  }
}
```

---

## Testing Requirements

### Manual Testing Checklist:

- [ ] Lists: Add/remove movies works offline and syncs
- [ ] Permissions: App doesn't crash on real devices
- [ ] Movie Details: Shows proper genre names and info
- [ ] Streaming: Links open correct apps/websites
- [ ] Sync: Changes reflect across devices in <5 seconds

### Automated Testing:

```bash
# Run these tests after fixes
flutter test test/lists/custom_lists_test.dart
flutter test test/sync/realtime_sync_test.dart
flutter test test/movies/movie_details_test.dart
flutter test integration_test/lists_flow_test.dart
```

---

## Deployment Checklist

Before releasing beta version:

1. [ ] All P0 issues fixed and tested
2. [ ] Permissions configured for all platforms
3. [ ] Real-time sync verified on 2+ devices
4. [ ] Movie details show complete information
5. [ ] At least 50% of P1 issues resolved

**Target Date**: End of January 2025
**Version**: 0.9.0-beta.1
