import 'package:flutter/material.dart';

import '../../core/error_reporting/error_reporting_service.dart';
import '../../services/error_reporting_config.dart';

/// Debug widget to show error reporting status and controls
/// Should only be shown in debug builds
class ErrorReportingDebugWidget extends StatefulWidget {
  const ErrorReportingDebugWidget({Key? key}) : super(key: key);

  @override
  State<ErrorReportingDebugWidget> createState() => _ErrorReportingDebugWidgetState();
}

class _ErrorReportingDebugWidgetState extends State<ErrorReportingDebugWidget> {
  late ErrorReportingService _errorReporting;
  late ErrorReportingConfig _config;
  Map<String, dynamic> _configData = {};

  @override
  void initState() {
    super.initState();
    _errorReporting = ErrorReportingService.instance;
    _config = ErrorReportingConfig.instance;
    _loadConfigData();
  }

  Future<void> _loadConfigData() async {
    setState(() {
      _configData = _config.currentConfig;
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
            _buildStatusRow('Service Initialized', _errorReporting.isInitialized),
            _buildStatusRow('Service Available', _errorReporting.isAvailable),
            _buildStatusRow('Config Initialized', _configData['initialized'] ?? false),
            _buildStatusRow('Currently Enabled', _configData['isEnabled'] ?? false),
            _buildStatusRow('User Opt-in', _configData['userOptIn'] ?? false),
            _buildStatusRow('Config Enabled', _configData['configEnabled'] ?? false),
            
            const SizedBox(height: 16),
            Text('Build Mode: ${_configData['buildMode'] ?? 'unknown'}'),
            
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
                  child: Text(_config.userOptIn ? 'Disable User Opt-in' : 'Enable User Opt-in'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _config.setEnabled(!_config.configEnabled);
                    await _loadConfigData();
                  },
                  child: Text(_config.configEnabled ? 'Disable Config' : 'Enable Config'),
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
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
}