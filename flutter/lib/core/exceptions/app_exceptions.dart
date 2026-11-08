/// Custom exceptions for the application
abstract class AppException implements Exception {
  const AppException(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  String toString() =>
      'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Network related exceptions
class NetworkException extends AppException {
  const NetworkException(super.message, [super.code]);

  factory NetworkException.noConnection() {
    return const NetworkException(
        'No internet connection available', 'NO_CONNECTION');
  }

  factory NetworkException.timeout() {
    return const NetworkException('Request timeout', 'TIMEOUT');
  }

  factory NetworkException.serverError([String? message]) {
    return NetworkException(message ?? 'Server error occurred', 'SERVER_ERROR');
  }
}

/// Authentication related exceptions
class AuthException extends AppException {
  const AuthException(super.message, [super.code]);

  factory AuthException.unauthorized() {
    return const AuthException('User is not authorized', 'UNAUTHORIZED');
  }

  factory AuthException.sessionExpired() {
    return const AuthException('Session has expired', 'SESSION_EXPIRED');
  }

  factory AuthException.invalidCredentials() {
    return const AuthException(
        'Invalid credentials provided', 'INVALID_CREDENTIALS');
  }
}

/// Data related exceptions
class DataException extends AppException {
  const DataException(super.message, [super.code]);

  factory DataException.notFound([String? resource]) {
    return DataException(
      resource != null ? '$resource not found' : 'Resource not found',
      'NOT_FOUND',
    );
  }

  factory DataException.invalidFormat([String? details]) {
    return DataException(
      details != null ? 'Invalid data format: $details' : 'Invalid data format',
      'INVALID_FORMAT',
    );
  }

  factory DataException.corruptedData() {
    return const DataException(
        'Data is corrupted or incomplete', 'CORRUPTED_DATA');
  }
}

/// Storage related exceptions
class StorageException extends AppException {
  const StorageException(super.message, [super.code]);

  factory StorageException.insufficientSpace() {
    return const StorageException(
        'Insufficient storage space', 'INSUFFICIENT_SPACE');
  }

  factory StorageException.accessDenied() {
    return const StorageException('Storage access denied', 'ACCESS_DENIED');
  }

  factory StorageException.writeError() {
    return const StorageException('Failed to write to storage', 'WRITE_ERROR');
  }

  factory StorageException.readError() {
    return const StorageException('Failed to read from storage', 'READ_ERROR');
  }
}

/// Cache related exceptions
class CacheException extends AppException {
  const CacheException(super.message, [super.code]);

  factory CacheException.expired() {
    return const CacheException('Cache has expired', 'CACHE_EXPIRED');
  }

  factory CacheException.invalidKey() {
    return const CacheException('Invalid cache key', 'INVALID_KEY');
  }

  factory CacheException.clearFailed() {
    return const CacheException('Failed to clear cache', 'CLEAR_FAILED');
  }
}

/// Validation related exceptions
class ValidationException extends AppException {
  const ValidationException(super.message, [super.code, this.field]);

  factory ValidationException.required(String field) {
    return ValidationException('$field is required', 'REQUIRED', field);
  }

  factory ValidationException.invalid(String field, [String? reason]) {
    final message =
        reason != null ? '$field is invalid: $reason' : '$field is invalid';
    return ValidationException(message, 'INVALID', field);
  }

  factory ValidationException.tooShort(String field, int minLength) {
    return ValidationException(
      '$field must be at least $minLength characters',
      'TOO_SHORT',
      field,
    );
  }

  factory ValidationException.tooLong(String field, int maxLength) {
    return ValidationException(
      '$field must be no more than $maxLength characters',
      'TOO_LONG',
      field,
    );
  }

  final String? field;

  @override
  String toString() {
    return 'ValidationException: $message${code != null ? ' (Code: $code)' : ''}${field != null ? ' (Field: $field)' : ''}';
  }
}

/// API related exceptions
class ApiException extends AppException {
  const ApiException(super.message, [super.code, this.statusCode]);

  factory ApiException.badRequest([String? message]) {
    return ApiException(message ?? 'Bad request', 'BAD_REQUEST', 400);
  }

  factory ApiException.notFound([String? resource]) {
    return ApiException(
      resource != null ? '$resource not found' : 'Resource not found',
      'NOT_FOUND',
      404,
    );
  }

  factory ApiException.serverError([String? message]) {
    return ApiException(
        message ?? 'Internal server error', 'SERVER_ERROR', 500);
  }

  factory ApiException.rateLimited() {
    return const ApiException('Rate limit exceeded', 'RATE_LIMITED', 429);
  }

  final int? statusCode;

  @override
  String toString() {
    return 'ApiException: $message${code != null ? ' (Code: $code)' : ''}${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}

/// Gamification related exceptions
class GamificationException extends AppException {
  const GamificationException(super.message, [super.code]);

  factory GamificationException.achievementNotFound() {
    return const GamificationException(
        'Achievement not found', 'ACHIEVEMENT_NOT_FOUND');
  }

  factory GamificationException.alreadyUnlocked() {
    return const GamificationException(
        'Achievement already unlocked', 'ALREADY_UNLOCKED');
  }

  factory GamificationException.insufficientProgress() {
    return const GamificationException(
        'Insufficient progress to unlock', 'INSUFFICIENT_PROGRESS');
  }

  factory GamificationException.invalidLevel() {
    return const GamificationException(
        'Invalid level specified', 'INVALID_LEVEL');
  }

  factory GamificationException.challengeNotFound() {
    return const GamificationException(
        'Challenge not found', 'CHALLENGE_NOT_FOUND');
  }

  factory GamificationException.challengeExpired() {
    return const GamificationException(
        'Challenge has expired', 'CHALLENGE_EXPIRED');
  }

  factory GamificationException.challengeAlreadyCompleted() {
    return const GamificationException(
        'Challenge already completed', 'CHALLENGE_COMPLETED');
  }
}

/// Movie related exceptions
class MovieException extends AppException {
  const MovieException(super.message, [super.code]);

  factory MovieException.notFound() {
    return const MovieException('Movie not found', 'MOVIE_NOT_FOUND');
  }

  factory MovieException.alreadyInWatchlist() {
    return const MovieException(
        'Movie already in watchlist', 'ALREADY_IN_WATCHLIST');
  }

  factory MovieException.notInWatchlist() {
    return const MovieException('Movie not in watchlist', 'NOT_IN_WATCHLIST');
  }

  factory MovieException.invalidRating() {
    return const MovieException('Invalid rating value', 'INVALID_RATING');
  }
}
