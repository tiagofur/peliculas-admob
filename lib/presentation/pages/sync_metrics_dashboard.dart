import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/services/sync_performance_metrics.dart';

class SyncMetricsDashboard extends StatefulWidget {
  const SyncMetricsDashboard({super.key});

  @override
  State<SyncMetricsDashboard> createState() => _SyncMetricsDashboardState();
}

class _SyncMetricsDashboardState extends State<SyncMetricsDashboard>
    with TickerProviderStateMixin {
  late StreamSubscription<MetricsSnapshot> _metricsSubscription;
  MetricsSnapshot? _currentMetrics;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<FlSpot> _performanceHistory = [];
  final List<FlSpot> _networkStabilityHistory = [];
  final List<FlSpot> _syncRateHistory = [];

  int _chartDataPoints = 0;
  static const int maxDataPoints = 50;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initializeMetrics();
    _animationController.forward();
  }

  void _initializeMetrics() {
    final metricsService = SyncPerformanceMetrics.instance;
    _currentMetrics = metricsService.getSnapshot();

    _metricsSubscription = metricsService.metricsStream.listen((snapshot) {
      if (mounted) {
        setState(() {
          _currentMetrics = snapshot;
          _updateChartData(snapshot);
        });
      }
    });
  }

  void _updateChartData(MetricsSnapshot snapshot) {
    final x = _chartDataPoints.toDouble();

    _performanceHistory.add(FlSpot(x, snapshot.performanceScore * 100));
    _networkStabilityHistory.add(FlSpot(x, snapshot.networkStability * 100));
    _syncRateHistory.add(FlSpot(x, snapshot.successRate * 100));

    // Mantener solo los últimos puntos de datos
    if (_performanceHistory.length > maxDataPoints) {
      _performanceHistory.removeAt(0);
      _networkStabilityHistory.removeAt(0);
      _syncRateHistory.removeAt(0);

      // Reajustar coordenadas X
      for (int i = 0; i < _performanceHistory.length; i++) {
        _performanceHistory[i] = FlSpot(i.toDouble(), _performanceHistory[i].y);
        _networkStabilityHistory[i] =
            FlSpot(i.toDouble(), _networkStabilityHistory[i].y);
        _syncRateHistory[i] = FlSpot(i.toDouble(), _syncRateHistory[i].y);
      }
    }

    _chartDataPoints++;
  }

  @override
  void dispose() {
    _metricsSubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard de Métricas de Sincronización'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              SyncPerformanceMetrics.instance.reset();
              setState(() {
                _performanceHistory.clear();
                _networkStabilityHistory.clear();
                _syncRateHistory.clear();
                _chartDataPoints = 0;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportMetrics,
          ),
        ],
      ),
      body: _currentMetrics == null
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCards(),
                    const SizedBox(height: 24),
                    _buildPerformanceChart(),
                    const SizedBox(height: 24),
                    _buildRealtimeMetrics(),
                    const SizedBox(height: 24),
                    _buildEntityMetrics(),
                    const SizedBox(height: 24),
                    _buildNetworkMetrics(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    final metrics = _currentMetrics;
    if (metrics == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen General',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Score de Rendimiento',
                '${(metrics.performanceScore * 100).toStringAsFixed(1)}%',
                _getScoreColor(metrics.performanceScore),
                Icons.speed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Tasa de Éxito',
                '${(metrics.successRate * 100).toStringAsFixed(1)}%',
                _getSuccessColor(metrics.successRate),
                Icons.check_circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Estado de Red',
                metrics.isOnline ? 'Online' : 'Offline',
                metrics.isOnline ? Colors.green : Colors.red,
                metrics.isOnline ? Icons.wifi : Icons.wifi_off,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Conflictos Resueltos',
                '${metrics.conflictsResolved}/${metrics.conflictsDetected}',
                _getConflictColor(metrics.conflictResolutionRate),
                Icons.merge_type,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tendencias de Rendimiento',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _performanceHistory.isEmpty
                  ? const Center(
                      child: Text('Esperando datos de rendimiento...'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 20,
                          verticalInterval: 10,
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 10,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 4,
                                  child: Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 20,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 4,
                                  child: Text(
                                    '${value.toInt()}%',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        minX: 0,
                        maxX: max(maxDataPoints.toDouble() - 1,
                            _performanceHistory.length.toDouble()),
                        minY: 0,
                        maxY: 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _performanceHistory,
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.shade100,
                            ),
                          ),
                          LineChartBarData(
                            spots: _networkStabilityHistory,
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                          ),
                          LineChartBarData(
                            spots: _syncRateHistory,
                            isCurved: true,
                            color: Colors.orange,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Rendimiento', Colors.blue),
                _buildLegendItem('Estabilidad Red', Colors.green),
                _buildLegendItem('Tasa Éxito', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRealtimeMetrics() {
    final metrics = _currentMetrics;
    if (metrics == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métricas en Tiempo Real',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Eventos Recibidos',
                    metrics.realtimeEventsReceived.toString(),
                    Icons.input,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Eventos Procesados',
                    metrics.realtimeEventsProcessed.toString(),
                    Icons.done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Eventos Throttled',
                    metrics.throttledEvents.toString(),
                    Icons.speed,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Tiempo Promedio',
                    '${metrics.averageRealtimeProcessingTime.inMilliseconds}ms',
                    Icons.timer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: metrics.realtimeProcessingRate,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProcessingRateColor(metrics.realtimeProcessingRate),
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

  Widget _buildEntityMetrics() {
    final metrics = _currentMetrics;
    if (metrics == null) return const SizedBox.shrink();

    if (metrics.entityMetrics.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métricas por Entidad',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...metrics.entityMetrics.entries.map((entry) {
              final entityMetrics = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ExpansionTile(
                  title: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Éxito: ${(entityMetrics.successRate * 100).toStringAsFixed(1)}% | '
                    'Eventos RT: ${entityMetrics.realtimeEventsProcessed}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  'Operaciones',
                                  '${entityMetrics.successfulOperations}/${entityMetrics.operationsStarted}',
                                  Icons.analytics,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'Conflictos',
                                  '${entityMetrics.conflictsResolved}/${entityMetrics.conflictsDetected}',
                                  Icons.warning,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  'Tiempo Promedio',
                                  '${entityMetrics.averageProcessingTime.inMilliseconds}ms',
                                  Icons.access_time,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'Throttled',
                                  entityMetrics.throttledEvents.toString(),
                                  Icons.slow_motion_video,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkMetrics() {
    final metrics = _currentMetrics;
    if (metrics == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métricas de Red',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Reconexiones',
                    metrics.networkReconnections.toString(),
                    Icons.refresh,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Tiempo Offline',
                    '${metrics.totalOfflineTime.inMinutes}min',
                    Icons.cloud_off,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  metrics.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: metrics.isOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Estado: ${metrics.isOnline ? "Conectado" : "Desconectado"}',
                  style: TextStyle(
                    color: metrics.isOnline ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: metrics.networkStability,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getStabilityColor(metrics.networkStability),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Estabilidad de Red: ${(metrics.networkStability * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Color _getSuccessColor(double rate) {
    if (rate >= 0.95) return Colors.green;
    if (rate >= 0.8) return Colors.orange;
    return Colors.red;
  }

  Color _getConflictColor(double rate) {
    if (rate >= 0.9) return Colors.green;
    if (rate >= 0.7) return Colors.orange;
    return Colors.red;
  }

  Color _getProcessingRateColor(double rate) {
    if (rate >= 0.95) return Colors.green;
    if (rate >= 0.8) return Colors.orange;
    return Colors.red;
  }

  Color _getStabilityColor(double stability) {
    if (stability >= 0.9) return Colors.green;
    if (stability >= 0.7) return Colors.orange;
    return Colors.red;
  }

  void _exportMetrics() {
    final metrics = SyncPerformanceMetrics.instance;
    final report = metrics.generatePerformanceReport();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reporte de Métricas'),
        content: SingleChildScrollView(
          child: Text(
            report,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
