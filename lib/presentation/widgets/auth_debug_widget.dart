import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../infrastructure/services/sync_service.dart';
import '../providers/auth_provider.dart';

/// Widget de debug para verificar el estado de autenticación en tiempo real
class AuthDebugWidget extends ConsumerWidget {
  const AuthDebugWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final currentUser = ref.watch(currentUserProvider);
    final authState = ref.watch(authStateProvider);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🔍 DEBUG: Estado de Autenticación',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Estado de la app
          _buildInfoRow(
            '📱 Modo de App:',
            appState.isAuthenticated ? '✅ Autenticado' : '❌ Invitado',
            appState.isAuthenticated ? Colors.green : Colors.red,
          ),

          // Usuario actual
          _buildInfoRow(
            '👤 Usuario Actual:',
            currentUser != null ? '✅ ${currentUser.email}' : '❌ No hay usuario',
            currentUser != null ? Colors.green : Colors.red,
          ),

          // Estado del stream de auth
          authState.when(
            data: (user) => _buildInfoRow(
              '🔄 Stream Auth:',
              user != null ? '✅ Usuario en stream' : '❌ Sin usuario en stream',
              user != null ? Colors.green : Colors.red,
            ),
            loading: () => _buildInfoRow(
              '🔄 Stream Auth:',
              '⏳ Cargando...',
              Colors.orange,
            ),
            error: (error, stack) => _buildInfoRow(
              '🔄 Stream Auth:',
              '❌ Error: ${error.toString()}',
              Colors.red,
            ),
          ),

          // Sesión de Supabase
          FutureBuilder<Session?>(
            future: Future.value(Supabase.instance.client.auth.currentSession),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildInfoRow(
                    '🔑 Sesión Supabase:', '⏳ Verificando...', Colors.orange);
              }

              if (snapshot.hasError) {
                return _buildInfoRow('🔑 Sesión Supabase:',
                    '❌ Error: ${snapshot.error}', Colors.red);
              }

              final session = snapshot.data;
              return _buildInfoRow(
                '🔑 Sesión Supabase:',
                session != null
                    ? '✅ Activa (${session.user.email})'
                    : '❌ Sin sesión',
                session != null ? Colors.green : Colors.red,
              );
            },
          ),

          const SizedBox(height: 16),

          // Botones de acción
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final session =
                        Supabase.instance.client.auth.currentSession;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(session != null
                            ? 'Sesión activa: ${session.user.email}'
                            : 'Sin sesión activa'),
                        backgroundColor:
                            session != null ? Colors.green : Colors.red,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error verificando sesión: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Verificar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final syncService = ref.read(syncServiceProvider);
                  final status = syncService.getSyncStatus();

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Estado de Sincronización'),
                      content: SingleChildScrollView(
                        child: Text('''
Sync Periódico Activo: ${status['is_periodic_sync_active']}
Repositorios: ${status['repositories_count']}
Reintentos: ${status['retry_attempts']}
Errores Recientes: ${status['recent_errors'].length}

Errores:
${status['recent_errors'].join('\n')}
                        '''),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Estado Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              if (currentUser != null)
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final syncService = ref.read(syncServiceProvider);
                      final result = await syncService.forceSyncAllData();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Sync manual completado: ${result.repositoryResults}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error en sync manual: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.cloud_sync, size: 16),
                  label: const Text('Sync Manual'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Información adicional
          Text(
            '💡 Para que funcione la sincronización:\n'
            '1. Debe haber un usuario autenticado\n'
            '2. La sesión debe estar activa\n'
            '3. El email debe estar confirmado (o deshabilitado en Supabase)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
