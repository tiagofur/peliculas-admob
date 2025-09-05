import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sync_integration_provider.dart' as integration;

import 'sync_status_indicator.dart';

/// Configuraciones de sincronización
class SyncSettings {
  final bool autoSyncEnabled;
  final bool offlineModeEnabled;
  final SyncFrequency syncFrequency;
  final ConflictResolutionStrategy conflictResolution;
  final bool wifiOnlyEnabled;
  final bool backgroundSyncEnabled;

  const SyncSettings({
    this.autoSyncEnabled = true,
    this.offlineModeEnabled = false,
    this.syncFrequency = SyncFrequency.automatic,
    this.conflictResolution = ConflictResolutionStrategy.askUser,
    this.wifiOnlyEnabled = false,
    this.backgroundSyncEnabled = true,
  });

  SyncSettings copyWith({
    bool? autoSyncEnabled,
    bool? offlineModeEnabled,
    SyncFrequency? syncFrequency,
    ConflictResolutionStrategy? conflictResolution,
    bool? wifiOnlyEnabled,
    bool? backgroundSyncEnabled,
  }) {
    return SyncSettings(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      offlineModeEnabled: offlineModeEnabled ?? this.offlineModeEnabled,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      conflictResolution: conflictResolution ?? this.conflictResolution,
      wifiOnlyEnabled: wifiOnlyEnabled ?? this.wifiOnlyEnabled,
      backgroundSyncEnabled: backgroundSyncEnabled ?? this.backgroundSyncEnabled,
    );
  }
}

/// Frecuencias de sincronización
enum SyncFrequency {
  automatic('Automática'),
  every5Minutes('Cada 5 minutos'),
  every15Minutes('Cada 15 minutos'),
  every30Minutes('Cada 30 minutos'),
  hourly('Cada hora'),
  manual('Solo manual');

  const SyncFrequency(this.displayName);
  final String displayName;
}

/// Estrategias de resolución de conflictos
enum ConflictResolutionStrategy {
  askUser('Preguntar al usuario'),
  keepLocal('Mantener cambios locales'),
  keepRemote('Mantener cambios remotos'),
  mergeAutomatic('Fusión automática');

  const ConflictResolutionStrategy(this.displayName);
  final String displayName;
}

/// Provider para configuraciones de sincronización
final syncSettingsProvider = StateNotifierProvider<SyncSettingsNotifier, SyncSettings>((ref) {
  return SyncSettingsNotifier();
});

class SyncSettingsNotifier extends StateNotifier<SyncSettings> {
  SyncSettingsNotifier() : super(const SyncSettings());

  void updateAutoSync(bool enabled) {
    state = state.copyWith(autoSyncEnabled: enabled);
  }

  void updateOfflineMode(bool enabled) {
    state = state.copyWith(offlineModeEnabled: enabled);
  }

  void updateSyncFrequency(SyncFrequency frequency) {
    state = state.copyWith(syncFrequency: frequency);
  }

  void updateConflictResolution(ConflictResolutionStrategy strategy) {
    state = state.copyWith(conflictResolution: strategy);
  }

  void updateWifiOnly(bool enabled) {
    state = state.copyWith(wifiOnlyEnabled: enabled);
  }

  void updateBackgroundSync(bool enabled) {
    state = state.copyWith(backgroundSyncEnabled: enabled);
  }
}

/// Widget principal de configuraciones de sincronización
class SyncSettingsWidget extends ConsumerWidget {
  const SyncSettingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(integration.syncIntegrationProvider);
    final settings = syncState.currentSettings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Configuración de Sincronización',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Estado actual
            const SyncStatusCard(),
            const SizedBox(height: 16),
            
            // Controles principales
            _buildMainControls(context, ref, settings, syncState),
            const SizedBox(height: 16),
            
            // Configuraciones avanzadas
            _buildAdvancedSettings(context, ref, settings),
            const SizedBox(height: 16),
            
            // Acciones de datos
            _buildDataActions(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildMainControls(BuildContext context, WidgetRef ref, SyncSettings settings, integration.SyncIntegrationState syncState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Controles Principales',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        
        // Botón de sincronización manual
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: syncState.globalSyncStatus == integration.SyncStatus.syncing
                ? null
                : () => _triggerManualSync(ref),
            icon: syncState.globalSyncStatus == integration.SyncStatus.syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(
              syncState.globalSyncStatus == integration.SyncStatus.syncing
                  ? 'Sincronizando...'
                  : 'Sincronizar Ahora',
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Toggle de auto-sync
        SwitchListTile(
          title: const Text('Sincronización Automática'),
          subtitle: const Text('Sincronizar cambios automáticamente'),
          value: settings.autoSyncEnabled,
          onChanged: (value) => ref.read(syncSettingsProvider.notifier).updateAutoSync(value),
        ),
        
        // Toggle de modo offline
        SwitchListTile(
          title: const Text('Modo Sin Conexión'),
          subtitle: const Text('Trabajar solo con datos locales'),
          value: settings.offlineModeEnabled,
          onChanged: (value) => ref.read(syncSettingsProvider.notifier).updateOfflineMode(value),
        ),
      ],
    );
  }

  Widget _buildAdvancedSettings(BuildContext context, WidgetRef ref, SyncSettings settings) {
    return ExpansionTile(
      title: const Text('Configuración Avanzada'),
      leading: const Icon(Icons.settings),
      children: [
        // Frecuencia de sincronización
        ListTile(
          title: const Text('Frecuencia de Sincronización'),
          subtitle: Text(settings.syncFrequency.displayName),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showFrequencySelector(context, ref, settings.syncFrequency),
        ),
        
        // Resolución de conflictos
        ListTile(
          title: const Text('Resolución de Conflictos'),
          subtitle: Text(settings.conflictResolution.displayName),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showConflictResolutionSelector(context, ref, settings.conflictResolution),
        ),
        
        // Solo Wi-Fi
        SwitchListTile(
          title: const Text('Solo Wi-Fi'),
          subtitle: const Text('Sincronizar solo cuando esté conectado a Wi-Fi'),
          value: settings.wifiOnlyEnabled,
          onChanged: (value) => ref.read(syncSettingsProvider.notifier).updateWifiOnly(value),
        ),
        
        // Sincronización en background
        SwitchListTile(
          title: const Text('Sincronización en Segundo Plano'),
          subtitle: const Text('Permitir sincronización cuando la app esté en segundo plano'),
          value: settings.backgroundSyncEnabled,
          onChanged: (value) => ref.read(syncSettingsProvider.notifier).updateBackgroundSync(value),
        ),
      ],
    );
  }

  Widget _buildDataActions(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones de Datos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        
        // Botones de acciones
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showSyncHistory(context),
              icon: const Icon(Icons.history),
              label: const Text('Ver Historial'),
            ),
            OutlinedButton.icon(
              onPressed: () => _clearLocalData(context, ref),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Limpiar Datos'),
            ),
            OutlinedButton.icon(
              onPressed: () => _forceFullResync(context, ref),
              icon: const Icon(Icons.refresh),
              label: const Text('Re-sincronizar Todo'),
            ),
          ],
        ),
      ],
    );
  }

  void _triggerManualSync(WidgetRef ref) async {
    final notifier = ref.read(integration.syncIntegrationProvider.notifier);
    await notifier.triggerManualSync();
  }

  void _showFrequencySelector(BuildContext context, WidgetRef ref, SyncFrequency current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frecuencia de Sincronización'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SyncFrequency.values.map((frequency) {
            return RadioListTile<SyncFrequency>(
              title: Text(frequency.displayName),
              value: frequency,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  ref.read(integration.syncIntegrationProvider.notifier).updateSyncFrequency(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }



  void _showConflictResolutionSelector(BuildContext context, WidgetRef ref, ConflictResolutionStrategy current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolución de Conflictos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ConflictResolutionStrategy.values.map((strategy) {
            return RadioListTile<ConflictResolutionStrategy>(
              title: Text(strategy.displayName),
              value: strategy,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  ref.read(integration.syncIntegrationProvider.notifier).updateConflictResolutionStrategy(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _showSyncHistory(BuildContext context) {
    // Implementar navegación al historial de sincronización
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Historial de sincronización - Por implementar')),
    );
  }

  void _clearLocalData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Datos Locales'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar todos los datos locales? '
          'Esta acción no se puede deshacer y se volverán a descargar en la próxima sincronización.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(integration.syncIntegrationProvider.notifier).clearLocalData();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos locales eliminados')),
        );
      }
    }
  }

  void _forceFullResync(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-sincronizar Todo'),
        content: const Text(
          '¿Quieres forzar una re-sincronización completa? '
          'Esto puede tomar un tiempo y consumir datos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Re-sincronizar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(integration.syncIntegrationProvider.notifier).forceFullResync();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Iniciando re-sincronización completa')),
        );
      }
    }
  }
}

/// Widget compacto de configuraciones rápidas
class QuickSyncSettings extends ConsumerWidget {
  const QuickSyncSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(syncSettingsProvider);
    final syncState = ref.watch(integration.syncIntegrationProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sincronización',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Switch(
                  value: settings.autoSyncEnabled,
                  onChanged: (value) => ref.read(syncSettingsProvider.notifier).updateAutoSync(value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: syncState.globalSyncStatus == integration.SyncStatus.syncing
                        ? null
                        : () => ref.read(integration.syncIntegrationProvider.notifier).triggerManualSync(),
                    icon: syncState.globalSyncStatus == integration.SyncStatus.syncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 16),
                    label: const Text('Sync'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => ref.read(syncSettingsProvider.notifier).updateOfflineMode(!settings.offlineModeEnabled),
                  icon: Icon(
                    settings.offlineModeEnabled ? Icons.airplanemode_active : Icons.wifi,
                    color: settings.offlineModeEnabled
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: settings.offlineModeEnabled ? 'Modo offline activo' : 'Modo online',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}