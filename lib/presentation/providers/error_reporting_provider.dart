import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/error_reporting/error_metrics_service.dart';
import '../../core/error_reporting/error_reporting_service.dart';
import '../../core/logging/logger_factory.dart';
import '../../services/error_reporting_config.dart';
import 'auth_provider.dart';

/// Provider for error reporting service
final errorReportingServiceProvider = Provider<ErrorReportingService>((ref) {
  return ErrorReportingService.instance;
});

/// Provider for error reporting configuration
final errorReportingConfigProvider = Provider<ErrorReportingConfig>((ref) {
  return ErrorReportingConfig.instance;
});

/// Provider for error metrics service
final errorMetricsServiceProvider = Provider<ErrorMetricsService>((ref) {
  return ErrorMetricsService.instance;
});

/// Provider to get current error reporting status
final errorReportingStatusProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final config = ref.watch(errorReportingConfigProvider);
  final service = ref.watch(errorReportingServiceProvider);

  // Ensure config is initialized
  if (!config.currentConfig['initialized']) {
    await config.initialize();
  }

  return {
    ...config.currentConfig,
    'service_initialized': service.isInitialized,
    'service_available': service.isAvailable,
    'metrics': service.metrics,
    'meets_crash_free_target': service.meetsCrashFreeTarget,
    'meets_core_flow_target': service.meetsCoreFlowTarget,
  };
});

/// Provider to automatically set user context when user logs in/out
final errorReportingUserContextProvider = Provider<void>((ref) {
  ref.listen(currentUserProvider, (previous, next) {
    final errorReporting = ref.read(errorReportingServiceProvider);

    if (next != null) {
      // User logged in, set user context
      errorReporting.setUserId(next.id);
      errorReporting.setCustomKey('user_email', next.email);
      errorReporting.setCustomKey('user_last_sign_in',
          next.lastSignInAt?.toIso8601String() ?? 'unknown');

      LoggerFactory.setUserContext(next.id);
      LoggerFactory.info('Error reporting context set for user: ${next.id}');
    } else {
      // User logged out, clear user context
      errorReporting.setUserId('anonymous');
      errorReporting.setCustomKey('user_email', null);
      errorReporting.setCustomKey('user_last_sign_in', null);

      LoggerFactory.info('Error reporting context cleared for logged out user');
    }
  });
});

/// Mixin to easily add error reporting to StateNotifiers
mixin ErrorReportingMixin<T> on StateNotifier<T> {
  /// Report an error with context about this StateNotifier
  Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? data,
    bool fatal = false,
  }) async {
    final notifierContext = context ?? runtimeType.toString();

    await LoggerFactory.reportCriticalError(
      error,
      stackTrace,
      context: notifierContext,
      data: {
        'notifier_type': runtimeType.toString(),
        'current_state': state.toString(),
        ...?data,
      },
      fatal: fatal,
    );
  }

  /// Run a function with error reporting for this StateNotifier
  Future<R> runWithErrorReporting<R>(
    Future<R> Function() body, {
    String? operationName,
    Map<String, dynamic>? customData,
  }) async {
    return await ErrorReportingService.instance.runAsyncWithErrorReporting(
      body,
      zoneName:
          '${runtimeType.toString()}${operationName != null ? '.$operationName' : ''}',
      customData: {
        'notifier_type': runtimeType.toString(),
        'current_state': state.toString(),
        ...?customData,
      },
    );
  }
}

/// Mixin to track core flow operations in StateNotifiers
mixin CoreFlowTrackingMixin<T> on StateNotifier<T> {
  /// Track a core flow operation with automatic error and success tracking
  Future<R> trackCoreFlow<R>(
    String flowName,
    Future<R> Function() operation, {
    Map<String, dynamic>? additionalData,
  }) async {
    ErrorMetricsService.instance.recordCoreFlowAttempt();

    try {
      final result =
          await ErrorReportingService.instance.runAsyncWithErrorReporting(
        operation,
        zoneName: '${runtimeType.toString()}.core_flow.$flowName',
        customData: {
          'notifier_type': runtimeType.toString(),
          'current_state': state.toString(),
          'core_flow': flowName,
          ...?additionalData,
        },
      );

      LoggerFactory.info(
          '✅ Core flow successful: $flowName in ${runtimeType.toString()}');
      return result;
    } catch (error) {
      ErrorMetricsService.instance.recordCoreFlowError(flowName);
      rethrow;
    }
  }

  /// Record a successful core flow attempt (without full operation tracking)
  Future<void> recordCoreFlowSuccess(String flowName) async {
    ErrorMetricsService.instance.recordCoreFlowAttempt();
    LoggerFactory.info(
        '✅ Core flow successful: $flowName in ${runtimeType.toString()}');
  }

  /// Record a core flow error (without full operation tracking)
  Future<void> recordCoreFlowError(String flowName, dynamic error) async {
    ErrorMetricsService.instance.recordCoreFlowError(flowName);
  }
}

/// Extension to add error reporting to any provider
extension ErrorReportingProviderExtension on Ref {
  /// Report an error with provider context
  Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? data,
    bool fatal = false,
  }) async {
    await LoggerFactory.reportCriticalError(
      error,
      stackTrace,
      context: context ?? 'Provider',
      data: {
        'provider_context': context ?? 'unknown',
        ...?data,
      },
      fatal: fatal,
    );
  }
}
