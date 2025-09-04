import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../services/error_reporting_config.dart';
import '../logging/logger_factory.dart';
import 'error_metrics_service.dart';

/// Utility function to clean null values from data maps to prevent
/// "Cannot send Null" errors in Flutter debugger and Firebase Crashlytics
Map<String, dynamic>? _cleanErrorDataMap(Map<String, dynamic>? data) {
  if (data == null) return null;
  
  final cleanData = <String, dynamic>{};
  for (final entry in data.entries) {
    if (entry.value != null) {
      cleanData[entry.key] = entry.value;
    }
  }
  
  return cleanData.isEmpty ? null : cleanData;
}

/// Service for handling error reporting using Firebase Crashlytics
/// Integrates with the existing logging system to provide crash reporting
class ErrorReportingService {
  ErrorReportingService._();
  static ErrorReportingService? _instance;
  static ErrorReportingService get instance =>
      _instance ??= ErrorReportingService._();

  bool _isInitialized = false;
  bool _isEnabled = false;

  /// Initialize the error reporting service
  /// Should be called during app initialization
  Future<void> initialize({bool? enabled}) async {
    if (_isInitialized) return;

    try {
      // Initialize config first
      await ErrorReportingConfig.instance.initialize();

      // Initialize metrics service
      await ErrorMetricsService.instance.initialize();

      // Use config to determine if enabled, or fall back to parameter
      _isEnabled = enabled ?? ErrorReportingConfig.instance.isEnabled;

      // Only initialize Crashlytics on non-web platforms and if enabled
      if (!kIsWeb && _isEnabled) {
        // Initialize Firebase Crashlytics
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(true);

        // Set up automatic crash reporting
        FlutterError.onError = (FlutterErrorDetails details) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);

          // Record crash in metrics
          ErrorMetricsService.instance.recordSessionCrash();

          LoggerFactory.error(
            'Flutter Fatal Error: ${details.exception}',
            data: {
              'library': details.library,
              'context': details.context?.toString(),
              'stack': details.stack.toString(),
            },
            stackTrace: details.stack,
          );
        };

        // Handle errors that occur outside of Flutter's context
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);

          // Record crash in metrics
          ErrorMetricsService.instance.recordSessionCrash();

          LoggerFactory.error(
            'Platform Error: $error',
            stackTrace: stack,
          );
          return true;
        };

        if (kDebugMode) {
          LoggerFactory.info(
              '✅ Error reporting service initialized with Crashlytics');
        }
      } else {
        if (kDebugMode) {
          final reason = kIsWeb
              ? 'Web platform not supported'
              : !_isEnabled
                  ? 'Disabled by configuration'
                  : 'Unknown reason';
          LoggerFactory.info(
              '⚠️ Error reporting service initialized but disabled ($reason)');
        }
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error(
            '❌ Failed to initialize error reporting service: $e');
      }
      // Don't throw - error reporting is not critical for app functionality
    }
  }

  /// Report a custom error with additional context
  Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    String? reason,
    Map<String, dynamic>? data,
    bool fatal = false,
  }) async {
    final cleanData = _cleanErrorDataMap(data);
    
    if (!_isInitialized || !_isEnabled || kIsWeb) {
      // Still log locally even if Crashlytics is not available
      LoggerFactory.error(
        reason ?? 'Error reported: $error',
        data: cleanData,
        stackTrace: stackTrace,
      );
      return;
    }

    try {
      // Set custom keys for additional context
      if (cleanData != null) {
        for (final entry in cleanData.entries) {
          await FirebaseCrashlytics.instance.setCustomKey(
            entry.key,
            entry.value.toString(),
          );
        }
      }

      // Record the error
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: fatal,
        information: reason != null ? [reason] : <Object>[],
      );

      // Also log locally
      LoggerFactory.error(
        reason ?? 'Error reported: $error',
        data: cleanData,
        stackTrace: stackTrace,
      );
    } catch (e) {
      // Fallback to local logging if Crashlytics fails
      LoggerFactory.error(
        'Failed to report error to Crashlytics: $e. Original error: $error',
        data: cleanData,
        stackTrace: stackTrace,
      );
    }
  }

  /// Set user identifier for crash reports
  Future<void> setUserId(String userId) async {
    if (!_isInitialized || !_isEnabled || kIsWeb) return;

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    } catch (e) {
      LoggerFactory.warning('Failed to set user ID for crash reporting: $e');
    }
  }

  /// Set custom key-value data for crash reports
  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_isInitialized || !_isEnabled || kIsWeb) return;

    try {
      await FirebaseCrashlytics.instance
          .setCustomKey(key, value?.toString() ?? 'null');
    } catch (e) {
      LoggerFactory.warning('Failed to set custom key for crash reporting: $e');
    }
  }

  /// Log a message to Crashlytics
  Future<void> log(String message) async {
    if (!_isInitialized || !_isEnabled || kIsWeb) {
      LoggerFactory.info(message);
      return;
    }

    try {
      await FirebaseCrashlytics.instance.log(message);
      LoggerFactory.info(message);
    } catch (e) {
      LoggerFactory.warning('Failed to log message to Crashlytics: $e');
    }
  }

  /// Test crash reporting (only in debug mode)
  Future<void> testCrash() async {
    if (!kDebugMode) {
      LoggerFactory.warning('Test crash can only be triggered in debug mode');
      return;
    }

    if (!_isInitialized || !_isEnabled || kIsWeb) {
      LoggerFactory.warning('Crashlytics not available for testing');
      return;
    }

    try {
      FirebaseCrashlytics.instance.crash();
    } catch (e) {
      LoggerFactory.error('Failed to trigger test crash: $e');
    }
  }

  /// Check if error reporting is available and enabled
  bool get isAvailable => _isInitialized && _isEnabled && !kIsWeb;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get current error reporting metrics
  Map<String, dynamic> get metrics =>
      ErrorMetricsService.instance.metricsSnapshot;

  /// Check if crash-free sessions meet success criteria (≥99.7%)
  bool get meetsCrashFreeTarget =>
      ErrorMetricsService.instance.meetsCrashFreeSuccessCriteria;

  /// Check if core flow error rate meets success criteria (<5%)
  bool get meetsCoreFlowTarget =>
      ErrorMetricsService.instance.meetsCoreFlowSuccessCriteria;
}

/// Extension to easily add error reporting to any zone
extension ErrorReportingZone on ErrorReportingService {
  /// Run code in a zone with automatic error reporting
  R runWithErrorReporting<R>(
    R Function() body, {
    String? zoneName,
    Map<String, dynamic>? customData,
  }) {
    final result = runZonedGuarded(
      body,
      (error, stackTrace) {
        reportError(
          error,
          stackTrace,
          reason: zoneName != null ? 'Error in zone: $zoneName' : null,
          data: _cleanErrorDataMap(customData),
          fatal: false,
        );
      },
    );
    
    // Handle the case where runZonedGuarded returns null
    // This can happen when an exception is thrown in the zone
    if (result == null) {
      // For void functions, we can return a default value
      try {
        return null as R;
      } catch (e) {
        // If casting null to R fails, it means R is not nullable
        // For non-nullable types, throw an error with more context
        throw StateError(
          'Zone body returned null in ${zoneName ?? "unknown zone"}. '
          'This typically indicates an unhandled exception occurred in the zone.'
        );
      }
    }
    
    return result;
  }

  /// Run async code in a zone with automatic error reporting
  Future<R> runAsyncWithErrorReporting<R>(
    Future<R> Function() body, {
    String? zoneName,
    Map<String, dynamic>? customData,
  }) async {
    final result = await runZonedGuarded(
      body,
      (error, stackTrace) {
        reportError(
          error,
          stackTrace,
          reason:
              zoneName != null ? 'Async error in zone: $zoneName' : null,
          data: _cleanErrorDataMap(customData),
          fatal: false,
        );
      },
    );
    
    // Handle the case where runZonedGuarded returns null
    // This can happen when an exception is thrown in the zone
    if (result == null) {
      // For void functions, we can return a default value
      try {
        return null as R;
      } catch (e) {
        // If casting null to R fails, it means R is not nullable
        // For non-nullable types, throw an error with more context
        throw StateError(
          'Zone body returned null in ${zoneName ?? "unknown zone"}. '
          'This typically indicates an unhandled exception occurred in the zone.'
        );
      }
    }
    
    return result;
  }
}
