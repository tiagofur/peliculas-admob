import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/logging/logger_factory.dart';
import 'web_safe_storage_service.dart';

/// Servicio para manejar sesiones persistentes y seguras de autenticación
class AuthSessionManager {
  AuthSessionManager._();
  static AuthSessionManager? _instance;
  static AuthSessionManager get instance =>
      _instance ??= AuthSessionManager._();

  final WebSafeStorageService _storage = WebSafeStorageService.instance;
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Claves de almacenamiento
  static const String _sessionKey = 'auth_session_encrypted';
  static const String _lastValidationKey = 'last_session_validation';
  static const String _deviceIdKey = 'device_id';
  static const String _sessionTokenKey = 'session_token_hash';

  // Configuración
  static const Duration _sessionValidationInterval = Duration(minutes: 5);
  static const Duration _maxSessionAge = Duration(days: 30);
  static const Duration _operationTimeout = Duration(seconds: 30);
  static const int _maxRetryAttempts = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 2);

  Timer? _validationTimer;
  String? _deviceId;
  bool _isInitialized = false;
  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;

  /// Inicializa el gestor de sesiones
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Ejecutar inicialización con timeout
      await _executeWithTimeout(
        () async {
          // Generar o recuperar ID de dispositivo único
          await _initializeDeviceId();

          // Recuperar sesión persistente si existe
          await _recoverPersistedSession();

          // Iniciar validación periódica
          _startPeriodicValidation();
        },
        timeout: _operationTimeout,
        operationName: 'initialize',
      );

      _isInitialized = true;
      _consecutiveFailures = 0; // Reset failure count on success

      if (kDebugMode) {
        LoggerFactory.info('✅ AuthSessionManager inicializado correctamente');
      }
    } catch (e) {
      _recordFailure();
      LoggerFactory.error('❌ Error inicializando AuthSessionManager: $e');

      // En caso de fallo crítico, seguir adelante sin sesión persistente
      _isInitialized = true; // Mark as initialized to avoid loops
      LoggerFactory.warning(
          '⚠️ Continuando sin sesión persistente debido a error');
    }
  }

  /// Guarda la sesión actual de forma segura
  Future<void> persistSession(Session session) async {
    try {
      await _executeWithTimeout(
        () async {
          final sessionData = {
            'access_token': session.accessToken,
            'refresh_token': session.refreshToken,
            'expires_at': session.expiresAt,
            'user_id': session.user.id,
            'device_id': _deviceId,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          };

          // Encriptar datos de sesión
          final encryptedData = _encryptSessionData(sessionData);

          // Guardar sesión encriptada
          await _storage.saveString(_sessionKey, encryptedData);

          // Guardar hash del token para validación rápida
          final tokenHash = _generateTokenHash(session.accessToken);
          await _storage.saveString(_sessionTokenKey, tokenHash);

          // Actualizar timestamp de última validación
          await _storage.saveString(
            _lastValidationKey,
            DateTime.now().millisecondsSinceEpoch.toString(),
          );
        },
        timeout: _operationTimeout,
        operationName: 'persistSession',
      );

      _consecutiveFailures = 0; // Reset on success

      if (kDebugMode) {
        LoggerFactory.info('✅ Sesión persistida de forma segura');
      }
    } catch (e) {
      _recordFailure();
      LoggerFactory.error('❌ Error persistiendo sesión: $e');
      throw Exception('Error al guardar sesión: $e');
    }
  }

  /// Recupera una sesión persistente
  Future<bool> recoverSession() async {
    try {
      // Check circuit breaker
      if (_shouldCircuitBreak()) {
        LoggerFactory.warning(
            '🚨 Circuit breaker activo - omitiendo recovery por fallos consecutivos');
        return false;
      }

      return await _executeWithTimeout(
        () => _recoverPersistedSession(),
        timeout: _operationTimeout,
        operationName: 'recoverSession',
      );
    } catch (e) {
      _recordFailure();
      LoggerFactory.error('❌ Error recuperando sesión: $e');
      return false;
    }
  }

  /// Valida si la sesión actual sigue siendo válida
  Future<bool> validateCurrentSession() async {
    try {
      return await _executeWithTimeout(
        () async {
          final currentUser = _supabase.auth.currentUser;
          if (currentUser == null) return false;

          // Verificar si la sesión ha expirado
          final session = _supabase.auth.currentSession;
          if (session == null) return false;

          final now = DateTime.now();
          final expiresAt = DateTime.fromMillisecondsSinceEpoch(
              (session.expiresAt ?? 0) * 1000);

          // Si expira en menos de 5 minutos, considerar inválida para forzar refresh
          if (expiresAt.difference(now).inMinutes < 5) {
            if (kDebugMode) {
              LoggerFactory.info(
                  '🔄 Sesión próxima a expirar, marcando como inválida');
            }
            return false;
          }

          // Verificar hash del token almacenado
          final storedHash = await _storage.getString(_sessionTokenKey);
          if (storedHash != null) {
            final currentHash = _generateTokenHash(session.accessToken);
            if (storedHash != currentHash) {
              if (kDebugMode) {
                LoggerFactory.warning(
                    '⚠️ Hash de token no coincide, sesión comprometida');
              }
              return false;
            }
          }

          return true;
        },
        timeout: const Duration(seconds: 10), // Shorter timeout for validation
        operationName: 'validateCurrentSession',
        maxRetries: 2, // Fewer retries for validation
      );
    } catch (e) {
      _recordFailure();
      LoggerFactory.error('❌ Error validando sesión: $e');
      return false;
    }
  }

  /// Limpia todos los datos de sesión
  Future<void> clearSession() async {
    try {
      _validationTimer?.cancel();

      await _storage.remove(_sessionKey);
      await _storage.remove(_sessionTokenKey);
      await _storage.remove(_lastValidationKey);

      if (kDebugMode) {
        LoggerFactory.info('✅ Datos de sesión limpiados');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error limpiando sesión: $e');
    }
  }

  /// Obtiene información sobre la sesión persistida
  Future<Map<String, dynamic>?> getSessionInfo() async {
    try {
      final encryptedData = await _storage.getString(_sessionKey);
      if (encryptedData == null) return null;

      final sessionData = _decryptSessionData(encryptedData);

      return {
        'user_id': sessionData['user_id'],
        'device_id': sessionData['device_id'],
        'created_at': sessionData['created_at'],
        'expires_at': sessionData['expires_at'],
        'is_valid': await validateCurrentSession(),
      };
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo info de sesión: $e');
      return null;
    }
  }

  /// Verifica si hay una sesión persistente disponible
  Future<bool> hasPersistedSession() async {
    try {
      final encryptedData = await _storage.getString(_sessionKey);
      return encryptedData != null;
    } catch (e) {
      return false;
    }
  }

  // --- Métodos privados ---

  Future<void> _initializeDeviceId() async {
    _deviceId = await _storage.getString(_deviceIdKey);

    if (_deviceId == null) {
      // Generar ID único basado en timestamp y datos aleatorios
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = DateTime.now().microsecondsSinceEpoch;
      _deviceId = _generateHash('$timestamp-$random');

      if (_deviceId != null) {
        await _storage.saveString(_deviceIdKey, _deviceId!);
      }
    }
  }

  Future<bool> _recoverPersistedSession() async {
    try {
      final encryptedData = await _storage.getString(_sessionKey);
      if (encryptedData == null) return false;

      final sessionData = _decryptSessionData(encryptedData);

      // Verificar que los datos son válidos
      if (!_isSessionDataValid(sessionData)) {
        await clearSession();
        return false;
      }

      // Verificar que no ha expirado
      final expiresAt = sessionData['expires_at'] as int?;
      if (expiresAt != null) {
        final expirationDate =
            DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        if (DateTime.now().isAfter(expirationDate)) {
          if (kDebugMode) {
            LoggerFactory.info(
                '🔄 Sesión persistida expirada, intentando refresh');
          }
          // Intentar refrescar con refresh token si está disponible
          return await _attemptTokenRefresh(sessionData);
        }
      }

      // Verificar edad máxima de la sesión
      final createdAt = sessionData['created_at'] as int?;
      if (createdAt != null) {
        final creationDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
        if (DateTime.now().difference(creationDate) > _maxSessionAge) {
          if (kDebugMode) {
            LoggerFactory.info('⏰ Sesión demasiado antigua, requiere re-login');
          }
          await clearSession();
          return false;
        }
      }

      // Intentar restaurar la sesión en Supabase
      try {
        await _supabase.auth.setSession(sessionData['refresh_token']);

        if (kDebugMode) {
          LoggerFactory.info('✅ Sesión recuperada exitosamente');
        }
        return true;
      } catch (e) {
        if (kDebugMode) {
          LoggerFactory.info(
              '🔄 Error restaurando sesión, intentando refresh: $e');
        }
        return await _attemptTokenRefresh(sessionData);
      }
    } catch (e) {
      LoggerFactory.error('❌ Error recuperando sesión persistida: $e');
      await clearSession();
      return false;
    }
  }

  Future<bool> _attemptTokenRefresh(Map<String, dynamic> sessionData) async {
    try {
      return await _executeWithTimeout(
        () async {
          final refreshToken = sessionData['refresh_token'] as String?;
          if (refreshToken == null) {
            throw Exception('Refresh token no disponible');
          }

          final response = await _supabase.auth.refreshSession(refreshToken);
          if (response.session != null) {
            // Persistir la nueva sesión
            await persistSession(response.session!);

            if (kDebugMode) {
              LoggerFactory.info('✅ Token refrescado y sesión actualizada');
            }
            return true;
          }

          throw Exception('Respuesta de refresh inválida');
        },
        timeout: _operationTimeout,
        operationName: 'attemptTokenRefresh',
        maxRetries: 2, // Limit retries for refresh to avoid loops
      );
    } catch (e) {
      _recordFailure();
      LoggerFactory.error('❌ Error refrescando token: $e');

      // Only clear session on non-recoverable errors
      if (e.toString().contains('refresh_token_not_found') ||
          e.toString().contains('invalid_grant') ||
          e.toString().contains('Token has expired')) {
        await clearSession();
      }

      return false;
    }
  }

  void _startPeriodicValidation() {
    _validationTimer?.cancel(); // Cancel existing timer if any

    _validationTimer =
        Timer.periodic(_sessionValidationInterval, (timer) async {
      try {
        // Don't validate if circuit breaker is active
        if (_shouldCircuitBreak()) {
          LoggerFactory.info(
              '🛑 Omitiendo validación periódica - circuit breaker activo');
          return;
        }

        final isValid = await validateCurrentSession();

        if (!isValid) {
          if (kDebugMode) {
            LoggerFactory.warning(
                '⚠️ Validación periódica fallida, iniciando limpieza');
          }
          timer.cancel();
          await clearSession();

          // Notify about session invalidation if needed
          _notifySessionInvalidated();
        } else {
          // Reset failure count on successful validation
          if (_consecutiveFailures > 0) {
            LoggerFactory.info(
                '✅ Validación exitosa - reseteando contador de fallos');
            _consecutiveFailures = 0;
            _lastFailureTime = null;
          }
        }
      } catch (e) {
        LoggerFactory.error('❌ Error en validación periódica: $e');
        _recordFailure();

        // If too many consecutive failures, stop validation
        if (_consecutiveFailures >= _maxRetryAttempts * 2) {
          LoggerFactory.warning(
              '🚨 Deteniendo validación periódica por exceso de fallos');
          timer.cancel();
        }
      }
    });
  }

  /// Notifica cuando la sesión se ha invalidado (placeholder para eventos futuros)
  void _notifySessionInvalidated() {
    if (kDebugMode) {
      LoggerFactory.info('📢 Sesión invalidada - notificando a listeners');
    }
    // Future: Emit events to notify other parts of the app
  }

  bool _isSessionDataValid(Map<String, dynamic> sessionData) {
    return sessionData.containsKey('access_token') &&
        sessionData.containsKey('refresh_token') &&
        sessionData.containsKey('user_id') &&
        sessionData.containsKey('device_id') &&
        sessionData['device_id'] == _deviceId;
  }

  String _encryptSessionData(Map<String, dynamic> data) {
    // Simple XOR encryption with device ID as key
    // En producción, usar una librería de encriptación más robusta
    final jsonString = jsonEncode(data);
    final key = _deviceId ?? 'default_key';
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(jsonString);

    final encryptedBytes = <int>[];
    for (int i = 0; i < dataBytes.length; i++) {
      encryptedBytes.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return base64Encode(encryptedBytes);
  }

  Map<String, dynamic> _decryptSessionData(String encryptedData) {
    final key = _deviceId ?? 'default_key';
    final keyBytes = utf8.encode(key);
    final encryptedBytes = base64Decode(encryptedData);

    final decryptedBytes = <int>[];
    for (int i = 0; i < encryptedBytes.length; i++) {
      decryptedBytes.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    final jsonString = utf8.decode(decryptedBytes);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  String _generateTokenHash(String token) {
    return _generateHash(token);
  }

  String _generateHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Ejecuta una operación con timeout y retry logic
  Future<T> _executeWithTimeout<T>(
    Future<T> Function() operation, {
    required Duration timeout,
    required String operationName,
    int? maxRetries,
  }) async {
    maxRetries ??= _maxRetryAttempts;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation().timeout(timeout);
      } catch (e) {
        final isLastAttempt = attempt == maxRetries;

        if (isLastAttempt) {
          LoggerFactory.error(
              '❌ $operationName falló después de $maxRetries intentos: $e');
          rethrow;
        }

        // Calcular delay con exponential backoff
        final delay = Duration(
          milliseconds: _baseRetryDelay.inMilliseconds *
              (1 << (attempt - 1)), // 2^(attempt-1)
        );

        LoggerFactory.warning(
            '⚠️ $operationName intento $attempt/$maxRetries falló: $e. '
            'Reintentando en ${delay.inMilliseconds}ms');

        await Future.delayed(delay);
      }
    }

    throw Exception(
        'Operación $operationName falló después de $maxRetries intentos');
  }

  /// Registra un fallo para tracking
  void _recordFailure() {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();

    if (_consecutiveFailures >= _maxRetryAttempts) {
      LoggerFactory.warning(
          '🚨 AuthSessionManager: $_consecutiveFailures fallos consecutivos');
    }
  }

  /// Verifica si deberíamos hacer circuit breaking por demasiados fallos
  bool _shouldCircuitBreak() {
    if (_consecutiveFailures < _maxRetryAttempts) return false;
    if (_lastFailureTime == null) return false;

    // Si han pasado más de 10 minutos desde el último fallo, resetear
    if (DateTime.now().difference(_lastFailureTime!) >
        const Duration(minutes: 10)) {
      _consecutiveFailures = 0;
      _lastFailureTime = null;
      return false;
    }

    return true;
  }

  /// Libera recursos del gestor
  void dispose() {
    _validationTimer?.cancel();
    _validationTimer = null;
    _isInitialized = false;
    _consecutiveFailures = 0;
    _lastFailureTime = null;
  }
}
