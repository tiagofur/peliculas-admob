import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/core/error_reporting/error_reporting_service.dart';
import 'package:peliculas/core/logging/logger_factory.dart';
import 'package:peliculas/presentation/providers/error_reporting_provider.dart';

/// Tests for error reporting functionality
void main() {
  group('Error Reporting Tests', () {
    late ProviderContainer container;
    late ErrorReportingService errorReporting;

    setUp(() {
      container = ProviderContainer();
      errorReporting = ErrorReportingService.instance;
    });

    tearDown(() {
      container.dispose();
    });

    group('Error Reporting Service', () {
      test('should initialize correctly', () async {
        await errorReporting.initialize(enabled: false); // Disable for testing
        expect(errorReporting.isInitialized, isTrue);
      });

      test('should handle error reporting when disabled', () async {
        await errorReporting.initialize(enabled: false);
        
        // Should not throw when reporting errors even if disabled
        expect(
          () => errorReporting.reportError(
            'Test error',
            StackTrace.current,
            reason: 'Unit test',
            data: {'test': true},
          ),
          returnsNormally,
        );
      });

      test('should set user context correctly', () async {
        await errorReporting.initialize(enabled: false);
        
        // Should not throw when setting user context
        expect(
          () => errorReporting.setUserId('test_user_123'),
          returnsNormally,
        );
      });

      test('should set custom keys correctly', () async {
        await errorReporting.initialize(enabled: false);
        
        // Should not throw when setting custom keys
        expect(
          () => errorReporting.setCustomKey('test_key', 'test_value'),
          returnsNormally,
        );
      });

      test('should log messages correctly', () async {
        await errorReporting.initialize(enabled: false);
        
        // Should not throw when logging messages
        expect(
          () => errorReporting.log('Test log message'),
          returnsNormally,
        );
      });

      test('should handle zone error reporting', () async {
        await errorReporting.initialize(enabled: false);
        
        // Test synchronous zone error reporting
        expect(
          () => errorReporting.runWithErrorReporting(
            () => 'success',
            zoneName: 'test_zone',
            customData: {'test': 'data'},
          ),
          returnsNormally,
        );

        // Test asynchronous zone error reporting
        expect(
          () => errorReporting.runAsyncWithErrorReporting(
            () async => 'async_success',
            zoneName: 'async_test_zone',
            customData: {'async_test': 'data'},
          ),
          returnsNormally,
        );
      });
    });

    group('LoggerFactory Integration', () {
      test('should report critical errors', () async {
        await errorReporting.initialize(enabled: false);
        
        // Should not throw when reporting critical errors
        expect(
          () => LoggerFactory.reportCriticalError(
            'Critical test error',
            StackTrace.current,
            context: 'Unit test context',
            data: {'critical': true},
            fatal: false,
          ),
          returnsNormally,
        );
      });

      test('should set user context through LoggerFactory', () async {
        await errorReporting.initialize(enabled: false);
        
        // Should not throw when setting user context
        expect(
          () => LoggerFactory.setUserContext('logger_test_user'),
          returnsNormally,
        );
      });

      test('should set custom context through LoggerFactory', () async {
        await errorReporting.initialize(enabled: false);
        
        // Should not throw when setting custom context
        expect(
          () => LoggerFactory.setCustomContext('logger_key', 'logger_value'),
          returnsNormally,
        );
      });
    });

    group('Provider Integration', () {
      test('should provide error reporting service', () {
        final service = container.read(errorReportingServiceProvider);
        expect(service, isNotNull);
        expect(service, isA<ErrorReportingService>());
      });

      test('should handle error reporting mixin', () async {
        await errorReporting.initialize(enabled: false);
        
        // Create a test state notifier with the mixin
        final testNotifier = TestStateNotifierWithErrorReporting();
        
        // Should not throw when reporting errors
        expect(
          () => testNotifier.reportError(
            'Test notifier error',
            StackTrace.current,
            context: 'Test context',
            data: {'notifier_test': true},
          ),
          returnsNormally,
        );

        // Should not throw when running with error reporting
        expect(
          () => testNotifier.runWithErrorReporting(
            () async => 'test_result',
            operationName: 'test_operation',
            customData: {'operation_test': true},
          ),
          returnsNormally,
        );
      });
    });

    group('Error Scenarios', () {
      test('should handle initialization failures gracefully', () async {
        // Should not throw even if initialization fails
        expect(
          () => errorReporting.initialize(enabled: true),
          returnsNormally,
        );
      });

      test('should handle reporting errors when not initialized', () async {
        // Create a fresh instance that's not initialized
        final freshService = ErrorReportingService();
        
        // Should not throw when reporting errors on uninitialized service
        expect(
          () => freshService.reportError(
            'Error on uninitialized service',
            StackTrace.current,
          ),
          returnsNormally,
        );
      });
    });
  });
}

/// Test state notifier with error reporting mixin
class TestStateNotifierWithErrorReporting extends StateNotifier<String>
    with ErrorReportingMixin<String> {
  TestStateNotifierWithErrorReporting() : super('initial_state');
  
  void updateState(String newState) {
    state = newState;
  }
}