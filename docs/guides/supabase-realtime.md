# Supabase Realtime Setup

> Real-time synchronization system with offline support and conflict resolution.

**Status**: ✅ Production Ready  
**Last Updated**: October 23, 2025

---

## Overview

The app uses Supabase for real-time data synchronization with:

- ✅ Optimistic updates for instant UI feedback
- ✅ Conflict resolution (server-wins strategy)
- ✅ Offline support with local caching
- ✅ Automatic retry with exponential backoff
- ✅ Network resilience

---

## Quick Start

### 1. Supabase Project Setup

1. Create project at [Supabase Dashboard](https://app.supabase.com/)
2. Get your project credentials:
   - **URL**: `https://your-project.supabase.co`
   - **Anon Key**: Public API key

### 2. Configure Environment Variables

**File**: `.env`

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

### 3. Initialize in App

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

await Supabase.initialize(
  url: Environment.supabaseUrl,
  anonKey: Environment.supabaseAnonKey,
  authOptions: FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
  ),
);
```

---

## Database Schema

### Essential Tables

#### 1. User Profiles

```sql
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  username TEXT UNIQUE,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 2. User Lists (Watchlists, Favorites)

```sql
CREATE TABLE user_lists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES user_profiles(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL, -- 'watchlist', 'favorites', 'custom'
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 3. List Items

```sql
CREATE TABLE list_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  list_id UUID REFERENCES user_lists(id) ON DELETE CASCADE,
  movie_id INTEGER NOT NULL,
  added_at TIMESTAMPTZ DEFAULT NOW(),
  position INTEGER,
  UNIQUE(list_id, movie_id)
);
```

#### 4. Movie Ratings

```sql
CREATE TABLE movie_ratings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES user_profiles(id),
  movie_id INTEGER NOT NULL,
  rating NUMERIC(3,1) CHECK (rating >= 0 AND rating <= 10),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, movie_id)
);
```

---

## Realtime Subscriptions

### Enable Realtime on Tables

In Supabase Dashboard:

1. Go to **Database** → **Replication**
2. Enable realtime for tables:
   - `user_lists`
   - `list_items`
   - `movie_ratings`

### Subscribe to Changes

```dart
final subscription = supabase
  .from('list_items')
  .stream(primaryKey: ['id'])
  .eq('list_id', listId)
  .listen((List<Map<String, dynamic>> data) {
    // Handle real-time updates
    setState(() {
      items = data.map((e) => ListItem.fromJson(e)).toList();
    });
  });

// Don't forget to cancel
@override
void dispose() {
  subscription.cancel();
  super.dispose();
}
```

---

## Sync Architecture

### Components

1. **SyncService** (`lib/services/sync_service.dart`)

   - Orchestrates all sync operations
   - Handles connectivity changes
   - Manages sync queue

2. **OptimisticUpdateService** (`lib/services/optimistic_update_service.dart`)

   - Immediate UI updates
   - Rollback on failure
   - Conflict detection

3. **ConflictResolver** (`lib/services/conflict_resolver.dart`)

   - Server-wins strategy by default
   - Timestamp-based resolution
   - Custom resolution rules

4. **RetryStrategy**
   - Exponential backoff
   - Max retry attempts: 3
   - Delays: 1s, 2s, 4s

### Flow Diagram

```
User Action
    ↓
Optimistic Update (UI immediately reflects change)
    ↓
Queue Sync Operation
    ↓
Check Connectivity
    ↓
[Online] → Send to Supabase → Success ✓
    ↓
[Offline] → Store locally → Retry when online
    ↓
[Conflict] → Resolve (server-wins) → Update UI
    ↓
[Error] → Rollback optimistic update → Show error
```

---

## Offline Support

### Local Storage Strategy

1. **Hive** for structured data caching
2. **Isar** for movie database (optional)
3. **Memory cache** for frequently accessed data

### Sync on Reconnection

```dart
// Automatic sync when network returns
Connectivity().onConnectivityChanged.listen((result) {
  if (result != ConnectivityResult.none) {
    syncService.syncPendingChanges();
  }
});
```

### Pending Operations Queue

```dart
class PendingOperation {
  final String id;
  final String type; // 'add', 'remove', 'update'
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;
}
```

---

## Conflict Resolution

### Strategy: Server Wins

When conflicts occur:

1. Server data takes precedence
2. Local changes are discarded
3. UI updates to reflect server state
4. User is notified (optional)

### Custom Resolution

For specific cases, implement custom logic:

```dart
class CustomConflictResolver extends ConflictResolver {
  @override
  Future<T> resolve<T>(T local, T remote) async {
    // Custom logic
    if (local.updatedAt.isAfter(remote.updatedAt)) {
      return local; // Client wins
    }
    return remote; // Server wins
  }
}
```

---

## Error Handling

### Common Errors

**Network Timeout**

```dart
try {
  await supabase.from('list_items').insert(item);
} on PostgrestException catch (e) {
  if (e.code == 'PGRST301') {
    // Handle timeout
    await queueForRetry(item);
  }
}
```

**Duplicate Key**

```dart
try {
  await supabase.from('list_items').insert(item);
} on PostgrestException catch (e) {
  if (e.code == '23505') {
    // Item already exists - update instead
    await supabase.from('list_items')
      .update(item)
      .eq('list_id', listId)
      .eq('movie_id', movieId);
  }
}
```

**Authentication Error**

```dart
try {
  await supabase.from('list_items').select();
} on PostgrestException catch (e) {
  if (e.code == '401' || e.code == 'PGRST301') {
    // Session expired - re-authenticate
    await refreshSession();
  }
}
```

---

## Row Level Security (RLS)

### Enable RLS

```sql
ALTER TABLE user_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE movie_ratings ENABLE ROW LEVEL SECURITY;
```

### Policies

**User can only access own lists**:

```sql
CREATE POLICY "Users can view own lists"
ON user_lists FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own lists"
ON user_lists FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own lists"
ON user_lists FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own lists"
ON user_lists FOR DELETE
USING (auth.uid() = user_id);
```

**List items inherit list permissions**:

```sql
CREATE POLICY "Users can view own list items"
ON list_items FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM user_lists
    WHERE user_lists.id = list_items.list_id
    AND user_lists.user_id = auth.uid()
  )
);
```

---

## Performance Optimization

### 1. Indexes

```sql
CREATE INDEX idx_list_items_list_id ON list_items(list_id);
CREATE INDEX idx_list_items_movie_id ON list_items(movie_id);
CREATE INDEX idx_movie_ratings_user_id ON movie_ratings(user_id);
CREATE INDEX idx_movie_ratings_movie_id ON movie_ratings(movie_id);
```

### 2. Pagination

```dart
final response = await supabase
  .from('list_items')
  .select()
  .eq('list_id', listId)
  .range(0, 49) // First 50 items
  .order('added_at', ascending: false);
```

### 3. Selective Sync

Only sync what's needed:

```dart
// Only sync active list
final activeListId = userPreferences.activeListId;
await syncService.syncList(activeListId);
```

---

## Testing

### Unit Tests

Test sync service:

```dart
test('SyncService retries on failure', () async {
  final mockSupabase = MockSupabaseClient();
  when(mockSupabase.from('list_items').insert(any))
    .thenThrow(Exception('Network error'));

  final syncService = SyncService(mockSupabase);
  await syncService.addItem(item);

  verify(mockSupabase.from('list_items').insert(any)).called(3); // 3 retries
});
```

### Integration Tests

Test real-time sync:

```dart
testWidgets('Real-time updates reflect in UI', (tester) async {
  await tester.pumpWidget(MyApp());

  // Add item via Supabase directly
  await supabase.from('list_items').insert({
    'list_id': testListId,
    'movie_id': 123,
  });

  await tester.pump(Duration(seconds: 1));

  // Verify UI updated
  expect(find.text('Movie 123'), findsOneWidget);
});
```

---

## Monitoring

### Metrics to Track

- Sync success rate
- Average sync latency
- Conflict resolution rate
- Retry attempts per operation
- Offline operation queue size

### Logging

Use `LoggerFactory`:

```dart
LoggerFactory.info('✅ Sync completed: $itemCount items');
LoggerFactory.warning('⚠️ Conflict detected, using server version');
LoggerFactory.error('❌ Sync failed after 3 retries: $error');
```

---

## Troubleshooting

### Realtime not working

1. Check if realtime is enabled for table in Supabase Dashboard
2. Verify subscription is active: `subscription.isPaused == false`
3. Check network connectivity
4. Verify RLS policies allow reading data

### Sync conflicts frequent

1. Reduce optimistic update scope
2. Implement better conflict resolution
3. Add user confirmation before syncing
4. Increase sync frequency

### Performance issues

1. Add database indexes
2. Implement pagination
3. Reduce subscription scope (filter by user/list)
4. Use memory cache for frequently accessed data

---

## Resources

- [Supabase Realtime Documentation](https://supabase.com/docs/guides/realtime)
- [Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Flutter Supabase Package](https://pub.dev/packages/supabase_flutter)

---

**Status**: Production-ready with enterprise-grade features  
**Maintainer**: @tiagofur  
**Project**: peliculas-admob
