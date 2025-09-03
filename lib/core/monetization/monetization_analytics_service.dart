import 'dart:async';

import '../analytics/analytics_service.dart';
import '../logging/base_logger.dart';
import '../logging/logger_factory.dart';
import 'ad_frequency_controller.dart';

/// Extensión del servicio de analytics específica para monetización
class MonetizationAnalyticsService {
  MonetizationAnalyticsService._();

  static final MonetizationAnalyticsService _instance =
      MonetizationAnalyticsService._();
  static MonetizationAnalyticsService get instance => _instance;

  final BaseLogger _logger = LoggerFactory.getLogger('MonetizationAnalytics');
  final AnalyticsService _analytics = AnalyticsService.instance;
  final AdFrequencyController _frequencyController =
      AdFrequencyController.instance;

  /// Registrar impresión de anuncio con detalles de monetización
  Future<void> trackAdImpression({
    required String adType,
    required String adUnitId,
    String? adId,
    String? placement,
    Map<String, dynamic>? customParameters,
  }) async {
    try {
      await _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'event': 'ad_impression',
        'adType': adType,
        'adUnitId': adUnitId,
        'adId': adId,
        'placement': placement,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionStats': _frequencyController.getSessionStats(),
        ...?customParameters,
      });

      await _frequencyController.recordAdShown(
        adType: adType,
        adId: adId,
        metadata: {
          'adUnitId': adUnitId,
          'placement': placement,
          ...?customParameters,
        },
      );

      _logger.info('Ad impression tracked: $adType at $placement');
    } catch (e) {
      _logger.error('Error tracking ad impression: $e');
    }
  }

  /// Registrar click en anuncio
  Future<void> trackAdClick({
    required String adType,
    required String adUnitId,
    String? adId,
    String? placement,
    double? estimatedRevenue,
    Map<String, dynamic>? customParameters,
  }) async {
    try {
      await _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'event': 'ad_click',
        'adType': adType,
        'adUnitId': adUnitId,
        'adId': adId,
        'placement': placement,
        'estimatedRevenue': estimatedRevenue,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionStats': _frequencyController.getSessionStats(),
        ...?customParameters,
      });

      await _frequencyController.recordAdClick(
        adType: adType,
        adId: adId,
        estimatedRevenue: estimatedRevenue,
      );

      _logger.info(
          'Ad click tracked: $adType (revenue: \$${estimatedRevenue ?? 0})');
    } catch (e) {
      _logger.error('Error tracking ad click: $e');
    }
  }

  /// Registrar error al cargar anuncio
  Future<void> trackAdLoadError({
    required String adType,
    required String adUnitId,
    required String errorCode,
    required String errorMessage,
    String? placement,
  }) async {
    try {
      await _analytics.trackEvent(AnalyticsEventType.error, {
        'event': 'ad_load_error',
        'adType': adType,
        'adUnitId': adUnitId,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'placement': placement,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionStats': _frequencyController.getSessionStats(),
      });

      _logger.warning('Ad load error: $adType - $errorMessage');
    } catch (e) {
      _logger.error('Error tracking ad load error: $e');
    }
  }

  /// Registrar anuncio bloqueado por frecuencia
  Future<void> trackAdBlocked({
    required String adType,
    required AdDecisionResult reason,
    String? placement,
  }) async {
    try {
      await _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'event': 'ad_blocked',
        'adType': adType,
        'blockReason': reason.name,
        'placement': placement,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionStats': _frequencyController.getSessionStats(),
      });

      _logger.info('Ad blocked: $adType - ${reason.name}');
    } catch (e) {
      _logger.error('Error tracking ad blocked: $e');
    }
  }

  /// Registrar tiempo de carga de anuncio
  Future<void> trackAdLoadTime({
    required String adType,
    required String adUnitId,
    required Duration loadTime,
    bool successful = true,
    String? placement,
  }) async {
    try {
      await _analytics.trackEvent(AnalyticsEventType.performance, {
        'event': 'ad_load_performance',
        'adType': adType,
        'adUnitId': adUnitId,
        'loadTimeMs': loadTime.inMilliseconds,
        'successful': successful,
        'placement': placement,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _logger.info('Ad load time: $adType - ${loadTime.inMilliseconds}ms');
    } catch (e) {
      _logger.error('Error tracking ad load time: $e');
    }
  }

  /// Registrar impacto en experiencia de usuario
  Future<void> trackUserExperienceImpact({
    required String adType,
    required String action, // 'view', 'skip', 'close', 'interact'
    Duration? timeToAction,
    String? placement,
    Map<String, dynamic>? customData,
  }) async {
    try {
      await _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'event': 'ad_ux_impact',
        'adType': adType,
        'action': action,
        'timeToActionMs': timeToAction?.inMilliseconds,
        'placement': placement,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionStats': _frequencyController.getSessionStats(),
        ...?customData,
      });

      _logger.info('UX impact tracked: $adType - $action');
    } catch (e) {
      _logger.error('Error tracking UX impact: $e');
    }
  }

  /// Obtener métricas detalladas de monetización
  Future<DetailedMonetizationMetrics> getDetailedMetrics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final allEvents = _analytics.getEvents();
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();

      final relevantEvents = allEvents
          .where((e) =>
              e.timestamp.isAfter(start) &&
              e.timestamp.isBefore(end) &&
              _isMonetizationEvent(e))
          .toList();

      return _calculateDetailedMetrics(relevantEvents);
    } catch (e) {
      _logger.error('Error getting detailed metrics: $e');
      return const DetailedMonetizationMetrics.empty();
    }
  }

  bool _isMonetizationEvent(AnalyticsEvent event) {
    final eventType = event.properties['event'] as String?;
    return eventType != null &&
        [
          'ad_impression',
          'ad_click',
          'ad_load_error',
          'ad_blocked',
          'ad_load_performance',
          'ad_ux_impact',
        ].contains(eventType);
  }

  DetailedMonetizationMetrics _calculateDetailedMetrics(
      List<AnalyticsEvent> events) {
    final impressions =
        events.where((e) => e.properties['event'] == 'ad_impression').toList();
    final clicks =
        events.where((e) => e.properties['event'] == 'ad_click').toList();
    final errors =
        events.where((e) => e.properties['event'] == 'ad_load_error').toList();
    final blocked =
        events.where((e) => e.properties['event'] == 'ad_blocked').toList();
    final performance = events
        .where((e) => e.properties['event'] == 'ad_load_performance')
        .toList();
    final uxEvents =
        events.where((e) => e.properties['event'] == 'ad_ux_impact').toList();

    // Calcular CTR
    final ctr =
        impressions.isNotEmpty ? clicks.length / impressions.length : 0.0;

    // Calcular revenue estimado
    final revenue = clicks.fold<double>(0.0, (sum, e) {
      final rev = e.properties['estimatedRevenue'] as double?;
      return sum + (rev ?? 0.0);
    });

    // Calcular métricas de rendimiento
    final avgLoadTime = performance.isNotEmpty
        ? performance.fold<int>(0,
                (sum, e) => sum + (e.properties['loadTimeMs'] as int? ?? 0)) /
            performance.length
        : 0.0;

    // Calcular distribución por tipo de anuncio
    final impressionsByType = <String, int>{};
    final clicksByType = <String, int>{};
    final revenueByType = <String, double>{};

    for (final impression in impressions) {
      final adType = impression.properties['adType'] as String? ?? 'unknown';
      impressionsByType[adType] = (impressionsByType[adType] ?? 0) + 1;
    }

    for (final click in clicks) {
      final adType = click.properties['adType'] as String? ?? 'unknown';
      clicksByType[adType] = (clicksByType[adType] ?? 0) + 1;

      final rev = click.properties['estimatedRevenue'] as double? ?? 0.0;
      revenueByType[adType] = (revenueByType[adType] ?? 0.0) + rev;
    }

    // Calcular tasa de error
    final totalAttempts = impressions.length + errors.length;
    final errorRate = totalAttempts > 0 ? errors.length / totalAttempts : 0.0;

    // Calcular métricas UX
    final uxMetrics = _calculateUXMetrics(uxEvents);

    return DetailedMonetizationMetrics(
      totalImpressions: impressions.length,
      totalClicks: clicks.length,
      ctr: ctr,
      estimatedRevenue: revenue,
      averageLoadTimeMs: avgLoadTime,
      errorRate: errorRate,
      blockedAdsCount: blocked.length,
      impressionsByType: impressionsByType,
      clicksByType: clicksByType,
      revenueByType: revenueByType,
      userExperienceScore: uxMetrics['score'] ?? 0.0,
      averageSessionDuration: uxMetrics['avgSessionDuration'] ?? Duration.zero,
    );
  }

  Map<String, dynamic> _calculateUXMetrics(List<AnalyticsEvent> uxEvents) {
    if (uxEvents.isEmpty) {
      return {
        'score': 0.8,
        'avgSessionDuration': Duration.zero
      }; // Default values
    }

    // Calcular score basado en acciones del usuario
    var score = 1.0;
    var totalTimeToAction = 0;
    var actionCount = 0;

    for (final event in uxEvents) {
      final action = event.properties['action'] as String?;
      final timeToAction = event.properties['timeToActionMs'] as int?;

      if (timeToAction != null) {
        totalTimeToAction += timeToAction;
        actionCount++;
      }

      // Penalizar acciones negativas
      switch (action) {
        case 'skip':
          score -= 0.1;
          break;
        case 'close':
          score -= 0.15;
          break;
        case 'interact':
          score += 0.05;
          break;
      }
    }

    final avgTimeToAction =
        actionCount > 0 ? totalTimeToAction / actionCount : 0.0;
    final avgSessionDuration = Duration(milliseconds: avgTimeToAction.round());

    return {
      'score':
          (score * 0.8).clamp(0.0, 1.0), // Normalizar entre 0-1, máximo 0.8
      'avgSessionDuration': avgSessionDuration,
    };
  }
}

/// Métricas detalladas de monetización
class DetailedMonetizationMetrics {
  const DetailedMonetizationMetrics({
    required this.totalImpressions,
    required this.totalClicks,
    required this.ctr,
    required this.estimatedRevenue,
    required this.averageLoadTimeMs,
    required this.errorRate,
    required this.blockedAdsCount,
    required this.impressionsByType,
    required this.clicksByType,
    required this.revenueByType,
    required this.userExperienceScore,
    required this.averageSessionDuration,
  });

  const DetailedMonetizationMetrics.empty()
      : totalImpressions = 0,
        totalClicks = 0,
        ctr = 0.0,
        estimatedRevenue = 0.0,
        averageLoadTimeMs = 0.0,
        errorRate = 0.0,
        blockedAdsCount = 0,
        impressionsByType = const {},
        clicksByType = const {},
        revenueByType = const {},
        userExperienceScore = 0.0,
        averageSessionDuration = Duration.zero;

  final int totalImpressions;
  final int totalClicks;
  final double ctr;
  final double estimatedRevenue;
  final double averageLoadTimeMs;
  final double errorRate;
  final int blockedAdsCount;
  final Map<String, int> impressionsByType;
  final Map<String, int> clicksByType;
  final Map<String, double> revenueByType;
  final double userExperienceScore;
  final Duration averageSessionDuration;

  /// Verificar si la experiencia de usuario es saludable
  bool get isUserExperienceHealthy => userExperienceScore >= 0.7;

  /// Verificar si el CTR es saludable
  bool get isCTRHealthy => ctr >= 0.01; // 1% es un CTR razonable

  /// Verificar si la tasa de error es aceptable
  bool get isErrorRateHealthy => errorRate <= 0.1; // Máximo 10% de errores

  Map<String, dynamic> toJson() => {
        'totalImpressions': totalImpressions,
        'totalClicks': totalClicks,
        'ctr': ctr,
        'estimatedRevenue': estimatedRevenue,
        'averageLoadTimeMs': averageLoadTimeMs,
        'errorRate': errorRate,
        'blockedAdsCount': blockedAdsCount,
        'impressionsByType': impressionsByType,
        'clicksByType': clicksByType,
        'revenueByType': revenueByType,
        'userExperienceScore': userExperienceScore,
        'averageSessionDurationMinutes': averageSessionDuration.inMinutes,
        'isUserExperienceHealthy': isUserExperienceHealthy,
        'isCTRHealthy': isCTRHealthy,
        'isErrorRateHealthy': isErrorRateHealthy,
      };
}
