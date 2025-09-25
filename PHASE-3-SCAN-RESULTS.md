# 🔍 **Phase 3: Project-Wide Timer Leak Fix - Comprehensive Scan Results**

## **📊 Current Status (Phase 2 Complete)**

✅ **Successfully Applied Pattern to 4 Files:**

1. `test/presentation/widgets/performance/lazy_optimized_image_test.dart` ✅ (15/15 tests)
2. `test/services/large_data_performance_test.dart` ✅ (4/5 tests)
3. `test/services/realtime_sync_performance_test.dart` ✅ (Timer leaks fixed)
4. `test/services/realtime_sync_manager_scenarios_test.dart` ✅ (9/14 tests, timer fixes applied)

## **🎯 Phase 3: Comprehensive Project Scan**

### **Priority 1: High-Impact Files (Need Immediate Fix)**

#### **Service Tests with Direct ConnectivityDetector Usage:**

1. `test/services/sync_coordinator_concurrent_test.dart` - Uses SyncCoordinator
2. `test/realtime_sync_manager_test.dart` - Uses MockRealtimeSyncManager
3. `test/connectivity_manager_test.dart` - Mock ConnectivityManager only (low priority)

#### **Service Tests with Indirect Timer Dependencies:**

4. `test/services/realtime_sync_intermittent_connectivity_test.dart` - Connectivity scenarios
5. `test/services/realtime_sync_conflict_resolution_test.dart` - RealtimeSyncManager usage

### **Priority 2: Integration Tests (Critical for CI/CD)**

6. `integration_test/performance_load_test.dart` - Uses MainApp with full service stack
7. `integration_test/enhanced_error_handling_test.dart` - Network error handling
8. `integration_test/movie_browsing_flow_test.dart` - Full app stack
9. `integration_test/user_authentication_flow_test.dart` - May trigger connectivity
10. `integration_test/watchlist_flow_test.dart` - Sync operations
11. `integration_test/sharing_functionality_flow_test.dart` - Network operations

### **Priority 3: Other Test Files (Potential Timer Sources)**

#### **Data Migration and Sync Related:**

12. `test/data_migration_service_test.dart` - May use sync services
13. `test/data_migration_service_standalone_test.dart` - Standalone version
14. `test/watched_movies_realtime_sync_test.dart` - RealtimeSyncManager usage
15. `test/watched_movies_multi_device_sync_test.dart` - Multi-device sync
16. `test/watched_movies_integration_complete_test.dart` - Complete sync integration

#### **Profile and User Services:**

17. `test/enhanced_user_profile_service_real_stats_test.dart` - May use network services
18. `test/enhanced_user_profile_service_isolated_test.dart` - Isolated version

### **Priority 4: Mock and Helper Files (Support Infrastructure)**

19. `test/helpers/mock_hybrid_image_service.dart` - Already has setUpAll(), check for connectivity
20. Mock files (`.mocks.dart`) - Generated files, check if regeneration needed

## **🚀 Phase 3 Implementation Strategy**

### **Step 1: Critical Service Tests (Priority 1)**

Apply ConnectivityDetector.setTestMode() pattern to:

- `test/services/sync_coordinator_concurrent_test.dart`
- `test/realtime_sync_manager_test.dart`
- `test/services/realtime_sync_intermittent_connectivity_test.dart`
- `test/services/realtime_sync_conflict_resolution_test.dart`

### **Step 2: Integration Tests (Priority 2)**

Add ConnectivityDetector test mode to integration tests that initialize MainApp:

- `integration_test/performance_load_test.dart`
- `integration_test/enhanced_error_handling_test.dart`
- `integration_test/movie_browsing_flow_test.dart`
- `integration_test/user_authentication_flow_test.dart`
- `integration_test/watchlist_flow_test.dart`
- `integration_test/sharing_functionality_flow_test.dart`

### **Step 3: Comprehensive Testing**

- Run full test suite to measure improvement
- Check for remaining timer leaks
- Validate integration test stability

### **Step 4: Documentation and Finalization**

- Update project documentation with timer leak prevention pattern
- Create testing guidelines for future development

## **🔧 Proven Pattern to Apply**

```dart
import 'package:peliculas/infrastructure/services/connectivity_detector.dart';

setUpAll(() {
  // Configure test mode for ConnectivityDetector to prevent Timer leaks
  ConnectivityDetector.setTestMode(true);
  // ... other setup
});

tearDownAll(() {
  ConnectivityDetector.setTestMode(false);
});
```

## **📈 Expected Outcomes**

- **Timer Leaks**: Complete elimination across all test files
- **Test Stability**: Improved integration test reliability
- **CI/CD Performance**: Faster and more stable automated testing
- **Developer Experience**: Consistent testing patterns project-wide

## **🎯 Success Metrics**

- 100% of identified files updated with timer leak prevention
- All integration tests passing consistently
- Zero timer-related memory leaks in test runs
- Improved overall test suite performance and reliability
