import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger_factory.dart';

/// Servicio de polling simple para sincronización en tiempo real
/// Se ejecuta en segundo plano cada X segundos para sincronizar con Supabase
class SimplePollingSync {
  SimplePollingSync._internal();

  static final SimplePollingSync _instance = SimplePollingSync._internal();
  static SimplePollingSync get instance => _instance;

  Timer? _pollingTimer;
  bool _isPolling = false;
  String? _currentUserId;
  DateTime? _lastSyncTime;

  /// Inicializa el polling para un usuario
  void startPolling(String userId) {
    if (_isPolling && _currentUserId == userId) {
      LoggerFactory.info('🔄 Polling ya está activo para usuario: $userId');
      return;
    }

    stopPolling(); // Detener cualquier polling previo

    _currentUserId = userId;
    _isPolling = true;
    _lastSyncTime = DateTime.now().subtract(
        const Duration(seconds: 30)); // Sync últimos 30 segundos al iniciar

    LoggerFactory.info('🚀 Iniciando polling para usuario: $userId');

    // Polling cada 10 segundos
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _performPollingSync();
    });

    // Hacer una sync inicial inmediatamente
    Future.delayed(const Duration(milliseconds: 500), () {
      _performPollingSync();
    });
  }

  /// Detiene el polling
  void stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
    }

    _isPolling = false;
    _currentUserId = null;

    LoggerFactory.info('🛑 Polling detenido');
  }

  /// Realiza la sincronización de polling
  Future<void> _performPollingSync() async {
    if (!_isPolling || _currentUserId == null) return;

    try {
      LoggerFactory.debug('🔄 Polling sync para usuario: $_currentUserId');

      // Obtener favoritos de Supabase modificados desde la última sync
      final newFavorites = await _getFavoritesModifiedAfter(_lastSyncTime!);

      if (newFavorites.isNotEmpty) {
        LoggerFactory.info(
            '📥 Polling encontró ${newFavorites.length} favoritos nuevos/modificados');

        // Notificar a los listeners que hay cambios
        _notifyFavoritesChanged(newFavorites);
      }

      _lastSyncTime = DateTime.now();
    } catch (e) {
      LoggerFactory.error('❌ Error en polling sync: $e');
    }
  }

  /// Obtiene favoritos modificados después de un timestamp
  Future<List<Map<String, dynamic>>> _getFavoritesModifiedAfter(
      DateTime timestamp) async {
    try {
      final response = await Supabase.instance.client
          .from('user_favorites')
          .select('*')
          .eq('user_id', _currentUserId!)
          .filter('last_modified_at', 'gte', timestamp.toIso8601String())
          .order('last_modified_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo favoritos modificados: $e');
      return [];
    }
  }

  /// Notifica a los listeners que hay cambios en favoritos
  void _notifyFavoritesChanged(List<Map<String, dynamic>> favorites) {
    // Aquí podríamos usar un StreamController o callback para notificar
    // Por simplicidad, vamos a usar un método que puede ser observado
    _onFavoritesChanged?.call(favorites);
  }

  /// Callback para cuando cambian los favoritos
  Function(List<Map<String, dynamic>>)? _onFavoritesChanged;

  /// Establecer callback para cambios de favoritos
  void setOnFavoritesChanged(Function(List<Map<String, dynamic>>) callback) {
    _onFavoritesChanged = callback;
  }

  /// Verifica si está haciendo polling
  bool get isPolling => _isPolling;

  /// ID del usuario actual
  String? get currentUserId => _currentUserId;
}
