import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sync_status_provider.dart';

/// Widget indicador de estado de sincronización
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({
    super.key,
    this.size = 20.0,
    this.showText = false,
    this.compact = false,
  });

  final double size;
  final bool showText;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final colors = Theme.of(context).colorScheme;

    if (compact && syncState.status == SyncStatus.idle) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: _buildIndicatorContent(context, syncState, colors),
    );
  }

  Widget _buildIndicatorContent(BuildContext context, SyncState syncState, ColorScheme colors) {
    if (showText) {
      return _buildTextIndicator(context, syncState, colors);
    } else {
      return _buildIconIndicator(context, syncState, colors);
    }
  }

  Widget _buildIconIndicator(BuildContext context, SyncState syncState, ColorScheme colors) {
    Widget icon;
    Color iconColor;

    switch (syncState.status) {
      case SyncStatus.idle:
        return const SizedBox.shrink();
      
      case SyncStatus.syncing:
        icon = SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            value: syncState.progress > 0 ? syncState.progress : null,
          ),
        );
        iconColor = colors.primary;
        break;
      
      case SyncStatus.success:
        icon = Icon(Icons.check_circle, size: size);
        iconColor = colors.primary;
        break;
      
      case SyncStatus.error:
        icon = Icon(Icons.error_outline, size: size);
        iconColor = colors.error;
        break;
      
      case SyncStatus.offline:
        icon = Icon(Icons.cloud_off_outlined, size: size);
        iconColor = colors.onSurface.withOpacity(0.6);
        break;
    }

    return Tooltip(
      message: _getTooltipMessage(syncState),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: IconTheme(
          data: IconThemeData(color: iconColor),
          child: icon,
        ),
      ),
    );
  }

  Widget _buildTextIndicator(BuildContext context, SyncState syncState, ColorScheme colors) {
    if (syncState.status == SyncStatus.idle) {
      return const SizedBox.shrink();
    }

    Color textColor;
    IconData iconData;

    switch (syncState.status) {
      case SyncStatus.syncing:
        textColor = colors.primary;
        iconData = Icons.sync;
        break;
      case SyncStatus.success:
        textColor = colors.primary;
        iconData = Icons.check_circle_outline;
        break;
      case SyncStatus.error:
        textColor = colors.error;
        iconData = Icons.error_outline;
        break;
      case SyncStatus.offline:
        textColor = colors.onSurface.withOpacity(0.6);
        iconData = Icons.cloud_off_outlined;
        break;
      case SyncStatus.idle:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (syncState.status == SyncStatus.syncing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
                value: syncState.progress > 0 ? syncState.progress : null,
              ),
            )
          else
            Icon(iconData, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            syncState.message.isNotEmpty ? syncState.message : _getStatusText(syncState.status),
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getTooltipMessage(SyncState syncState) {
    switch (syncState.status) {
      case SyncStatus.idle:
        return 'Sincronización inactiva';
      case SyncStatus.syncing:
        return syncState.message.isNotEmpty ? syncState.message : 'Sincronizando datos...';
      case SyncStatus.success:
        final lastSync = syncState.lastSyncTime;
        if (lastSync != null) {
          final diff = DateTime.now().difference(lastSync);
          if (diff.inMinutes < 1) {
            return 'Datos sincronizados hace unos segundos';
          } else if (diff.inHours < 1) {
            return 'Datos sincronizados hace ${diff.inMinutes} minutos';
          } else {
            return 'Datos sincronizados hace ${diff.inHours} horas';
          }
        }
        return 'Datos sincronizados';
      case SyncStatus.error:
        return syncState.errorMessage ?? 'Error en sincronización';
      case SyncStatus.offline:
        return 'Sin conexión a internet';
    }
  }

  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return '';
      case SyncStatus.syncing:
        return 'Sincronizando...';
      case SyncStatus.success:
        return 'Actualizado';
      case SyncStatus.error:
        return 'Error';
      case SyncStatus.offline:
        return 'Sin conexión';
    }
  }
}

/// Widget de estado de sincronización expandido para uso en pantallas
class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final colors = Theme.of(context).colorScheme;

    if (syncState.status == SyncStatus.idle) {
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
                    _getTitle(syncState.status),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (syncState.message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      syncState.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                  if (syncState.status == SyncStatus.syncing && syncState.progress > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: syncState.progress,
                      backgroundColor: colors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ],
                ],
              ),
            ),
            if (syncState.status == SyncStatus.error)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.read(syncStatusProvider.notifier).startManualSync();
                },
                tooltip: 'Reintentar sincronización',
              ),
          ],
        ),
      ),
    );
  }

  String _getTitle(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'Sincronización';
      case SyncStatus.syncing:
        return 'Sincronizando datos';
      case SyncStatus.success:
        return 'Datos actualizados';
      case SyncStatus.error:
        return 'Error de sincronización';
      case SyncStatus.offline:
        return 'Sin conexión';
    }
  }
}