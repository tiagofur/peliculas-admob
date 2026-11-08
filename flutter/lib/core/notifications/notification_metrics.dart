import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logging/logger_factory.dart';
import 'notification_manager.dart';

/// Métricas de entrega de notificaciones
class NotificationDeliveryMetrics {
  const NotificationDeliveryMetrics({
    required this.notificationId,
    required this.type,
    required this.sentAt,
    required this.scheduledFor,
    this.deliveredAt,
    this.clickedAt,
    this.dismissedAt,
    this.failed = false,
    this.failureReason,
  });

  factory NotificationDeliveryMetrics.fromJson(Map<String, dynamic> json) {
    return NotificationDeliveryMetrics(
      notificationId: json['notificationId'] as String,
      type: NotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationType.newMovies,
      ),
      sentAt: DateTime.parse(json['sentAt'] as String),
      scheduledFor: DateTime.parse(json['scheduledFor'] as String),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'] as String)
          : null,
      clickedAt: json['clickedAt'] != null
          ? DateTime.parse(json['clickedAt'] as String)
          : null,
      dismissedAt: json['dismissedAt'] != null
          ? DateTime.parse(json['dismissedAt'] as String)
          : null,
      failed: json['failed'] as bool? ?? false,
      failureReason: json['failureReason'] as String?,
    );
  }

  final String notificationId;
  final NotificationType type;
  final DateTime sentAt;
  final DateTime scheduledFor;
  final DateTime? deliveredAt;
  final DateTime? clickedAt;
  final DateTime? dismissedAt;
  final bool failed;
  final String? failureReason;

  /// Latencia de entrega en milisegundos
  int? get deliveryLatencyMs {
    if (deliveredAt == null) return null;
    return deliveredAt!.difference(sentAt).inMilliseconds;
  }

  /// Latencia de programación en milisegundos (diferencia entre cuando se programó y cuando se envió)
  int get schedulingLatencyMs {
    return sentAt.difference(scheduledFor).inMilliseconds.abs();
  }

  /// Si la notificación fue entregada exitosamente
  bool get wasDelivered => deliveredAt != null && !failed;

  /// Si la notificación fue interaccionada (clickeada)
  bool get wasClicked => clickedAt != null;

  /// Si la notificación fue dismisseda sin interacción
  bool get wasDismissed => dismissedAt != null && clickedAt == null;

  Map<String, dynamic> toJson() {
    return {
      'notificationId': notificationId,
      'type': type.name,
      'sentAt': sentAt.toIso8601String(),
      'scheduledFor': scheduledFor.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'clickedAt': clickedAt?.toIso8601String(),
      'dismissedAt': dismissedAt?.toIso8601String(),
      'failed': failed,
      'failureReason': failureReason,
    };
  }

  NotificationDeliveryMetrics copyWith({
    String? notificationId,
    NotificationType? type,
    DateTime? sentAt,
    DateTime? scheduledFor,
    DateTime? deliveredAt,
    DateTime? clickedAt,
    DateTime? dismissedAt,
    bool? failed,
    String? failureReason,
  }) {
    return NotificationDeliveryMetrics(
      notificationId: notificationId ?? this.notificationId,
      type: type ?? this.type,
      sentAt: sentAt ?? this.sentAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      clickedAt: clickedAt ?? this.clickedAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      failed: failed ?? this.failed,
      failureReason: failureReason ?? this.failureReason,
    );
  }
}

/// Estadísticas agregadas de notificaciones
class NotificationStats {
  const NotificationStats({
    required this.totalSent,
    required this.totalDelivered,
    required this.totalClicked,
    required this.totalFailed,
    required this.averageDeliveryLatencyMs,
    required this.averageSchedulingLatencyMs,
    required this.deliveryRate,
    required this.clickThroughRate,
    required this.failureRate,
    required this.period,
  });

  final int totalSent;
  final int totalDelivered;
  final int totalClicked;
  final int totalFailed;
  final double averageDeliveryLatencyMs;
  final double averageSchedulingLatencyMs;
  final double deliveryRate;
  final double clickThroughRate;
  final double failureRate;
  final String period;

  Map<String, dynamic> toJson() {
    return {
      'totalSent': totalSent,
      'totalDelivered': totalDelivered,
      'totalClicked': totalClicked,
      'totalFailed': totalFailed,
      'averageDeliveryLatencyMs': averageDeliveryLatencyMs,
      'averageSchedulingLatencyMs': averageSchedulingLatencyMs,
      'deliveryRate': deliveryRate,
      'clickThroughRate': clickThroughRate,
      'failureRate': failureRate,
      'period': period,
    };
  }
}

/// Servicio para tracking de métricas de notificaciones
class NotificationMetricsService {
  NotificationMetricsService._();
  static NotificationMetricsService? _instance;
  static NotificationMetricsService get instance =>
      _instance ??= NotificationMetricsService._();

  final _logger = LoggerFactory.logger;
  final List<NotificationDeliveryMetrics> _metrics = [];
  Timer? _cleanupTimer;

  static const String _prefsKey = 'notification_metrics';
  static const int _maxMetricsToKeep = 1000;
  static const Duration _metricsRetentionPeriod = Duration(days: 30);

  /// Inicializa el servicio de métricas
  Future<void> initialize() async {
    await _loadMetrics();
    _startCleanupTimer();
    _logger.info('Servicio de métricas de notificaciones inicializado');
  }

  /// Registra que una notificación fue enviada
  Future<void> recordNotificationSent({
    required String notificationId,
    required NotificationType type,
    required DateTime scheduledFor,
    DateTime? sentAt,
  }) async {
    final metrics = NotificationDeliveryMetrics(
      notificationId: notificationId,
      type: type,
      sentAt: sentAt ?? DateTime.now(),
      scheduledFor: scheduledFor,
    );

    _metrics.add(metrics);
    await _saveMetrics();

    _logger
        .info('Métrica registrada - Enviada: $notificationId (${type.name})');
  }

  /// Registra que una notificación fue entregada
  Future<void> recordNotificationDelivered({
    required String notificationId,
    DateTime? deliveredAt,
  }) async {
    final index =
        _metrics.indexWhere((m) => m.notificationId == notificationId);
    if (index != -1) {
      _metrics[index] = _metrics[index].copyWith(
        deliveredAt: deliveredAt ?? DateTime.now(),
      );
      await _saveMetrics();

      _logger.info('Métrica actualizada - Entregada: $notificationId');
    }
  }

  /// Registra que una notificación fue clickeada
  Future<void> recordNotificationClicked({
    required String notificationId,
    DateTime? clickedAt,
  }) async {
    final index =
        _metrics.indexWhere((m) => m.notificationId == notificationId);
    if (index != -1) {
      _metrics[index] = _metrics[index].copyWith(
        clickedAt: clickedAt ?? DateTime.now(),
      );
      await _saveMetrics();

      _logger.info('Métrica actualizada - Clickeada: $notificationId');
    }
  }

  /// Registra que una notificación fue dismisseda
  Future<void> recordNotificationDismissed({
    required String notificationId,
    DateTime? dismissedAt,
  }) async {
    final index =
        _metrics.indexWhere((m) => m.notificationId == notificationId);
    if (index != -1) {
      _metrics[index] = _metrics[index].copyWith(
        dismissedAt: dismissedAt ?? DateTime.now(),
      );
      await _saveMetrics();

      _logger.info('Métrica actualizada - Dismisseda: $notificationId');
    }
  }

  /// Registra que una notificación falló
  Future<void> recordNotificationFailed({
    required String notificationId,
    required String reason,
  }) async {
    final index =
        _metrics.indexWhere((m) => m.notificationId == notificationId);
    if (index != -1) {
      _metrics[index] = _metrics[index].copyWith(
        failed: true,
        failureReason: reason,
      );
      await _saveMetrics();

      _logger.error('Métrica actualizada - Falló: $notificationId - $reason');
    }
  }

  /// Obtiene estadísticas para un período específico
  NotificationStats getStats({
    Duration? period,
    NotificationType? type,
  }) {
    final now = DateTime.now();
    final startDate = period != null
        ? now.subtract(period)
        : DateTime.fromMillisecondsSinceEpoch(0);

    final filteredMetrics = _metrics.where((m) {
      if (m.sentAt.isBefore(startDate)) return false;
      if (type != null && m.type != type) return false;
      return true;
    }).toList();

    if (filteredMetrics.isEmpty) {
      return NotificationStats(
        totalSent: 0,
        totalDelivered: 0,
        totalClicked: 0,
        totalFailed: 0,
        averageDeliveryLatencyMs: 0.0,
        averageSchedulingLatencyMs: 0.0,
        deliveryRate: 0.0,
        clickThroughRate: 0.0,
        failureRate: 0.0,
        period: period?.toString() ?? 'All time',
      );
    }

    final totalSent = filteredMetrics.length;
    final totalDelivered = filteredMetrics.where((m) => m.wasDelivered).length;
    final totalClicked = filteredMetrics.where((m) => m.wasClicked).length;
    final totalFailed = filteredMetrics.where((m) => m.failed).length;

    final deliveredMetrics =
        filteredMetrics.where((m) => m.deliveryLatencyMs != null);
    final avgDeliveryLatency = deliveredMetrics.isNotEmpty
        ? deliveredMetrics
                .map((m) => m.deliveryLatencyMs!)
                .reduce((a, b) => a + b) /
            deliveredMetrics.length
        : 0.0;

    final avgSchedulingLatency = filteredMetrics.isNotEmpty
        ? filteredMetrics
                .map((m) => m.schedulingLatencyMs)
                .reduce((a, b) => a + b) /
            filteredMetrics.length
        : 0.0;

    return NotificationStats(
      totalSent: totalSent,
      totalDelivered: totalDelivered,
      totalClicked: totalClicked,
      totalFailed: totalFailed,
      averageDeliveryLatencyMs: avgDeliveryLatency,
      averageSchedulingLatencyMs: avgSchedulingLatency,
      deliveryRate: totalSent > 0 ? totalDelivered / totalSent : 0.0,
      clickThroughRate:
          totalDelivered > 0 ? totalClicked / totalDelivered : 0.0,
      failureRate: totalSent > 0 ? totalFailed / totalSent : 0.0,
      period: period?.toString() ?? 'All time',
    );
  }

  /// Obtiene estadísticas de las últimas 24 horas
  NotificationStats get last24HoursStats =>
      getStats(period: const Duration(hours: 24));

  /// Obtiene estadísticas de la última semana
  NotificationStats get lastWeekStats =>
      getStats(period: const Duration(days: 7));

  /// Obtiene estadísticas del último mes
  NotificationStats get lastMonthStats =>
      getStats(period: const Duration(days: 30));

  /// Verifica si la tasa de entrega cumple con el objetivo (>95%)
  bool get isDeliveryRateHealthy {
    final stats = last24HoursStats;
    return stats.deliveryRate >= 0.95 ||
        stats.totalSent < 5; // Requiere al menos 5 notificaciones para evaluar
  }

  /// Verifica si la latencia promedio está dentro del rango aceptable (<5 segundos)
  bool get isLatencyHealthy {
    final stats = last24HoursStats;
    return stats.averageDeliveryLatencyMs <= 5000; // 5 segundos
  }

  /// Obtiene un reporte de salud del sistema de notificaciones
  Map<String, dynamic> getHealthReport() {
    final stats24h = last24HoursStats;
    final statsWeek = lastWeekStats;

    return {
      'deliveryRateHealthy': isDeliveryRateHealthy,
      'latencyHealthy': isLatencyHealthy,
      'last24Hours': stats24h.toJson(),
      'lastWeek': statsWeek.toJson(),
      'metricsCount': _metrics.length,
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Carga métricas desde SharedPreferences
  Future<void> _loadMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metricsJson = prefs.getString(_prefsKey);

      if (metricsJson != null) {
        final metricsList = jsonDecode(metricsJson) as List;
        _metrics.clear();
        _metrics.addAll(
          metricsList.map((json) => NotificationDeliveryMetrics.fromJson(json)),
        );

        _logger.info('${_metrics.length} métricas de notificaciones cargadas');
      }
    } catch (e) {
      _logger.error('Error cargando métricas de notificaciones: $e');
    }
  }

  /// Guarda métricas en SharedPreferences
  Future<void> _saveMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metricsJson = jsonEncode(_metrics.map((m) => m.toJson()).toList());
      await prefs.setString(_prefsKey, metricsJson);
    } catch (e) {
      _logger.error('Error guardando métricas de notificaciones: $e');
    }
  }

  /// Inicia el timer de limpieza automática
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(hours: 6), (_) {
      _cleanupOldMetrics();
    });
  }

  /// Limpia métricas antiguas
  void _cleanupOldMetrics() {
    final now = DateTime.now();
    final cutoffDate = now.subtract(_metricsRetentionPeriod);

    final initialCount = _metrics.length;
    _metrics.removeWhere((m) => m.sentAt.isBefore(cutoffDate));

    // También limitar por cantidad
    if (_metrics.length > _maxMetricsToKeep) {
      _metrics.sort(
          (a, b) => b.sentAt.compareTo(a.sentAt)); // Más recientes primero
      _metrics.removeRange(_maxMetricsToKeep, _metrics.length);
    }

    final removedCount = initialCount - _metrics.length;
    if (removedCount > 0) {
      _logger.info(
          'Limpieza de métricas: $removedCount métricas antiguas eliminadas');
      _saveMetrics(); // Guardar cambios
    }
  }

  /// Limpia todas las métricas
  Future<void> clearAllMetrics() async {
    _metrics.clear();
    await _saveMetrics();
    _logger.info('Todas las métricas de notificaciones han sido limpiadas');
  }

  /// Detiene el servicio y limpia recursos
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _instance = null;
  }
}
