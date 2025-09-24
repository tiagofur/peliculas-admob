import 'package:flutter/material.dart';

import '../../core/error_handling/centralized_error_handler.dart';

/// Widget para mostrar errores de manera user-friendly
class UserFriendlyErrorWidget extends StatelessWidget {
  const UserFriendlyErrorWidget({
    super.key,
    required this.error,
    this.compact = false,
    this.showIcon = true,
  });

  final UserFriendlyError error;
  final bool compact;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactError(context);
    }
    return _buildFullError(context);
  }

  Widget _buildCompactError(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getErrorColor(colorScheme).withValues(alpha: 0.1),
        border: Border(
          left: BorderSide(
            color: _getErrorColor(colorScheme),
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (showIcon) ...[
            Icon(
              _getErrorIcon(),
              color: _getErrorColor(colorScheme),
              size: 20,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _getErrorColor(colorScheme),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (error.primaryAction != null) ...[
            const SizedBox(width: 12),
            _buildActionButton(context, error.primaryAction!, true),
          ],
        ],
      ),
    );
  }

  Widget _buildFullError(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getErrorColor(colorScheme).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _getErrorColor(colorScheme).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              _getErrorIcon(),
              size: 48,
              color: _getErrorColor(colorScheme),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            error.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: _getErrorColor(colorScheme),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            error.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final actions = [
      if (error.primaryAction != null) error.primaryAction!,
      if (error.secondaryAction != null) error.secondaryAction!,
    ];

    if (actions.isEmpty && error.retryCallback == null) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        // Retry button (implicit if retryCallback is provided)
        if (error.retryCallback != null && error.primaryAction == null)
          _buildActionButton(
            context,
            ErrorAction(
              label: 'Reintentar',
              callback: error.retryCallback!,
            ),
            true,
          ),

        // Explicit actions
        ...actions.map((action) =>
            _buildActionButton(context, action, action == error.primaryAction)),
      ],
    );
  }

  Widget _buildActionButton(
      BuildContext context, ErrorAction action, bool isPrimary) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isPrimary) {
      return FilledButton(
        onPressed: action.callback,
        style: FilledButton.styleFrom(
          backgroundColor: action.isDestructive
              ? colorScheme.error
              : _getErrorColor(colorScheme),
          foregroundColor:
              action.isDestructive ? colorScheme.onError : Colors.white,
        ),
        child: Text(action.label),
      );
    }

    return OutlinedButton(
      onPressed: action.callback,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: action.isDestructive
              ? colorScheme.error
              : _getErrorColor(colorScheme),
        ),
        foregroundColor: action.isDestructive
            ? colorScheme.error
            : _getErrorColor(colorScheme),
      ),
      child: Text(action.label),
    );
  }

  Color _getErrorColor(ColorScheme colorScheme) {
    switch (error.severity) {
      case ErrorSeverity.low:
        return colorScheme.primary;
      case ErrorSeverity.medium:
        return Colors.orange;
      case ErrorSeverity.high:
        return colorScheme.error;
      case ErrorSeverity.critical:
        return Colors.red.shade800;
    }
  }

  IconData _getErrorIcon() {
    switch (error.severity) {
      case ErrorSeverity.low:
        return Icons.info_outline;
      case ErrorSeverity.medium:
        return Icons.warning_amber_outlined;
      case ErrorSeverity.high:
        return Icons.error_outline;
      case ErrorSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }
}

/// Dialog para mostrar errores críticos
class ErrorDialog extends StatelessWidget {
  const ErrorDialog({
    super.key,
    required this.error,
    this.dismissible = true,
  });

  final UserFriendlyError error;
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        _getErrorIcon(),
        size: 40,
        color: _getErrorColor(Theme.of(context).colorScheme),
      ),
      title: Text(
        error.title,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _getErrorColor(Theme.of(context).colorScheme),
        ),
      ),
      content: Text(
        error.message,
        textAlign: TextAlign.center,
      ),
      actions: _buildDialogActions(context),
    );
  }

  List<Widget> _buildDialogActions(BuildContext context) {
    final actions = <Widget>[];

    // Close button (always available if dismissible)
    if (dismissible) {
      actions.add(
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      );
    }

    // Secondary action
    if (error.secondaryAction != null) {
      actions.add(
        TextButton(
          onPressed: () {
            error.secondaryAction!.callback();
            if (dismissible) Navigator.of(context).pop();
          },
          child: Text(error.secondaryAction!.label),
        ),
      );
    }

    // Primary action or retry
    final primaryAction = error.primaryAction ??
        (error.retryCallback != null
            ? ErrorAction(label: 'Reintentar', callback: error.retryCallback!)
            : null);

    if (primaryAction != null) {
      actions.add(
        FilledButton(
          onPressed: () {
            primaryAction.callback();
            if (dismissible) Navigator.of(context).pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: primaryAction.isDestructive
                ? Theme.of(context).colorScheme.error
                : _getErrorColor(Theme.of(context).colorScheme),
          ),
          child: Text(primaryAction.label),
        ),
      );
    }

    return actions;
  }

  Color _getErrorColor(ColorScheme colorScheme) {
    switch (error.severity) {
      case ErrorSeverity.low:
        return colorScheme.primary;
      case ErrorSeverity.medium:
        return Colors.orange;
      case ErrorSeverity.high:
        return colorScheme.error;
      case ErrorSeverity.critical:
        return Colors.red.shade800;
    }
  }

  IconData _getErrorIcon() {
    switch (error.severity) {
      case ErrorSeverity.low:
        return Icons.info_outline;
      case ErrorSeverity.medium:
        return Icons.warning_amber_outlined;
      case ErrorSeverity.high:
        return Icons.error_outline;
      case ErrorSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }

  /// Muestra el dialog de error
  static Future<void> show(BuildContext context, UserFriendlyError error) {
    return showDialog(
      context: context,
      barrierDismissible: error.severity != ErrorSeverity.critical,
      builder: (context) => ErrorDialog(
        error: error,
        dismissible: error.severity != ErrorSeverity.critical,
      ),
    );
  }
}

/// SnackBar para mostrar errores no críticos
class ErrorSnackBar {
  static void show(BuildContext context, UserFriendlyError error) {
    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getErrorIcon(error.severity),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (error.message.isNotEmpty)
                    Text(
                      error.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _getErrorColor(colorScheme, error.severity),
        duration: _getDuration(error.severity),
        action: error.primaryAction != null || error.retryCallback != null
            ? SnackBarAction(
                label: error.primaryAction?.label ?? 'Reintentar',
                textColor: Colors.white,
                onPressed: error.primaryAction?.callback ??
                    error.retryCallback ??
                    () {},
              )
            : null,
      ),
    );
  }

  static IconData _getErrorIcon(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return Icons.info_outline;
      case ErrorSeverity.medium:
        return Icons.warning_amber_outlined;
      case ErrorSeverity.high:
        return Icons.error_outline;
      case ErrorSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }

  static Color _getErrorColor(ColorScheme colorScheme, ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return colorScheme.primary;
      case ErrorSeverity.medium:
        return Colors.orange;
      case ErrorSeverity.high:
        return colorScheme.error;
      case ErrorSeverity.critical:
        return Colors.red.shade800;
    }
  }

  static Duration _getDuration(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return const Duration(seconds: 3);
      case ErrorSeverity.medium:
        return const Duration(seconds: 5);
      case ErrorSeverity.high:
        return const Duration(seconds: 7);
      case ErrorSeverity.critical:
        return const Duration(seconds: 10);
    }
  }
}

/// Widget para el estado de error en lugar de datos
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  final UserFriendlyError error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: UserFriendlyErrorWidget(
          error: error.retryCallback == null && onRetry != null
              ? UserFriendlyError(
                  title: error.title,
                  message: error.message,
                  actionable: error.actionable,
                  retryCallback: onRetry,
                  primaryAction: error.primaryAction,
                  secondaryAction: error.secondaryAction,
                  severity: error.severity,
                )
              : error,
          compact: false,
        ),
      ),
    );
  }
}

/// Extension para facilitar el uso del error handler
extension ErrorHandlerExt on BuildContext {
  /// Muestra un error usando el método más apropiado según la severidad
  void showUserError(UserFriendlyError error) {
    switch (error.severity) {
      case ErrorSeverity.low:
        ErrorSnackBar.show(this, error);
        break;
      case ErrorSeverity.medium:
        if (error.actionable) {
          ErrorDialog.show(this, error);
        } else {
          ErrorSnackBar.show(this, error);
        }
        break;
      case ErrorSeverity.high:
      case ErrorSeverity.critical:
        ErrorDialog.show(this, error);
        break;
    }
  }

  /// Shortcut para procesar y mostrar un error automáticamente
  Future<void> handleAndShowError(
    dynamic error,
    StackTrace? stackTrace, {
    OperationContext? context,
    VoidCallback? retryCallback,
  }) async {
    final handler = CentralizedErrorHandler();
    final userError = await handler.processError(
      error,
      stackTrace,
      context: context,
      retryCallback: retryCallback,
    );
    showUserError(userError);
  }
}
