import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/sync_integration_provider.dart' as integration;

/// Entrada del historial de sincronización
class SyncHistoryEntry {
  const SyncHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.status,
    this.entityType,
    this.entityId,
    this.description,
    this.errorMessage,
    this.duration,
    this.itemsProcessed,
    this.itemsSuccess,
    this.itemsError,
  });
  final String id;
  final DateTime timestamp;
  final SyncOperationType type;
  final SyncOperationStatus status;
  final String? entityType;
  final String? entityId;
  final String? description;
  final String? errorMessage;
  final Duration? duration;
  final int? itemsProcessed;
  final int? itemsSuccess;
  final int? itemsError;
}

/// Tipos de operación de sincronización
enum SyncOperationType {
  fullSync('Sincronización Completa'),
  incrementalSync('Sincronización Incremental'),
  upload('Subida'),
  download('Descarga'),
  conflictResolution('Resolución de Conflicto'),
  cleanup('Limpieza'),
  initialization('Inicialización');

  const SyncOperationType(this.displayName);
  final String displayName;
}

/// Estados de operación de sincronización
enum SyncOperationStatus {
  success('Exitoso'),
  error('Error'),
  warning('Advertencia'),
  cancelled('Cancelado'),
  inProgress('En Progreso');

  const SyncOperationStatus(this.displayName);
  final String displayName;

  Color getColor(BuildContext context) {
    switch (this) {
      case SyncOperationStatus.success:
        return Colors.green;
      case SyncOperationStatus.error:
        return Theme.of(context).colorScheme.error;
      case SyncOperationStatus.warning:
        return Colors.orange;
      case SyncOperationStatus.cancelled:
        return Colors.grey;
      case SyncOperationStatus.inProgress:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData getIcon() {
    switch (this) {
      case SyncOperationStatus.success:
        return Icons.check_circle;
      case SyncOperationStatus.error:
        return Icons.error;
      case SyncOperationStatus.warning:
        return Icons.warning;
      case SyncOperationStatus.cancelled:
        return Icons.cancel;
      case SyncOperationStatus.inProgress:
        return Icons.sync;
    }
  }
}

/// Provider simple para el historial de sincronización usando Provider en lugar de StateNotifierProvider
final syncHistoryProvider = Provider<List<SyncHistoryEntry>>((ref) {
  return _generateMockHistory();
});

/// Función para generar historial mock
List<SyncHistoryEntry> _generateMockHistory() {
  final now = DateTime.now();
  return [
    SyncHistoryEntry(
      id: '1',
      timestamp: now.subtract(const Duration(minutes: 5)),
      type: SyncOperationType.incrementalSync,
      status: SyncOperationStatus.success,
      description: 'Sincronización automática completada',
      duration: const Duration(seconds: 12),
      itemsProcessed: 15,
      itemsSuccess: 15,
      itemsError: 0,
    ),
    SyncHistoryEntry(
      id: '2',
      timestamp: now.subtract(const Duration(hours: 2)),
      type: SyncOperationType.upload,
      status: SyncOperationStatus.success,
      entityType: 'Película',
      entityId: 'movie_123',
      description: 'Película "Avatar" subida exitosamente',
      duration: const Duration(seconds: 8),
    ),
  ];
}

/// Widget principal del visor de historial
class SyncHistoryViewer extends ConsumerWidget {
  const SyncHistoryViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncHistory = ref.watch(syncHistoryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historial de Sincronización',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    // Trigger manual sync
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: syncHistory.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay historial de sincronización disponible',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: syncHistory.length,
                      itemBuilder: (context, index) {
                        final entry = syncHistory[index];
                        return _buildHistoryEntry(context, entry);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(BuildContext context, SyncHistoryEntry entry) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              entry.status.getColor(context).withValues(alpha: 0.1),
          child: Icon(
            entry.status.getIcon(),
            color: entry.status.getColor(context),
            size: 20,
          ),
        ),
        title: Text(
          entry.type.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.description != null)
              Text(
                entry.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Text(
              dateFormat.format(entry.timestamp),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: entry.status.getColor(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            entry.status.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: entry.status.getColor(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget simple del visor de historial para integración
class SimpleSyncHistoryViewer extends ConsumerWidget {
  const SimpleSyncHistoryViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(integration.syncIntegrationProvider);
    final syncHistory = syncState.syncHistory;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historial de Sincronización',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref
                        .read(integration.syncIntegrationProvider.notifier)
                        .triggerManualSync();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: syncHistory.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay historial de sincronización disponible',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: syncHistory.length,
                      itemBuilder: (context, index) {
                        final entry = syncHistory[index];
                        return _buildHistoryEntry(context, entry);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(BuildContext context, SyncHistoryEntry entry) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              entry.status.getColor(context).withValues(alpha: 0.1),
          child: Icon(
            entry.status.getIcon(),
            color: entry.status.getColor(context),
            size: 20,
          ),
        ),
        title: Text(
          entry.type.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.description != null)
              Text(
                entry.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Text(
              dateFormat.format(entry.timestamp),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: entry.status.getColor(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            entry.status.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: entry.status.getColor(context),
            ),
          ),
        ),
      ),
    );
  }
}
