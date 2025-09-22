import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/notifications/local_notification_service.dart';

class NotificationsPermissionsScreen extends StatefulWidget {
  const NotificationsPermissionsScreen({super.key});

  static const name = 'notifications-permissions';

  @override
  State<NotificationsPermissionsScreen> createState() =>
      _NotificationsPermissionsScreenState();
}

class _NotificationsPermissionsScreenState
    extends State<NotificationsPermissionsScreen> {
  bool _isLoading = false;
  bool? _hasNotificationPermission;
  bool? _hasExactAlarmPermission;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final service = LocalNotificationService.instance;
      final flutterLocalNotificationsPlugin = service.plugin;

      if (flutterLocalNotificationsPlugin != null) {
        final androidImplementation = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          final canScheduleExact =
              await androidImplementation.canScheduleExactNotifications();

          setState(() {
            _hasNotificationPermission =
                true; // Asumimos que las notificaciones básicas están habilitadas
            _hasExactAlarmPermission = canScheduleExact;
          });
        }
      }
    } catch (e) {
      LoggerFactory.error('Error checking permissions: $e');
    }
  }

  Future<void> _requestNotificationPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final service = LocalNotificationService.instance;
      final flutterLocalNotificationsPlugin = service.plugin;

      if (flutterLocalNotificationsPlugin != null) {
        final androidImplementation = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          await androidImplementation.requestNotificationsPermission();
          await _checkPermissions();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permisos de notificaciones solicitados'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      LoggerFactory.error('Error requesting notification permission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al solicitar permisos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestExactAlarmPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await LocalNotificationService.instance
          .requestExactAlarmsPermissionIfNeeded();

      await _checkPermissions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Permisos de alarmas exactas solicitados'
                : 'No se pudieron solicitar los permisos'),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      LoggerFactory.error('Error requesting exact alarm permission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al solicitar permisos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones y Recordatorios'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Permisos de Notificaciones',
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Permite a la app mostrar notificaciones sobre nuevas películas, recomendaciones y actualizaciones.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _hasNotificationPermission == true
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: _hasNotificationPermission == true
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _hasNotificationPermission == true
                                      ? 'Habilitado'
                                      : 'Deshabilitado',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            if (_hasNotificationPermission != true)
                              ElevatedButton(
                                onPressed: _requestNotificationPermission,
                                child: const Text('Habilitar'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Alarmas y Recordatorios',
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Permite programar recordatorios precisos para películas en tu watchlist y eventos especiales. Este permiso es opcional.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Este permiso es completamente opcional. La app funciona perfectamente sin él.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _hasExactAlarmPermission == true
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: _hasExactAlarmPermission == true
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _hasExactAlarmPermission == true
                                      ? 'Habilitado'
                                      : 'Deshabilitado',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            if (_hasExactAlarmPermission != true)
                              ElevatedButton(
                                onPressed: _requestExactAlarmPermission,
                                child: const Text('Habilitar'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'La app funciona sin permisos',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Puedes usar todas las funciones principales de la app sin necesidad de habilitar estos permisos. Solo te perderás las notificaciones y recordatorios programados.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
