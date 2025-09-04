import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../debug/sync_test_helper.dart';
import '../../debug/supabase_direct_test.dart';
import '../../infrastructure/services/realtime_sync_service.dart';

/// Widget de debug para probar la sincronización manualmente
/// Solo se muestra en modo debug
class SyncDebugWidget extends ConsumerStatefulWidget {
  const SyncDebugWidget({super.key});

  @override
  ConsumerState<SyncDebugWidget> createState() => _SyncDebugWidgetState();
}

class _SyncDebugWidgetState extends ConsumerState<SyncDebugWidget> {
  Map<String, dynamic>? _lastTestResult;
  bool _isTestingSync = false;

  @override
  Widget build(BuildContext context) {
    // Solo mostrar en debug mode
    if (!kDebugMode) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧪 DEBUG: Sincronización',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),

            // Botones de acción
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
                  onPressed: _clearResults,
                  child: const Text('Limpiar'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Mostrar resultados si existen
            if (_lastTestResult != null) ...[
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
              'Usa estos botones para probar la sincronización manualmente.\n'
              'Revisa los logs de la consola para ver detalles.',
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

  Future<void> _runSyncTest() async {
    setState(() {
      _isTestingSync = true;
      _lastTestResult = null;
    });

    try {
      final syncTestHelper = ref.read(syncTestHelperProvider);
      final result = await syncTestHelper.runFullSyncTest();

      setState(() {
        _lastTestResult = result;
      });

      if (context.mounted) {
        final errors = result['errors'] as List? ?? [];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Prueba de sync completada. ${errors.isEmpty ? "✅ Sin errores" : "❌ ${errors.length} errores"}',
            ),
            backgroundColor: errors.isEmpty ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ejecutando prueba: $e'),
            backgroundColor: Colors.red,
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
      final syncTestHelper = ref.read(syncTestHelperProvider);
      await syncTestHelper.forceSyncAll();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔄 Sincronización forzada iniciada'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error forzando sync: $e'),
            backgroundColor: Colors.red,
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

  void _clearResults() {
    setState(() {
      _lastTestResult = null;
    });
  }

  String _formatTestResult(Map<String, dynamic> result) {
    final buffer = StringBuffer();

    buffer.writeln('👤 Usuario autenticado: ${result['user_authenticated']}');
    if (result.containsKey('user_id')) {
      buffer.writeln('🆔 User ID: ${result['user_id']}');
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
