import '../analytics/analytics_service.dart';
import '../logging/base_logger.dart';
import '../logging/logger_factory.dart';

/// Analytics service for tracking user events and behavior
class AnalyticsService {
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();
  static final AnalyticsService _instance = AnalyticsService._internal();

  /// Track an event with optional parameters
  void trackEvent(String eventName, [Map<String, dynamic>? parameters]) {
    // In a real implementation, this would send data to analytics providers
    // like Firebase Analytics, Google Analytics, etc.
    LoggerFactory.info('Analytics Event: $eventName',
        category: LogCategory.analytics);
    if (parameters != null && parameters.isNotEmpty) {
      LoggerFactory.debug('Parameters: $parameters',
          category: LogCategory.analytics);
    }
  }

  /// Track user property
  void setUserProperty(String name, String value) {
    LoggerFactory.info('User Property: $name = $value',
        category: LogCategory.analytics);
  }

  /// Track screen view
  void trackScreenView(String screenName) {
    LoggerFactory.info('Screen View: $screenName',
        category: LogCategory.analytics);
  }

  /// Track challenge completion
  void trackChallengeCompleted(
      String challengeId, String challengeType, int points) {
    trackEvent(AnalyticsEventType.userEngagement.name, {
      'challenge_id': challengeId,
      'challenge_type': challengeType,
      'points_earned': points,
    });
  }

  /// Track challenge progress
  void trackChallengeProgress(
      String challengeId, String challengeType, double progress) {
    trackEvent(AnalyticsEventType.userEngagement.name, {
      'challenge_id': challengeId,
      'challenge_type': challengeType,
      'progress': progress,
    });
  }
}
