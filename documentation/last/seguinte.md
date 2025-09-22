# 📋 Development Priority Queue

## Critical Issues to Fix (Priority Order)

### 🔴 P0 - Beta Blockers (Must Fix First)

1. **Custom Lists System** - Movies not saving locally or to Supabase

   - Files affected: `lib/presentation/providers/storage/direct_custom_lists_provider.dart`
   - Issue: Local storage and Supabase sync failing

2. **Real-Time Sync** - Not working for any data

   - Component: Supabase real-time subscriptions
   - Impact: Multi-device sync broken

3. **System Permissions** - Not configured for any platform
   - Files needed: `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `macos/Runner/Info.plist`
   - Impact: App crashes on real devices

### 🟠 P1 - High Priority (Fix After P0)

4. **Movie Details** - Missing genre names and technical info

   - File: `lib/infrastructure/mappers/movie_mapper.dart`
   - Issue: Showing genre IDs instead of names

5. **Streaming Platforms** - All links broken (404s)
   - Component: Streaming providers service
   - Impact: Revenue loss from affiliate links

### 🟡 P2 - Medium Priority (Post-Beta)

6. **TMDB → Trakt Migration** - Needs implementation

   - New service required: `lib/infrastructure/services/trakt_service.dart`
   - Reason: Better API features and rate limits

7. **Series Support** - Requires UI/UX design first
   - Impact: Major feature expansion
   - Status: Awaiting design completion

---

## ⚡ Immediate Action Items

### Sprint Tasks (This Week)

- [ ] Fix the Supabase table permissions and real-time setup
- [ ] Add permission configurations to all platform manifests
- [ ] Implement genre mapping in movie mapper
- [ ] Fix the DirectCustomListsProvider state management

### Development Commands

```bash
# Test custom lists functionality
flutter test test/lists/custom_lists_test.dart

# Test sync functionality
flutter test test/sync/realtime_sync_test.dart

# Run integration tests
flutter test integration_test/

# Build and test on real device
flutter build apk --debug
```

### Files to Modify First

1. `android/app/src/main/AndroidManifest.xml` - Add permissions
2. `lib/infrastructure/mappers/movie_mapper.dart` - Add genre mapping
3. `lib/presentation/providers/storage/direct_custom_lists_provider.dart` - Fix state management
4. `supabase/migrations/` - Update RLS policies

---

**Last Updated**: January 2025  
**Next Review**: After P0 fixes completion  
**Status**: 🚧 Active Development
