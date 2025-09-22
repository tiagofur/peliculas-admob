import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/sync_performance_metrics.dart';
import '../../l10n/app_localizations.dart';

/// Dashboard en tiempo real para monitorear el rendimiento de sincronización
/// Cumple con los requisitos del issue #69 para verificación de latencia
class RealtimeSyncDashboard extends ConsumerStatefulWidget {
  const RealtimeSyncDashboard({super.key});

  @override
  ConsumerState<RealtimeSyncDashboard> createState() =>
      _RealtimeSyncDashboardState();
}

class _RealtimeSyncDashboardState extends ConsumerState<RealtimeSyncDashboard> {
  late StreamSubscription<MetricsSnapshot> _metricsSubscription;
  MetricsSnapshot? _currentMetrics;
  final List<_LatencyDataPoint> _latencyHistory = [];
  final List<_EventDataPoint> _eventHistory = [];

  // Configuración de alertas según issue #69
  static const Duration _latencyThreshold =
      Duration(milliseconds: 1500); // < 1.5s requirement
  static const int _maxHistoryPoints = 50;

  @override
  void initState() {
    super.initState();
    _startMetricsSubscription();
  }

  @override
  void dispose() {
    _metricsSubscription.cancel();
    super.dispose();
  }

  void _startMetricsSubscription() {
    _metricsSubscription = SyncPerformanceMetrics.instance.metricsStream.listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _currentMetrics = snapshot;
            _updateLatencyHistory(snapshot);
            _updateEventHistory(snapshot);
          });
        }
      },
    );
  }

  void _updateLatencyHistory(MetricsSnapshot snapshot) {
    final now = DateTime.now();
    _latencyHistory.add(_LatencyDataPoint(
      timestamp: now,
      syncLatency: snapshot.averageSyncDuration,
      realtimeLatency: snapshot.averageRealtimeProcessingTime,
    ));

    // Mantener solo los últimos N puntos
    while (_latencyHistory.length > _maxHistoryPoints) {
      _latencyHistory.removeAt(0);
    }
  }

  void _updateEventHistory(MetricsSnapshot snapshot) {
    final now = DateTime.now();
    _eventHistory.add(_EventDataPoint(
      timestamp: now,
      realtimeEvents: snapshot.realtimeEventsReceived,
      throttledEvents: snapshot.throttledEvents,
      conflicts: snapshot.conflictsDetected,
    ));

    // Mantener solo los últimos N puntos
    while (_eventHistory.length > _maxHistoryPoints) {
      _eventHistory.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMetrics == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.realtimeSyncDashboard ??
            'Realtime Sync Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusOverview(),
            const SizedBox(height: 24),
            _buildLatencySection(),
            const SizedBox(height: 24),
            _buildRealtimeEventsSection(),
            const SizedBox(height: 24),
            _buildConflictResolutionSection(),
            const SizedBox(height: 24),
            _buildEntityMetricsSection(),
            const SizedBox(height: 24),
            _buildNetworkStabilitySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverview() {
    final metrics = _currentMetrics;
    if (metrics == null) return const SizedBox.shrink();
    final isHealthy = _isSystemHealthy(metrics);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isHealthy ? Icons.check_circle : Icons.warning,
                  color: isHealthy ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)?.systemStatus ?? 'System Status',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    AppLocalizations.of(context)?.performanceScore ??
                        'Performance Score',
                    '${(metrics.performanceScore * 100).toStringAsFixed(1)}%',
                    _getScoreColor(metrics.performanceScore),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    AppLocalizations.of(context)?.connectionStatus ??
                        'Connection Status',
                    metrics.isOnline
                        ? (AppLocalizations.of(context)?.online ?? 'Online')
                        : (AppLocalizations.of(context)?.offline ?? 'Offline'),
                    metrics.isOnline ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatencySection() {
    final metrics = _currentMetrics;
    if (metrics == null) return const SizedBox.shrink();
    final avgSyncMs = metrics.averageSyncDuration.inMilliseconds;
    final avgRealtimeMs = metrics.averageRealtimeProcessingTime.inMilliseconds;

    // Alertas de latencia según requisitos del issue #69
    final syncLatencyAlert = avgSyncMs > _latencyThreshold.inMilliseconds;
    final realtimeLatencyAlert =
        avgRealtimeMs > _latencyThreshold.inMilliseconds;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.syncLatency ?? 'Sync Latency',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.latencyTarget ??
                  'Target: < 1.5 seconds (Issue #69 requirement)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    AppLocalizations.of(context)?.avgSync ?? 'Avg Sync',
                    '${avgSyncMs}ms',
                    syncLatencyAlert ? Colors.red : Colors.green,
                    alert: syncLatencyAlert,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    AppLocalizations.of(context)?.avgRealtime ?? 'Avg Realtime',
                    '${avgRealtimeMs}ms',
                    realtimeLatencyAlert ? Colors.red : Colors.green,
                    alert: realtimeLatencyAlert,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLatencyChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeEventsSection() {
    final metrics = _currentMetrics;
    if (metrics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.realtimeEvents ?? 'Realtime Events',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    AppLocalizations.of(context)?.eventsReceived ??
                        'Events Received',
                    '${metrics.realtimeEventsReceived}',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Eventos Procesados',
                    '${metrics.realtimeEventsProcessed}',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Eventos Throttled',
                    '${metrics.throttledEvents}',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: metrics.realtimeProcessingRate,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                metrics.realtimeProcessingRate > 0.95
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tasa de Procesamiento: ${(metrics.realtimeProcessingRate * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictResolutionSection() {
    final metrics = _currentMetrics;
    if (metrics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resolución de Conflictos',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Estrategia: Last-Write-Wins (updated_at)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Conflictos Detectados',
                    '${metrics.conflictsDetected}',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Conflictos Resueltos',
                    '${metrics.conflictsResolved}',
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (metrics.conflictsDetected > 0) ...[
              LinearProgressIndicator(
                value: metrics.conflictResolutionRate,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  metrics.conflictResolutionRate > 0.95
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tasa de Resolución: ${(metrics.conflictResolutionRate * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEntityMetricsSection() {
    final metrics = _currentMetrics;
    if (metrics == null) return const SizedBox.shrink();
    final watchlistMetrics = metrics.entityMetrics['user_watchlist'];
    final ratingsMetrics = metrics.entityMetrics['user_movie_ratings'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métricas por Entidad',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (watchlistMetrics != null) ...[
              _buildEntityCard('Watchlist', watchlistMetrics),
              const SizedBox(height: 12),
            ],
            if (ratingsMetrics != null) ...[
              _buildEntityCard('Ratings', ratingsMetrics),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEntityCard(String entityName, EntityMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entityName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSmallMetric(
                    'Sync Ops', '${metrics.operationsStarted}'),
              ),
              Expanded(
                child: _buildSmallMetric(
                    'Success', '${metrics.successfulOperations}'),
              ),
              Expanded(
                child: _buildSmallMetric(
                    'Realtime', '${metrics.realtimeEventsReceived}'),
              ),
              Expanded(
                child: _buildSmallMetric(
                    'Conflicts', '${metrics.conflictsDetected}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkStabilitySection() {
    final metrics = _currentMetrics;
    if (metrics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estabilidad de Red',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Estabilidad',
                    '${(metrics.networkStability * 100).toStringAsFixed(1)}%',
                    _getStabilityColor(metrics.networkStability),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Reconexiones',
                    '${metrics.networkReconnections}',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSmallMetric(
              'Tiempo Offline Total',
              _formatDuration(metrics.totalOfflineTime),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatencyChart() {
    if (_latencyHistory.length < 2) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('Recopilando datos de latencia...'),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: CustomPaint(
        painter: _LatencyChartPainter(_latencyHistory, _latencyThreshold),
        size: const Size.fromHeight(100),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color,
      {bool alert = false}) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1 * 255),
        border: Border.all(
          color: alert ? Colors.red : color,
          width: alert ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (alert) ...[
                const Icon(Icons.warning, color: Colors.red, size: 16),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: alert ? Colors.red : color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetric(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  bool _isSystemHealthy(MetricsSnapshot metrics) {
    return metrics.performanceScore > 0.8 &&
        metrics.isOnline &&
        metrics.averageSyncDuration < _latencyThreshold &&
        metrics.averageRealtimeProcessingTime < _latencyThreshold;
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Color _getStabilityColor(double stability) {
    if (stability >= 0.9) return Colors.green;
    if (stability >= 0.7) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ${seconds % 60}s';
    final hours = minutes ~/ 60;
    return '${hours}h ${minutes % 60}m';
  }
}

/// Clase para almacenar puntos de datos de latencia
class _LatencyDataPoint {
  _LatencyDataPoint({
    required this.timestamp,
    required this.syncLatency,
    required this.realtimeLatency,
  });
  final DateTime timestamp;
  final Duration syncLatency;
  final Duration realtimeLatency;
}

/// Clase para almacenar puntos de datos de eventos
class _EventDataPoint {
  _EventDataPoint({
    required this.timestamp,
    required this.realtimeEvents,
    required this.throttledEvents,
    required this.conflicts,
  });
  final DateTime timestamp;
  final int realtimeEvents;
  final int throttledEvents;
  final int conflicts;
}

/// Custom painter para el gráfico de latencia
class _LatencyChartPainter extends CustomPainter {
  _LatencyChartPainter(this.dataPoints, this.threshold);
  final List<_LatencyDataPoint> dataPoints;
  final Duration threshold;

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final thresholdPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5 * 255)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Línea de threshold
    final thresholdY =
        size.height - (threshold.inMilliseconds / 3000.0) * size.height;
    canvas.drawLine(
      Offset(0, thresholdY),
      Offset(size.width, thresholdY),
      thresholdPaint,
    );

    // Datos de sync latency
    paint.color = Colors.blue;
    _drawLatencyLine(canvas, size, paint, (point) => point.syncLatency);

    // Datos de realtime latency
    paint.color = Colors.green;
    _drawLatencyLine(canvas, size, paint, (point) => point.realtimeLatency);
  }

  void _drawLatencyLine(Canvas canvas, Size size, Paint paint,
      Duration Function(_LatencyDataPoint) getValue) {
    final path = Path();
    final stepX = size.width / (dataPoints.length - 1);

    for (int i = 0; i < dataPoints.length; i++) {
      final latency = getValue(dataPoints[i]);
      final x = i * stepX;
      final y = size.height - (latency.inMilliseconds / 3000.0) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
