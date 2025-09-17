import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../logging/logger_factory.dart';
import 'app_state_manager.dart';

/// Widget que maneja la restauración automática del estado de navegación
class AppStateRestoration extends StatefulWidget {
  const AppStateRestoration({
    super.key,
    required this.child,
    this.enableAutoRestore = true,
    this.showRecoveryDialog = true,
  });

  final Widget child;
  final bool enableAutoRestore;
  final bool showRecoveryDialog;

  @override
  State<AppStateRestoration> createState() => _AppStateRestorationState();
}

class _AppStateRestorationState extends State<AppStateRestoration>
    with WidgetsBindingObserver {
  final _logger = LoggerFactory.logger;
  final _stateManager = AppStateManager.instance;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeStateRestoration();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        _logger.debug('App pausada, guardando estado...');
        _stateManager.saveImmediately();
        break;
      case AppLifecycleState.detached:
        _logger.debug('App terminándose, guardando estado final...');
        _stateManager.saveImmediately();
        break;
      case AppLifecycleState.resumed:
        _logger.debug('App resumida');
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initializeStateRestoration() async {
    if (_hasInitialized) return;

    try {
      await _stateManager.initialize();

      if (mounted && widget.enableAutoRestore) {
        await _performStateRestoration();
      }

      _hasInitialized = true;
    } catch (e) {
      _logger.error('Error inicializando restauración de estado: $e');
    }
  }

  Future<void> _performStateRestoration() async {
    // Verificar si necesitamos mostrar diálogo de recuperación
    if (_stateManager.isRecoveringFromCrash && widget.showRecoveryDialog) {
      await _showRecoveryDialog();
    }

    // Restaurar navegación si hay una ruta previa
    final lastRoute = _stateManager.lastRoute;
    if (lastRoute != null && lastRoute != '/' && mounted) {
      _logger.info('Restaurando navegación a: $lastRoute');

      // Usar GoRouter para navegar de forma segura
      try {
        // Usar post frame callback para asegurar que el contexto esté listo
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go(lastRoute);
          }
        });
      } catch (e) {
        _logger.error('Error restaurando navegación a $lastRoute: $e');
        // Fallback a ruta segura
        if (mounted) {
          context.go('/');
        }
      }
    }

    // Marcar recuperación como completada si corresponde
    if (_stateManager.isRecoveringFromCrash) {
      _stateManager.markCrashRecoveryComplete();
    }
  }

  Future<void> _showRecoveryDialog() async {
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.restore, color: Colors.orange),
              SizedBox(width: 8),
              Text('Recuperación de Estado'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La aplicación se recuperó de un cierre inesperado.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                'Hemos restaurado tu sesión al último estado conocido. '
                'Si experimentas problemas, puedes reiniciar desde el inicio.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Limpiar estado y ir al inicio
                _stateManager.clearSessionData();
                context.go('/');
              },
              child: const Text('Reiniciar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Continuar con la restauración
              },
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios de ruta y actualizar estado
    return NavigationTracker(
      stateManager: _stateManager,
      child: widget.child,
    );
  }
}

/// Widget que rastrea cambios de navegación
class NavigationTracker extends StatefulWidget {
  const NavigationTracker({
    super.key,
    required this.stateManager,
    required this.child,
  });

  final AppStateManager stateManager;
  final Widget child;

  @override
  State<NavigationTracker> createState() => _NavigationTrackerState();
}

class _NavigationTrackerState extends State<NavigationTracker> {
  final _logger = LoggerFactory.logger;
  String? _lastLocation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurrentLocation();
  }

  void _updateCurrentLocation() {
    try {
      final currentLocation = GoRouterState.of(context).uri.toString();
      if (currentLocation != _lastLocation) {
        _lastLocation = currentLocation;
        widget.stateManager.updateCurrentRoute(currentLocation);
        _logger.debug('Ruta actualizada en estado: $currentLocation');
      }
    } catch (e) {
      _logger.error('Error actualizando ubicación actual: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin para widgets que necesitan guardar/restaurar estado específico
mixin StatePersistenceMixin<T extends StatefulWidget> on State<T> {
  final _stateManager = AppStateManager.instance;

  /// Clave única para este widget
  String get stateKey;

  /// Guarda el estado específico del widget
  void saveWidgetState(Map<String, dynamic> state) {
    _stateManager.updateSessionData(stateKey, state);
  }

  /// Restaura el estado específico del widget
  Map<String, dynamic>? restoreWidgetState() {
    return _stateManager.getSessionValue<Map<String, dynamic>>(stateKey);
  }

  /// Limpia el estado específico del widget
  void clearWidgetState() {
    _stateManager.updateSessionData(stateKey, null);
  }
}

/// Extensión para facilitar el uso del estado en widgets
extension AppStateExtension on BuildContext {
  /// Acceso rápido al AppStateManager
  AppStateManager get appState => AppStateManager.instance;

  /// Guarda un valor en el estado de sesión
  void saveSessionValue(String key, dynamic value) {
    AppStateManager.instance.updateSessionData(key, value);
  }

  /// Obtiene un valor del estado de sesión
  T? getSessionValue<T>(String key) {
    return AppStateManager.instance.getSessionValue<T>(key);
  }

  /// Guarda una preferencia de usuario
  void saveUserPreference(String key, dynamic value) {
    AppStateManager.instance.updateUserPreference(key, value);
  }

  /// Obtiene una preferencia de usuario
  T? getUserPreference<T>(String key) {
    return AppStateManager.instance.getUserPreference<T>(key);
  }
}
