import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/error_reporting/error_reporting_service.dart';
import '../../core/logging/logger_factory.dart';

/// Error boundary widget para capturar y manejar errores de navegación
/// Previene crashes y proporciona una experiencia de usuario graceful
class NavigationErrorBoundary extends StatefulWidget {
  const NavigationErrorBoundary({
    super.key,
    required this.child,
    this.fallbackWidget,
    this.onError,
  });

  final Widget child;
  final Widget? fallbackWidget;
  final void Function(FlutterErrorDetails)? onError;

  @override
  State<NavigationErrorBoundary> createState() =>
      _NavigationErrorBoundaryState();
}

class _NavigationErrorBoundaryState extends State<NavigationErrorBoundary> {
  bool _hasError = false;
  FlutterErrorDetails? _errorDetails;
  FlutterExceptionHandler? _previousErrorHandler;

  @override
  void initState() {
    super.initState();

    // Override the error handler for this boundary
    _previousErrorHandler = FlutterError.onError;
    FlutterError.onError = _handleFlutterError;
  }

  @override
  void dispose() {
    if (FlutterError.onError == _handleFlutterError) {
      FlutterError.onError = _previousErrorHandler;
    }
    super.dispose();
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    // Log the error
    LoggerFactory.error(
        '🚨 Navigation Error Boundary caught error: ${details.exception}');
    LoggerFactory.debug('Stack trace: ${details.stack}');

    // Report to error reporting service
    ErrorReportingService.instance.reportError(
      details.exception,
      details.stack,
      reason: 'Navigation Error Boundary',
      data: {
        'error_boundary': 'NavigationErrorBoundary',
        'widget_tree': details.context?.toString() ?? 'unknown',
        'library': details.library ?? 'unknown',
      },
    );

    // Check if this is a navigation-related error
    final isNavigationError = _isNavigationRelatedError(details);

    if (isNavigationError && mounted) {
      setState(() {
        _hasError = true;
        _errorDetails = details;
      });
    }

    // Call custom error handler if provided
    widget.onError?.call(details);

    // Delegate to previous handler so Crashlytics/other handlers continue working
    if (_previousErrorHandler != null) {
      _previousErrorHandler!(details);
    } else if (!isNavigationError) {
      FlutterError.presentError(details);
    }
  }

  bool _isNavigationRelatedError(FlutterErrorDetails details) {
    final errorString = details.exception.toString().toLowerCase();
    final stackString = details.stack.toString().toLowerCase();

    return errorString.contains('navigation') ||
        errorString.contains('router') ||
        errorString.contains('route') ||
        errorString.contains('context.go') ||
        errorString.contains('context.push') ||
        stackString.contains('go_router') ||
        stackString.contains('navigation') ||
        stackString.contains('router');
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallbackWidget ?? _buildDefaultErrorWidget(context);
    }

    return widget.child;
  }

  Widget _buildDefaultErrorWidget(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error de Navegación'),
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error de Navegación',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ha ocurrido un error al navegar por la aplicación. No te preocupes, hemos registrado el error y trabajaremos para solucionarlo.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Action buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleRetry(context),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToHome(context),
                    icon: const Icon(Icons.home),
                    label: const Text('Ir al Inicio'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showErrorDetails(context),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Ver Detalles del Error'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleRetry(BuildContext context) {
    setState(() {
      _hasError = false;
      _errorDetails = null;
    });

    LoggerFactory.info('🔄 User retried after navigation error');
  }

  void _navigateToHome(BuildContext context) {
    try {
      context.go('/');
      LoggerFactory.info('🏠 User navigated to home after error');
    } catch (e) {
      LoggerFactory.error('❌ Failed to navigate to home: $e');
      // If navigation to home fails, show a more severe error
      _showCriticalError(context);
    }
  }

  void _showErrorDetails(BuildContext context) {
    if (_errorDetails == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles del Error'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Error:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              SelectableText(_errorDetails!.exception.toString()),
              const SizedBox(height: 16),
              Text(
                'Stack Trace:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _errorDetails!.stack.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: '${_errorDetails!.exception}\n\n${_errorDetails!.stack}',
              ));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error copiado al portapapeles'),
                ),
              );
            },
            child: const Text('Copiar'),
          ),
        ],
      ),
    );
  }

  void _showCriticalError(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Error Crítico'),
        content: const Text(
          'Ha ocurrido un error crítico en la navegación. Por favor, reinicia la aplicación.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Force restart app or exit
              SystemNavigator.pop();
            },
            child: const Text('Reiniciar App'),
          ),
        ],
      ),
    );
  }
}

/// Safe navigation utility que captura errores durante navegación
class SafeNavigation {
  static final _logger = LoggerFactory.logger;

  /// Navegar de forma segura usando go
  static void safeGo(BuildContext context, String route, {Object? extra}) {
    try {
      context.go(route, extra: extra);
      _logger.debug('✅ Safe navigation to: $route');
    } catch (e, stackTrace) {
      _logger.error('❌ Safe navigation failed for route: $route, error: $e');
      ErrorReportingService.instance.reportError(
        e,
        stackTrace,
        reason: 'Safe navigation failed',
        data: {
          'navigation_method': 'go',
          'target_route': route,
          'has_extra': extra != null,
        },
      );

      // Fallback navigation
      _fallbackNavigation(context, route);
    }
  }

  /// Navegar de forma segura usando push
  static void safePush(BuildContext context, String route, {Object? extra}) {
    try {
      context.push(route, extra: extra);
      _logger.debug('✅ Safe push navigation to: $route');
    } catch (e, stackTrace) {
      _logger
          .error('❌ Safe push navigation failed for route: $route, error: $e');
      ErrorReportingService.instance.reportError(
        e,
        stackTrace,
        reason: 'Safe push navigation failed',
        data: {
          'navigation_method': 'push',
          'target_route': route,
          'has_extra': extra != null,
        },
      );

      // Fallback navigation
      _fallbackNavigation(context, route);
    }
  }

  /// Reemplazar ruta actual de forma segura
  static void safeReplace(BuildContext context, String route, {Object? extra}) {
    try {
      context.pushReplacement(route, extra: extra);
      _logger.debug('✅ Safe replace navigation to: $route');
    } catch (e, stackTrace) {
      _logger.error(
          '❌ Safe replace navigation failed for route: $route, error: $e');
      ErrorReportingService.instance.reportError(
        e,
        stackTrace,
        reason: 'Safe replace navigation failed',
        data: {
          'navigation_method': 'replace',
          'target_route': route,
          'has_extra': extra != null,
        },
      );

      // Fallback navigation
      _fallbackNavigation(context, route);
    }
  }

  /// Navegación de fallback cuando falla la navegación principal
  static void _fallbackNavigation(BuildContext context, String targetRoute) {
    try {
      // Intentar navegar a la ruta más cercana o al home
      if (targetRoute.startsWith('/movie/')) {
        context.go('/'); // Ir al home si falla navegación a película
      } else if (targetRoute.startsWith('/my-library/')) {
        context.go(
            '/my-library'); // Ir a la biblioteca si falla navegación específica
      } else {
        context.go('/'); // Ir al home como último recurso
      }

      _logger.info('✅ Fallback navigation successful');
    } catch (e) {
      _logger.error('❌ Fallback navigation also failed: $e');
      // Si incluso el fallback falla, no hacer nada más
      // La app debería estar manejada por el NavigationErrorBoundary
    }
  }

  /// Verificar si una ruta es válida antes de navegar
  static bool isValidRoute(String route) {
    try {
      // Lista de rutas conocidas válidas
      const validRoutes = [
        '/',
        '/my-library',
        '/search',
        '/favorites',
        '/watchlist',
        '/settings',
        '/profile',
        '/login',
        '/register',
      ];

      // Rutas con parámetros dinámicos
      const validPatterns = [
        r'^/movie/\d+$',
        r'^/my-library/lists/.+$',
        r'^/recommendations/.+$',
      ];

      // Verificar rutas exactas
      if (validRoutes.contains(route)) {
        return true;
      }

      // Verificar patrones
      for (final pattern in validPatterns) {
        if (RegExp(pattern).hasMatch(route)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.warning('Error validating route: $route, error: $e');
      return false;
    }
  }

  /// Sanitizar una ruta antes de navegación
  static String sanitizeRoute(String route) {
    // Eliminar caracteres peligrosos o inválidos
    String sanitized = route.trim();

    // Asegurar que comience con /
    if (!sanitized.startsWith('/')) {
      sanitized = '/$sanitized';
    }

    // Eliminar múltiples slashes consecutivos
    sanitized = sanitized.replaceAll(RegExp(r'/+'), '/');

    // Eliminar trailing slash excepto para root
    if (sanitized.length > 1 && sanitized.endsWith('/')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }

    return sanitized;
  }
}
