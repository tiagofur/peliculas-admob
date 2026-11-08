import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'logger_factory.dart';

/// Utility class to safely handle developer.log calls and prevent
/// "Cannot send Null" errors in Flutter's debug service
class SafeDeveloperLog {
  /// Safely call developer.log with null-safe parameters
  static void log(
    String message, {
    String? name,
    int? level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;

    try {
      // Clean the message to ensure it's not null and properly formatted
      final safeMessage = message.isEmpty ? 'Empty log message' : message;
      final safeName = name ?? 'App';

      // Only pass error and stackTrace if they are not null to prevent "Cannot send Null" errors
      if (error != null && stackTrace != null) {
        developer.log(
          safeMessage,
          name: safeName,
          level: level ?? 0,
          error: _sanitizeError(error),
          stackTrace: stackTrace,
        );
      } else if (error != null) {
        developer.log(
          safeMessage,
          name: safeName,
          level: level ?? 0,
          error: _sanitizeError(error),
        );
      } else {
        developer.log(
          safeMessage,
          name: safeName,
          level: level ?? 0,
        );
      }
    } catch (e) {
      // Fallback to LoggerFactory if developer.log fails
      LoggerFactory.error(
          'SafeDeveloperLog error: $e. Original message: $message');
    }
  }

  /// Sanitize error objects to prevent serialization issues
  static Object _sanitizeError(Object error) {
    if (error is Map) {
      // Convert map to string to avoid serialization issues with complex objects
      try {
        final cleanMap = <String, dynamic>{};
        error.forEach((key, value) {
          if (key != null && value != null) {
            cleanMap[key.toString()] = value.toString();
          }
        });
        return cleanMap.isEmpty ? error.toString() : cleanMap;
      } catch (e) {
        return error.toString();
      }
    }

    // For other types, convert to string to be safe
    return error.toString();
  }
}
