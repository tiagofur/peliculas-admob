import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';

/// Helper class for centralized error handling and user feedback
///
/// This class provides:
/// - Consistent error message display across the app
/// - Integration with app localization system
/// - Different types of user feedback (error, success, info)
/// - Retry action support
class ErrorHandlerHelper {
  /// Show an error snackbar with retry option
  static void showError(
    BuildContext context, {
    required String message,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: AppLocalizations.of(context)!.actionRetry,
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show a success snackbar
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration,
      ),
    );
  }

  /// Show an info snackbar
  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: duration,
      ),
    );
  }

  /// Show a warning snackbar
  static void showWarning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: duration,
      ),
    );
  }

  /// Show network error with automatic message
  static void showNetworkError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    showError(
      context,
      message: AppLocalizations.of(context)!.errorNetworkError,
      onRetry: onRetry,
    );
  }

  /// Show server error with automatic message
  static void showServerError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    showError(
      context,
      message: AppLocalizations.of(context)!.errorServerError,
      onRetry: onRetry,
    );
  }

  /// Show timeout error with automatic message
  static void showTimeoutError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    showError(
      context,
      message: AppLocalizations.of(context)!.errorTimeout,
      onRetry: onRetry,
    );
  }

  /// Show generic error with automatic message
  static void showGenericError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    showError(
      context,
      message: AppLocalizations.of(context)!.errorGeneric,
      onRetry: onRetry,
    );
  }

  /// Show movie load failed error
  static void showMovieLoadError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    showError(
      context,
      message: AppLocalizations.of(context)!.errorMovieLoadFailed,
      onRetry: onRetry,
    );
  }

  /// Show list load failed error
  static void showListLoadError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    showError(
      context,
      message: AppLocalizations.of(context)!.errorListLoadFailed,
      onRetry: onRetry,
    );
  }

  /// Show login required error
  static void showLoginRequired(BuildContext context) {
    showWarning(
      context,
      message: AppLocalizations.of(context)!.errorLoginRequired,
    );
  }

  /// Show login success
  static void showLoginSuccess(BuildContext context) {
    showSuccess(
      context,
      message: AppLocalizations.of(context)!.successLoginComplete,
    );
  }

  /// Show logout success
  static void showLogoutSuccess(BuildContext context) {
    showSuccess(
      context,
      message: AppLocalizations.of(context)!.successLogoutComplete,
    );
  }

  /// Show account created success
  static void showAccountCreated(BuildContext context) {
    showSuccess(
      context,
      message: AppLocalizations.of(context)!.successAccountCreated,
    );
  }

  /// Show vote registered success
  static void showVoteSuccess(BuildContext context) {
    showSuccess(
      context,
      message: AppLocalizations.of(context)!.successVoteRegistered,
    );
  }

  /// Helper to determine error type from exception and show appropriate message
  static void handleException(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      showNetworkError(context, onRetry: onRetry);
    } else if (errorString.contains('timeout')) {
      showTimeoutError(context, onRetry: onRetry);
    } else if (errorString.contains('server') ||
        errorString.contains('500') ||
        errorString.contains('503')) {
      showServerError(context, onRetry: onRetry);
    } else {
      showGenericError(context, onRetry: onRetry);
    }
  }
}
