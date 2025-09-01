import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sync_status_provider.dart';
import '../../providers/auth_provider.dart';

/// Widget que proporciona funcionalidad de pull-to-refresh para sincronización
class SyncRefreshWrapper extends ConsumerWidget {
  const SyncRefreshWrapper({
    super.key,
    required this.child,
    this.onRefresh,
  });

  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final syncNotifier = ref.read(syncStatusProvider.notifier);

    // Solo mostrar pull-to-refresh si el usuario está autenticado
    if (!appState.isAuthenticated) {
      return child;
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Ejecutar callback personalizado si se proporciona
        if (onRefresh != null) {
          await onRefresh!();
        } else {
          // Sincronización por defecto
          syncNotifier.startManualSync();
          
          // Esperar un poco para que la UI se actualice
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      },
      child: child,
    );
  }
}

/// Widget para forzar sincronización manual desde la UI
class ManualSyncButton extends ConsumerWidget {
  const ManualSyncButton({
    super.key,
    this.showText = true,
  });

  final bool showText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final appState = ref.watch(appStateProvider);
    
    // Solo mostrar si está autenticado
    if (!appState.isAuthenticated) {
      return const SizedBox.shrink();
    }

    final isLoading = syncState.status == SyncStatus.syncing;

    return FilledButton.icon(
      onPressed: isLoading ? null : () {
        ref.read(syncStatusProvider.notifier).startManualSync();
      },
      icon: isLoading 
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.sync),
      label: showText 
        ? Text(isLoading ? 'Sincronizando...' : 'Sincronizar')
        : const SizedBox.shrink(),
    );
  }
}

/// FloatingActionButton para sincronización rápida
class SyncFloatingActionButton extends ConsumerWidget {
  const SyncFloatingActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final appState = ref.watch(appStateProvider);
    
    // Solo mostrar si está autenticado y hay algún estado relevante
    if (!appState.isAuthenticated || syncState.status == SyncStatus.idle) {
      return const SizedBox.shrink();
    }

    Color? backgroundColor;
    IconData icon;
    String tooltip;
    VoidCallback? onPressed;

    switch (syncState.status) {
      case SyncStatus.syncing:
        backgroundColor = Theme.of(context).colorScheme.primary;
        icon = Icons.sync;
        tooltip = 'Sincronizando...';
        onPressed = null; // Deshabilitado durante sync
        break;
      case SyncStatus.success:
        backgroundColor = Theme.of(context).colorScheme.primary;
        icon = Icons.check;
        tooltip = 'Datos sincronizados';
        onPressed = () {
          ref.read(syncStatusProvider.notifier).startManualSync();
        };
        break;
      case SyncStatus.error:
        backgroundColor = Theme.of(context).colorScheme.error;
        icon = Icons.refresh;
        tooltip = 'Reintentar sincronización';
        onPressed = () {
          ref.read(syncStatusProvider.notifier).startManualSync();
        };
        break;
      case SyncStatus.offline:
        backgroundColor = Theme.of(context).colorScheme.outline;
        icon = Icons.cloud_off;
        tooltip = 'Sin conexión';
        onPressed = null;
        break;
      case SyncStatus.idle:
        return const SizedBox.shrink();
    }

    return AnimatedScale(
      scale: syncState.status == SyncStatus.syncing ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        tooltip: tooltip,
        child: syncState.status == SyncStatus.syncing
          ? const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            )
          : Icon(icon),
      ),
    );
  }
}