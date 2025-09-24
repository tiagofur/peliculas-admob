# Test Setup Guide

This document explains how to properly set up tests in this Flutter application to avoid common initialization issues.

## Common Test Initialization Issues Fixed

### 1. HiveError: You need to initialize Hive or provide a path to store the box
This error occurs when tests try to use Hive repositories without proper initialization.

### 2. Supabase.instance not initialized error
This error occurs when tests try to access Supabase services before initialization.

## Solution: TestSetupHelper

We've created a `TestSetupHelper` class that handles all test initialization needs:

```dart
// test/helpers/test_setup_helper.dart
```

## How to Use TestSetupHelper in Your Tests

### Basic Test Setup Pattern

```dart
import 'package:flutter_test/flutter_test.dart';
import 'helpers/test_setup_helper.dart'; // Import the helper

void main() {
  group('Your Test Group', () {
    setUp(() async {
      // Initialize all test dependencies
      await TestSetupHelper.setupTest();
    });

    tearDown(() async {
      // Clean up after tests
      await TestSetupHelper.tearDownTest();
    });

    test('your test name', () async {
      // Your test code here
      // Hive and Supabase are now properly initialized
    });
  });
}
```

### For Tests with ProviderContainer

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/test_setup_helper.dart';

void main() {
  group('Provider Tests', () {
    late ProviderContainer container;

    setUp(() async {
      await TestSetupHelper.setupTest();
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await TestSetupHelper.tearDownTest();
    });

    test('provider test', () async {
      final provider = container.read(yourProvider);
      // Test your providers
    });
  });
}
```

### For Widget Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'helpers/test_setup_helper.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('widget test', (tester) async {
      await TestSetupHelper.setupTest();

      // Your widget test code

      await TestSetupHelper.tearDownTest();
    });
  });
}
```

## What TestSetupHelper Does

1. **Hive Initialization**:
   - Creates a temporary directory for Hive storage
   - Registers all necessary TypeAdapters safely
   - Prevents duplicate adapter registration errors

2. **Supabase Initialization**:
   - Initializes Supabase with mock configuration
   - Handles already-initialized scenarios gracefully

3. **SharedPreferences**:
   - Sets up mock values for testing

## Files Already Fixed

The following test files have been updated to use the TestSetupHelper pattern:

- `test/anonymous_data_migration_test.dart`
- `test/watched_movies_realtime_sync_test.dart`
- `test/watched_movies_multi_device_sync_test.dart`
- `test/watched_movies_integration_complete_test.dart`

## Important Notes

### Hive TypeAdapter Warnings
You may see warnings like:
```
Registering type adapters for dynamic type is must be avoided...
```
These are just warnings and don't affect test functionality. They occur because we're registering adapters generically for test setup.

### Test Performance
The initialization adds some overhead to test startup, but ensures reliable test execution without mysterious initialization failures.

### Test Isolation
Each test group properly sets up and tears down its environment, ensuring test isolation and preventing side effects between tests.

## Troubleshooting

### If you still get initialization errors:
1. Make sure you're calling `await TestSetupHelper.setupTest()` in your `setUp()` method
2. Make sure you're calling `await TestSetupHelper.tearDownTest()` in your `tearDown()` method
3. Check that your import path to the helper is correct: `import 'helpers/test_setup_helper.dart';`

### For complex integration tests:
The helper should handle most scenarios, but for very complex tests that need specific mocks, you might need additional setup beyond the helper.

## Migration Guide

To migrate existing tests:

1. Add the import: `import 'helpers/test_setup_helper.dart';`
2. Add `await TestSetupHelper.setupTest();` to your `setUp()` method
3. Add `await TestSetupHelper.tearDownTest();` to your `tearDown()` method
4. Remove any manual Hive or Supabase initialization code
5. Remove any manual SharedPreferences mock setup (it's handled by the helper)

## Benefits

- ✅ No more "Hive needs initialization" errors
- ✅ No more "Supabase not initialized" errors
- ✅ Consistent test setup across the entire test suite
- ✅ Easy to use and maintain
- ✅ Proper test isolation and cleanup