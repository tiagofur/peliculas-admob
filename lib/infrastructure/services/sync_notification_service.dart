import 'package:flutter/foundation.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/notifications/local_notification_service.dart';

/// Servicio para manejar notificaciones de sincronización en background
class SyncNotificationService {
  SyncNotificationService._();
  static final SyncNotificationService instance = SyncNotificationService._();

  static const int _syncNotificationId = 1001;
  static const String _syncChannelId = 'sync_updates';
  static const String _syncChannelName = 'Sincronización';

  bool _isInitialized = false;
  bool _notificationsEnabled = true;

  /// Inicializar el servicio de notificaciones de sync
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Solo habilitar notificaciones en modo release para evitar spam durante desarrollo
      _notificationsEnabled = !kDebugMode;
      
      if (_notificationsEnabled && !kIsWeb) {
        await _createNotificationChannel();
      }
      
      _isInitialized = true;
      LoggerFactory.info('✅ SyncNotificationService inicializado (enabled: $_notificationsEnabled)');
    } catch (e) {
      LoggerFactory.error('❌ Error inicializando SyncNotificationService: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    try {
      // El LocalNotificationService ya maneja la creación de canales
      // Solo necesitamos verificar que esté disponible
      if (!LocalNotificationService.instance.isInitialized) {
        LoggerFactory.warning('LocalNotificationService no está inicializado');
        _notificationsEnabled = false;
      }
    } catch (e) {
      LoggerFactory.error('Error creando canal de notificación: $e');
      _notificationsEnabled = false;
    }
  }

  /// Mostrar notificación de sincronización exitosa
  Future<void> showSyncSuccessNotification({
    required int itemsSynced,
    String? additionalInfo,
  }) async {
    if (!_notificationsEnabled || kIsWeb || !_isInitialized) return;

    try {
      final title = '✅ Datos sincronizados';
      final body = _formatSyncMessage(itemsSynced, additionalInfo);
      
      await LocalNotificationService.instance.showNotification(
        id: _syncNotificationId,
        title: title,
        body: body,
        channelId: _syncChannelId,
        channelName: _syncChannelName,
        priority: 'low', // Prioridad baja para no molestar
      );
      
      LoggerFactory.info('📱 Notificación de sync exitoso mostrada');
    } catch (e) {
      LoggerFactory.error('Error mostrando notificación de sync: $e');
    }
  }

  /// Mostrar notificación de error de sincronización
  Future<void> showSyncErrorNotification({
    required String errorMessage,
    bool canRetry = true,
  }) async {
    if (!_notificationsEnabled || kIsWeb || !_isInitialized) return;

    try {
      final title = '⚠️ Error de sincronización';
      final body = canRetry 
        ? 'Reintentando automáticamente...' 
        : 'Verifica tu conexión a internet';
      
      await LocalNotificationService.instance.showNotification(
        id: _syncNotificationId + 1,
        title: title,
        body: body,
        channelId: _syncChannelId,
        channelName: _syncChannelName,
        priority: 'default',
      );
      
      LoggerFactory.info('📱 Notificación de error de sync mostrada');
    } catch (e) {
      LoggerFactory.error('Error mostrando notificación de error: $e');
    }
  }

  /// Mostrar notificación de sincronización inicial
  Future<void> showInitialSyncNotification() async {
    if (!_notificationsEnabled || kIsWeb || !_isInitialized) return;

    try {
      await LocalNotificationService.instance.showNotification(
        id: _syncNotificationId + 2,
        title: '🔄 Sincronizando datos',
        body: 'Actualizando tu biblioteca de películas...',
        channelId: _syncChannelId,
        channelName: _syncChannelName,
        priority: 'low',
      );
      
      LoggerFactory.info('📱 Notificación de sync inicial mostrada');
    } catch (e) {
      LoggerFactory.error('Error mostrando notificación inicial: $e');
    }
  }

  /// Cancelar todas las notificaciones de sincronización
  Future<void> cancelAllSyncNotifications() async {
    if (!_notificationsEnabled || kIsWeb || !_isInitialized) return;

    try {
      await LocalNotificationService.instance.cancelNotification(_syncNotificationId);
      await LocalNotificationService.instance.cancelNotification(_syncNotificationId + 1);
      await LocalNotificationService.instance.cancelNotification(_syncNotificationId + 2);
      
      LoggerFactory.info('📱 Notificaciones de sync canceladas');
    } catch (e) {
      LoggerFactory.error('Error cancelando notificaciones: $e');
    }
  }

  String _formatSyncMessage(int itemsSynced, String? additionalInfo) {
    if (itemsSynced == 0) {
      return 'Datos actualizados';
    } else if (itemsSynced == 1) {
      return '1 elemento actualizado';
    } else {
      return '$itemsSynced elementos actualizados';
    }
  }

  /// Habilitar/deshabilitar notificaciones
  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    LoggerFactory.info('📱 Notificaciones de sync ${enabled ? 'habilitadas' : 'deshabilitadas'}');
  }

  /// Verificar si las notificaciones están habilitadas
  bool get isNotificationsEnabled => _notificationsEnabled && _isInitialized;
}