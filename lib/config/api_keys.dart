import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/logging/logger_factory.dart';

// Archivo de configuración de claves API
// TODAS las claves se cargan desde variables de entorno o dart-define
// NO HAY CLAVES HARDCODEADAS por seguridad

class ApiKeys {
  // TMDB API Key - solo desde variables de entorno
  static String get tmdbApiKey {
    // Prioridad: dart-define > .env > error
    const dartDefineKey = String.fromEnvironment('TMDB_API_KEY');
    if (dartDefineKey.isNotEmpty) return dartDefineKey;

    final envKey = dotenv.env['TMDB_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) return envKey;

    throw const ConfigurationException(
        'TMDB_API_KEY not configured. Set via dart-define or .env file');
  }

  // Trakt.tv API Keys - solo desde variables de entorno
  static String get traktApiKey {
    const dartDefineKey = String.fromEnvironment('TRAKT_API_KEY');
    if (dartDefineKey.isNotEmpty) return dartDefineKey;

    final envKey = dotenv.env['TRAKT_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) return envKey;

    throw const ConfigurationException(
        'TRAKT_API_KEY not configured. Set via dart-define or .env file');
  }

  static String get traktClientId {
    const dartDefineKey = String.fromEnvironment('TRAKT_CLIENT_ID');
    if (dartDefineKey.isNotEmpty) return dartDefineKey;

    final envKey = dotenv.env['TRAKT_CLIENT_ID'];
    if (envKey != null && envKey.isNotEmpty) return envKey;

    throw const ConfigurationException(
        'TRAKT_CLIENT_ID not configured. Set via dart-define or .env file');
  }

  static String get traktClientSecret {
    const dartDefineKey = String.fromEnvironment('TRAKT_CLIENT_SECRET');
    if (dartDefineKey.isNotEmpty) return dartDefineKey;

    final envKey = dotenv.env['TRAKT_CLIENT_SECRET'];
    if (envKey != null && envKey.isNotEmpty) return envKey;

    throw const ConfigurationException(
        'TRAKT_CLIENT_SECRET not configured. Set via dart-define or .env file');
  }

  // Supabase Keys (si están configuradas)
  static String get supabaseUrl {
    const dartDefineKey = String.fromEnvironment('SUPABASE_URL');
    if (dartDefineKey.isNotEmpty) return dartDefineKey;

    final envKey = dotenv.env['SUPABASE_URL'];
    if (envKey != null && envKey.isNotEmpty) return envKey;

    throw const ConfigurationException(
        'SUPABASE_URL not configured. Set via dart-define or .env file');
  }

  static String get supabaseAnonKey {
    const dartDefineKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (dartDefineKey.isNotEmpty) return dartDefineKey;

    final envKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (envKey != null && envKey.isNotEmpty) return envKey;

    throw const ConfigurationException(
        'SUPABASE_ANON_KEY not configured. Set via dart-define or .env file');
  }

  // Validación de todas las claves en startup
  static void validateConfiguration() {
    if (kDebugMode) {
      LoggerFactory.info('🔑 Validating API configuration...');
    }

    try {
      final tmdb = tmdbApiKey;
      final trakt = traktApiKey;
      final traktId = traktClientId;
      final traktSecret = traktClientSecret;

      if (kDebugMode) {
        LoggerFactory.info('✅ TMDB API Key: ${tmdb.substring(0, 8)}...');
        LoggerFactory.info('✅ Trakt API Key: ${trakt.substring(0, 8)}...');
        LoggerFactory.info('✅ Trakt Client ID: ${traktId.substring(0, 8)}...');
        LoggerFactory.info('✅ Trakt Secret: ${traktSecret.substring(0, 8)}...');
      }

      // Opcional: validar Supabase si está presente
      try {
        final supaUrl = supabaseUrl;
        final supaKey = supabaseAnonKey;
        if (kDebugMode) {
          LoggerFactory.info('✅ Supabase URL: ${supaUrl.substring(0, 20)}...');
          LoggerFactory.info('✅ Supabase Key: ${supaKey.substring(0, 8)}...');
        }
      } catch (e) {
        if (kDebugMode) {
          LoggerFactory.warning('⚠️  Supabase not configured (optional)');
        }
      }

      if (kDebugMode) {
        LoggerFactory.info('✅ All required API keys configured successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ API configuration error: $e');
      }
      rethrow;
    }
  }
}

// Excepción personalizada para errores de configuración
class ConfigurationException implements Exception {
  const ConfigurationException(this.message);
  final String message;

  @override
  String toString() => 'ConfigurationException: $message';
}

// URLs base
class ApiUrls {
  static const String traktBase = 'https://api.trakt.tv';
  static const String tmdbBase = 'https://api.themoviedb.org/3';
  static const String tmdbImageBase = 'https://image.tmdb.org/t/p/w500';
}
