import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/notifications/local_notification_service.dart';

/// Pantalla para configurar las notificaciones y recordatorios
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _hasNotificationPermissions = false;
  bool _dailyReminders = false;
  bool _weeklyWatchlistReminders = false;
  bool _movieReleaseNotifications = false;
  bool _achievementNotifications = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    try {
      final hasPermissions = await LocalNotificationService.instance
          .checkNotificationPermissions();

      if (mounted) {
        setState(() {
          _hasNotificationPermissions = hasPermissions;
          _isLoading = false;
        });
      }

      LoggerFactory.info('🔍 Estado actual permisos: $hasPermissions');
    } catch (e) {
      LoggerFactory.error('❌ Error verificando permisos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final granted = await LocalNotificationService.instance
          .requestNotificationPermissions();

      if (mounted) {
        setState(() {
          _hasNotificationPermissions = granted;
          _isLoading = false;
        });

        if (granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Permisos de notificación otorgados'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      LoggerFactory.error('❌ Error solicitando permisos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al solicitar permisos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permisos denegados'),
        content: const Text(
            'Para recibir recordatorios y alarmas, necesitas habilitar las notificaciones en la configuración del sistema.\n\n'
            '1. Ve a Configuración > Aplicaciones\n'
            '2. Busca "Películas"\n'
            '3. Toca en Notificaciones\n'
            '4. Habilita "Mostrar notificaciones"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkCurrentPermissions(); // Verificar de nuevo
            },
            child: const Text('Verificar de nuevo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de notificaciones'),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Estado de permisos
                _buildPermissionStatusCard(),
                const SizedBox(height: 16),

                // Configuraciones de notificación (solo si hay permisos)
                if (_hasNotificationPermissions) ...[
                  _buildNotificationOptionsCard(),
                  const SizedBox(height: 16),
                  _buildAdvancedOptionsCard(),
                ] else ...[
                  _buildEnableNotificationsCard(),
                ],

                const SizedBox(height: 16),
                _buildHelpCard(),
              ],
            ),
    );
  }

  Widget _buildPermissionStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasNotificationPermissions
                      ? Icons.check_circle
                      : Icons.warning,
                  color: _hasNotificationPermissions
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _hasNotificationPermissions
                        ? 'Notificaciones habilitadas'
                        : 'Notificaciones deshabilitadas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _hasNotificationPermissions
                              ? Colors.green
                              : Colors.orange,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _hasNotificationPermissions
                  ? 'La app puede enviar recordatorios y notificaciones.'
                  : 'Necesitas habilitar los permisos para recibir recordatorios.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableNotificationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_off,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Habilitar notificaciones',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Para recibir recordatorios de películas, notificaciones de estrenos y alarmas personalizadas, necesitas habilitar los permisos de notificación.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.notifications_active),
                label: const Text('Habilitar notificaciones'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Tipos de notificaciones',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Recordatorios diarios'),
              subtitle:
                  const Text('Recibe un recordatorio diario para usar la app'),
              value: _dailyReminders,
              onChanged: (value) {
                setState(() {
                  _dailyReminders = value;
                });
                _saveNotificationPreference('dailyReminders', value);
              },
            ),
            SwitchListTile(
              title: const Text('Recordatorios de watchlist'),
              subtitle: const Text(
                  'Recordatorios semanales de películas en tu lista'),
              value: _weeklyWatchlistReminders,
              onChanged: (value) {
                setState(() {
                  _weeklyWatchlistReminders = value;
                });
                _saveNotificationPreference('weeklyWatchlistReminders', value);
              },
            ),
            SwitchListTile(
              title: const Text('Nuevos estrenos'),
              subtitle: const Text(
                  'Notificaciones cuando salgan películas que te interesan'),
              value: _movieReleaseNotifications,
              onChanged: (value) {
                setState(() {
                  _movieReleaseNotifications = value;
                });
                _saveNotificationPreference('movieReleaseNotifications', value);
              },
            ),
            SwitchListTile(
              title: const Text('Logros desbloqueados'),
              subtitle:
                  const Text('Notificaciones cuando desbloquees nuevos logros'),
              value: _achievementNotifications,
              onChanged: (value) {
                setState(() {
                  _achievementNotifications = value;
                });
                _saveNotificationPreference('achievementNotifications', value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Configuración avanzada',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Horario de notificaciones'),
              subtitle: const Text('08:00 - 22:00'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implementar configuración de horario
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Configuración de horario próximamente'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('Sonido de notificaciones'),
              subtitle: const Text('Sonido predeterminado'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implementar configuración de sonido
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Configuración de sonido próximamente'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.science),
              title: const Text('Enviar notificación de prueba'),
              subtitle:
                  const Text('Verificar que las notificaciones funcionen'),
              trailing: const Icon(Icons.send),
              onTap: _sendTestNotification,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Ayuda',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '• Las notificaciones requieren permisos del sistema\n'
              '• Los recordatorios se pueden personalizar por tipo\n'
              '• Puedes probar las notificaciones antes de activarlas\n'
              '• Los permisos se pueden cambiar en cualquier momento',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveNotificationPreference(String key, bool value) {
    // TODO: Implementar guardado de preferencias
    LoggerFactory.info('💾 Guardando preferencia $key: $value');
  }

  Future<void> _sendTestNotification() async {
    try {
      await LocalNotificationService.instance.showNotification(
        id: 999,
        title: '🎬 Notificación de prueba',
        body: 'Si ves esto, ¡las notificaciones funcionan correctamente!',
        payload:
            '{"type": "test", "timestamp": "${DateTime.now().millisecondsSinceEpoch}"}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notificación de prueba enviada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      LoggerFactory.error('❌ Error enviando notificación de prueba: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
