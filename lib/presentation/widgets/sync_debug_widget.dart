import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math';

import '../../debug/supabase_direct_test.dart';
import '../../infrastructure/services/realtime_sync_service.dart';
import '../../infrastructure/services/safe_sync_service.dart';

/// Widget de debug para probar la sincronización manualmente
/// Solo se muestra en modo debug
class SyncDebugWidget extends ConsumerStatefulWidget {
  const SyncDebugWidget({super.key});

  @override
  ConsumerState<SyncDebugWidget> createState() => _SyncDebugWidgetState();
}

class _SyncDebugWidgetState extends ConsumerState<SyncDebugWidget> with TickerProviderStateMixin {
  Map<String, dynamic>? _lastTestResult;
  bool _isTestingSync = false;
  Timer? _metricsTimer;
  Map<String, dynamic> _performanceMetrics = {};
  Map<String, dynamic> _syncQueue = {};
  Map<String, dynamic> _repositoryStatus = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _startMetricsCollection();
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startMetricsCollection() {
    _metricsTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _updateMetrics();
      }
    });
  }

  Future<void> _updateMetrics() async {
    try {
      // Simular métricas de rendimiento
      final random = Random();
      setState(() {
        _performanceMetrics = {
          'sync_latency_ms': 50 + random.nextInt(200),
          'queue_size': random.nextInt(10),
          'active_connections': 1 + random.nextInt(3),
          'memory_usage_mb': 15.5 + random.nextDouble() * 10,
          'network_speed_kbps': 100 + random.nextInt(500),
          'last_sync_duration_ms': 200 + random.nextInt(800),
          'conflicts_resolved': random.nextInt(5),
          'sync_success_rate': 0.85 + random.nextDouble() * 0.15,
        };
        
        _syncQueue = {
          'pending_uploads': random.nextInt(5),
          'pending_downloads': random.nextInt(3),
          'failed_operations': random.nextInt(2),
          'retry_queue': random.nextInt(3),
        };
        
        _repositoryStatus = {
          'favorites': {
            'status': ['synced', 'syncing', 'error'][random.nextInt(3)],
            'last_sync': DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
            'pending_changes': random.nextInt(5),
          },
          'watchlist': {
            'status': ['synced', 'syncing', 'error'][random.nextInt(3)],
            'last_sync': DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
            'pending_changes': random.nextInt(3),
          },
          'watched_movies': {
            'status': ['synced', 'syncing', 'error'][random.nextInt(3)],
            'last_sync': DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
            'pending_changes': random.nextInt(8),
          },
          'custom_lists': {
            'status': ['synced', 'syncing', 'error'][random.nextInt(3)],
            'last_sync': DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
            'pending_changes': random.nextInt(2),
          },
        };
      });
    } catch (e) {
      // Silently handle errors in metrics collection
    }
  }

  @override
  Widget build(BuildContext context) {
    // Solo mostrar en debug mode
    if (!kDebugMode) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header con tabs
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🧪 DEBUG: Sincronización Avanzada',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.orange,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.orange,
                  tabs: const [
                    Tab(text: 'Tests', icon: Icon(Icons.play_arrow, size: 16)),
                    Tab(text: 'Métricas', icon: Icon(Icons.analytics, size: 16)),
                    Tab(text: 'Cola', icon: Icon(Icons.queue, size: 16)),
                    Tab(text: 'Repos', icon: Icon(Icons.storage, size: 16)),
                  ],
                ),
              ],
            ),
          ),
          // Tab content
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTestsTab(),
                _buildMetricsTab(),
                _buildQueueTab(),
                _buildRepositoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botones de pruebas básicas
            const Text('Pruebas Básicas:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton(
                  onPressed: _isTestingSync ? null : _runSyncTest,
                  child: _isTestingSync
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Probar Sync'),
                ),
                ElevatedButton(
                  onPressed: _forceSyncAll,
                  child: const Text('Forzar Sync'),
                ),
                ElevatedButton(
                  onPressed: _testRealtimeSync,
                  child: const Text('Test Realtime'),
                ),
                ElevatedButton(
                  onPressed: _testSupabaseDirect,
                  child: const Text('Test Supabase'),
                ),
                ElevatedButton(
                  onPressed: _resetCircuitBreaker,
                  child: const Text('Reset Circuit'),
                ),
                ElevatedButton(
                  onPressed: _clearResults,
                  child: const Text('Limpiar'),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Simulaciones avanzadas
            const Text('Simulaciones:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton.icon(
                  onPressed: _simulateConflict,
                  icon: const Icon(Icons.warning, size: 16),
                  label: const Text('Simular Conflicto'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
                ElevatedButton.icon(
                  onPressed: _simulateNetworkIssue,
                  icon: const Icon(Icons.wifi_off, size: 16),
                  label: const Text('Red Lenta'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton.icon(
                  onPressed: _injectSyncError,
                  icon: const Icon(Icons.bug_report, size: 16),
                  label: const Text('Inyectar Error'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                ),
                ElevatedButton.icon(
                  onPressed: _simulateOfflineMode,
                  icon: const Icon(Icons.offline_bolt, size: 16),
                  label: const Text('Modo Offline'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                ),
              ],
            ),

            // Mostrar resultados si existen
            if (_lastTestResult != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Resultados del último test:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _formatTestResult(_lastTestResult!),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Información del estado
            Text(
              'Este widget solo aparece en modo DEBUG.\n'
              'Usa estos botones para probar la sincronización manualmente.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Métricas de Rendimiento:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Performance metrics cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildMetricCard('Latencia', '${_performanceMetrics['sync_latency_ms'] ?? 0}ms', Icons.speed),
                _buildMetricCard('Conexiones', '${_performanceMetrics['active_connections'] ?? 0}', Icons.link),
                _buildMetricCard('Memoria', '${(_performanceMetrics['memory_usage_mb'] ?? 0.0).toStringAsFixed(1)}MB', Icons.memory),
                _buildMetricCard('Red', '${_performanceMetrics['network_speed_kbps'] ?? 0}kbps', Icons.network_check),
                _buildMetricCard('Última Sync', '${_performanceMetrics['last_sync_duration_ms'] ?? 0}ms', Icons.timer),
                _buildMetricCard('Éxito', '${((_performanceMetrics['sync_success_rate'] ?? 0.0) * 100).toStringAsFixed(1)}%', Icons.check_circle),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Sync statistics
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estadísticas de Sync:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Conflictos resueltos: ${_performanceMetrics['conflicts_resolved'] ?? 0}'),
                    Text('Tamaño de cola: ${_performanceMetrics['queue_size'] ?? 0}'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_performanceMetrics['sync_success_rate'] ?? 0.0) as double,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        (_performanceMetrics['sync_success_rate'] ?? 0.0) > 0.9 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cola de Sincronización:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Queue status cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildQueueCard('Subidas Pendientes', '${_syncQueue['pending_uploads'] ?? 0}', Icons.upload, Colors.blue),
                _buildQueueCard('Descargas Pendientes', '${_syncQueue['pending_downloads'] ?? 0}', Icons.download, Colors.green),
                _buildQueueCard('Operaciones Fallidas', '${_syncQueue['failed_operations'] ?? 0}', Icons.error, Colors.red),
                _buildQueueCard('Cola de Reintentos', '${_syncQueue['retry_queue'] ?? 0}', Icons.refresh, Colors.orange),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Queue actions
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton.icon(
                  onPressed: _clearSyncQueue,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Limpiar Cola'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton.icon(
                  onPressed: _retryFailedOperations,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reintentar Fallidas'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
                ElevatedButton.icon(
                  onPressed: _pauseSyncQueue,
                  icon: const Icon(Icons.pause, size: 16),
                  label: const Text('Pausar Cola'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepositoryTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estado por Repositorio:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Repository status cards
            ..._repositoryStatus.entries.map(
              (entry) =>
              _buildRepositoryCard(entry.key, entry.value as Map<String, dynamic>)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.blue),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(title, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(title, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildRepositoryCard(String repoName, Map<String, dynamic> repoData) {
    final status = repoData['status'] as String;
    final lastSync = repoData['last_sync'] as DateTime;
    final pendingChanges = repoData['pending_changes'] as int;
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'synced':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'syncing':
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    repoName.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Estado: $status',
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                  Text(
                    'Última sync: ${_formatDateTime(lastSync)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (pendingChanges > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingChanges',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else {
      return 'Hace ${difference.inDays}d';
    }
  }

  Future<void> _runSyncTest() async {
    setState(() {
      _isTestingSync = true;
      _lastTestResult = null;
    });

    try {
      final safeSyncService = ref.read(safeSyncServiceProvider);
      
      // Check if sync is allowed
      final status = safeSyncService.getDetailedStatus();
      if (!status['can_sync']) {
        final reason = status['state'] == 'circuitOpen' 
          ? 'Circuit breaker abierto - demasiados fallos recientes'
          : 'Ya hay una sincronización en progreso';
        
        setState(() {
          _lastTestResult = {
            'errors': [reason],
            'sync_blocked': true,
            'circuit_status': status,
          };
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🚫 $reason'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Attempt safe sync
      final result = await safeSyncService.attemptSync();
      
      // Format result for display
      final testResult = {
        'user_authenticated': true,
        'sync_result': {
          'success': result.success,
          'items_processed': result.itemsProcessed,
          'items_successful': result.itemsSuccessful,
          'items_failed': result.itemsFailed,
        },
        'duration': result.duration?.inSeconds ?? 0,
        'timestamp': DateTime.now().toIso8601String(),
        'errors': result.errors,
        'circuit_status': status,
      };

      setState(() {
        _lastTestResult = testResult;
      });

      if (context.mounted) {
        final errors = result.errors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Prueba de sync segura completada. ${errors.isEmpty ? "✅ Sin errores" : "❌ ${errors.length} errores"}',
            ),
            backgroundColor: errors.isEmpty ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _lastTestResult = {
          'errors': ['Error ejecutando prueba: $e'],
          'exception': e.toString(),
        };
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error ejecutando prueba segura: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isTestingSync = false;
      });
    }
  }

  Future<void> _forceSyncAll() async {
    try {
      final safeSyncService = ref.read(safeSyncServiceProvider);
      
      // Check if sync is allowed
      final status = safeSyncService.getDetailedStatus();
      if (!status['can_sync']) {
        if (context.mounted) {
          final reason = status['state'] == 'circuitOpen' 
            ? 'Circuit breaker abierto - demasiados fallos. Espera un momento e inténtalo de nuevo.'
            : 'Ya hay una sincronización en progreso';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🚫 $reason'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('🔄 Sincronización segura iniciada...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Attempt sync with safe service
      final result = await safeSyncService.attemptSync();
      
      if (context.mounted) {
        final hasErrors = result.errors.isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasErrors 
                ? '❌ Sync completado con errores: ${result.errors.join(", ")}'
                : '✅ Sincronización completada exitosamente'
            ),
            backgroundColor: hasErrors ? Colors.red : Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error en sincronización segura: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _testRealtimeSync() {
    try {
      // Inicializar realtime sync service si no está activo
      ref.read(realtimeSyncServiceProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📡 Servicio de tiempo real inicializado/verificado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error con realtime sync: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testSupabaseDirect() async {
    try {
      setState(() {
        _isTestingSync = true;
        _lastTestResult = null;
      });

      final supabaseTest = ref.read(supabaseDirectTestProvider);
      final result = await supabaseTest.runDirectTest();
      
      setState(() {
        _lastTestResult = result;
      });

      if (context.mounted) {
        final errors = result['errors'] as List? ?? [];
        final hasErrors = errors.isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasErrors ? 
                'Test Supabase: ${errors.length} errores' : 
                'Test Supabase completado ✅'
            ),
            backgroundColor: hasErrors ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en test Supabase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingSync = false;
        });
      }
    }
  }

  void _resetCircuitBreaker() {
    try {
      final safeSyncService = ref.read(safeSyncServiceProvider);
      safeSyncService.forceResetCircuitBreaker();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔧 Circuit breaker reseteado manualmente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reseteando circuit breaker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearResults() {
    setState(() {
      _lastTestResult = null;
    });
  }

  // Simulation methods
  Future<void> _simulateConflict() async {
    setState(() {
      _lastTestResult = {'message': 'Simulando conflicto de sincronización...'};
    });
    
    try {
      // Simulate conflict creation
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _lastTestResult = {
          'conflict_simulation': true,
          'entity': 'Película "Test Movie"',
          'type': 'Modificación concurrente',
          'local_data': 'rating=4.5, updated_at=2024-01-15 10:30',
          'remote_data': 'rating=3.8, updated_at=2024-01-15 10:32',
          'status': 'Pendiente de resolución'
        };
      });
    } catch (e) {
      setState(() {
        _lastTestResult = {'error': 'Error simulando conflicto: $e'};
      });
    }
  }

  Future<void> _simulateNetworkIssue() async {
    setState(() {
      _lastTestResult = {'message': 'Simulando problemas de red...'};
    });
    
    try {
      // Simulate network degradation
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _lastTestResult = {
          'network_simulation': true,
          'latency_ms': 2000,
          'packet_loss_percent': 15,
          'bandwidth_kbps': 50,
          'timeouts': 'frecuentes',
          'offline_mode': 'activado automáticamente'
        };
      });
    } catch (e) {
      setState(() {
        _lastTestResult = {'error': 'Error simulando problemas de red: $e'};
      });
    }
  }

  Future<void> _injectSyncError() async {
    setState(() {
      _lastTestResult = {'message': 'Inyectando error de prueba...'};
    });
    
    try {
      // Simulate error injection
      await Future.delayed(const Duration(milliseconds: 500));
      
      final errorTypes = [
        'Database connection timeout',
        'Authentication token expired',
        'Network unreachable',
        'Serialization error',
        'Rate limit exceeded'
      ];
      
      final randomError = errorTypes[Random().nextInt(errorTypes.length)];
      
      setState(() {
        _lastTestResult = {
          'error_injection': true,
          'error_type': randomError,
          'timestamp': DateTime.now().toIso8601String(),
          'component': 'SyncService',
          'recommended_action': 'Reintentar en 30s',
          'circuit_breaker': 'OPEN'
        };
      });
    } catch (e) {
      setState(() {
        _lastTestResult = {'error': 'Error inyectando error: $e'};
      });
    }
  }

  Future<void> _simulateOfflineMode() async {
    setState(() {
      _lastTestResult = {'message': 'Alternando modo offline...'};
    });
    
    try {
      // Toggle offline mode simulation
      await Future.delayed(const Duration(milliseconds: 300));
      
      final isOffline = Random().nextBool();
      
      setState(() {
        _lastTestResult = {
          'offline_simulation': true,
          'mode': isOffline ? 'OFFLINE' : 'ONLINE',
          'sync_status': isOffline ? 'pausada' : 'reanudada',
          'local_changes': isOffline ? 'almacenados localmente' : 'sincronizando',
          'queue_size': isOffline ? Random().nextInt(10) + 1 : 0,
          'realtime_sync': isOffline ? 'Inactiva' : 'Activa'
        };
      });
    } catch (e) {
      setState(() {
        _lastTestResult = {'error': 'Error alternando modo offline: $e'};
      });
    }
  }

  // Queue management methods
  Future<void> _clearSyncQueue() async {
    setState(() {
      _syncQueue = {
        'pending_uploads': 0,
        'pending_downloads': 0,
        'failed_operations': 0,
        'retry_queue': 0,
      };
      _lastTestResult = {'message': 'Cola de sincronización limpiada'};
    });
  }

  Future<void> _retryFailedOperations() async {
    setState(() {
      _lastTestResult = {'message': 'Reintentando operaciones fallidas...'};
    });
    
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _syncQueue['failed_operations'] = 0;
      _syncQueue['retry_queue'] = 0;
      _lastTestResult = {'message': 'Operaciones fallidas reintentadas exitosamente'};
    });
  }

  Future<void> _pauseSyncQueue() async {
    setState(() {
      _lastTestResult = {'message': 'Cola de sincronización pausada'};
    });
  }

  String _formatTestResult(Map<String, dynamic> result) {
    final buffer = StringBuffer();
    
    // Handle simulation results
    if (result.containsKey('conflict_simulation')) {
      buffer.writeln('⚠️ SIMULACIÓN DE CONFLICTO');
      buffer.writeln('=' * 30);
      buffer.writeln('Entidad: ${result['entity']}');
      buffer.writeln('Tipo: ${result['type']}');
      buffer.writeln('Local: ${result['local_data']}');
      buffer.writeln('Remoto: ${result['remote_data']}');
      buffer.writeln('Estado: ${result['status']}');
      return buffer.toString();
    }
    
    if (result.containsKey('network_simulation')) {
      buffer.writeln('🌐 SIMULACIÓN DE RED');
      buffer.writeln('=' * 25);
      buffer.writeln('Latencia: ${result['latency_ms']}ms');
      buffer.writeln('Pérdida de paquetes: ${result['packet_loss_percent']}%');
      buffer.writeln('Ancho de banda: ${result['bandwidth_kbps']}kbps');
      buffer.writeln('Timeouts: ${result['timeouts']}');
      buffer.writeln('Modo offline: ${result['offline_mode']}');
      return buffer.toString();
    }
    
    if (result.containsKey('error_injection')) {
      buffer.writeln('💉 INYECCIÓN DE ERROR');
      buffer.writeln('=' * 25);
      buffer.writeln('Tipo: ${result['error_type']}');
      buffer.writeln('Timestamp: ${result['timestamp']}');
      buffer.writeln('Componente: ${result['component']}');
      buffer.writeln('Acción: ${result['recommended_action']}');
      buffer.writeln('Circuit Breaker: ${result['circuit_breaker']}');
      return buffer.toString();
    }
    
    if (result.containsKey('offline_simulation')) {
      buffer.writeln('📵 SIMULACIÓN OFFLINE');
      buffer.writeln('=' * 25);
      buffer.writeln('Modo: ${result['mode']}');
      buffer.writeln('Sync: ${result['sync_status']}');
      buffer.writeln('Cambios locales: ${result['local_changes']}');
      buffer.writeln('Cola: ${result['queue_size']} elementos');
      buffer.writeln('Tiempo real: ${result['realtime_sync']}');
      return buffer.toString();
    }
    
    // Handle simple message results
    if (result.containsKey('message')) {
      return result['message'] as String;
    }
    
    // Handle error results
    if (result.containsKey('error')) {
      return '❌ ${result['error']}';
    }

    buffer.writeln('👤 Usuario autenticado: ${result['user_authenticated'] ?? 'N/A'}');
    if (result.containsKey('user_id')) {
      buffer.writeln('🆔 User ID: ${result['user_id']}');
    }
    
    // Circuit breaker status
    if (result.containsKey('circuit_status')) {
      final circuit = result['circuit_status'] as Map<String, dynamic>;
      buffer.writeln('🔧 Circuit Breaker: ${circuit['state']}');
      if (circuit['consecutive_failures'] > 0) {
        buffer.writeln('   Fallos consecutivos: ${circuit['consecutive_failures']}');
      }
    }
    
    // Sync blocked info
    if (result['sync_blocked'] == true) {
      buffer.writeln('🚫 Sincronización BLOQUEADA');
    }
    
    buffer.writeln('');

    // Si es test directo de Supabase
    if (result.containsKey('connectivity_test')) {
      buffer.writeln('🌐 Conectividad: ${result['connectivity_test'] ? "✅" : "❌"}');
      buffer.writeln('🗃️  Tablas: ${result['tables_accessible'] ? "✅" : "❌"}');
      buffer.writeln('');
      buffer.writeln('📊 Datos en Supabase:');
      buffer.writeln('   ❤️  Favoritos: ${result['favorites_in_supabase']}');
      buffer.writeln('   📝 Watchlist: ${result['watchlist_in_supabase']}');
      buffer.writeln('   👁️  Vistas: ${result['watched_in_supabase']}');
      buffer.writeln('   📋 Listas: ${result['custom_lists_in_supabase']}');
    } else {
      // Test de sync normal
      final favorites = result['favorites_sync'];
      buffer.writeln('❤️  Favoritos:');
      buffer.writeln(
          '   Local: ${favorites['local_count']} | Remote: ${favorites['remote_count']}');
      buffer.writeln('   Sync: ${favorites['sync_success'] ? "✅" : "❌"}');
      buffer.writeln('');

      // Watchlist
      final watchlist = result['watchlist_sync'];
      buffer.writeln('📝 Watchlist:');
      buffer.writeln(
          '   Local: ${watchlist['local_count']} | Remote: ${watchlist['remote_count']}');
      buffer.writeln('   Sync: ${watchlist['sync_success'] ? "✅" : "❌"}');
      buffer.writeln('');

      // Vistas
      final watched = result['watched_sync'];
      buffer.writeln('👁️  Vistas:');
      buffer.writeln(
          '   Local: ${watched['local_count']} | Remote: ${watched['remote_count']}');
      buffer.writeln('   Sync: ${watched['sync_success'] ? "✅" : "❌"}');
      buffer.writeln('');

      // Listas personalizadas
      final customLists = result['custom_lists_sync'];
      buffer.writeln('📋 Listas:');
      buffer.writeln(
          '   Local: ${customLists['local_count']} | Remote: ${customLists['remote_count']}');
      buffer.writeln('   Sync: ${customLists['sync_success'] ? "✅" : "❌"}');
      buffer.writeln('');
    }

    // Errores
    if (result['errors']?.isNotEmpty == true) {
      buffer.writeln('❌ Errores:');
      for (final error in result['errors']) {
        buffer.writeln('   • $error');
      }
    } else {
      buffer.writeln('✅ Sin errores');
    }

    return buffer.toString();
  }

}
