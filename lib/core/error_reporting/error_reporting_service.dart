import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../logging/logger_factory.dart';
import '../../services/error_reporting_config.dart';

/// Service for handling error reporting using Firebase Crashlytics
/// Integrates with the existing logging system to provide crash reporting
class ErrorReportingService {
  static ErrorReportingService? _instance;
  static ErrorReportingService get instance => _instance ??= ErrorReportingService._();
  
  ErrorReportingService._();

  bool _isInitialized = false;
  bool _isEnabled = false;

  /// Initialize the error reporting service
  /// Should be called during app initialization
  Future<void> initialize({bool? enabled}) async {
    if (_isInitialized) return;

    try {
      // Initialize config first
      await ErrorReportingConfig.instance.initialize();
      
      // Use config to determine if enabled, or fall back to parameter
      _isEnabled = enabled ?? ErrorReportingConfig.instance.isEnabled;

      // Only initialize Crashlytics on non-web platforms and if enabled
      if (!kIsWeb && _isEnabled) {
        // Initialize Firebase Crashlytics
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
        
        // Set up automatic crash reporting
        FlutterError.onError = (FlutterErrorDetails details) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
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
          LoggerFactory.error(
            'Platform Error: $error',
            stackTrace: stack,
          );
          return true;
        };

        if (kDebugMode) {
          LoggerFactory.info('✅ Error reporting service initialized with Crashlytics');
        }
      } else {
        if (kDebugMode) {
          final reason = kIsWeb ? 'Web platform not supported' : 
                        !_isEnabled ? 'Disabled by configuration' : 'Unknown reason';
          LoggerFactory.info('⚠️ Error reporting service initialized but disabled ($reason)');
        }
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Failed to initialize error reporting service: $e');
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
    if (!_isInitialized || !_isEnabled || kIsWeb) {
      // Still log locally even if Crashlytics is not available
      LoggerFactory.error(
        reason ?? 'Error reported: $error',
        data: data,
        stackTrace: stackTrace,
      );
      return;
    }

    try {
      // Set custom keys for additional context
      if (data != null) {
        for (final entry in data.entries) {
          await FirebaseCrashlytics.instance.setCustomKey(
            entry.key,
            entry.value?.toString() ?? 'null',
          );
        }
      }

      // Record the error
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: fatal,
        information: reason != null ? [reason] : null,
      );

      // Also log locally
      LoggerFactory.error(
        reason ?? 'Error reported: $error',
        data: data,
        stackTrace: stackTrace,
      );
    } catch (e) {
      // Fallback to local logging if Crashlytics fails
      LoggerFactory.error(
        'Failed to report error to Crashlytics: $e. Original error: $error',
        data: data,
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
      await FirebaseCrashlytics.instance.setCustomKey(key, value?.toString() ?? 'null');
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
      await FirebaseCrashlytics.instance.crash();
    } catch (e) {
      LoggerFactory.error('Failed to trigger test crash: $e');
    }
  }

  /// Check if error reporting is available and enabled
  bool get isAvailable => _isInitialized && _isEnabled && !kIsWeb;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;
}

/// Extension to easily add error reporting to any zone
extension ErrorReportingZone on ErrorReportingService {
  /// Run code in a zone with automatic error reporting
  R runWithErrorReporting<R>(
    R Function() body, {
    String? zoneName,
    Map<String, dynamic>? customData,
  }) {
    return runZonedGuarded(
      body,
      (error, stackTrace) {
        reportError(
          error,
          stackTrace,
          reason: zoneName != null ? 'Error in zone: $zoneName' : null,
          data: customData,
          fatal: false,
        );
      },
    ) ?? (throw StateError('Zone body returned null'));
  }

  /// Run async code in a zone with automatic error reporting
  Future<R> runAsyncWithErrorReporting<R>(
    Future<R> Function() body, {
    String? zoneName,
    Map<String, dynamic>? customData,
  }) async {
    return await runZonedGuarded(
      body,
      (error, stackTrace) {
        reportError(
          error,
          stackTrace,
          reason: zoneName != null ? 'Async error in zone: $zoneName' : null,
          data: customData,
          fatal: false,
        );
      },
    ) ?? (throw StateError('Zone body returned null'));
  }
}