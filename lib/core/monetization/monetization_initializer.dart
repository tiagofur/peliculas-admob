import 'package:flutter/foundation.dart';

import '../logging/base_logger.dart';
import '../logging/logger_factory.dart';
import 'ad_frequency_controller.dart';
import 'monetization_analytics_service.dart';

/// Servicio de inicialización para el sistema de monetización
class MonetizationInitializer {
  MonetizationInitializer._();

  static final MonetizationInitializer _instance = MonetizationInitializer._();
  static MonetizationInitializer get instance => _instance;

  final BaseLogger _logger = LoggerFactory.getLogger('MonetizationInitializer');

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Inicializar el sistema de monetización completo
  Future<void> initialize({
    AdFrequencyConfig? config,
    bool enableDebugMode = kDebugMode,
  }) async {
    if (_isInitialized) {
      _logger.warning('Monetization system already initialized');
      return;
    }

    try {
      _logger.info('Initializing monetization system...');

      // Configuración específica para debug/producción
      final finalConfig = config ?? _getDefaultConfig(enableDebugMode);

      // Inicializar controlador de frecuencia
      await AdFrequencyController.instance.initialize(config: finalConfig);

      _logger.info('AdFrequencyController initialized');

      // El servicio de analytics ya se auto-inicializa cuando se usa
      // Solo validamos que esté disponible
      final analytics = MonetizationAnalyticsService.instance;
      _logger.info('MonetizationAnalyticsService ready');

      _isInitialized = true;
      _logger.info('Monetization system initialized successfully');

      // Registrar métricas de inicialización
      await analytics.trackUserExperienceImpact(
        adType: 'system',
        action: 'initialized',
        customData: {
          'config': finalConfig.toJson(),
          'debugMode': enableDebugMode,
        },
      );
    } catch (e) {
      _logger.error('Error initializing monetization system: $e');
      rethrow;
    }
  }

  /// Obtener configuración por defecto basada en el modo
  AdFrequencyConfig _getDefaultConfig(bool isDebugMode) {
    if (isDebugMode) {
      // Configuración más permisiva para desarrollo
      return const AdFrequencyConfig(
        maxAdsPerSession: 15,
        maxAdsPerHour: 20,
        maxAdsPerDay: 100,
        minTimeBetweenAds: Duration(seconds: 30),
        cooldownAfterUserInteraction: Duration(minutes: 1),
        respectUserPreferences: true,
      );
    } else {
      // Configuración optimizada para producción
      return const AdFrequencyConfig(
        maxAdsPerSession: 8,
        maxAdsPerHour: 12,
        maxAdsPerDay: 50,
        minTimeBetweenAds: Duration(minutes: 2),
        cooldownAfterUserInteraction: Duration(minutes: 5),
        respectUserPreferences: true,
      );
    }
  }

  /// Configuraciones predefinidas para diferentes estrategias
  static const AdFrequencyConfig conservativeConfig = AdFrequencyConfig(
    maxAdsPerSession: 5,
    maxAdsPerHour: 8,
    maxAdsPerDay: 30,
    minTimeBetweenAds: Duration(minutes: 3),
    cooldownAfterUserInteraction: Duration(minutes: 8),
    respectUserPreferences: true,
  );

  static const AdFrequencyConfig balancedConfig = AdFrequencyConfig(
    maxAdsPerSession: 8,
    maxAdsPerHour: 12,
    maxAdsPerDay: 50,
    minTimeBetweenAds: Duration(minutes: 2),
    cooldownAfterUserInteraction: Duration(minutes: 5),
    respectUserPreferences: true,
  );

  static const AdFrequencyConfig aggressiveConfig = AdFrequencyConfig(
    maxAdsPerSession: 12,
    maxAdsPerHour: 18,
    maxAdsPerDay: 80,
    minTimeBetweenAds: Duration(minutes: 1),
    cooldownAfterUserInteraction: Duration(minutes: 3),
    respectUserPreferences: true,
  );

  /// Obtener estado del sistema
  Map<String, dynamic> getSystemStatus() {
    return {
      'initialized': _isInitialized,
      'frequencyController': {
        'config': AdFrequencyController.instance.config.toJson(),
        'sessionStats': AdFrequencyController.instance.getSessionStats(),
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Reiniciar el sistema de monetización
  Future<void> reset() async {
    try {
      _logger.info('Resetting monetization system...');

      // Reinicializar el controlador de frecuencia
      await AdFrequencyController.instance.initialize();

      _logger.info('Monetization system reset completed');
    } catch (e) {
      _logger.error('Error resetting monetization system: $e');
      rethrow;
    }
  }

  /// Actualizar configuración del sistema
  Future<void> updateConfig(AdFrequencyConfig newConfig) async {
    try {
      if (!_isInitialized) {
        throw StateError('Monetization system not initialized');
      }

      await AdFrequencyController.instance.updateConfig(newConfig);

      _logger.info('Monetization config updated: ${newConfig.toJson()}');

      // Registrar cambio de configuración
      await MonetizationAnalyticsService.instance.trackUserExperienceImpact(
        adType: 'system',
        action: 'config_updated',
        customData: {
          'newConfig': newConfig.toJson(),
        },
      );
    } catch (e) {
      _logger.error('Error updating monetization config: $e');
      rethrow;
    }
  }

  /// Obtener métricas completas del sistema
  Future<SystemMonetizationReport> getSystemReport() async {
    try {
      if (!_isInitialized) {
        throw StateError('Monetization system not initialized');
      }

      final frequencyMetrics =
          await AdFrequencyController.instance.getMonetizationMetrics();
      final detailedMetrics =
          await MonetizationAnalyticsService.instance.getDetailedMetrics();
      final sessionStats = AdFrequencyController.instance.getSessionStats();

      return SystemMonetizationReport(
        frequencyMetrics: frequencyMetrics,
        detailedMetrics: detailedMetrics,
        sessionStats: sessionStats,
        config: AdFrequencyController.instance.config,
        systemStatus: getSystemStatus(),
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      _logger.error('Error generating system report: $e');
      rethrow;
    }
  }

  /// Verificar salud del sistema
  Future<MonetizationHealthCheck> performHealthCheck() async {
    try {
      final report = await getSystemReport();

      final issues = <String>[];
      var overallHealth = 1.0;

      // Verificar métricas de UX
      if (!report.detailedMetrics.isUserExperienceHealthy) {
        issues.add(
            'User experience score below threshold (${report.detailedMetrics.userExperienceScore})');
        overallHealth -= 0.3;
      }

      // Verificar CTR
      if (!report.detailedMetrics.isCTRHealthy) {
        issues.add(
            'Click-through rate below threshold (${report.detailedMetrics.ctr})');
        overallHealth -= 0.2;
      }

      // Verificar tasa de error
      if (!report.detailedMetrics.isErrorRateHealthy) {
        issues.add(
            'Error rate above threshold (${report.detailedMetrics.errorRate})');
        overallHealth -= 0.3;
      }

      // Verificar frecuencia de bloqueos
      final sessionStats = report.sessionStats;
      final sessionAdCount = sessionStats['sessionAdCount'] as int? ?? 0;
      final config = report.config;

      if (sessionAdCount >= config.maxAdsPerSession * 0.8) {
        issues.add(
            'Session approaching ad limit ($sessionAdCount/${config.maxAdsPerSession})');
        overallHealth -= 0.1;
      }

      final healthStatus = overallHealth >= 0.8
          ? MonetizationHealthStatus.healthy
          : overallHealth >= 0.6
              ? MonetizationHealthStatus.warning
              : MonetizationHealthStatus.critical;

      return MonetizationHealthCheck(
        status: healthStatus,
        overallScore: overallHealth.clamp(0.0, 1.0),
        issues: issues,
        report: report,
        checkedAt: DateTime.now(),
      );
    } catch (e) {
      _logger.error('Error performing health check: $e');
      return MonetizationHealthCheck(
        status: MonetizationHealthStatus.error,
        overallScore: 0.0,
        issues: ['Health check failed: $e'],
        report: null,
        checkedAt: DateTime.now(),
      );
    }
  }
}

/// Reporte completo del sistema de monetización
class SystemMonetizationReport {
  const SystemMonetizationReport({
    required this.frequencyMetrics,
    required this.detailedMetrics,
    required this.sessionStats,
    required this.config,
    required this.systemStatus,
    required this.generatedAt,
  });

  final AdMonetizationMetrics frequencyMetrics;
  final DetailedMonetizationMetrics detailedMetrics;
  final Map<String, dynamic> sessionStats;
  final AdFrequencyConfig config;
  final Map<String, dynamic> systemStatus;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => {
        'frequencyMetrics': frequencyMetrics.toJson(),
        'detailedMetrics': detailedMetrics.toJson(),
        'sessionStats': sessionStats,
        'config': config.toJson(),
        'systemStatus': systemStatus,
        'generatedAt': generatedAt.toIso8601String(),
      };
}

/// Estados de salud del sistema
enum MonetizationHealthStatus {
  healthy,
  warning,
  critical,
  error,
}

/// Resultado de verificación de salud
class MonetizationHealthCheck {
  const MonetizationHealthCheck({
    required this.status,
    required this.overallScore,
    required this.issues,
    required this.report,
    required this.checkedAt,
  });

  final MonetizationHealthStatus status;
  final double overallScore;
  final List<String> issues;
  final SystemMonetizationReport? report;
  final DateTime checkedAt;

  bool get isHealthy => status == MonetizationHealthStatus.healthy;
  bool get hasIssues => issues.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'overallScore': overallScore,
        'issues': issues,
        'hasIssues': hasIssues,
        'isHealthy': isHealthy,
        'report': report?.toJson(),
        'checkedAt': checkedAt.toIso8601String(),
      };
}
