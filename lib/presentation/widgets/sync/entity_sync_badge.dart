import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/syncable_entity.dart';

/// Widget badge que muestra el estado de sincronización de un elemento individual
class EntitySyncBadge extends ConsumerWidget {
  const EntitySyncBadge({
    super.key,
    required this.status,
    this.size = 16.0,
    this.showTooltip = true,
    this.compact = false,
  });

  final SyncItemStatus status;
  final double size;
  final bool showTooltip;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final widget = _buildBadgeContent(context, colors);

    if (showTooltip) {
      return Tooltip(
        message: _getTooltipMessage(context),
        child: widget,
      );
    }

    return widget;
  }

  Widget _buildBadgeContent(BuildContext context, ColorScheme colors) {
    if (status == SyncItemStatus.synced && compact) {
      return const SizedBox.shrink();
    }

    final iconData = _getIconData();
    final iconColor = _getIconColor(colors);
    final backgroundColor = _getBackgroundColor(colors);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        iconData,
        size: size * 0.6,
        color: iconColor,
      ),
    );
  }

  IconData _getIconData() {
    switch (status) {
      case SyncItemStatus.synced:
        return Icons.check;
      case SyncItemStatus.pendingUpload:
        return Icons.upload;
      case SyncItemStatus.pendingDownload:
        return Icons.download;
      case SyncItemStatus.conflict:
        return Icons.warning;
      case SyncItemStatus.error:
        return Icons.error;
      case SyncItemStatus.uploading:
        return Icons.cloud_upload;
      case SyncItemStatus.downloading:
        return Icons.cloud_download;
      case SyncItemStatus.processing:
        return Icons.sync;
    }
  }

  Color _getIconColor(ColorScheme colors) {
    switch (status) {
      case SyncItemStatus.synced:
        return colors.primary;
      case SyncItemStatus.pendingUpload:
      case SyncItemStatus.uploading:
        return colors.tertiary;
      case SyncItemStatus.pendingDownload:
      case SyncItemStatus.downloading:
        return colors.secondary;
      case SyncItemStatus.conflict:
        return colors.error;
      case SyncItemStatus.error:
        return colors.error;
      case SyncItemStatus.processing:
        return colors.secondary;
    }
  }

  Color _getBackgroundColor(ColorScheme colors) {
    switch (status) {
      case SyncItemStatus.synced:
        return colors.primary.withOpacity(0.1);
      case SyncItemStatus.pendingUpload:
      case SyncItemStatus.uploading:
        return colors.tertiary.withOpacity(0.1);
      case SyncItemStatus.pendingDownload:
      case SyncItemStatus.downloading:
        return colors.secondary.withOpacity(0.1);
      case SyncItemStatus.conflict:
        return colors.error.withOpacity(0.1);
      case SyncItemStatus.error:
        return colors.error.withOpacity(0.1);
      case SyncItemStatus.processing:
        return colors.secondary.withOpacity(0.1);
    }
  }

  String _getTooltipMessage(BuildContext context) {
    switch (status) {
      case SyncItemStatus.synced:
        return 'Sincronizado';
      case SyncItemStatus.pendingUpload:
        return 'Pendiente de subir';
      case SyncItemStatus.pendingDownload:
        return 'Pendiente de descargar';
      case SyncItemStatus.conflict:
        return 'Conflicto detectado';
      case SyncItemStatus.error:
        return 'Error de sincronización';
      case SyncItemStatus.uploading:
        return 'Subiendo...';
      case SyncItemStatus.downloading:
        return 'Descargando...';
      case SyncItemStatus.processing:
        return 'Procesando cambios';
    }
  }
}

/// Widget badge expandido con texto para mostrar estado de sincronización
class EntitySyncBadgeExpanded extends ConsumerWidget {
  const EntitySyncBadgeExpanded({
    super.key,
    required this.status,
    this.showIcon = true,
    this.showProgress = false,
    this.progress,
  });

  final SyncItemStatus status;
  final bool showIcon;
  final bool showProgress;
  final double? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(colors),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getIconColor(colors).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              _getIconData(),
              size: 14,
              color: _getIconColor(colors),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            _getStatusText(),
            style: textStyle?.copyWith(
              color: _getIconColor(colors),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showProgress && progress != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              height: 2,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: colors.surfaceContainerHighest,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_getIconColor(colors)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconData() {
    switch (status) {
      case SyncItemStatus.synced:
        return Icons.check_circle;
      case SyncItemStatus.pendingUpload:
        return Icons.upload;
      case SyncItemStatus.pendingDownload:
        return Icons.download;
      case SyncItemStatus.conflict:
        return Icons.warning;
      case SyncItemStatus.error:
        return Icons.error;
      case SyncItemStatus.uploading:
        return Icons.cloud_upload;
      case SyncItemStatus.downloading:
        return Icons.cloud_download;
      case SyncItemStatus.processing:
        return Icons.sync;
    }
  }

  Color _getIconColor(ColorScheme colors) {
    switch (status) {
      case SyncItemStatus.synced:
        return colors.primary;
      case SyncItemStatus.pendingUpload:
      case SyncItemStatus.uploading:
        return colors.tertiary;
      case SyncItemStatus.pendingDownload:
      case SyncItemStatus.downloading:
        return colors.secondary;
      case SyncItemStatus.conflict:
        return colors.error;
      case SyncItemStatus.error:
        return colors.error;
      case SyncItemStatus.processing:
        return colors.secondary;
    }
  }

  Color _getBackgroundColor(ColorScheme colors) {
    switch (status) {
      case SyncItemStatus.synced:
        return colors.primary.withOpacity(0.1);
      case SyncItemStatus.pendingUpload:
      case SyncItemStatus.uploading:
        return colors.tertiary.withOpacity(0.1);
      case SyncItemStatus.pendingDownload:
      case SyncItemStatus.downloading:
        return colors.secondary.withOpacity(0.1);
      case SyncItemStatus.conflict:
        return colors.error.withOpacity(0.1);
      case SyncItemStatus.error:
        return colors.error.withOpacity(0.1);
      case SyncItemStatus.processing:
        return colors.secondary.withOpacity(0.1);
    }
  }

  String _getStatusText() {
    switch (status) {
      case SyncItemStatus.synced:
        return 'Sincronizado';
      case SyncItemStatus.pendingUpload:
        return 'Pendiente';
      case SyncItemStatus.pendingDownload:
        return 'Descargando';
      case SyncItemStatus.conflict:
        return 'Conflicto';
      case SyncItemStatus.error:
        return 'Error';
      case SyncItemStatus.uploading:
        return 'Subiendo';
      case SyncItemStatus.downloading:
        return 'Descargando';
      case SyncItemStatus.processing:
        return 'Procesando';
    }
  }
}

/// Widget para mostrar múltiples badges de sincronización en una lista
class EntitySyncBadgeList extends ConsumerWidget {
  const EntitySyncBadgeList({
    super.key,
    required this.items,
    this.maxVisible = 3,
    this.showCount = true,
  });

  final List<SyncItemStatus> items;
  final int maxVisible;
  final bool showCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    final visibleItems = items.take(maxVisible).toList();
    final remainingCount = items.length - maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visibleItems.map((status) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: EntitySyncBadge(
                status: status,
                size: 14,
                compact: true,
              ),
            )),
        if (remainingCount > 0 && showCount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+$remainingCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
      ],
    );
  }
}
