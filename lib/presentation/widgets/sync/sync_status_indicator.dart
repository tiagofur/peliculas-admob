import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sync_integration_provider.dart' as integration;

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({
    super.key,
    this.size = 16,
    this.showText = true,
  });

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(integration.syncIntegrationProvider);
    final syncStatus = syncState.globalSyncStatus;
    final isConnected = syncState.isConnected;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(syncStatus, isConnected).withValues(alpha: 0.1 * 255),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(syncStatus, isConnected),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(syncStatus, isConnected),
            size: size,
            color: _getStatusColor(syncStatus, isConnected),
          ),
          if (showText) ...[
            const SizedBox(width: 6),
            Text(
              _getStatusText(syncStatus, isConnected),
              style: TextStyle(
                color: _getStatusColor(syncStatus, isConnected),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(integration.SyncStatus status, bool isConnected) {
    if (!isConnected) return Colors.grey;
    
    switch (status) {
      case integration.SyncStatus.syncing:
        return Colors.blue;
      case integration.SyncStatus.synced:
        return Colors.green;
      case integration.SyncStatus.error:
        return Colors.red;
      case integration.SyncStatus.conflicts:
        return Colors.orange;
      case integration.SyncStatus.offline:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(integration.SyncStatus status, bool isConnected) {
    if (!isConnected) return Icons.cloud_off;
    
    switch (status) {
      case integration.SyncStatus.syncing:
        return Icons.sync;
      case integration.SyncStatus.synced:
        return Icons.cloud_done;
      case integration.SyncStatus.error:
        return Icons.error;
      case integration.SyncStatus.conflicts:
        return Icons.warning;
      case integration.SyncStatus.offline:
        return Icons.cloud_off;
      default:
        return Icons.cloud_queue;
    }
  }

  String _getStatusText(integration.SyncStatus status, bool isConnected) {
    if (!isConnected) return 'Sin conexión';
    
    switch (status) {
      case integration.SyncStatus.syncing:
        return 'Sincronizando';
      case integration.SyncStatus.synced:
        return 'Sincronizado';
      case integration.SyncStatus.error:
        return 'Error';
      case integration.SyncStatus.conflicts:
        return 'Conflictos';
      case integration.SyncStatus.offline:
        return 'Sin conexión';
      default:
        return 'Esperando';
    }
  }
}

/// Widget de estado de sincronización expandido para uso en pantallas
class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(integration.syncIntegrationProvider);
    final colors = Theme.of(context).colorScheme;

    if (syncState.globalSyncStatus == integration.SyncStatus.idle) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const SyncStatusIndicator(size: 24, showText: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTitle(syncState.globalSyncStatus),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (syncState.lastError != null && syncState.lastError!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      syncState.lastError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                  if (syncState.globalSyncStatus == integration.SyncStatus.syncing) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                       backgroundColor: colors.surfaceContainerHighest,
                       valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                     ),
                  ],
                ],
              ),
            ),
            if (syncState.globalSyncStatus == integration.SyncStatus.error)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.read(integration.syncIntegrationProvider.notifier).triggerManualSync();
                },
                tooltip: 'Reintentar sincronización',
              ),
          ],
        ),
      ),
    );
  }

  String _getTitle(integration.SyncStatus status) {
    switch (status) {
      case integration.SyncStatus.idle:
        return 'Sincronización';
      case integration.SyncStatus.syncing:
        return 'Sincronizando datos';
      case integration.SyncStatus.synced:
        return 'Datos actualizados';
      case integration.SyncStatus.error:
        return 'Error de sincronización';
      case integration.SyncStatus.conflicts:
        return 'Conflictos detectados';
      case integration.SyncStatus.offline:
        return 'Sin conexión';
    }
  }
}
