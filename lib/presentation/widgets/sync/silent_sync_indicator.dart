import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/silent_favorites_sync_service.dart';
import '../../providers/silent_sync_provider.dart';

/// Indicador sutil de sincronización silenciosa
/// Se muestra en la parte superior como una barra de progreso muy delgada
class SilentSyncIndicator extends ConsumerWidget {
  const SilentSyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(silentSyncProvider);

    if (!syncState.isActive) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 2.0,
      width: double.infinity,
      child: LinearProgressIndicator(
        value: syncState.progress,
        backgroundColor: Colors.grey.withValues(alpha: 0.3),
        valueColor: AlwaysStoppedAnimation<Color>(
          _getColorForSyncType(context, syncState.currentType),
        ),
      ),
    );
  }

  Color _getColorForSyncType(BuildContext context, SyncProgressType? type) {
    final theme = Theme.of(context);

    switch (type) {
      case SyncProgressType.started:
      case SyncProgressType.fetching:
        return theme.colorScheme.primary.withValues(alpha: 0.8);
      case SyncProgressType.itemSynced:
        return Colors.green.withValues(alpha: 0.8);
      case SyncProgressType.itemError:
        return Colors.red.withValues(alpha: 0.8);
      default:
        return theme.colorScheme.primary.withValues(alpha: 0.6);
    }
  }
}



/// Floating Action Button con indicador de sync
class SyncAwareFAB extends ConsumerWidget {
  const SyncAwareFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(isSyncActiveProvider);

    return Stack(
      children: [
        FloatingActionButton(
          onPressed: onPressed,
          tooltip: tooltip,
          child: icon,
        ),
        if (isSyncing)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
              child: const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}
