# 🔧 Technical Issues - Pending Fixes

## Database Issues

### Custom Lists Not Saving

**Severity**: CRITICAL
**Component**: `user_list_items` table

```sql
-- Verify this table exists and has proper permissions
CREATE TABLE IF NOT EXISTS user_list_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id UUID REFERENCES user_lists(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL,
    movie_title VARCHAR(255),
    movie_poster_path TEXT,
    movie_backdrop_path TEXT,
    position INTEGER DEFAULT 0,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_list_items ENABLE ROW LEVEL SECURITY;

-- Create policy for users to manage their items
CREATE POLICY "Users can manage their list items" ON user_list_items
    FOR ALL USING (
        list_id IN (
            SELECT id FROM user_lists WHERE user_id = auth.uid()
        )
    );

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE user_list_items;
```

### Real-Time Sync Not Working

**Severity**: CRITICAL
**Component**: Supabase Realtime

```dart
// Check subscription setup in:
// lib/presentation/providers/storage/direct_custom_lists_provider.dart

// Should be:
final channel = supabase
    .channel('custom_lists_changes')
    .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_list_items',
        callback: (payload) {
          // Handle changes
        })
    .subscribe();
```

## API Issues

### Movie Genres Showing IDs

**File**: `lib/infrastructure/mappers/movie_mapper.dart`

```dart
// Add this mapping
static const Map<int, String> GENRE_MAP = {
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
```

### Streaming Platforms 404 Errors

**Issue**: Hardcoded/outdated provider URLs
**Solution**: Integrate with JustWatch API or TMDB watch providers

```dart
// New service needed
class WatchProvidersService {
  Future<List<WatchProvider>> getProviders(
    int movieId,
    String countryCode
  ) async {
    // Use TMDB endpoint:
    // /movie/{movie_id}/watch/providers

    final response = await http.get(
      '/3/movie/$movieId/watch/providers?api_key=$apiKey'
    );

    // Parse by country
    final countryData = response['results'][countryCode];
    return parseProviders(countryData);
  }
}
```

### Missing Movie Technical Details

**Fields needed**:

- Runtime
- Original language
- Production companies
- Budget/Revenue
- Credits (Director, Cast)

```dart
// Enhance movie model
class MovieDetails extends Movie {
  final int? runtime; // in minutes
  final String? originalLanguage;
  final List<ProductionCompany>? productionCompanies;
  final int? budget;
  final int? revenue;
  final String? status;
  final String? tagline;
  final List<CastMember>? cast;
  final List<CrewMember>? crew;
}
```

## State Management Issues

### Lists Not Updating in UI

**Provider**: `DirectCustomListsProvider`
**Issue**: State not emitting after changes

```dart
// Ensure state updates trigger UI rebuild
Future<void> addMovieToList(String listId, int movieId) async {
  // ... add logic

  // Must update state to trigger rebuild
  state = state.copyWith(
    listItems: {...state.listItems, listId: updatedItems}
  );
}
```

## Platform-Specific Issues

### Permissions Not Configured

See [Permissions Configuration](../04-PERMISSIONS-CONFIGURATION.md)

### Windows Build Issues

- Check Visual Studio installation
- Verify C++ build tools

### macOS Entitlements

- Network access denied
- Sandbox restrictions

## Performance Issues

### Large Lists Lag

**Problem**: UI freezes with 500+ items
**Solution**: Implement pagination and virtual scrolling

```dart
// Use ListView.builder with itemExtent
ListView.builder(
  itemExtent: 120.0, // Fixed height improves performance
  itemCount: items.length,
  itemBuilder: (context, index) => MovieCard(items[index]),
)
```

---

**Last Updated**: January 2025
**Priority**: Fix in order listed
