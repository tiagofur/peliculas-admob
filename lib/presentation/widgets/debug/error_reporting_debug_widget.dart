import 'package:flutter/material.dart';

import '../../../core/error_reporting/error_metrics_service.dart';
import '../../../core/error_reporting/error_reporting_service.dart';
import '../../../services/error_reporting_config.dart';

/// Debug widget to show error reporting status and controls
/// Should only be shown in debug builds
class ErrorReportingDebugWidget extends StatefulWidget {
  const ErrorReportingDebugWidget({super.key});

  @override
  State<ErrorReportingDebugWidget> createState() =>
      _ErrorReportingDebugWidgetState();
}

class _ErrorReportingDebugWidgetState extends State<ErrorReportingDebugWidget> {
  late ErrorReportingService _errorReporting;
  late ErrorReportingConfig _config;
  late ErrorMetricsService _metrics;
  Map<String, dynamic> _configData = {};
  Map<String, dynamic> _metricsData = {};

  @override
  void initState() {
    super.initState();
    _errorReporting = ErrorReportingService.instance;
    _config = ErrorReportingConfig.instance;
    _metrics = ErrorMetricsService.instance;
    _loadConfigData();
  }

  Future<void> _loadConfigData() async {
    setState(() {
      _configData = _config.currentConfig;
      _metricsData = _metrics.metricsSnapshot;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🚨 Error Reporting Debug',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Status indicators
            _buildStatusRow(
                'Service Initialized', _errorReporting.isInitialized),
            _buildStatusRow('Service Available', _errorReporting.isAvailable),
            _buildStatusRow(
                'Config Initialized', _configData['initialized'] ?? false),
            _buildStatusRow(
                'Currently Enabled', _configData['isEnabled'] ?? false),
            _buildStatusRow('User Opt-in', _configData['userOptIn'] ?? false),
            _buildStatusRow(
                'Config Enabled', _configData['configEnabled'] ?? false),

            const SizedBox(height: 16),
            Text('Build Mode: ${_configData['buildMode'] ?? 'unknown'}'),

            const SizedBox(height: 16),

            // Metrics section
            const Text(
              '📊 Success Criteria Metrics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildMetricsSection(),

            const SizedBox(height: 16),

            // Controls
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _config.setUserOptIn(!_config.userOptIn);
                    await _loadConfigData();
                  },
                  child: Text(_config.userOptIn
                      ? 'Disable User Opt-in'
                      : 'Enable User Opt-in'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _config.setEnabled(!_config.configEnabled);
                    await _loadConfigData();
                  },
                  child: Text(_config.configEnabled
                      ? 'Disable Config'
                      : 'Enable Config'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _errorReporting.reportError(
                      'Test error from debug widget',
                      StackTrace.current,
                      reason: 'Debug widget test',
                      data: {
                        'test_type': 'manual',
                        'timestamp': DateTime.now().toIso8601String(),
                      },
                      fatal: false,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test error reported')),
                    );
                  },
                  child: const Text('Test Error Report'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _errorReporting.testCrash();
                  },
                  child: const Text('Test Crash (Debug Only)'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _loadConfigData();
                  },
                  child: const Text('Refresh Status'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _metrics.recordCoreFlowAttempt();
                    await _loadConfigData();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Test core flow attempt recorded')),
                    );
                  },
                  child: const Text('Test Core Flow Attempt'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _metrics.recordCoreFlowError('authentication');
                    await _loadConfigData();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Test core flow error recorded')),
                    );
                  },
                  child: const Text('Test Core Flow Error'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _metrics.reset();
                    await _loadConfigData();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Metrics reset')),
                    );
                  },
                  child: const Text('Reset Metrics'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Raw config data
            ExpansionTile(
              title: const Text('Raw Configuration'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _configData.toString(),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            status ? 'Yes' : 'No',
            style: TextStyle(
              color: status ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    if (!_metricsData['initialized']) {
      return const Text('Metrics not initialized',
          style: TextStyle(color: Colors.grey));
    }

    final sessionMetrics =
        _metricsData['session_metrics'] as Map<String, dynamic>?;
    final coreFlowMetrics =
        _metricsData['core_flow_metrics'] as Map<String, dynamic>?;

    if (sessionMetrics == null || coreFlowMetrics == null) {
      return const Text('Metrics data unavailable',
          style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Crash-free sessions
        _buildMetricRow(
          '🛡️ Crash-free Sessions',
          '${sessionMetrics['crash_free_percentage']}%',
          sessionMetrics['meets_crash_free_criteria'] ?? false,
          'Target: ≥${sessionMetrics['crash_free_target']}%',
        ),
        const SizedBox(height: 4),
        Text(
          '   Sessions: ${sessionMetrics['total_sessions']} total, ${sessionMetrics['crash_sessions']} crashed',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),

        const SizedBox(height: 12),

        // Core flow error rate
        _buildMetricRow(
          '⚡ Core Flow Error Rate',
          '${coreFlowMetrics['error_rate_percentage']}%',
          coreFlowMetrics['meets_error_rate_criteria'] ?? false,
          'Target: <${coreFlowMetrics['error_rate_target']}%',
        ),
        const SizedBox(height: 4),
        Text(
          '   Attempts: ${coreFlowMetrics['total_attempts']} total, ${coreFlowMetrics['total_errors']} errors',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMetricRow(
      String label, String value, bool meetsTarget, String targetText) {
    return Row(
      children: [
        Icon(
          meetsTarget ? Icons.check_circle : Icons.warning,
          color: meetsTarget ? Colors.green : Colors.orange,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              Text(
                targetText,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: meetsTarget ? Colors.green : Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
