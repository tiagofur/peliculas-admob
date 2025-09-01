import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/logger_factory.dart';

/// Configuration service for error reporting settings
class ErrorReportingConfig {
  static ErrorReportingConfig? _instance;
  static ErrorReportingConfig get instance => _instance ??= ErrorReportingConfig._();
  
  ErrorReportingConfig._();

  static const String _errorReportingEnabledKey = 'error_reporting_enabled';
  static const String _errorReportingUserOptInKey = 'error_reporting_user_opt_in';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Initialize the configuration service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      
      LoggerFactory.info('✅ Error reporting config initialized');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize error reporting config: $e');
    }
  }

  /// Get whether error reporting is enabled based on environment and user preference
  bool get isEnabled {
    if (!_isInitialized || _prefs == null) {
      // Default behavior when not initialized
      return !kDebugMode; // Disabled in debug, enabled in release by default
    }

    // In debug mode, respect explicit setting only
    if (kDebugMode) {
      return _prefs!.getBool(_errorReportingEnabledKey) ?? false;
    }

    // In release mode, check user opt-in (default to true if not set)
    final userOptIn = _prefs!.getBool(_errorReportingUserOptInKey) ?? true;
    final configEnabled = _prefs!.getBool(_errorReportingEnabledKey) ?? true;
    
    return userOptIn && configEnabled;
  }

  /// Set whether error reporting is enabled (admin/config setting)
  Future<void> setEnabled(bool enabled) async {
    if (!_isInitialized || _prefs == null) return;

    try {
      await _prefs!.setBool(_errorReportingEnabledKey, enabled);
      LoggerFactory.info('Error reporting config enabled: $enabled');
    } catch (e) {
      LoggerFactory.error('Failed to set error reporting enabled: $e');
    }
  }

  /// Set user opt-in for error reporting (user preference)
  Future<void> setUserOptIn(bool optIn) async {
    if (!_isInitialized || _prefs == null) return;

    try {
      await _prefs!.setBool(_errorReportingUserOptInKey, optIn);
      LoggerFactory.info('Error reporting user opt-in: $optIn');
    } catch (e) {
      LoggerFactory.error('Failed to set error reporting user opt-in: $e');
    }
  }

  /// Get user opt-in preference
  bool get userOptIn {
    if (!_isInitialized || _prefs == null) {
      return true; // Default to opted in
    }
    return _prefs!.getBool(_errorReportingUserOptInKey) ?? true;
  }

  /// Get admin/config enabled setting
  bool get configEnabled {
    if (!_isInitialized || _prefs == null) {
      return !kDebugMode; // Default based on build mode
    }
    return _prefs!.getBool(_errorReportingEnabledKey) ?? !kDebugMode;
  }

  /// Reset all error reporting preferences to defaults
  Future<void> reset() async {
    if (!_isInitialized || _prefs == null) return;

    try {
      await _prefs!.remove(_errorReportingEnabledKey);
      await _prefs!.remove(_errorReportingUserOptInKey);
      LoggerFactory.info('Error reporting config reset to defaults');
    } catch (e) {
      LoggerFactory.error('Failed to reset error reporting config: $e');
    }
  }

  /// Get current configuration as a map for debugging
  Map<String, dynamic> get currentConfig {
    if (!_isInitialized || _prefs == null) {
      return {
        'initialized': false,
        'isEnabled': !kDebugMode,
        'buildMode': kDebugMode ? 'debug' : 'release',
      };
    }

    return {
      'initialized': true,
      'isEnabled': isEnabled,
      'userOptIn': userOptIn,
      'configEnabled': configEnabled,
      'buildMode': kDebugMode ? 'debug' : 'release',
    };
  }
}