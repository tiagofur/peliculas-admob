import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/core/error_reporting/error_reporting_service.dart';
import 'package:peliculas/core/error_reporting/error_metrics_service.dart';
import 'package:peliculas/core/logging/logger_factory.dart';
import 'package:peliculas/presentation/providers/error_reporting_provider.dart';
import 'package:peliculas/services/error_reporting_config.dart';

/// Tests for error reporting functionality
void main() {
  group('Error Reporting Tests', () {
    late ProviderContainer container;
    late ErrorReportingService errorReporting;
    late ErrorMetricsService metrics;

    setUp(() {
      container = ProviderContainer();
      errorReporting = ErrorReportingService.instance;
      metrics = ErrorMetricsService.instance;
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

      test('should provide error reporting config', () {
        final config = container.read(errorReportingConfigProvider);
        expect(config, isNotNull);
        expect(config, isA<ErrorReportingConfig>());
      });

      test('should provide error metrics service', () {
        final metricsService = container.read(errorMetricsServiceProvider);
        expect(metricsService, isNotNull);
        expect(metricsService, isA<ErrorMetricsService>());
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

      test('should handle core flow tracking mixin', () async {
        await errorReporting.initialize(enabled: false);
        await metrics.initialize();
        
        final testNotifier = TestStateNotifierWithCoreFlowTracking();
        
        // Should not throw when tracking core flows
        expect(
          () => testNotifier.trackCoreFlow(
            'authentication',
            () async => 'flow_result',
            additionalData: {'test': true},
          ),
          returnsNormally,
        );

        // Should not throw when recording core flow success
        expect(
          () => testNotifier.recordCoreFlowSuccess('movie_search'),
          returnsNormally,
        );

        // Should not throw when recording core flow error
        expect(
          () => testNotifier.recordCoreFlowError('watchlist_add', 'Test error'),
          returnsNormally,
        );
      });
    });

    group('Configuration Service', () {
      late ErrorReportingConfig config;

      setUp(() {
        config = ErrorReportingConfig.instance;
      });

      test('should get current config data', () {
        final configData = config.currentConfig;
        expect(configData, isA<Map<String, dynamic>>());
        expect(configData.containsKey('initialized'), isTrue);
        expect(configData.containsKey('buildMode'), isTrue);
      });

      test('should handle enable/disable operations safely', () async {
        // Should not throw even if not initialized
        expect(
          () => config.setEnabled(true),
          returnsNormally,
        );
        
        expect(
          () => config.setUserOptIn(false),
          returnsNormally,
        );
      });

      test('should provide default values when not initialized', () {
        // Before initialization, should provide reasonable defaults
        expect(config.currentConfig['buildMode'], isNotNull);
        expect(config.isEnabled, isA<bool>());
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
  
  group('Error Metrics Service Tests', () {
    late ErrorMetricsService metrics;

    setUp(() {
      metrics = ErrorMetricsService.instance;
    });

    test('should initialize correctly', () async {
      await metrics.initialize();
      expect(metrics.metricsSnapshot['initialized'], isTrue);
    });

    test('should track core flow attempts and errors', () async {
      await metrics.initialize();
      await metrics.resetMetrics();
      
      // Track some attempts
      await metrics.recordCoreFlowAttempt('authentication');
      await metrics.recordCoreFlowAttempt('movie_search');
      await metrics.recordCoreFlowAttempt('watchlist_add');
      
      // Track some errors
      await metrics.recordCoreFlowError('authentication', errorDetails: 'Test error');
      
      final snapshot = metrics.metricsSnapshot;
      final coreFlowMetrics = snapshot['core_flow_metrics'] as Map<String, dynamic>;
      
      expect(coreFlowMetrics['total_attempts'], equals(3));
      expect(coreFlowMetrics['total_errors'], equals(1));
      expect(coreFlowMetrics['successful_attempts'], equals(2));
      expect(coreFlowMetrics['error_rate_percentage'], greaterThan(0));
    });

    test('should calculate crash-free sessions correctly', () async {
      await metrics.initialize();
      await metrics.resetMetrics();
      
      // Start with no crashes - should be 100% crash-free initially
      var snapshot = metrics.metricsSnapshot;
      var sessionMetrics = snapshot['session_metrics'] as Map<String, dynamic>;
      expect(sessionMetrics['crash_free_percentage'], equals(100.0));
      expect(metrics.meetsCrashFreeSuccessCriteria, isTrue);
      
      // Record a crash
      await metrics.recordSessionCrash();
      
      snapshot = metrics.metricsSnapshot;
      sessionMetrics = snapshot['session_metrics'] as Map<String, dynamic>;
      
      // Should be less than 100% now
      expect(sessionMetrics['crash_free_percentage'], lessThan(100.0));
    });

    test('should meet success criteria with good metrics', () async {
      await metrics.initialize();
      await metrics.resetMetrics();
      
      // Simulate good metrics - many attempts, few errors
      for (int i = 0; i < 100; i++) {
        await metrics.recordCoreFlowAttempt('authentication');
      }
      
      // Only 1 error out of 100 = 1% error rate (under 5% target)
      await metrics.recordCoreFlowError('authentication');
      
      expect(metrics.meetsCoreFlowSuccessCriteria, isTrue);
      expect(metrics.coreFlowErrorRate, lessThan(5.0));
      
      // Should still meet crash-free criteria (no crashes recorded)
      expect(metrics.meetsCrashFreeSuccessCriteria, isTrue);
      expect(metrics.crashFreeSessionPercentage, equals(100.0));
    });

    test('should provide comprehensive metrics snapshot', () async {
      await metrics.initialize();
      
      final snapshot = metrics.metricsSnapshot;
      
      expect(snapshot['initialized'], isTrue);
      expect(snapshot, containsKey('session_metrics'));
      expect(snapshot, containsKey('core_flow_metrics'));
      expect(snapshot, containsKey('current_session'));
      
      final sessionMetrics = snapshot['session_metrics'] as Map<String, dynamic>;
      expect(sessionMetrics, containsKey('total_sessions'));
      expect(sessionMetrics, containsKey('crash_sessions'));
      expect(sessionMetrics, containsKey('crash_free_percentage'));
      expect(sessionMetrics, containsKey('meets_crash_free_criteria'));
      
      final coreFlowMetrics = snapshot['core_flow_metrics'] as Map<String, dynamic>;
      expect(coreFlowMetrics, containsKey('total_attempts'));
      expect(coreFlowMetrics, containsKey('total_errors'));
      expect(coreFlowMetrics, containsKey('error_rate_percentage'));
      expect(coreFlowMetrics, containsKey('meets_error_rate_criteria'));
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

/// Test state notifier with core flow tracking mixin
class TestStateNotifierWithCoreFlowTracking extends StateNotifier<String>
    with CoreFlowTrackingMixin<String> {
  TestStateNotifierWithCoreFlowTracking() : super('initial_state');
  
  void updateState(String newState) {
    state = newState;
  }
}