import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logging/logger_factory.dart';

/// Gestor de estado de aplicación para restauración automática
/// después de crashes o reinicios
class AppStateManager {
  factory AppStateManager() => _instance;
  AppStateManager._internal();
  static final AppStateManager _instance = AppStateManager._internal();

  static AppStateManager get instance => _instance;

  final _logger = LoggerFactory.logger;
  SharedPreferences? _prefs;
  Timer? _saveTimer;

  // Claves para almacenamiento
  static const String _lastRouteKey = 'app_state_last_route';
  static const String _sessionDataKey = 'app_state_session_data';
  static const String _userPreferencesKey = 'app_state_user_preferences';
  static const String _appStateKey = 'app_state_general';
  static const String _lastSaveTimestampKey = 'app_state_last_save';
  static const String _crashDataKey = 'app_state_crash_data';

  // Estado actual
  String? _currentRoute;
  Map<String, dynamic> _sessionData = {};
  Map<String, dynamic> _userPreferences = {};
  Map<String, dynamic> _appState = {};
  bool _isInitialized = false;
  bool _hasUnsavedChanges = false;

  /// Inicializa el gestor de estado
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadStoredState();
      _startPeriodicSave();
      _isInitialized = true;

      _logger.info('AppStateManager inicializado correctamente');
    } catch (e) {
      _logger.error('Error inicializando AppStateManager: $e');
    }
  }

  /// Carga el estado almacenado desde SharedPreferences
  Future<void> _loadStoredState() async {
    try {
      // Cargar ruta anterior
      _currentRoute = _prefs?.getString(_lastRouteKey);

      // Cargar datos de sesión
      final sessionJson = _prefs?.getString(_sessionDataKey);
      if (sessionJson != null && sessionJson.isNotEmpty) {
        _sessionData = Map<String, dynamic>.from(jsonDecode(sessionJson));
      }

      // Cargar preferencias de usuario
      final prefsJson = _prefs?.getString(_userPreferencesKey);
      if (prefsJson != null && prefsJson.isNotEmpty) {
        _userPreferences = Map<String, dynamic>.from(jsonDecode(prefsJson));
      }

      // Cargar estado general
      final stateJson = _prefs?.getString(_appStateKey);
      if (stateJson != null && stateJson.isNotEmpty) {
        _appState = Map<String, dynamic>.from(jsonDecode(stateJson));
      }

      // Verificar si hay datos de crash
      await _checkForCrashData();

      _logger.debug(
          'Estado restaurado: route=$_currentRoute, session=${_sessionData.length} items');
    } catch (e) {
      _logger.error('Error cargando estado almacenado: $e');
      // Limpiar datos corruptos
      await _clearStoredState();
    }
  }

  /// Verifica si hay datos de crash previo
  Future<void> _checkForCrashData() async {
    final crashDataJson = _prefs?.getString(_crashDataKey);
    if (crashDataJson != null && crashDataJson.isNotEmpty) {
      try {
        final crashData = Map<String, dynamic>.from(jsonDecode(crashDataJson));
        _logger.warning('Detectado crash previo: $crashData');

        // Procesar datos de crash
        await _processCrashRecovery(crashData);

        // Limpiar datos de crash después de procesarlos
        await _prefs?.remove(_crashDataKey);
      } catch (e) {
        _logger.error('Error procesando datos de crash: $e');
      }
    }
  }

  /// Procesa la recuperación después de un crash
  Future<void> _processCrashRecovery(Map<String, dynamic> crashData) async {
    _logger.info('Iniciando recuperación post-crash...');

    // Validar y limpiar datos potencialmente corruptos
    if (crashData.containsKey('corrupted_session')) {
      _sessionData.clear();
      _logger.warning('Sesión corrompida detectada, limpiando datos de sesión');
    }

    // Restaurar estado seguro
    if (crashData.containsKey('safe_route')) {
      _currentRoute = crashData['safe_route'] as String?;
      _logger.info('Restaurando ruta segura: $_currentRoute');
    } else {
      _currentRoute = '/'; // Ruta por defecto
    }

    // Marcar como recuperación de crash
    _appState['crash_recovery'] = true;
    _appState['crash_timestamp'] = DateTime.now().toIso8601String();

    _hasUnsavedChanges = true;
  }

  /// Guarda el estado actual de forma periódica
  void _startPeriodicSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasUnsavedChanges) {
        _saveStateToStorage();
      }
    });
  }

  /// Actualiza la ruta actual
  void updateCurrentRoute(String route) {
    if (_currentRoute != route) {
      _currentRoute = route;
      _hasUnsavedChanges = true;

      _logger.debug('Ruta actualizada: $route');
    }
  }

  /// Actualiza datos de sesión
  void updateSessionData(String key, dynamic value) {
    if (_sessionData[key] != value) {
      _sessionData[key] = value;
      _hasUnsavedChanges = true;

      _logger.debug('Datos de sesión actualizados: $key');
    }
  }

  /// Actualiza preferencias de usuario
  void updateUserPreference(String key, dynamic value) {
    if (_userPreferences[key] != value) {
      _userPreferences[key] = value;
      _hasUnsavedChanges = true;

      _logger.debug('Preferencia actualizada: $key');
    }
  }

  /// Actualiza estado general de la aplicación
  void updateAppState(String key, dynamic value) {
    if (_appState[key] != value) {
      _appState[key] = value;
      _hasUnsavedChanges = true;

      _logger.debug('Estado de app actualizado: $key');
    }
  }

  /// Guarda el estado inmediatamente
  Future<void> saveImmediately() async {
    await _saveStateToStorage();
  }

  /// Guarda el estado en SharedPreferences
  Future<void> _saveStateToStorage() async {
    if (!_isInitialized || _prefs == null) return;

    try {
      // Guardar ruta actual
      if (_currentRoute != null) {
        await _prefs!.setString(_lastRouteKey, _currentRoute!);
      }

      // Guardar datos de sesión
      if (_sessionData.isNotEmpty) {
        await _prefs!.setString(_sessionDataKey, jsonEncode(_sessionData));
      }

      // Guardar preferencias de usuario
      if (_userPreferences.isNotEmpty) {
        await _prefs!
            .setString(_userPreferencesKey, jsonEncode(_userPreferences));
      }

      // Guardar estado general
      if (_appState.isNotEmpty) {
        await _prefs!.setString(_appStateKey, jsonEncode(_appState));
      }

      // Guardar timestamp del último guardado
      await _prefs!
          .setString(_lastSaveTimestampKey, DateTime.now().toIso8601String());

      _hasUnsavedChanges = false;
      _logger.debug('Estado guardado correctamente');
    } catch (e) {
      _logger.error('Error guardando estado: $e');
    }
  }

  /// Registra datos de crash para recuperación
  Future<void> registerCrashData({
    String? currentRoute,
    Map<String, dynamic>? sessionData,
    String? errorMessage,
  }) async {
    try {
      final crashData = {
        'timestamp': DateTime.now().toIso8601String(),
        'current_route': currentRoute ?? _currentRoute,
        'safe_route': _getSafeRoute(currentRoute ?? _currentRoute),
        'session_data_count': sessionData?.length ?? _sessionData.length,
        'error_message': errorMessage,
        'corrupted_session': sessionData == null && _sessionData.isNotEmpty,
      };

      await _prefs?.setString(_crashDataKey, jsonEncode(crashData));
      _logger.error('Datos de crash registrados: $crashData');
    } catch (e) {
      _logger.error('Error registrando datos de crash: $e');
    }
  }

  /// Determina una ruta segura basada en la ruta actual
  String _getSafeRoute(String? currentRoute) {
    // Rutas conocidas como seguras
    const safeRoutes = ['/', '/movies', '/search', '/profile'];

    if (currentRoute == null || currentRoute.isEmpty) {
      return '/';
    }

    // Si la ruta actual es segura, usarla
    if (safeRoutes.contains(currentRoute)) {
      return currentRoute;
    }

    // Si es una ruta de detalle, ir a la lista correspondiente
    if (currentRoute.startsWith('/movie/')) {
      return '/movies';
    }

    if (currentRoute.startsWith('/person/')) {
      return '/search';
    }

    // Por defecto, ir al home
    return '/';
  }

  /// Limpia todo el estado almacenado
  Future<void> _clearStoredState() async {
    try {
      await _prefs?.remove(_lastRouteKey);
      await _prefs?.remove(_sessionDataKey);
      await _prefs?.remove(_userPreferencesKey);
      await _prefs?.remove(_appStateKey);
      await _prefs?.remove(_lastSaveTimestampKey);
      await _prefs?.remove(_crashDataKey);

      _currentRoute = null;
      _sessionData.clear();
      _userPreferences.clear();
      _appState.clear();
      _hasUnsavedChanges = false;

      _logger.info('Estado almacenado limpiado');
    } catch (e) {
      _logger.error('Error limpiando estado: $e');
    }
  }

  /// Limpia solo los datos de sesión (mantiene preferencias)
  Future<void> clearSessionData() async {
    _sessionData.clear();
    _hasUnsavedChanges = true;
    await _saveStateToStorage();
    _logger.info('Datos de sesión limpiados');
  }

  /// Getters para acceder al estado
  String? get lastRoute => _currentRoute;
  Map<String, dynamic> get sessionData => Map.unmodifiable(_sessionData);
  Map<String, dynamic> get userPreferences =>
      Map.unmodifiable(_userPreferences);
  Map<String, dynamic> get appState => Map.unmodifiable(_appState);
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get isInitialized => _isInitialized;

  /// Obtiene un valor específico de sesión
  T? getSessionValue<T>(String key) {
    return _sessionData[key] as T?;
  }

  /// Obtiene una preferencia específica de usuario
  T? getUserPreference<T>(String key) {
    return _userPreferences[key] as T?;
  }

  /// Obtiene un valor específico del estado de la app
  T? getAppStateValue<T>(String key) {
    return _appState[key] as T?;
  }

  /// Verifica si la app se está recuperando de un crash
  bool get isRecoveringFromCrash {
    return _appState['crash_recovery'] == true;
  }

  /// Marca la recuperación de crash como completada
  void markCrashRecoveryComplete() {
    _appState.remove('crash_recovery');
    _hasUnsavedChanges = true;
    _logger.info('Recuperación de crash marcada como completada');
  }

  /// Obtiene estadísticas del estado
  Map<String, dynamic> getStateStatistics() {
    final lastSave = _prefs?.getString(_lastSaveTimestampKey);
    return {
      'initialized': _isInitialized,
      'current_route': _currentRoute,
      'session_data_keys': _sessionData.keys.length,
      'user_preferences_keys': _userPreferences.keys.length,
      'app_state_keys': _appState.keys.length,
      'has_unsaved_changes': _hasUnsavedChanges,
      'last_save_timestamp': lastSave,
      'is_recovering_from_crash': isRecoveringFromCrash,
    };
  }

  /// Dispose del gestor
  void dispose() {
    _saveTimer?.cancel();
    if (_hasUnsavedChanges) {
      // Guardar estado final de forma síncrona si es posible
      _saveStateToStorage();
    }
    _logger.info('AppStateManager disposed');
  }
}
