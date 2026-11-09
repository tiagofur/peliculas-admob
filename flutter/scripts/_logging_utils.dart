/// Simple logging utilities for scripts
/// This suppresses avoid_print warnings while maintaining console output functionality
library;

import 'dart:io';

/// Output informational message to console
void logInfo(String message) {
  stdout.writeln(message);
}

/// Output error message to console
void logError(String message) {
  stderr.writeln('ERROR: $message');
}

/// Output warning message to console
void logWarning(String message) {
  stderr.writeln('WARNING: $message');
}

/// Output success message to console
void logSuccess(String message) {
  stdout.writeln('✅ $message');
}
