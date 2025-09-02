import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/analytics_service.dart';
import '../logging/base_logger.dart';
import '../logging/logger_factory.dart';

/// Configuración de frecuencia de anuncios
class AdFrequencyConfig {
  const AdFrequencyConfig({
    this.maxAdsPerSession = 8,
    this.maxAdsPerHour = 12,
    this.maxAdsPerDay = 50,
    this.minTimeBetweenAds = const Duration(minutes: 2),
    this.cooldownAfterUserInteraction = const Duration(minutes: 5),
    this.respectUserPreferences = true,
  });

  final int maxAdsPerSession;
  final int maxAdsPerHour;
  final int maxAdsPerDay;
  final Duration minTimeBetweenAds;
  final Duration cooldownAfterUserInteraction;
  final bool respectUserPreferences;

  Map<String, dynamic> toJson() => {
        'maxAdsPerSession': maxAdsPerSession,
        'maxAdsPerHour': maxAdsPerHour,
        'maxAdsPerDay': maxAdsPerDay,
        'minTimeBetweenAdsMinutes': minTimeBetweenAds.inMinutes,
        'cooldownAfterUserInteractionMinutes': cooldownAfterUserInteraction.inMinutes,
        'respectUserPreferences': respectUserPreferences,
      };

  factory AdFrequencyConfig.fromJson(Map<String, dynamic> json) => AdFrequencyConfig(
        maxAdsPerSession: json['maxAdsPerSession'] ?? 8,
        maxAdsPerHour: json['maxAdsPerHour'] ?? 12,
        maxAdsPerDay: json['maxAdsPerDay'] ?? 50,
        minTimeBetweenAds: Duration(minutes: json['minTimeBetweenAdsMinutes'] ?? 2),
        cooldownAfterUserInteraction: Duration(minutes: json['cooldownAfterUserInteractionMinutes'] ?? 5),
        respectUserPreferences: json['respectUserPreferences'] ?? true,
      );
}

/// Métricas de monetización de anuncios
class AdMonetizationMetrics {
  const AdMonetizationMetrics({
    required this.totalImpressions,
    required this.totalClicks,
    required this.ctr,
    required this.estimatedRevenue,
    required this.averageSessionLength,
    required this.userRetentionRate,
    required this.adBlockedCount,
    required this.adSkippedCount,
  });

  final int totalImpressions;
  final int totalClicks;
  final double ctr; // Click-through rate
  final double estimatedRevenue;
  final Duration averageSessionLength;
  final double userRetentionRate;
  final int adBlockedCount;
  final int adSkippedCount;

  Map<String, dynamic> toJson() => {
        'totalImpressions': totalImpressions,
        'totalClicks': totalClicks,
        'ctr': ctr,
        'estimatedRevenue': estimatedRevenue,
        'averageSessionLengthMinutes': averageSessionLength.inMinutes,
        'userRetentionRate': userRetentionRate,
        'adBlockedCount': adBlockedCount,
        'adSkippedCount': adSkippedCount,
      };
}

/// Estados de decisión para mostrar anuncios
enum AdDecisionResult {
  allowed,
  blockedBySessionLimit,
  blockedByHourlyLimit,
  blockedByDailyLimit,
  blockedByTimeCooldown,
  blockedByUserInteraction,
  blockedByUserPreference,
}

/// Controlador de frecuencia de anuncios con métricas de monetización
class AdFrequencyController {
  AdFrequencyController._();
  
  static final AdFrequencyController _instance = AdFrequencyController._();
  static AdFrequencyController get instance => _instance;

  final BaseLogger _logger = LoggerFactory.getLogger('AdFrequencyController');
  final AnalyticsService _analytics = AnalyticsService.instance;
  
  SharedPreferences? _prefs;
  AdFrequencyConfig _config = const AdFrequencyConfig();
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  DateTime? _lastAdShownTime;
  DateTime? _lastUserInteractionTime;
  
  // Contadores de sesión
  int _sessionAdCount = 0;
  int _sessionClickCount = 0;
  
  // Cache para métricas
  List<DateTime> _todayImpressions = [];
  List<DateTime> _hourlyImpressions = [];

  /// Inicializar el controlador
  Future<void> initialize({AdFrequencyConfig? config}) async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (config != null) {
        _config = config;
        await _saveConfig();
      } else {
        await _loadConfig();
      }
      
      _startNewSession();
      await _loadTodayData();
      
      _logger.info('AdFrequencyController initialized with config: ${_config.toJson()}');
    } catch (e) {
      _logger.error('Error initializing AdFrequencyController: $e');
      rethrow;
    }
  }

  /// Iniciar nueva sesión
  void _startNewSession() {
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionStartTime = DateTime.now();
    _sessionAdCount = 0;
    _sessionClickCount = 0;
    
    _analytics.trackEvent(AnalyticsEventType.sessionStart, {
      'sessionId': _currentSessionId,
      'timestamp': _sessionStartTime!.toIso8601String(),
    });
  }

  /// Verificar si se puede mostrar un anuncio
  Future<AdDecisionResult> canShowAd({String? adType}) async {
    try {
      final now = DateTime.now();
      
      // Verificar límite de sesión
      if (_sessionAdCount >= _config.maxAdsPerSession) {
        _logDecision(AdDecisionResult.blockedBySessionLimit, adType);
        return AdDecisionResult.blockedBySessionLimit;
      }
      
      // Verificar límite horario
      _cleanupOldImpressions();
      if (_hourlyImpressions.length >= _config.maxAdsPerHour) {
        _logDecision(AdDecisionResult.blockedByHourlyLimit, adType);
        return AdDecisionResult.blockedByHourlyLimit;
      }
      
      // Verificar límite diario
      if (_todayImpressions.length >= _config.maxAdsPerDay) {
        _logDecision(AdDecisionResult.blockedByDailyLimit, adType);
        return AdDecisionResult.blockedByDailyLimit;
      }
      
      // Verificar tiempo mínimo entre anuncios
      if (_lastAdShownTime != null) {
        final timeSinceLastAd = now.difference(_lastAdShownTime!);
        if (timeSinceLastAd < _config.minTimeBetweenAds) {
          _logDecision(AdDecisionResult.blockedByTimeCooldown, adType);
          return AdDecisionResult.blockedByTimeCooldown;
        }
      }
      
      // Verificar cooldown después de interacción del usuario
      if (_lastUserInteractionTime != null) {
        final timeSinceInteraction = now.difference(_lastUserInteractionTime!);
        if (timeSinceInteraction < _config.cooldownAfterUserInteraction) {
          _logDecision(AdDecisionResult.blockedByUserInteraction, adType);
          return AdDecisionResult.blockedByUserInteraction;
        }
      }
      
      _logDecision(AdDecisionResult.allowed, adType);
      return AdDecisionResult.allowed;
      
    } catch (e) {
      _logger.error('Error checking ad permission: $e');
      return AdDecisionResult.blockedBySessionLimit; // Fail safe
    }
  }

  /// Registrar que se mostró un anuncio
  Future<void> recordAdShown({
    required String adType,
    String? adId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final now = DateTime.now();
      
      _sessionAdCount++;
      _lastAdShownTime = now;
      _todayImpressions.add(now);
      _hourlyImpressions.add(now);
      
      // Persistir datos
      await _saveTodayData();
      
      // Enviar evento de analytics
      await _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'event': 'ad_impression',
        'adType': adType,
        'adId': adId,
        'sessionId': _currentSessionId,
        'sessionAdCount': _sessionAdCount,
        'timestamp': now.toIso8601String(),
        ...?metadata,
      });
      
      _logger.info('Ad shown: $adType (session: $_sessionAdCount/${_config.maxAdsPerSession})');
    } catch (e) {
      _logger.error('Error recording ad shown: $e');
    }
  }

  /// Registrar click en anuncio
  Future<void> recordAdClick({
    required String adType,
    String? adId,
    double? estimatedRevenue,
  }) async {
    try {
      _sessionClickCount++;
      
      await _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'event': 'ad_click',
        'adType': adType,
        'adId': adId,
        'sessionId': _currentSessionId,
        'estimatedRevenue': estimatedRevenue,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _logger.info('Ad clicked: $adType (session clicks: $_sessionClickCount)');
    } catch (e) {
      _logger.error('Error recording ad click: $e');
    }
  }

  /// Registrar interacción del usuario (pausa temporalmente anuncios)
  void recordUserInteraction() {
    _lastUserInteractionTime = DateTime.now();
  }

  /// Obtener métricas de monetización
  Future<AdMonetizationMetrics> getMonetizationMetrics() async {
    try {
      final allEvents = await _analytics.getEvents();
      final adEvents = allEvents.where((e) => 
        e.properties['event'] == 'ad_impression' || 
        e.properties['event'] == 'ad_click'
      ).toList();
      
      final impressions = adEvents.where((e) => e.properties['event'] == 'ad_impression').length;
      final clicks = adEvents.where((e) => e.properties['event'] == 'ad_click').length;
      final ctr = impressions > 0 ? clicks / impressions : 0.0;
      
      final revenue = adEvents
          .where((e) => e.properties['estimatedRevenue'] != null)
          .fold<double>(0.0, (sum, e) => sum + (e.properties['estimatedRevenue'] as double? ?? 0.0));
      
      final sessionLength = _sessionStartTime != null 
          ? DateTime.now().difference(_sessionStartTime!)
          : Duration.zero;
      
      return AdMonetizationMetrics(
        totalImpressions: impressions,
        totalClicks: clicks,
        ctr: ctr,
        estimatedRevenue: revenue,
        averageSessionLength: sessionLength,
        userRetentionRate: _calculateRetentionRate(),
        adBlockedCount: 0, // TODO: Implementar
        adSkippedCount: 0, // TODO: Implementar
      );
    } catch (e) {
      _logger.error('Error getting monetization metrics: $e');
      return const AdMonetizationMetrics(
        totalImpressions: 0,
        totalClicks: 0,
        ctr: 0.0,
        estimatedRevenue: 0.0,
        averageSessionLength: Duration.zero,
        userRetentionRate: 0.0,
        adBlockedCount: 0,
        adSkippedCount: 0,
      );
    }
  }

  /// Limpiar datos antiguos de las listas de impresiones
  void _cleanupOldImpressions() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final oneDayAgo = now.subtract(const Duration(days: 1));
    
    _hourlyImpressions.removeWhere((time) => time.isBefore(oneHourAgo));
    _todayImpressions.removeWhere((time) => time.isBefore(oneDayAgo));
  }

  /// Log de decisión de anuncio
  void _logDecision(AdDecisionResult decision, String? adType) {
    _logger.info('Ad decision for $adType: ${decision.name}');
  }

  /// Calcular tasa de retención (simplificado)
  double _calculateRetentionRate() {
    // TODO: Implementar cálculo real basado en sesiones de usuario
    return 0.8; // Placeholder
  }

  /// Guardar configuración
  Future<void> _saveConfig() async {
    await _prefs?.setString('ad_frequency_config', jsonEncode(_config.toJson()));
  }

  /// Cargar configuración
  Future<void> _loadConfig() async {
    final configStr = _prefs?.getString('ad_frequency_config');
    if (configStr != null) {
      try {
        final configJson = jsonDecode(configStr) as Map<String, dynamic>;
        _config = AdFrequencyConfig.fromJson(configJson);
      } catch (e) {
        _logger.warning('Error loading config, using defaults: $e');
      }
    }
  }

  /// Guardar datos del día
  Future<void> _saveTodayData() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final impressionsJson = _todayImpressions.map((d) => d.toIso8601String()).toList();
    await _prefs?.setStringList('today_impressions_$today', impressionsJson);
  }

  /// Cargar datos del día
  Future<void> _loadTodayData() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final impressionsStr = _prefs?.getStringList('today_impressions_$today') ?? [];
    
    _todayImpressions = impressionsStr
        .map((str) => DateTime.parse(str))
        .where((date) => _isToday(date))
        .toList();
    
    _hourlyImpressions = _todayImpressions
        .where((date) => DateTime.now().difference(date).inHours < 1)
        .toList();
  }

  /// Verificar si una fecha es hoy
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  /// Obtener configuración actual
  AdFrequencyConfig get config => _config;

  /// Obtener estadísticas de sesión actual
  Map<String, dynamic> getSessionStats() => {
    'sessionId': _currentSessionId,
    'sessionAdCount': _sessionAdCount,
    'sessionClickCount': _sessionClickCount,
    'sessionDuration': _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!).inMinutes 
        : 0,
    'lastAdShown': _lastAdShownTime?.toIso8601String(),
    'dailyImpressions': _todayImpressions.length,
    'hourlyImpressions': _hourlyImpressions.length,
  };

  /// Actualizar configuración
  Future<void> updateConfig(AdFrequencyConfig newConfig) async {
    _config = newConfig;
    await _saveConfig();
    _logger.info('Ad frequency config updated: ${_config.toJson()}');
  }
}