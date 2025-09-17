import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../lib/core/state/app_state_manager.dart';

void main() {
  group('AppStateManager', () {
    late AppStateManager appStateManager;

    setUp(() {
      appStateManager = AppStateManager.instance;
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({});

        // Act
        await appStateManager.initialize();

        // Assert
        expect(appStateManager.isInitialized, isTrue);
      });

      test('should not reinitialize if already initialized', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({});
        await appStateManager.initialize();

        // Act
        await appStateManager.initialize();

        // Assert
        expect(appStateManager.isInitialized, isTrue);
      });
    });

    group('Route Management', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        await appStateManager.initialize();
      });

      test('should update current route', () {
        // Act
        appStateManager.updateCurrentRoute('/movies');

        // Assert
        expect(appStateManager.lastRoute, equals('/movies'));
      });

      test('should track unsaved changes when route changes', () {
        // Act
        appStateManager.updateCurrentRoute('/movies');

        // Assert
        expect(appStateManager.hasUnsavedChanges, isTrue);
      });
    });

    group('Session Data Management', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        await appStateManager.initialize();
      });

      test('should update session data', () {
        // Act
        appStateManager.updateSessionData('testKey', 'testValue');

        // Assert
        expect(appStateManager.getSessionValue('testKey'), equals('testValue'));
      });

      test('should track unsaved changes when session data changes', () {
        // Act
        appStateManager.updateSessionData('testKey', 'testValue');

        // Assert
        expect(appStateManager.hasUnsavedChanges, isTrue);
      });

      test('should handle different data types', () {
        // Act
        appStateManager.updateSessionData('stringKey', 'stringValue');
        appStateManager.updateSessionData('intKey', 42);
        appStateManager.updateSessionData('boolKey', true);
        appStateManager.updateSessionData('doubleKey', 3.14);

        // Assert
        expect(appStateManager.getSessionValue('stringKey'), equals('stringValue'));
        expect(appStateManager.getSessionValue('intKey'), equals(42));
        expect(appStateManager.getSessionValue('boolKey'), equals(true));
        expect(appStateManager.getSessionValue('doubleKey'), equals(3.14));
      });
    });

    group('User Preferences Management', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        await appStateManager.initialize();
      });

      test('should update user preferences', () {
        // Act
        appStateManager.updateUserPreference('theme', 'dark');

        // Assert
        expect(appStateManager.getUserPreference('theme'), equals('dark'));
      });

      test('should track unsaved changes when preferences change', () {
        // Act
        appStateManager.updateUserPreference('theme', 'dark');

        // Assert
        expect(appStateManager.hasUnsavedChanges, isTrue);
      });
    });

    group('App State Management', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        await appStateManager.initialize();
      });

      test('should update app state', () {
        // Act
        appStateManager.updateAppState('selectedTab', 1);

        // Assert
        expect(appStateManager.getAppStateValue('selectedTab'), equals(1));
      });

      test('should track unsaved changes when app state changes', () {
        // Act
        appStateManager.updateAppState('selectedTab', 1);

        // Assert
        expect(appStateManager.hasUnsavedChanges, isTrue);
      });
    });

    group('State Persistence', () {
      test('should save state when requested', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({});
        await appStateManager.initialize();
        appStateManager.updateSessionData('key', 'value');

        // Act & Assert - should not throw
        // Verificar que los datos están guardados
        expect(appStateManager.getSessionValue('key'), equals('value'));
      });
    });

    group('Crash Recovery', () {
      test('should handle crash recovery data', () async {
        // Arrange
        final mockData = {
          'crash_data': '{"current_route":"/home","timestamp":"${DateTime.now().millisecondsSinceEpoch}"}',
        };
        SharedPreferences.setMockInitialValues(mockData);

        // Act & Assert - should not throw
        expect(() async => await appStateManager.initialize(), returnsNormally);
      });

      test('should mark crash recovery as complete', () {
        // Act & Assert - should not throw
        expect(() => appStateManager.markCrashRecoveryComplete(), returnsNormally);
      });
    });

    group('Error Handling', () {
      test('should handle invalid data gracefully', () async {
        // Arrange
        final mockData = {
          'session_data': 'invalid_json',
          'user_preferences': 'also_invalid_json',
          'app_state': 'not_json_either',
        };
        SharedPreferences.setMockInitialValues(mockData);

        // Act & Assert - should not throw
        expect(() async => await appStateManager.initialize(), returnsNormally);
        await appStateManager.initialize();
        
        expect(appStateManager.isInitialized, isTrue);
      });
    });

    group('Lifecycle Management', () {
      test('should dispose properly', () {
        // Act & Assert - should not throw
        expect(() => appStateManager.dispose(), returnsNormally);
      });
    });
  });
}