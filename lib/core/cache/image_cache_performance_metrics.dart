import 'dart:async';
import 'dart:collection';

import '../logging/logger_factory.dart';

/// Métricas de rendimiento del caché de imágenes
class ImageCachePerformanceMetrics {
  ImageCachePerformanceMetrics._();
  static ImageCachePerformanceMetrics? _instance;
  static ImageCachePerformanceMetrics get instance =>
      _instance ??= ImageCachePerformanceMetrics._();

  final _logger = LoggerFactory.logger;

  // Contadores de rendimiento
  int _totalRequests = 0;
  int _memoryCacheHits = 0;
  int _diskCacheHits = 0;
  int _networkDownloads = 0;
  int _failedRequests = 0;

  // Métricas de tiempo
  final Queue<Duration> _loadTimes = Queue<Duration>();
  final Queue<Duration> _memoryCacheAccessTimes = Queue<Duration>();
  final Queue<Duration> _diskCacheAccessTimes = Queue<Duration>();
  final Queue<Duration> _downloadTimes = Queue<Duration>();

  // Configuración de ventana de métricas
  static const int _maxSamples = 1000;
  static const Duration _metricsWindow = Duration(minutes: 30);

  // Control de tiempo
  DateTime? _metricsStartTime;
  Timer? _cleanupTimer;

  /// Inicializa las métricas
  void initialize() {
    if (_metricsStartTime != null) return;

    _metricsStartTime = DateTime.now();
    _startCleanupTimer();

    _logger.info('📊 Métricas de rendimiento de caché inicializadas');
  }

  /// Registra una solicitud de imagen
  void recordImageRequest() {
    _totalRequests++;
  }

  /// Registra un hit en el caché de memoria
  void recordMemoryCacheHit(Duration accessTime) {
    _memoryCacheHits++;
    _addTimeToQueue(_memoryCacheAccessTimes, accessTime);
  }

  /// Registra un hit en el caché de disco
  void recordDiskCacheHit(Duration accessTime) {
    _diskCacheHits++;
    _addTimeToQueue(_diskCacheAccessTimes, accessTime);
  }

  /// Registra una descarga de red
  void recordNetworkDownload(Duration downloadTime) {
    _networkDownloads++;
    _addTimeToQueue(_downloadTimes, downloadTime);
  }

  /// Registra una solicitud fallida
  void recordFailedRequest() {
    _failedRequests++;
  }

  /// Registra el tiempo total de carga de una imagen
  void recordLoadTime(Duration loadTime) {
    _addTimeToQueue(_loadTimes, loadTime);
  }

  /// Agrega un tiempo a la cola y mantiene el límite
  void _addTimeToQueue(Queue<Duration> queue, Duration time) {
    queue.add(time);
    if (queue.length > _maxSamples) {
      queue.removeFirst();
    }
  }

  /// Obtiene estadísticas de rendimiento
  PerformanceStats getStats() {
    final now = DateTime.now();
    final uptime = _metricsStartTime != null
        ? now.difference(_metricsStartTime!)
        : Duration.zero;

    return PerformanceStats(
      totalRequests: _totalRequests,
      memoryCacheHits: _memoryCacheHits,
      diskCacheHits: _diskCacheHits,
      networkDownloads: _networkDownloads,
      failedRequests: _failedRequests,

      // Ratios
      memoryCacheHitRate:
          _totalRequests > 0 ? _memoryCacheHits / _totalRequests : 0.0,
      diskCacheHitRate:
          _totalRequests > 0 ? _diskCacheHits / _totalRequests : 0.0,
      overallCacheHitRate: _totalRequests > 0
          ? (_memoryCacheHits + _diskCacheHits) / _totalRequests
          : 0.0,
      failureRate: _totalRequests > 0 ? _failedRequests / _totalRequests : 0.0,

      // Tiempos promedio
      averageLoadTime: _calculateAverage(_loadTimes),
      averageMemoryCacheAccessTime: _calculateAverage(_memoryCacheAccessTimes),
      averageDiskCacheAccessTime: _calculateAverage(_diskCacheAccessTimes),
      averageDownloadTime: _calculateAverage(_downloadTimes),

      // Percentiles de tiempo de carga
      loadTimeP50: _calculatePercentile(_loadTimes, 0.5),
      loadTimeP90: _calculatePercentile(_loadTimes, 0.9),
      loadTimeP95: _calculatePercentile(_loadTimes, 0.95),

      // Meta información
      uptime: uptime,
      sampleSize: _loadTimes.length,
    );
  }

  /// Calcula el promedio de una cola de duraciones
  Duration _calculateAverage(Queue<Duration> times) {
    if (times.isEmpty) return Duration.zero;

    final totalMicroseconds =
        times.map((t) => t.inMicroseconds).reduce((a, b) => a + b);

    return Duration(microseconds: totalMicroseconds ~/ times.length);
  }

  /// Calcula un percentil de una cola de duraciones
  Duration _calculatePercentile(Queue<Duration> times, double percentile) {
    if (times.isEmpty) return Duration.zero;

    final sortedTimes = List<Duration>.from(times)
      ..sort((a, b) => a.compareTo(b));

    final index = (sortedTimes.length * percentile)
        .floor()
        .clamp(0, sortedTimes.length - 1);

    return sortedTimes[index];
  }

  /// Inicia el timer de limpieza periódica
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupOldData();
    });
  }

  /// Limpia datos antiguos fuera de la ventana de métricas
  void _cleanupOldData() {
    // En esta implementación simplificada, solo limitamos por número de muestras
    // En una implementación completa, se podría filtrar por tiempo

    // Las colas ya están limitadas por _maxSamples en _addTimeToQueue
    // Aquí podríamos agregar lógica adicional si fuera necesario
  }

  /// Reinicia todas las métricas
  void reset() {
    _totalRequests = 0;
    _memoryCacheHits = 0;
    _diskCacheHits = 0;
    _networkDownloads = 0;
    _failedRequests = 0;

    _loadTimes.clear();
    _memoryCacheAccessTimes.clear();
    _diskCacheAccessTimes.clear();
    _downloadTimes.clear();

    _metricsStartTime = DateTime.now();

    _logger.info('🔄 Métricas de rendimiento reiniciadas');
  }

  /// Genera un reporte detallado de rendimiento
  String generateReport() {
    final stats = getStats();
    final buffer = StringBuffer();

    buffer.writeln('=== REPORTE DE RENDIMIENTO DEL CACHÉ DE IMÁGENES ===');
    buffer.writeln('Tiempo activo: ${_formatDuration(stats.uptime)}');
    buffer.writeln('Tamaño de muestra: ${stats.sampleSize}');
    buffer.writeln();

    buffer.writeln('SOLICITUDES:');
    buffer.writeln('  Total: ${stats.totalRequests}');
    buffer.writeln('  Exitosas: ${stats.totalRequests - stats.failedRequests}');
    buffer.writeln('  Fallidas: ${stats.failedRequests}');
    buffer.writeln(
        '  Tasa de error: ${(stats.failureRate * 100).toStringAsFixed(2)}%');
    buffer.writeln();

    buffer.writeln('CACHÉ:');
    buffer.writeln(
        '  Hits memoria: ${stats.memoryCacheHits} (${(stats.memoryCacheHitRate * 100).toStringAsFixed(2)}%)');
    buffer.writeln(
        '  Hits disco: ${stats.diskCacheHits} (${(stats.diskCacheHitRate * 100).toStringAsFixed(2)}%)');
    buffer.writeln('  Descargas red: ${stats.networkDownloads}');
    buffer.writeln(
        '  Hit rate total: ${(stats.overallCacheHitRate * 100).toStringAsFixed(2)}%');
    buffer.writeln();

    buffer.writeln('TIEMPOS DE RESPUESTA:');
    buffer
        .writeln('  Promedio carga: ${_formatDuration(stats.averageLoadTime)}');
    buffer.writeln(
        '  Promedio memoria: ${_formatDuration(stats.averageMemoryCacheAccessTime)}');
    buffer.writeln(
        '  Promedio disco: ${_formatDuration(stats.averageDiskCacheAccessTime)}');
    buffer.writeln(
        '  Promedio descarga: ${_formatDuration(stats.averageDownloadTime)}');
    buffer.writeln();

    buffer.writeln('PERCENTILES CARGA:');
    buffer.writeln('  P50: ${_formatDuration(stats.loadTimeP50)}');
    buffer.writeln('  P90: ${_formatDuration(stats.loadTimeP90)}');
    buffer.writeln('  P95: ${_formatDuration(stats.loadTimeP95)}');

    return buffer.toString();
  }

  /// Formatea una duración para display
  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds}ms';
    } else {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)}s';
    }
  }

  /// Evalúa si las métricas indican buena performance
  PerformanceAssessment assessPerformance() {
    final stats = getStats();
    final issues = <String>[];

    // Evaluar tasa de hit del caché
    if (stats.overallCacheHitRate < 0.7) {
      issues.add(
          'Baja tasa de hit del caché (${(stats.overallCacheHitRate * 100).toStringAsFixed(1)}%)');
    }

    // Evaluar tasa de errores
    if (stats.failureRate > 0.05) {
      issues.add(
          'Alta tasa de errores (${(stats.failureRate * 100).toStringAsFixed(1)}%)');
    }

    // Evaluar tiempo de carga
    if (stats.loadTimeP95.inMilliseconds > 2000) {
      issues.add(
          'Tiempo de carga P95 alto (${stats.loadTimeP95.inMilliseconds}ms)');
    }

    // Evaluar tiempo promedio
    if (stats.averageLoadTime.inMilliseconds > 1000) {
      issues.add(
          'Tiempo promedio de carga alto (${stats.averageLoadTime.inMilliseconds}ms)');
    }

    return PerformanceAssessment(
      isHealthy: issues.isEmpty,
      issues: issues,
      score: _calculatePerformanceScore(stats),
    );
  }

  /// Calcula un score de rendimiento (0-100)
  double _calculatePerformanceScore(PerformanceStats stats) {
    double score = 100.0;

    // Penalizar por baja tasa de hit
    if (stats.overallCacheHitRate < 0.8) {
      score -= (0.8 - stats.overallCacheHitRate) * 100;
    }

    // Penalizar por alta tasa de errores
    score -= stats.failureRate * 500; // 50 puntos por 10% de errores

    // Penalizar por tiempos lentos
    if (stats.averageLoadTime.inMilliseconds > 500) {
      score -= (stats.averageLoadTime.inMilliseconds - 500) * 0.05;
    }

    return score.clamp(0.0, 100.0);
  }

  /// Libera recursos
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _logger.info('🧹 ImageCachePerformanceMetrics disposed');
  }
}

/// Estadísticas de rendimiento
class PerformanceStats {
  const PerformanceStats({
    required this.totalRequests,
    required this.memoryCacheHits,
    required this.diskCacheHits,
    required this.networkDownloads,
    required this.failedRequests,
    required this.memoryCacheHitRate,
    required this.diskCacheHitRate,
    required this.overallCacheHitRate,
    required this.failureRate,
    required this.averageLoadTime,
    required this.averageMemoryCacheAccessTime,
    required this.averageDiskCacheAccessTime,
    required this.averageDownloadTime,
    required this.loadTimeP50,
    required this.loadTimeP90,
    required this.loadTimeP95,
    required this.uptime,
    required this.sampleSize,
  });

  final int totalRequests;
  final int memoryCacheHits;
  final int diskCacheHits;
  final int networkDownloads;
  final int failedRequests;

  final double memoryCacheHitRate;
  final double diskCacheHitRate;
  final double overallCacheHitRate;
  final double failureRate;

  final Duration averageLoadTime;
  final Duration averageMemoryCacheAccessTime;
  final Duration averageDiskCacheAccessTime;
  final Duration averageDownloadTime;

  final Duration loadTimeP50;
  final Duration loadTimeP90;
  final Duration loadTimeP95;

  final Duration uptime;
  final int sampleSize;
}

/// Evaluación de rendimiento
class PerformanceAssessment {
  const PerformanceAssessment({
    required this.isHealthy,
    required this.issues,
    required this.score,
  });

  final bool isHealthy;
  final List<String> issues;
  final double score; // 0-100

  String get healthStatus {
    if (score >= 90) return 'Excelente';
    if (score >= 75) return 'Bueno';
    if (score >= 60) return 'Regular';
    if (score >= 40) return 'Pobre';
    return 'Crítico';
  }
}
