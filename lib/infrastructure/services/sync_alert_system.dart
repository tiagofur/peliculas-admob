import 'dart:async';
import 'sync_logger.dart';

/// Niveles de severidad para las alertas de sincronización
enum AlertSeverity {
  info,
  warning,
  error,
  critical
}

/// Tipos de alertas de sincronización
enum AlertType {
  connectionLost,
  syncFailed,
  conflictResolution,
  dataCorruption,
  performanceDegraded,
  quotaExceeded,
  authenticationFailed,
  serverError
}

/// Canales de notificación para las alertas
enum AlertChannel {
  inApp,
  push,
  email,
  log
}

/// Modelo para una alerta de sincronización
class SyncAlert {

  const SyncAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.metadata = const {},
    required this.timestamp,
    this.channels = const [AlertChannel.inApp, AlertChannel.log],
    this.isResolved = false,
    this.resolutionNote,
    this.resolvedAt,
  });
  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final List<AlertChannel> channels;
  final bool isResolved;
  final String? resolutionNote;
  final DateTime? resolvedAt;

  SyncAlert copyWith({
    String? id,
    AlertType? type,
    AlertSeverity? severity,
    String? title,
    String? message,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    List<AlertChannel>? channels,
    bool? isResolved,
    String? resolutionNote,
    DateTime? resolvedAt,
  }) {
    return SyncAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      channels: channels ?? this.channels,
      isResolved: isResolved ?? this.isResolved,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'severity': severity.name,
      'title': title,
      'message': message,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'channels': channels.map((c) => c.name).toList(),
      'isResolved': isResolved,
      'resolutionNote': resolutionNote,
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }
}

/// Configuración para el sistema de alertas
class AlertConfig {

  const AlertConfig({
    this.enableInAppNotifications = true,
    this.enablePushNotifications = false,
    this.enableEmailNotifications = false,
    this.alertThrottleDuration = const Duration(minutes: 5),
    this.maxAlertsPerHour = 20,
    this.alertSeverityMap = const {
      AlertType.connectionLost: AlertSeverity.warning,
      AlertType.syncFailed: AlertSeverity.error,
      AlertType.conflictResolution: AlertSeverity.info,
      AlertType.dataCorruption: AlertSeverity.critical,
      AlertType.performanceDegraded: AlertSeverity.warning,
      AlertType.quotaExceeded: AlertSeverity.error,
      AlertType.authenticationFailed: AlertSeverity.critical,
      AlertType.serverError: AlertSeverity.error,
    },
    this.severityChannelMap = const {
      AlertSeverity.info: [AlertChannel.log],
      AlertSeverity.warning: [AlertChannel.inApp, AlertChannel.log],
      AlertSeverity.error: [AlertChannel.inApp, AlertChannel.push, AlertChannel.log],
      AlertSeverity.critical: [AlertChannel.inApp, AlertChannel.push, AlertChannel.email, AlertChannel.log],
    },
  });
  final bool enableInAppNotifications;
  final bool enablePushNotifications;
  final bool enableEmailNotifications;
  final Duration alertThrottleDuration;
  final int maxAlertsPerHour;
  final Map<AlertType, AlertSeverity> alertSeverityMap;
  final Map<AlertSeverity, List<AlertChannel>> severityChannelMap;
}

/// Sistema de alertas para sincronización
class SyncAlertSystem {
  factory SyncAlertSystem() => _instance;
  SyncAlertSystem._internal();
  static final SyncAlertSystem _instance = SyncAlertSystem._internal();

  final SyncLogger _logger = SyncLogger();
  
  AlertConfig _config = const AlertConfig();
  final List<SyncAlert> _activeAlerts = [];
  final Map<String, DateTime> _alertThrottleMap = {};
  final StreamController<SyncAlert> _alertStreamController = StreamController<SyncAlert>.broadcast();

  /// Stream de alertas activas
  Stream<SyncAlert> get alertStream => _alertStreamController.stream;

  /// Lista de alertas activas
  List<SyncAlert> get activeAlerts => List.unmodifiable(_activeAlerts);

  /// Configurar el sistema de alertas
  void configure(AlertConfig config) {
    _config = config;
    _logger.info(
      'SyncAlertSystem',
      SyncOperationType.system,
      'Sistema de alertas configurado',
      metadata: {
        'inApp': config.enableInAppNotifications,
        'push': config.enablePushNotifications,
        'email': config.enableEmailNotifications,
        'throttleDuration': config.alertThrottleDuration.inMinutes,
        'maxAlertsPerHour': config.maxAlertsPerHour,
      },
    );
  }

  /// Crear y enviar una alerta
  Future<void> createAlert({
    required AlertType type,
    required String title,
    required String message,
    Map<String, dynamic> metadata = const {},
    AlertSeverity? severity,
    List<AlertChannel>? channels,
  }) async {
    try {
      // Determinar severidad basada en configuración
      final alertSeverity = severity ?? _config.alertSeverityMap[type] ?? AlertSeverity.info;
      
      // Determinar canales basados en severidad
      final alertChannels = channels ?? _config.severityChannelMap[alertSeverity] ?? [AlertChannel.log];
      
      // Verificar throttling
      final throttleKey = '${type.name}_${alertSeverity.name}';
      if (_shouldThrottleAlert(throttleKey)) {
        _logger.debug(
          'SyncAlertSystem',
          SyncOperationType.system,
          'Alerta throttled: $throttleKey',
        );
        return;
      }

      // Verificar límite de alertas por hora
      if (_isAlertLimitExceeded()) {
        _logger.warning(
          'SyncAlertSystem',
          SyncOperationType.system,
          'Límite de alertas por hora excedido',
        );
        return;
      }

      // Crear la alerta
      final alert = SyncAlert(
        id: _generateAlertId(),
        type: type,
        severity: alertSeverity,
        title: title,
        message: message,
        metadata: metadata,
        timestamp: DateTime.now(),
        channels: alertChannels,
      );

      // Agregar a alertas activas
      _activeAlerts.add(alert);
      
      // Actualizar throttle
      _alertThrottleMap[throttleKey] = DateTime.now();

      // Enviar por los canales configurados
      await _sendAlert(alert);

      // Notificar a listeners
      _alertStreamController.add(alert);

      _logger.info(
        'SyncAlertSystem',
        SyncOperationType.system,
        'Alerta creada: ${alert.title}',
        metadata: {
          'alertId': alert.id,
          'type': alert.type.name,
          'severity': alert.severity.name,
          'channels': alert.channels.map((c) => c.name).toList(),
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'SyncAlertSystem',
        SyncOperationType.system,
        'Error creando alerta: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Resolver una alerta
  Future<void> resolveAlert(String alertId, {String? resolutionNote}) async {
    try {
      final alertIndex = _activeAlerts.indexWhere((alert) => alert.id == alertId);
      if (alertIndex == -1) {
        _logger.warning(
          'SyncAlertSystem',
          SyncOperationType.system,
          'Alerta no encontrada para resolver: $alertId',
        );
        return;
      }

      final alert = _activeAlerts[alertIndex];
      final resolvedAlert = alert.copyWith(
        isResolved: true,
        resolutionNote: resolutionNote,
        resolvedAt: DateTime.now(),
      );

      _activeAlerts[alertIndex] = resolvedAlert;
      _alertStreamController.add(resolvedAlert);

      _logger.info(
        'SyncAlertSystem',
        SyncOperationType.system,
        'Alerta resuelta: ${alert.title}',
        metadata: {
          'alertId': alertId,
          'resolutionNote': resolutionNote,
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'SyncAlertSystem',
        SyncOperationType.system,
        'Error resolviendo alerta: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Limpiar alertas resueltas antiguas
  void cleanupResolvedAlerts({Duration? olderThan}) {
    final cutoffTime = DateTime.now().subtract(olderThan ?? const Duration(days: 7));
    
    _activeAlerts.removeWhere((alert) => 
      alert.isResolved && 
      alert.resolvedAt != null && 
      alert.resolvedAt!.isBefore(cutoffTime)
    );

    _logger.debug(
      'SyncAlertSystem',
      SyncOperationType.system,
      'Alertas resueltas limpiadas',
      metadata: {'cutoffTime': cutoffTime.toIso8601String()},
    );
  }

  /// Obtener alertas por tipo
  List<SyncAlert> getAlertsByType(AlertType type) {
    return _activeAlerts.where((alert) => alert.type == type).toList();
  }

  /// Obtener alertas por severidad
  List<SyncAlert> getAlertsBySeverity(AlertSeverity severity) {
    return _activeAlerts.where((alert) => alert.severity == severity).toList();
  }

  /// Obtener alertas no resueltas
  List<SyncAlert> getUnresolvedAlerts() {
    return _activeAlerts.where((alert) => !alert.isResolved).toList();
  }

  /// Verificar si se debe throttlear una alerta
  bool _shouldThrottleAlert(String throttleKey) {
    final lastAlertTime = _alertThrottleMap[throttleKey];
    if (lastAlertTime == null) return false;
    
    return DateTime.now().difference(lastAlertTime) < _config.alertThrottleDuration;
  }

  /// Verificar si se ha excedido el límite de alertas por hora
  bool _isAlertLimitExceeded() {
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    final recentAlerts = _activeAlerts.where(
      (alert) => alert.timestamp.isAfter(oneHourAgo)
    ).length;
    
    return recentAlerts >= _config.maxAlertsPerHour;
  }

  /// Enviar alerta por los canales configurados
  Future<void> _sendAlert(SyncAlert alert) async {
    for (final channel in alert.channels) {
      try {
        switch (channel) {
          case AlertChannel.inApp:
            await _sendInAppNotification(alert);
            break;
          case AlertChannel.push:
            await _sendPushNotification(alert);
            break;
          case AlertChannel.email:
            await _sendEmailNotification(alert);
            break;
          case AlertChannel.log:
            await _sendLogNotification(alert);
            break;
        }
      } catch (e) {
        _logger.error(
          'SyncAlertSystem',
          SyncOperationType.system,
          'Error enviando alerta por canal ${channel.name}: $e',
          error: e,
        );
      }
    }
  }

  /// Enviar notificación in-app
  Future<void> _sendInAppNotification(SyncAlert alert) async {
    if (!_config.enableInAppNotifications) return;
    
    // Implementar notificación in-app usando SnackBar o similar
    // Esta implementación dependerá del contexto de la UI
    _logger.debug(
      'SyncAlertSystem',
      SyncOperationType.system,
      'Notificación in-app enviada: ${alert.title}',
    );
  }

  /// Enviar notificación push
  Future<void> _sendPushNotification(SyncAlert alert) async {
    if (!_config.enablePushNotifications) return;
    
    // Implementar notificación push usando Firebase Cloud Messaging
    _logger.debug(
      'SyncAlertSystem',
      SyncOperationType.system,
      'Notificación push enviada: ${alert.title}',
    );
  }

  /// Enviar notificación por email
  Future<void> _sendEmailNotification(SyncAlert alert) async {
    if (!_config.enableEmailNotifications) return;
    
    // Implementar notificación por email
    _logger.debug(
      'SyncAlertSystem',
      SyncOperationType.system,
      'Notificación email enviada: ${alert.title}',
    );
  }

  /// Enviar notificación al log
  Future<void> _sendLogNotification(SyncAlert alert) async {
    _logger.info(
      'SyncAlertSystem',
      SyncOperationType.alert,
      '[ALERTA] ${alert.title}: ${alert.message}',
      metadata: alert.metadata,
    );
  }

  /// Generar ID único para alerta
  String _generateAlertId() {
    return 'alert_${DateTime.now().millisecondsSinceEpoch}_${_activeAlerts.length}';
  }

  /// Limpiar recursos
  void dispose() {
    _alertStreamController.close();
    _activeAlerts.clear();
    _alertThrottleMap.clear();
  }
}

/// Extensión para facilitar el uso del sistema de alertas
extension SyncAlertSystemExtension on Object {
  /// Crear alerta de conexión perdida
  Future<void> alertConnectionLost({String? details}) async {
    await SyncAlertSystem().createAlert(
      type: AlertType.connectionLost,
      title: 'Conexión perdida',
      message: 'Se ha perdido la conexión con el servidor de sincronización',
      metadata: {'details': details ?? 'Sin detalles adicionales'},
    );
  }

  /// Crear alerta de fallo de sincronización
  Future<void> alertSyncFailed({
    required String operation,
    required String error,
    Map<String, dynamic>? additionalData,
  }) async {
    await SyncAlertSystem().createAlert(
      type: AlertType.syncFailed,
      title: 'Fallo de sincronización',
      message: 'Error en operación: $operation',
      metadata: {
        'operation': operation,
        'error': error,
        ...?additionalData,
      },
    );
  }

  /// Crear alerta de resolución de conflictos
  Future<void> alertConflictResolution({
    required String dataType,
    required String resolution,
  }) async {
    await SyncAlertSystem().createAlert(
      type: AlertType.conflictResolution,
      title: 'Conflicto resuelto',
      message: 'Conflicto en $dataType resuelto: $resolution',
      metadata: {
        'dataType': dataType,
        'resolution': resolution,
      },
    );
  }

  /// Crear alerta de corrupción de datos
  Future<void> alertDataCorruption({
    required String dataType,
    required String details,
  }) async {
    await SyncAlertSystem().createAlert(
      type: AlertType.dataCorruption,
      title: 'Corrupción de datos detectada',
      message: 'Datos corruptos en $dataType: $details',
      metadata: {
        'dataType': dataType,
        'details': details,
      },
    );
  }

  /// Crear alerta de rendimiento degradado
  Future<void> alertPerformanceDegraded({
    required String operation,
    required Duration duration,
    Duration? threshold,
  }) async {
    await SyncAlertSystem().createAlert(
      type: AlertType.performanceDegraded,
      title: 'Rendimiento degradado',
      message: 'Operación $operation tardó ${duration.inMilliseconds}ms',
      metadata: {
        'operation': operation,
        'duration': duration.inMilliseconds,
        'threshold': threshold?.inMilliseconds,
      },
    );
  }
}