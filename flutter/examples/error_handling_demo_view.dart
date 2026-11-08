import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peliculas/core/error_handling/centralized_error_handler.dart';
import 'package:peliculas/core/exceptions/app_exceptions.dart';
import 'package:peliculas/presentation/widgets/error_widgets.dart';

/// Página de demostración del sistema de error handling mejorado
class ErrorHandlingDemoView extends ConsumerWidget {
  const ErrorHandlingDemoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo: Error Handling Mejorado'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header explicativo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 Sistema de Error Handling Centralizado',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este sistema convierte errores técnicos en mensajes user-friendly con acciones específicas.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botones para simular diferentes tipos de errores
            Text(
              'Tipos de Errores Implementados:',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 16),

            // Network Errors
            _buildErrorDemoSection(
              context,
              title: '🌐 Errores de Red',
              description: 'Sin conexión, timeout, problemas de servidor',
              buttons: [
                _DemoButton(
                  label: 'Sin Conexión',
                  severity: ErrorSeverity.high,
                  onPressed: () =>
                      _simulateNetworkError(context, 'NO_CONNECTION'),
                ),
                _DemoButton(
                  label: 'Timeout',
                  severity: ErrorSeverity.medium,
                  onPressed: () => _simulateNetworkError(context, 'TIMEOUT'),
                ),
                _DemoButton(
                  label: 'Error Servidor',
                  severity: ErrorSeverity.high,
                  onPressed: () => _simulateApiError(context, 500),
                ),
              ],
            ),

            // Authentication Errors
            _buildErrorDemoSection(
              context,
              title: '🔐 Errores de Autenticación',
              description: 'Sesión expirada, credenciales incorrectas',
              buttons: [
                _DemoButton(
                  label: 'Sesión Expirada',
                  severity: ErrorSeverity.high,
                  onPressed: () =>
                      _simulateAuthError(context, 'SESSION_EXPIRED'),
                ),
                _DemoButton(
                  label: 'No Autorizado',
                  severity: ErrorSeverity.high,
                  onPressed: () => _simulateAuthError(context, 'UNAUTHORIZED'),
                ),
                _DemoButton(
                  label: 'Credenciales Incorrectas',
                  severity: ErrorSeverity.medium,
                  onPressed: () =>
                      _simulateAuthError(context, 'INVALID_CREDENTIALS'),
                ),
              ],
            ),

            // API Errors
            _buildErrorDemoSection(
              context,
              title: '🌐 Errores de API',
              description: 'Rate limiting, no encontrado, solicitud incorrecta',
              buttons: [
                _DemoButton(
                  label: 'Rate Limit (429)',
                  severity: ErrorSeverity.medium,
                  onPressed: () => _simulateApiError(context, 429),
                ),
                _DemoButton(
                  label: 'No Encontrado (404)',
                  severity: ErrorSeverity.low,
                  onPressed: () => _simulateApiError(context, 404),
                ),
                _DemoButton(
                  label: 'Bad Request (400)',
                  severity: ErrorSeverity.medium,
                  onPressed: () => _simulateApiError(context, 400),
                ),
              ],
            ),

            // Validation Errors
            _buildErrorDemoSection(
              context,
              title: '📝 Errores de Validación',
              description: 'Campos requeridos, formato incorrecto',
              buttons: [
                _DemoButton(
                  label: 'Campo Requerido',
                  severity: ErrorSeverity.low,
                  onPressed: () =>
                      _simulateValidationError(context, 'email', 'REQUIRED'),
                ),
                _DemoButton(
                  label: 'Formato Inválido',
                  severity: ErrorSeverity.low,
                  onPressed: () =>
                      _simulateValidationError(context, 'email', 'INVALID'),
                ),
              ],
            ),

            // Storage Errors
            _buildErrorDemoSection(
              context,
              title: '💾 Errores de Almacenamiento',
              description: 'Problemas de espacio, permisos, acceso a archivos',
              buttons: [
                _DemoButton(
                  label: 'Sin Espacio',
                  severity: ErrorSeverity.medium,
                  onPressed: () => _simulateStorageError(context),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Footer con info técnica
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚡ Características del Sistema:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Mensajes user-friendly automáticos'),
                    const Text('• Acciones específicas por contexto'),
                    const Text('• Retry automático con backoff'),
                    const Text('• Reporting automático a analytics'),
                    const Text('• Contexto operacional inteligente'),
                    const Text('• Severidad adaptiva (low → critical)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorDemoSection(
    BuildContext context, {
    required String title,
    required String description,
    required List<_DemoButton> buttons,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: buttons
                  .map((button) => _buildDemoButton(context, button))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoButton(BuildContext context, _DemoButton button) {
    Color color;
    IconData icon;

    switch (button.severity) {
      case ErrorSeverity.low:
        color = Theme.of(context).colorScheme.primary;
        icon = Icons.info_outline;
        break;
      case ErrorSeverity.medium:
        color = Colors.orange;
        icon = Icons.warning_amber_outlined;
        break;
      case ErrorSeverity.high:
        color = Theme.of(context).colorScheme.error;
        icon = Icons.error_outline;
        break;
      case ErrorSeverity.critical:
        color = Colors.red.shade800;
        icon = Icons.dangerous_outlined;
        break;
    }

    return OutlinedButton.icon(
      onPressed: button.onPressed,
      icon: Icon(icon, size: 16),
      label: Text(button.label),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        foregroundColor: color,
      ),
    );
  }

  // Simulaciones de errores para demostración

  Future<void> _simulateNetworkError(BuildContext context, String code) async {
    final handler = CentralizedErrorHandler();
    final error = NetworkException('Network simulation error', code);

    final userError = await handler.processError(
      error,
      StackTrace.current,
      context: OperationContext.network,
      retryCallback: () => _showSuccessSnack(context, 'Reintentar clicked!'),
    );

    if (context.mounted) {
      context.showUserError(userError);
    }
  }

  Future<void> _simulateAuthError(BuildContext context, String code) async {
    final handler = CentralizedErrorHandler();
    final error = AuthException('Auth simulation error', code);

    final userError = await handler.processError(
      error,
      StackTrace.current,
      context: OperationContext.authentication,
    );

    if (context.mounted) {
      context.showUserError(userError);
    }
  }

  Future<void> _simulateApiError(BuildContext context, int statusCode) async {
    final handler = CentralizedErrorHandler();
    final error = ApiException('API simulation error', 'API_ERROR', statusCode);

    final userError = await handler.processError(
      error,
      StackTrace.current,
      context: OperationContext.dataLoading,
      retryCallback: statusCode == 429
          ? () => _showSuccessSnack(context, 'Esperando y reintentando...')
          : () => _showSuccessSnack(context, 'Reintentando operación...'),
    );

    if (context.mounted) {
      context.showUserError(userError);
    }
  }

  Future<void> _simulateValidationError(
      BuildContext context, String field, String code) async {
    final handler = CentralizedErrorHandler();
    final error = ValidationException('Field validation failed', code, field);

    final userError = await handler.processError(
      error,
      StackTrace.current,
      context: OperationContext.userAction,
    );

    if (context.mounted) {
      context.showUserError(userError);
    }
  }

  Future<void> _simulateStorageError(BuildContext context) async {
    final handler = CentralizedErrorHandler();
    final error = Exception('Insufficient storage space available');

    final userError = await handler.processError(
      error,
      StackTrace.current,
      context: OperationContext.storage,
      retryCallback: () =>
          _showSuccessSnack(context, 'Limpiando caché y reintentando...'),
    );

    if (context.mounted) {
      context.showUserError(userError);
    }
  }

  void _showSuccessSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _DemoButton {
  const _DemoButton({
    required this.label,
    required this.severity,
    required this.onPressed,
  });

  final String label;
  final ErrorSeverity severity;
  final VoidCallback onPressed;
}
