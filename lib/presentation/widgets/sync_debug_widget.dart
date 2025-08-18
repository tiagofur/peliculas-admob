import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/services/sync_service.dart';
import '../providers/sync_init_provider.dart';

/// Widget de depuración para mostrar el estado de sincronización
/// Solo se muestra en modo debug
class SyncDebugWidget extends ConsumerWidget {
  const SyncDebugWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solo mostrar en modo debug
    if (!kDebugMode) return const SizedBox.shrink();

    return Positioned(
      bottom: 100,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sync,
                    color: Colors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sync Debug',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SyncStatusIndicator(),
              const SizedBox(height: 8),
              _SyncActions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatusIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authSyncListener = ref.watch(authSyncListenerProvider);
    final syncStatus = authSyncListener.getSyncStatus();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusRow('Platform', kIsWeb ? 'Web' : 'Native'),
        _StatusRow(
          'Periodic Sync',
          syncStatus['is_periodic_sync_active'] ? 'Active' : 'Inactive',
          color: syncStatus['is_periodic_sync_active']
              ? Colors.green
              : Colors.orange,
        ),
        _StatusRow('Repositories', '${syncStatus['repositories_count']}'),
        _StatusRow(
            'Retry Attempts', '${syncStatus['retry_attempts']?.length ?? 0}'),
        _StatusRow(
            'Recent Errors', '${syncStatus['recent_errors']?.length ?? 0}'),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.sync,
          onPressed: () async {
            try {
              final authSyncListener = ref.read(authSyncListenerProvider);
              await authSyncListener.forceSyncAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sync completed!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sync failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.health_and_safety,
          onPressed: () async {
            final authSyncListener = ref.read(authSyncListenerProvider);
            final health = await authSyncListener.checkServicesHealth();

            if (context.mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Services Health'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: health.entries.map((entry) {
                      return Row(
                        children: [
                          Icon(
                            entry.value ? Icons.check_circle : Icons.error,
                            color: entry.value ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(entry.key),
                        ],
                      );
                    }).toList(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onPressed,
  });
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 14,
          color: Colors.blue,
        ),
      ),
    );
  }
}

/// Widget para mostrar notificaciones de sincronización
class SyncNotificationWidget extends ConsumerWidget {
  const SyncNotificationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(syncStateProvider).when(
          data: (result) {
            if (result == null) return const SizedBox.shrink();

            final hasErrors = result.errors.isNotEmpty;

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasErrors ? Colors.red[100] : Colors.green[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasErrors ? Colors.red : Colors.green,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasErrors ? Icons.sync_problem : Icons.sync,
                    color: hasErrors ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasErrors
                              ? 'Sync completed with errors'
                              : 'Sync completed successfully',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                hasErrors ? Colors.red[800] : Colors.green[800],
                          ),
                        ),
                        if (hasErrors) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Errors: ${result.errors.join(', ')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[600],
                            ),
                          ),
                        ],
                        Text(
                          'Duration: ${result.duration.inMilliseconds}ms',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                hasErrors ? Colors.red[600] : Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue, width: 1),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Syncing...'),
              ],
            ),
          ),
          error: (error, stackTrace) => Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sync error: $error',
                    style: TextStyle(color: Colors.red[800]),
                  ),
                ),
              ],
            ),
          ),
        );
  }
}
