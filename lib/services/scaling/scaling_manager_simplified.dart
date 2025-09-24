/// Scaling Manager (Fase 4)
///
/// Manager central simplificado que coordina los servicios de escalado:
/// - Database Scaling Service
/// - CDN Manager Service
/// - Load Balancer Service
/// - Enterprise Monitoring Service
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cdn/cdn_manager_service.dart';
import 'database/database_scaling_service.dart';
import 'load_balancing/load_balancer_service.dart';
import 'monitoring/enterprise_monitoring_service.dart';

/// Estados del sistema de escalado
enum ScalingStatus {
  initializing,
  ready,
  scaling,
  optimizing,
  maintenance,
  error
}

/// Configuración simplificada del sistema de escalado
class ScalingConfiguration {
  const ScalingConfiguration({
    this.enableDatabaseScaling = true,
    this.enableCdnOptimization = true,
    this.enableLoadBalancing = true,
    this.enableEnterpriseMonitoring = true,
    this.monitoringInterval = const Duration(seconds: 30),
  });
  final bool enableDatabaseScaling;
  final bool enableCdnOptimization;
  final bool enableLoadBalancing;
  final bool enableEnterpriseMonitoring;
  final Duration monitoringInterval;
}

/// Manager simplificado del sistema de escalado
class ScalingManager {
  factory ScalingManager() => _instance;
  ScalingManager._internal();
  static final ScalingManager _instance = ScalingManager._internal();

  // Servicios de escalado
  DatabaseScalingService? _databaseService;
  CdnManagerService? _cdnService;
  LoadBalancerService? _loadBalancerService;
  EnterpriseMonitoringService? _monitoringService;

  // Estado del manager
  ScalingStatus _status = ScalingStatus.initializing;
  ScalingConfiguration? _configuration;
  DateTime? _initializationTime;
  Timer? _healthCheckTimer;

  // Callbacks
  Function(ScalingStatus)? _onStatusChange;
  Function(String, String)? _onError;

  /// Estado actual del sistema
  ScalingStatus get status => _status;

  /// Tiempo de actividad
  Duration? get uptime => _initializationTime != null
      ? DateTime.now().difference(_initializationTime!)
      : null;

  /// Inicializar el sistema de escalado
  Future<bool> initialize({
    required ScalingConfiguration configuration,
    Function(ScalingStatus)? onStatusChange,
    Function(String, String)? onError,
  }) async {
    try {
      if (kDebugMode) debugPrint('🚀 Inicializando Scaling Manager Fase 4...');
      _updateStatus(ScalingStatus.initializing);

      _configuration = configuration;
      _onStatusChange = onStatusChange;
      _onError = onError;

      // Inicializar servicios habilitados
      await _initializeServices();

      // Configurar monitoreo básico
      _startHealthChecks();

      _initializationTime = DateTime.now();
      _updateStatus(ScalingStatus.ready);

      if (kDebugMode) {
        debugPrint('✅ Scaling Manager Fase 4 inicializado exitosamente');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error inicializando Scaling Manager: $e');
      _handleError('Initialization Error', e.toString());
      _updateStatus(ScalingStatus.error);
      return false;
    }
  }

  /// Optimizar imagen a través del CDN
  Future<String?> optimizeImage(String imageUrl) async {
    if (_cdnService == null || !_configuration!.enableCdnOptimization) {
      return imageUrl;
    }

    try {
      // Usar método disponible en el CDN service
      return _cdnService!.getOptimizedImageUrl(
        imagePath: imageUrl,
        quality: ImageQuality.medium,
      );
    } catch (e) {
      _handleError('CDN Optimization Error', e.toString());
      return imageUrl; // Fallback
    }
  }

  /// Ejecutar solicitud balanceada
  Future<Map<String, dynamic>?> executeBalancedRequest(
      Future<Map<String, dynamic>> Function(String baseUrl)
          requestFunction) async {
    if (_loadBalancerService == null || !_configuration!.enableLoadBalancing) {
      _handleError('Load Balancer Error', 'Load balancing not enabled');
      return null;
    }

    try {
      return await _loadBalancerService!.executeRequest<Map<String, dynamic>>(
        requestFunction: requestFunction,
      );
    } catch (e) {
      _handleError('Load Balanced Request Error', e.toString());
      return null;
    }
  }

  /// Registrar métrica personalizada
  void recordMetric(
    String name,
    double value, {
    String unit = 'count',
    Map<String, dynamic>? tags,
  }) {
    if (_monitoringService == null ||
        !_configuration!.enableEnterpriseMonitoring) {
      return;
    }

    _monitoringService!.recordMetric(name, value, unit: unit, tags: tags);
  }

  /// Crear alerta
  void createAlert({
    required AlertType type,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) {
    if (_monitoringService == null ||
        !_configuration!.enableEnterpriseMonitoring) {
      return;
    }

    _monitoringService!.createAlert(
      type: type,
      title: title,
      message: message,
      source: 'scaling_manager',
      metadata: metadata,
    );
  }

  /// Obtener estado del sistema
  Map<String, dynamic> getSystemStatus() {
    return {
      'status': _status.toString(),
      'uptime_seconds': uptime?.inSeconds ?? 0,
      'services': {
        'database': _databaseService != null ? 'active' : 'inactive',
        'cdn': _cdnService != null ? 'active' : 'inactive',
        'load_balancer': _loadBalancerService != null ? 'active' : 'inactive',
        'monitoring': _monitoringService != null ? 'active' : 'inactive',
      },
      'configuration': {
        'database_scaling': _configuration?.enableDatabaseScaling ?? false,
        'cdn_optimization': _configuration?.enableCdnOptimization ?? false,
        'load_balancing': _configuration?.enableLoadBalancing ?? false,
        'monitoring': _configuration?.enableEnterpriseMonitoring ?? false,
      },
    };
  }

  /// Forzar optimización básica
  Future<void> forceOptimization() async {
    if (_status != ScalingStatus.ready) return;

    _updateStatus(ScalingStatus.optimizing);

    try {
      if (kDebugMode) debugPrint('🔧 Ejecutando optimización básica...');

      // Registrar métricas de optimización
      recordMetric('optimization_cycles', 1);

      await Future.delayed(
          const Duration(milliseconds: 500)); // Simular trabajo

      if (kDebugMode) debugPrint('✅ Optimización completada');
    } catch (e) {
      _handleError('Optimization Error', e.toString());
    } finally {
      _updateStatus(ScalingStatus.ready);
    }
  }

  /// Detener el sistema de escalado
  void shutdown() {
    if (kDebugMode) debugPrint('🛑 Deteniendo Scaling Manager...');

    _updateStatus(ScalingStatus.maintenance);

    // Detener timers
    _healthCheckTimer?.cancel();

    // Detener servicios
    _monitoringService?.stopMonitoring();
    // Los singletons no necesitan dispose

    // Limpiar estado
    _databaseService = null;
    _cdnService = null;
    _loadBalancerService = null;
    _monitoringService = null;

    if (kDebugMode) debugPrint('✅ Scaling Manager detenido');
  }

  // Métodos privados

  /// Inicializar servicios habilitados
  Future<void> _initializeServices() async {
    // Database Scaling Service
    if (_configuration!.enableDatabaseScaling) {
      _databaseService = DatabaseScalingService.instance;
      await _databaseService!.initialize();
      if (kDebugMode) debugPrint('✅ Database Scaling Service inicializado');
    }

    // CDN Manager Service
    if (_configuration!.enableCdnOptimization) {
      _cdnService = CdnManagerService.instance;
      await _cdnService!.initialize();
      if (kDebugMode) debugPrint('✅ CDN Manager Service inicializado');
    }

    // Load Balancer Service
    if (_configuration!.enableLoadBalancing) {
      _loadBalancerService = LoadBalancerService.instance;
      await _loadBalancerService!.initialize();
      if (kDebugMode) debugPrint('✅ Load Balancer Service inicializado');
    }

    // Enterprise Monitoring Service
    if (_configuration!.enableEnterpriseMonitoring) {
      _monitoringService = EnterpriseMonitoringService();
      await _monitoringService!.startMonitoring(
        monitoringInterval: _configuration!.monitoringInterval,
        alertsInterval: const Duration(seconds: 10),
        reportInterval: const Duration(hours: 1),
        onAlert: (alert) => _handleMonitoringAlert(alert),
        onHealthChange: (prev, current) => _handleHealthChange(prev, current),
      );
      if (kDebugMode) {
        debugPrint('✅ Enterprise Monitoring Service inicializado');
      }
    }
  }

  /// Iniciar checks de salud básicos
  void _startHealthChecks() {
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _performBasicHealthCheck();
    });
  }

  /// Realizar check de salud básico
  void _performBasicHealthCheck() {
    if (_status != ScalingStatus.ready) return;

    // Check simple de servicios activos
    int activeServices = 0;
    if (_databaseService != null) activeServices++;
    if (_cdnService != null) activeServices++;
    if (_loadBalancerService != null) activeServices++;
    if (_monitoringService != null) activeServices++;

    // Registrar métrica de salud
    recordMetric('active_services', activeServices.toDouble());

    if (kDebugMode) {
      debugPrint('💓 Health Check: $activeServices servicios activos');
    }
  }

  /// Manejar alerta de monitoreo
  void _handleMonitoringAlert(Alert alert) {
    if (kDebugMode) debugPrint('📢 Monitoring Alert: ${alert.title}');

    // Acciones automáticas básicas
    if (alert.title.contains('Critical') && alert.type == AlertType.critical) {
      forceOptimization();
    }
  }

  /// Manejar cambio de salud del sistema
  void _handleHealthChange(SystemHealth previous, SystemHealth current) {
    if (kDebugMode) debugPrint('🏥 Health Changed: $previous -> $current');

    if (current == SystemHealth.critical) {
      createAlert(
        type: AlertType.critical,
        title: 'System Health Critical',
        message: 'System health degraded to critical state',
        metadata: {
          'previous': previous.toString(),
          'current': current.toString()
        },
      );
    }
  }

  /// Actualizar estado y notificar
  void _updateStatus(ScalingStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _onStatusChange?.call(newStatus);
      if (kDebugMode) debugPrint('📊 Scaling Status: $newStatus');
    }
  }

  /// Manejar errores
  void _handleError(String context, String error) {
    if (kDebugMode) debugPrint('❌ $context: $error');
    _onError?.call(context, error);
  }
}
