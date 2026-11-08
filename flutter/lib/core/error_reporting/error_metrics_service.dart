import 'dart:async';

import '../logging/logger_factory.dart';

/// Service for tracking error reporting metrics and performance indicators
class ErrorMetricsService {
  ErrorMetricsService._();
  static ErrorMetricsService? _instance;
  static ErrorMetricsService get instance =>
      _instance ??= ErrorMetricsService._();

  bool _isInitialized = false;
  int _totalSessions = 0;
  int _crashFreeSessions = 0;
  int _coreFlowErrors = 0;
  int _totalCoreFlowAttempts = 0;
  final List<DateTime> _sessionStartTimes = [];
  final List<DateTime> _crashTimes = [];
  final List<String> _errorTypes = [];

  /// Initialize the metrics service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      _startNewSession();
      LoggerFactory.info('✅ Error metrics service initialized');
    } catch (e) {
      LoggerFactory.error('Failed to initialize error metrics service: $e');
      rethrow;
    }
  }

  /// Start a new session
  void _startNewSession() {
    _totalSessions++;
    _sessionStartTimes.add(DateTime.now());

    // Assume session is crash-free until proven otherwise
    _crashFreeSessions++;
  }

  /// Record a session crash
  void recordSessionCrash() {
    if (!_isInitialized) return;

    _crashTimes.add(DateTime.now());
    // Reduce crash-free sessions count
    if (_crashFreeSessions > 0) {
      _crashFreeSessions--;
    }
  }

  /// Record a core flow error
  void recordCoreFlowError(String errorType) {
    if (!_isInitialized) return;

    _coreFlowErrors++;
    _errorTypes.add(errorType);
  }

  /// Record a core flow attempt
  void recordCoreFlowAttempt() {
    if (!_isInitialized) return;

    _totalCoreFlowAttempts++;
  }

  /// Get crash-free session rate (percentage)
  double get crashFreeSessionRate {
    if (_totalSessions == 0) return 100.0;
    return (_crashFreeSessions / _totalSessions) * 100.0;
  }

  /// Get core flow error rate (percentage)
  double get coreFlowErrorRate {
    if (_totalCoreFlowAttempts == 0) return 0.0;
    return (_coreFlowErrors / _totalCoreFlowAttempts) * 100.0;
  }

  /// Check if crash-free sessions meet success criteria (≥99.7%)
  bool get meetsCrashFreeSuccessCriteria {
    return crashFreeSessionRate >= 99.7;
  }

  /// Check if core flow error rate meets success criteria (<5%)
  bool get meetsCoreFlowSuccessCriteria {
    return coreFlowErrorRate < 5.0;
  }

  /// Get current metrics snapshot
  Map<String, dynamic> get metricsSnapshot {
    return {
      'initialized': _isInitialized,
      'total_sessions': _totalSessions,
      'crash_free_sessions': _crashFreeSessions,
      'crash_free_rate': crashFreeSessionRate,
      'core_flow_errors': _coreFlowErrors,
      'total_core_flow_attempts': _totalCoreFlowAttempts,
      'core_flow_error_rate': coreFlowErrorRate,
      'meets_crash_free_criteria': meetsCrashFreeSuccessCriteria,
      'meets_core_flow_criteria': meetsCoreFlowSuccessCriteria,
      'recent_crashes': _crashTimes.length,
      'error_types': _getErrorTypeDistribution(),
    };
  }

  /// Get error type distribution
  Map<String, int> _getErrorTypeDistribution() {
    final distribution = <String, int>{};
    for (final errorType in _errorTypes) {
      distribution[errorType] = (distribution[errorType] ?? 0) + 1;
    }
    return distribution;
  }

  /// Reset all metrics (useful for testing)
  void reset() {
    _totalSessions = 0;
    _crashFreeSessions = 0;
    _coreFlowErrors = 0;
    _totalCoreFlowAttempts = 0;
    _sessionStartTimes.clear();
    _crashTimes.clear();
    _errorTypes.clear();
  }

  /// Get detailed analytics for the last N days
  Map<String, dynamic> getAnalytics({int days = 7}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    final recentCrashes =
        _crashTimes.where((time) => time.isAfter(cutoffDate)).length;

    final recentSessions =
        _sessionStartTimes.where((time) => time.isAfter(cutoffDate)).length;

    return {
      'period_days': days,
      'recent_sessions': recentSessions,
      'recent_crashes': recentCrashes,
      'recent_crash_rate':
          recentSessions > 0 ? (recentCrashes / recentSessions) * 100.0 : 0.0,
      'stability_trend': _calculateStabilityTrend(),
    };
  }

  /// Calculate stability trend (simplified)
  String _calculateStabilityTrend() {
    if (_crashTimes.length < 2) return 'stable';

    final recentCrashes = _crashTimes
        .where((time) =>
            time.isAfter(DateTime.now().subtract(const Duration(days: 1))))
        .length;

    final olderCrashes = _crashTimes
        .where((time) =>
            time.isBefore(DateTime.now().subtract(const Duration(days: 1))) &&
            time.isAfter(DateTime.now().subtract(const Duration(days: 2))))
        .length;

    if (recentCrashes > olderCrashes) return 'declining';
    if (recentCrashes < olderCrashes) return 'improving';
    return 'stable';
  }
}
