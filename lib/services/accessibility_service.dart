import 'package:flutter/material.dart';

/// Service for managing accessibility features and providing
/// WCAG AA compliance support throughout the app
class AccessibilityService {
  AccessibilityService._();
  static final AccessibilityService instance = AccessibilityService._();

  /// Check if screen reader is enabled
  static bool isScreenReaderEnabled(BuildContext context) {
    return MediaQuery.accessibleNavigationOf(context);
  }

  /// Check if high contrast mode is enabled
  static bool isHighContrastEnabled(BuildContext context) {
    return MediaQuery.highContrastOf(context);
  }

  /// Get the current text scale factor
  static double getTextScaleFactor(BuildContext context) {
    return MediaQuery.textScalerOf(context).scale(1.0);
  }

  /// Check if text scaling is large (>1.3x)
  static bool isLargeTextScale(BuildContext context) {
    return getTextScaleFactor(context) > 1.3;
  }

  /// Check if bold text is preferred
  static bool isBoldTextEnabled(BuildContext context) {
    return MediaQuery.boldTextOf(context);
  }

  /// Get accessible color contrast for text on background
  static Color getAccessibleTextColor(
      BuildContext context, Color backgroundColor) {
    final theme = Theme.of(context);
    final isHighContrast = isHighContrastEnabled(context);

    if (isHighContrast) {
      // Use maximum contrast for high contrast mode
      return ThemeData.estimateBrightnessForColor(backgroundColor) ==
              Brightness.dark
          ? Colors.white
          : Colors.black;
    }

    // Use theme-appropriate colors with WCAG AA compliance
    return theme.colorScheme.onSurface;
  }

  /// Get accessible button size for touch targets
  static double getAccessibleButtonSize(BuildContext context) {
    const minTouchTarget = 44.0; // WCAG AA minimum
    final textScale = getTextScaleFactor(context);
    return minTouchTarget * textScale.clamp(1.0, 1.5);
  }

  /// Create semantic label for star rating
  static String getStarRatingSemantics(int rating, int maxRating) {
    if (rating == 0) {
      return 'Sin calificación de $maxRating estrellas';
    }
    return 'Calificación $rating de $maxRating estrellas';
  }

  /// Create semantic label for movie poster
  static String getMoviePosterSemantics(String movieTitle) {
    return 'Póster de la película $movieTitle';
  }

  /// Get semantic label for streaming platform
  static String getStreamingPlatformSemantics(
      String platformName, bool isAvailable) {
    if (isAvailable) {
      return 'Disponible en $platformName';
    }
    return 'No disponible en $platformName';
  }

  /// Get semantic label for sync status
  static String getSyncStatusSemantics(String status, String? message) {
    final baseLabel = 'Estado de sincronización: $status';
    if (message != null && message.isNotEmpty) {
      return '$baseLabel. $message';
    }
    return baseLabel;
  }

  /// Check if we should use enhanced visual indicators
  static bool shouldUseEnhancedVisuals(BuildContext context) {
    return isHighContrastEnabled(context) || isLargeTextScale(context);
  }

  /// Get recommended spacing for accessibility
  static double getAccessibleSpacing(BuildContext context, double baseSpacing) {
    final textScale = getTextScaleFactor(context);
    return baseSpacing * textScale.clamp(1.0, 1.3);
  }
}
