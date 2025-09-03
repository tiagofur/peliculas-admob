import 'package:flutter/material.dart';

import '../core/monetization/ad_frequency_controller.dart';
import '../core/monetization/monetization_analytics_service.dart';
import '../core/monetization/monetization_initializer.dart';
import '../presentation/widgets/admob/controlled_ad_widget.dart';

/// Ejemplo de integración del sistema de monetización optimizado
class MonetizationIntegrationExample extends StatefulWidget {
  const MonetizationIntegrationExample({super.key});

  @override
  State<MonetizationIntegrationExample> createState() =>
      _MonetizationIntegrationExampleState();
}

class _MonetizationIntegrationExampleState
    extends State<MonetizationIntegrationExample> {
  final MonetizationInitializer _initializer = MonetizationInitializer.instance;
  final AdFrequencyController _controller = AdFrequencyController.instance;
  final MonetizationAnalyticsService _analytics =
      MonetizationAnalyticsService.instance;

  Map<String, dynamic>? _systemStatus;
  DetailedMonetizationMetrics? _metrics;
  MonetizationHealthCheck? _healthCheck;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final status = _initializer.getSystemStatus();
      final metrics = await _analytics.getDetailedMetrics();
      final healthCheck = await _initializer.performHealthCheck();

      setState(() {
        _systemStatus = status;
        _metrics = metrics;
        _healthCheck = healthCheck;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monetización - Sistema Optimizado'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSystemStatusCard(),
                  const SizedBox(height: 16),
                  _buildHealthCheckCard(),
                  const SizedBox(height: 16),
                  _buildMetricsCard(),
                  const SizedBox(height: 16),
                  _buildAdExamplesCard(),
                  const SizedBox(height: 16),
                  _buildConfigurationCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado del Sistema',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_systemStatus != null) ...[
              _buildStatusRow(
                  'Inicializado', _systemStatus?['initialized'] ?? false),
              const SizedBox(height: 8),
              Text(
                  'Sesión: ${_controller.getSessionStats()['sessionId'] ?? 'N/A'}'),
              Text(
                  'Anuncios en sesión: ${_controller.getSessionStats()['sessionAdCount'] ?? 0}'),
              Text(
                  'Clicks en sesión: ${_controller.getSessionStats()['sessionClickCount'] ?? 0}'),
            ] else
              const Text('Cargando estado del sistema...'),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCheckCard() {
    final healthCheck = _healthCheck;
    if (healthCheck == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Cargando verificación de salud...'),
        ),
      );
    }

    Color statusColor;
    IconData statusIcon;
    switch (healthCheck.status) {
      case MonetizationHealthStatus.healthy:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case MonetizationHealthStatus.warning:
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case MonetizationHealthStatus.critical:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case MonetizationHealthStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'Salud del Sistema',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                'Puntuación: ${(healthCheck.overallScore * 100).toStringAsFixed(1)}%'),
            Text('Estado: ${healthCheck.status.name.toUpperCase()}'),
            if (healthCheck.hasIssues) ...[
              const SizedBox(height: 8),
              const Text('Problemas detectados:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...healthCheck.issues.map((issue) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(issue)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard() {
    final metrics = _metrics;
    if (metrics == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Cargando métricas...'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Métricas de Monetización',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Impresiones',
                    metrics.totalImpressions.toString(),
                    Icons.visibility,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Clicks',
                    metrics.totalClicks.toString(),
                    Icons.touch_app,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'CTR',
                    '${(metrics.ctr * 100).toStringAsFixed(2)}%',
                    Icons.trending_up,
                    isHealthy: metrics.isCTRHealthy,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Revenue',
                    '\$${metrics.estimatedRevenue.toStringAsFixed(2)}',
                    Icons.attach_money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'UX Score',
                    '${(metrics.userExperienceScore * 100).toStringAsFixed(1)}%',
                    Icons.sentiment_satisfied,
                    isHealthy: metrics.isUserExperienceHealthy,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Error Rate',
                    '${(metrics.errorRate * 100).toStringAsFixed(1)}%',
                    Icons.error_outline,
                    isHealthy: metrics.isErrorRateHealthy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon,
      {bool? isHealthy}) {
    Color? color;
    if (isHealthy != null) {
      color = isHealthy ? Colors.green : Colors.red;
    }

    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAdExamplesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ejemplos de Anuncios Controlados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Banner Ad Example
            const Text('Banner Ad con Control de Frecuencia:'),
            const SizedBox(height: 8),
            ControlledBannerAd(
              onAdShown: () => _showSnackBar('Banner ad mostrado'),
              onAdBlocked: (reason) =>
                  _showSnackBar('Banner ad bloqueado: ${reason.name}'),
            ),

            const SizedBox(height: 16),

            // Native Ad Example
            const Text('Native Ad con Control de Frecuencia:'),
            const SizedBox(height: 8),
            ControlledNativeAd(
              height: 100,
              showLabel: true,
              onAdShown: () => _showSnackBar('Native ad mostrado'),
              onAdBlocked: (reason) =>
                  _showSnackBar('Native ad bloqueado: ${reason.name}'),
            ),

            const SizedBox(height: 16),

            // Grid Ad Example
            const Text('Grid Ad con Control de Frecuencia:'),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ControlledGridAd(
                aspectRatio: 1.0,
                showLabel: true,
                onAdShown: () => _showSnackBar('Grid ad mostrado'),
                onAdBlocked: (reason) =>
                    _showSnackBar('Grid ad bloqueado: ${reason.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuración',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  _updateConfig(MonetizationInitializer.conservativeConfig),
              child: const Text('Configuración Conservadora'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  _updateConfig(MonetizationInitializer.balancedConfig),
              child: const Text('Configuración Balanceada'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  _updateConfig(MonetizationInitializer.aggressiveConfig),
              child: const Text('Configuración Agresiva'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _triggerUserInteraction,
              child: const Text('Simular Interacción de Usuario'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _resetSystem,
              child: const Text('Reiniciar Sistema'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Row(
      children: [
        Icon(
          status ? Icons.check_circle : Icons.cancel,
          color: status ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text('$label: ${status ? 'Sí' : 'No'}'),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _updateConfig(AdFrequencyConfig config) async {
    try {
      await _initializer.updateConfig(config);
      _showSnackBar('Configuración actualizada');
      await _loadData();
    } catch (e) {
      _showSnackBar('Error actualizando configuración: $e');
    }
  }

  void _triggerUserInteraction() {
    _controller.recordUserInteraction();
    _showSnackBar('Interacción de usuario registrada - cooldown activado');
  }

  Future<void> _resetSystem() async {
    try {
      await _initializer.reset();
      _showSnackBar('Sistema reiniciado');
      await _loadData();
    } catch (e) {
      _showSnackBar('Error reiniciando sistema: $e');
    }
  }
}
