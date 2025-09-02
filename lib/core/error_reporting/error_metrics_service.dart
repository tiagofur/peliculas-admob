import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/logger_factory.dart';

/// Service to track error reporting metrics and success criteria
/// Monitors crash-free sessions and core flow error rates
class ErrorMetricsService {
  static ErrorMetricsService? _instance;
  static ErrorMetricsService get instance => _instance ??= ErrorMetricsService._();
  
  ErrorMetricsService._();

  static const String _sessionCountKey = 'error_metrics_session_count';
  static const String _crashSessionCountKey = 'error_metrics_crash_session_count';
  static const String _coreFlowAttemptCountKey = 'error_metrics_core_flow_attempts';
  static const String _coreFlowErrorCountKey = 'error_metrics_core_flow_errors';
  static const String _sessionStartTimeKey = 'error_metrics_session_start_time';
  static const String _lastMetricsResetKey = 'error_metrics_last_reset';
  
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  Timer? _metricsTimer;
  DateTime? _currentSessionStart;
  bool _sessionHadCrash = false;

  /// Core flows that we monitor for error rates
  static const List<String> coreFlows = [
    'authentication',
    'movie_search',
    'movie_details',
    'watchlist_add',
    'watchlist_remove',
    'movie_rating',
    'user_profile',
    'sync_operation',
  ];

  /// Initialize the metrics service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      
      // Start new session
      await _startNewSession();
      
      // Reset metrics weekly to keep recent data relevant
      await _checkAndResetMetricsIfNeeded();
      
      // Start periodic metrics logging
      _startPeriodicMetricsLogging();
      
      LoggerFactory.info('✅ Error metrics service initialized');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize error metrics service: $e');
    }
  }

  /// Start a new session
  Future<void> _startNewSession() async {
    if (!_isInitialized || _prefs == null) return;

    _currentSessionStart = DateTime.now();
    _sessionHadCrash = false;
    
    try {
      await _prefs!.setString(_sessionStartTimeKey, _currentSessionStart!.toIso8601String());
      
      // Increment total session count
      final currentCount = _prefs!.getInt(_sessionCountKey) ?? 0;
      await _prefs!.setInt(_sessionCountKey, currentCount + 1);
      
      LoggerFactory.info('📊 New session started for metrics tracking');
    } catch (e) {
      LoggerFactory.error('Failed to start new session for metrics: $e');
    }
  }

  /// Record that current session had a crash
  Future<void> recordSessionCrash() async {
    if (!_isInitialized || _prefs == null || _sessionHadCrash) return;

    _sessionHadCrash = true;
    
    try {
      final currentCrashCount = _prefs!.getInt(_crashSessionCountKey) ?? 0;
      await _prefs!.setInt(_crashSessionCountKey, currentCrashCount + 1);
      
      LoggerFactory.warning('💥 Session crash recorded for metrics');
    } catch (e) {
      LoggerFactory.error('Failed to record session crash: $e');
    }
  }

  /// Record a core flow attempt
  Future<void> recordCoreFlowAttempt(String flowName) async {
    if (!_isInitialized || _prefs == null) return;
    if (!coreFlows.contains(flowName)) {
      LoggerFactory.warning('Unknown core flow attempted: $flowName');
      return;
    }

    try {
      final currentAttempts = _prefs!.getInt(_coreFlowAttemptCountKey) ?? 0;
      await _prefs!.setInt(_coreFlowAttemptCountKey, currentAttempts + 1);
      
      if (kDebugMode) {
        LoggerFactory.debug('📈 Core flow attempt recorded: $flowName');
      }
    } catch (e) {
      LoggerFactory.error('Failed to record core flow attempt: $e');
    }
  }

  /// Record a core flow error
  Future<void> recordCoreFlowError(String flowName, {String? errorDetails}) async {
    if (!_isInitialized || _prefs == null) return;
    if (!coreFlows.contains(flowName)) {
      LoggerFactory.warning('Unknown core flow error: $flowName');
      return;
    }

    try {
      final currentErrors = _prefs!.getInt(_coreFlowErrorCountKey) ?? 0;
      await _prefs!.setInt(_coreFlowErrorCountKey, currentErrors + 1);
      
      LoggerFactory.warning(
        '❌ Core flow error recorded: $flowName${errorDetails != null ? ' - $errorDetails' : ''}',
      );
    } catch (e) {
      LoggerFactory.error('Failed to record core flow error: $e');
    }
  }

  /// Get current crash-free session percentage
  double get crashFreeSessionPercentage {
    if (!_isInitialized || _prefs == null) return 0.0;

    final totalSessions = _prefs!.getInt(_sessionCountKey) ?? 0;
    final crashSessions = _prefs!.getInt(_crashSessionCountKey) ?? 0;

    if (totalSessions == 0) return 100.0;

    final crashFreePercentage = ((totalSessions - crashSessions) / totalSessions) * 100;
    return double.parse(crashFreePercentage.toStringAsFixed(2));
  }

  /// Get current core flow error rate percentage
  double get coreFlowErrorRate {
    if (!_isInitialized || _prefs == null) return 0.0;

    final totalAttempts = _prefs!.getInt(_coreFlowAttemptCountKey) ?? 0;
    final totalErrors = _prefs!.getInt(_coreFlowErrorCountKey) ?? 0;

    if (totalAttempts == 0) return 0.0;

    final errorRate = (totalErrors / totalAttempts) * 100;
    return double.parse(errorRate.toStringAsFixed(2));
  }

  /// Check if crash-free sessions meet success criteria (≥99.7%)
  bool get meetsCrashFreeSuccessCriteria {
    return crashFreeSessionPercentage >= 99.7;
  }

  /// Check if core flow error rate meets success criteria (<5%)
  bool get meetsCoreFlowSuccessCriteria {
    return coreFlowErrorRate < 5.0;
  }

  /// Get comprehensive metrics summary
  Map<String, dynamic> get metricsSnapshot {
    if (!_isInitialized || _prefs == null) {
      return {
        'initialized': false,
        'error': 'Metrics service not initialized',
      };
    }

    final totalSessions = _prefs!.getInt(_sessionCountKey) ?? 0;
    final crashSessions = _prefs!.getInt(_crashSessionCountKey) ?? 0;
    final totalAttempts = _prefs!.getInt(_coreFlowAttemptCountKey) ?? 0;
    final totalErrors = _prefs!.getInt(_coreFlowErrorCountKey) ?? 0;

    return {
      'initialized': true,
      'session_metrics': {
        'total_sessions': totalSessions,
        'crash_sessions': crashSessions,
        'crash_free_sessions': totalSessions - crashSessions,
        'crash_free_percentage': crashFreeSessionPercentage,
        'meets_crash_free_criteria': meetsCrashFreeSuccessCriteria,
        'crash_free_target': 99.7,
      },
      'core_flow_metrics': {
        'total_attempts': totalAttempts,
        'total_errors': totalErrors,
        'successful_attempts': totalAttempts - totalErrors,
        'error_rate_percentage': coreFlowErrorRate,
        'meets_error_rate_criteria': meetsCoreFlowSuccessCriteria,
        'error_rate_target': 5.0,
      },
      'current_session': {
        'session_start': _currentSessionStart?.toIso8601String(),
        'session_had_crash': _sessionHadCrash,
      },
      'last_reset': _prefs!.getString(_lastMetricsResetKey),
    };
  }

  /// Reset metrics (typically done weekly to keep data fresh)
  Future<void> resetMetrics() async {
    if (!_isInitialized || _prefs == null) return;

    try {
      await _prefs!.setInt(_sessionCountKey, 0);
      await _prefs!.setInt(_crashSessionCountKey, 0);
      await _prefs!.setInt(_coreFlowAttemptCountKey, 0);
      await _prefs!.setInt(_coreFlowErrorCountKey, 0);
      await _prefs!.setString(_lastMetricsResetKey, DateTime.now().toIso8601String());
      
      LoggerFactory.info('📊 Error metrics reset');
    } catch (e) {
      LoggerFactory.error('Failed to reset metrics: $e');
    }
  }

  /// Check if metrics need to be reset (weekly reset)
  Future<void> _checkAndResetMetricsIfNeeded() async {
    if (!_isInitialized || _prefs == null) return;

    final lastResetString = _prefs!.getString(_lastMetricsResetKey);
    if (lastResetString == null) {
      // First time - set reset time but don't reset
      await _prefs!.setString(_lastMetricsResetKey, DateTime.now().toIso8601String());
      return;
    }

    try {
      final lastReset = DateTime.parse(lastResetString);
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      if (lastReset.isBefore(weekAgo)) {
        LoggerFactory.info('📊 Weekly metrics reset due');
        await resetMetrics();
      }
    } catch (e) {
      LoggerFactory.error('Failed to check metrics reset: $e');
    }
  }

  /// Start periodic metrics logging
  void _startPeriodicMetricsLogging() {
    _metricsTimer?.cancel();
    
    // Log metrics every hour in debug mode, every 6 hours in release
    final duration = kDebugMode ? const Duration(hours: 1) : const Duration(hours: 6);
    
    _metricsTimer = Timer.periodic(duration, (timer) {
      _logCurrentMetrics();
    });
  }

  /// Log current metrics
  void _logCurrentMetrics() {
    final metrics = metricsSnapshot;
    final sessionMetrics = metrics['session_metrics'] as Map<String, dynamic>;
    final coreFlowMetrics = metrics['core_flow_metrics'] as Map<String, dynamic>;
    
    LoggerFactory.info(
      '📊 Error Metrics Report: '
      'Crash-free: ${sessionMetrics['crash_free_percentage']}% '
      '(${sessionMetrics['meets_crash_free_criteria'] ? '✅' : '❌'} target: ${sessionMetrics['crash_free_target']}%), '
      'Core flow error rate: ${coreFlowMetrics['error_rate_percentage']}% '
      '(${coreFlowMetrics['meets_error_rate_criteria'] ? '✅' : '❌'} target: <${coreFlowMetrics['error_rate_target']}%)',
    );
  }

  /// Dispose resources
  void dispose() {
    _metricsTimer?.cancel();
    _metricsTimer = null;
  }
}

/// Helper extension to easily track core flows
extension CoreFlowTracking on ErrorMetricsService {
  /// Track a core flow operation with automatic error handling
  Future<T> trackCoreFlow<T>(
    String flowName,
    Future<T> Function() operation,
  ) async {
    await recordCoreFlowAttempt(flowName);
    
    try {
      final result = await operation();
      return result;
    } catch (error, stackTrace) {
      await recordCoreFlowError(flowName, errorDetails: error.toString());
      
      // Also report to error reporting service
      LoggerFactory.reportCriticalError(
        error,
        stackTrace,
        context: 'Core flow: $flowName',
        data: {
          'core_flow': flowName,
          'flow_tracked': true,
        },
        fatal: false,
      );
      
      rethrow;
    }
  }
}