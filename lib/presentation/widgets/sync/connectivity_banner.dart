import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../infrastructure/services/connectivity_manager.dart';
import '../../providers/sync_integration_provider.dart' as integration;

/// Provider para el estado de conectividad
final connectivityStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  // Este provider debería conectarse con el ConnectivityManager real
  // Por ahora retornamos un stream mock
  return Stream.periodic(
    const Duration(seconds: 5),
    (count) => ConnectionStatus.online,
  );
});

/// Banner que muestra el estado de conexión de forma no intrusiva
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(integration.syncIntegrationProvider);
    final isConnected = syncState.isConnected;
    final syncStatus = syncState.globalSyncStatus;

    // Only show banner when offline or has connectivity issues
    if (isConnected && syncStatus != integration.SyncStatus.offline) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 40,
      width: double.infinity,
      color: _getBannerColor(syncStatus, isConnected),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getBannerIcon(syncStatus, isConnected),
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _getBannerText(syncStatus, isConnected),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (syncStatus == integration.SyncStatus.syncing) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBannerColor(integration.SyncStatus status, bool isConnected) {
    if (!isConnected || status == integration.SyncStatus.offline) {
      return Colors.red.shade600;
    }

    switch (status) {
      case integration.SyncStatus.syncing:
        return Colors.orange.shade600;
      case integration.SyncStatus.error:
        return Colors.red.shade600;
      case integration.SyncStatus.conflicts:
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getBannerIcon(integration.SyncStatus status, bool isConnected) {
    if (!isConnected || status == integration.SyncStatus.offline) {
      return Icons.cloud_off;
    }

    switch (status) {
      case integration.SyncStatus.syncing:
        return Icons.sync_problem;
      case integration.SyncStatus.error:
        return Icons.error;
      case integration.SyncStatus.conflicts:
        return Icons.warning;
      default:
        return Icons.cloud_queue;
    }
  }

  String _getBannerText(integration.SyncStatus status, bool isConnected) {
    if (!isConnected || status == integration.SyncStatus.offline) {
      return '📵 Trabajando sin conexión';
    }

    switch (status) {
      case integration.SyncStatus.syncing:
        return '🔄 Reconectando...';
      case integration.SyncStatus.error:
        return '❌ Error de sincronización';
      case integration.SyncStatus.conflicts:
        return '⚠️ Conflictos detectados';
      default:
        return 'Verificando conexión...';
    }
  }
}

/// Banner compacto para mostrar en la barra de estado
class ConnectivityStatusChip extends ConsumerWidget {
  const ConnectivityStatusChip({
    super.key,
    this.showLabel = true,
  });

  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityStatusProvider);

    return connectivityAsync.when(
      data: (status) => _buildChip(context, status),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildChip(BuildContext context, ConnectionStatus status) {
    if (status == ConnectionStatus.online) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    final chipData = _getChipData(status, colors);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipData.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: chipData.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            chipData.icon,
            size: 14,
            color: chipData.iconColor,
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              chipData.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: chipData.textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  _ChipData _getChipData(ConnectionStatus status, ColorScheme colors) {
    switch (status) {
      case ConnectionStatus.online:
        return _ChipData(
          icon: Icons.wifi,
          iconColor: colors.primary,
          backgroundColor: colors.primary.withValues(alpha: 0.1),
          borderColor: colors.primary.withValues(alpha: 0.3),
          textColor: colors.primary,
          label: 'Online',
        );

      case ConnectionStatus.offline:
        return _ChipData(
          icon: Icons.wifi_off,
          iconColor: colors.error,
          backgroundColor: colors.error.withValues(alpha: 0.1),
          borderColor: colors.error.withValues(alpha: 0.3),
          textColor: colors.error,
          label: 'Offline',
        );

      case ConnectionStatus.limited:
        return _ChipData(
          icon: Icons.signal_wifi_bad,
          iconColor: colors.tertiary,
          backgroundColor: colors.tertiary.withValues(alpha: 0.1),
          borderColor: colors.tertiary.withValues(alpha: 0.3),
          textColor: colors.tertiary,
          label: 'Limitado',
        );

      case ConnectionStatus.manual:
        return _ChipData(
          icon: Icons.airplanemode_active,
          iconColor: colors.secondary,
          backgroundColor: colors.secondary.withValues(alpha: 0.1),
          borderColor: colors.secondary.withValues(alpha: 0.3),
          textColor: colors.secondary,
          label: 'Manual',
        );
    }
  }
}

/// Datos para configurar el chip
class _ChipData {
  _ChipData({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final String label;
}

/// Widget flotante que muestra el estado de conectividad
class ConnectivityFloatingIndicator extends ConsumerWidget {
  const ConnectivityFloatingIndicator({
    super.key,
    this.position = FloatingIndicatorPosition.topRight,
  });

  final FloatingIndicatorPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityStatusProvider);

    return connectivityAsync.when(
      data: (status) => _buildFloatingIndicator(context, status),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildFloatingIndicator(
      BuildContext context, ConnectionStatus status) {
    if (status == ConnectionStatus.online) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    final indicatorData = _getIndicatorData(status, colors);

    return Positioned(
      top: position == FloatingIndicatorPosition.topLeft ||
              position == FloatingIndicatorPosition.topRight
          ? 16
          : null,
      bottom: position == FloatingIndicatorPosition.bottomLeft ||
              position == FloatingIndicatorPosition.bottomRight
          ? 16
          : null,
      left: position == FloatingIndicatorPosition.topLeft ||
              position == FloatingIndicatorPosition.bottomLeft
          ? 16
          : null,
      right: position == FloatingIndicatorPosition.topRight ||
              position == FloatingIndicatorPosition.bottomRight
          ? 16
          : null,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        color: indicatorData.backgroundColor,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                indicatorData.icon,
                size: 16,
                color: indicatorData.iconColor,
              ),
              const SizedBox(width: 6),
              Text(
                indicatorData.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: indicatorData.textColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ChipData _getIndicatorData(ConnectionStatus status, ColorScheme colors) {
    switch (status) {
      case ConnectionStatus.online:
        return _ChipData(
          icon: Icons.wifi,
          iconColor: colors.primary,
          backgroundColor: colors.surface,
          borderColor: colors.primary.withValues(alpha: 0.3),
          textColor: colors.primary,
          label: 'Online',
        );

      case ConnectionStatus.offline:
        return _ChipData(
          icon: Icons.wifi_off,
          iconColor: colors.error,
          backgroundColor: colors.surface,
          borderColor: colors.error.withValues(alpha: 0.3),
          textColor: colors.error,
          label: 'Sin conexión',
        );

      case ConnectionStatus.limited:
        return _ChipData(
          icon: Icons.signal_wifi_bad,
          iconColor: colors.tertiary,
          backgroundColor: colors.surface,
          borderColor: colors.tertiary.withValues(alpha: 0.3),
          textColor: colors.tertiary,
          label: 'Reconectando',
        );

      case ConnectionStatus.manual:
        return _ChipData(
          icon: Icons.airplanemode_active,
          iconColor: colors.secondary,
          backgroundColor: colors.surface,
          borderColor: colors.secondary.withValues(alpha: 0.3),
          textColor: colors.secondary,
          label: 'Modo offline',
        );
    }
  }
}

/// Posiciones para el indicador flotante
enum FloatingIndicatorPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}
