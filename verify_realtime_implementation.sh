#!/bin/bash

# Verification script for realtime sync implementation
# This script validates the key components of the realtime sync system

echo "🔍 Verifying Realtime Sync Implementation for Watchlist and Ratings"
echo "=================================================================="

# Check if required files exist
echo -n "✅ Checking RealtimeListenerService... "
if [ -f "lib/core/services/realtime_listener_service.dart" ]; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

echo -n "✅ Checking SyncableUserMovieRating entity... "
if [ -f "lib/domain/entities/syncable_user_movie_rating.dart" ]; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

echo -n "✅ Checking MultiplataformSyncManager... "
if [ -f "lib/infrastructure/services/multiplatform_sync_manager.dart" ]; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

# Check for new listeners in the RealtimeListenerService
echo -n "✅ Checking watchlist listener implementation... "
if grep -q "_setupWatchlistListener" lib/core/services/realtime_listener_service.dart; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

echo -n "✅ Checking ratings listener implementation... "
if grep -q "_setupRatingsListener" lib/core/services/realtime_listener_service.dart; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

# Check for handler methods
echo -n "✅ Checking watchlist change handler... "
if grep -q "_handleWatchlistChange" lib/core/services/realtime_listener_service.dart; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

echo -n "✅ Checking ratings change handler... "
if grep -q "_handleRatingsChange" lib/core/services/realtime_listener_service.dart; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

# Check for provider invalidation in sync manager
echo -n "✅ Checking provider invalidation system... "
if grep -q "_invalidateProviders" lib/infrastructure/services/multiplatform_sync_manager.dart; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

# Check test files
echo -n "✅ Checking watchlist/ratings realtime tests... "
if [ -f "test/watchlist_ratings_realtime_test.dart" ]; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

echo -n "✅ Checking latency performance tests... "
if [ -f "test/realtime_latency_performance_test.dart" ]; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

# Verify table names are correct
echo -n "✅ Checking user_watchlist table references... "
if grep -q "user_watchlist" lib/core/services/realtime_listener_service.dart; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

echo -n "✅ Checking user_movie_ratings table references... "
if grep -q "user_movie_ratings" lib/core/services/realtime_listener_service.dart; then
    echo "FOUND"
else
    echo "❌ MISSING"
    exit 1
fi

# Check for throttling configuration
echo -n "✅ Checking throttling configuration... "
if grep -q "debounceDelay.*300" lib/core/services/realtime_listener_service.dart && \
   grep -q "throttleInterval.*seconds: 1" lib/core/services/realtime_listener_service.dart && \
   grep -q "maxEvents: 3" lib/core/services/realtime_listener_service.dart; then
    echo "FOUND"
else
    echo "❌ MISSING OR INCORRECT"
    exit 1
fi

# Count total number of listeners
echo ""
echo "📊 Implementation Summary:"
echo "========================"

# Count setup methods
listener_count=$(grep -c "_setupFavoritesListener\|_setupWatchedMoviesListener\|_setupCustomListsListener\|_setupWatchlistListener\|_setupRatingsListener" lib/core/services/realtime_listener_service.dart)
echo "• Total realtime listeners: $listener_count"

# Count handler methods
handler_count=$(grep -c "_handleFavoriteChange\|_handleWatchedMovieChange\|_handleCustomListChange\|_handleWatchlistChange\|_handleRatingsChange" lib/core/services/realtime_listener_service.dart)
echo "• Total event handlers: $handler_count"

# Check imports for new entities
import_count=$(grep -c "syncable_user_movie_rating\|syncable_watchlist_movie" lib/core/services/realtime_listener_service.dart)
echo "• Syncable entity imports: $import_count"

echo ""
echo "🎯 Performance Requirements:"
echo "============================"
echo "• Target latency: <1.5 seconds"
echo "• Throttling: 300ms debounce, 1s throttle, max 3 events/second"
echo "• Tables covered: user_watchlist, user_movie_ratings"

echo ""
echo "🧪 Test Coverage:"
echo "================="
test_files=("test/watchlist_ratings_realtime_test.dart" "test/realtime_latency_performance_test.dart")
for test_file in "${test_files[@]}"; do
    if [ -f "$test_file" ]; then
        test_count=$(grep -c "test(" "$test_file")
        echo "• $test_file: $test_count tests"
    fi
done

echo ""
echo "✅ ALL CHECKS PASSED! Realtime sync implementation is ready."
echo ""
echo "🚀 Next Steps:"
echo "=============="
echo "1. Run tests to validate functionality"
echo "2. Test on multiple devices for synchronization"
echo "3. Monitor latency in development environment"
echo "4. Verify UI updates occur automatically on realtime events"
echo ""