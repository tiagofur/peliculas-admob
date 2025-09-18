import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/logging/logger_factory.dart';
import '../api_keys.dart';

class Environment {
  // Eliminar propiedades estáticas con valores por defecto peligrosos
  
  // En su lugar, usar la nueva clase ApiKeys que maneja todo de forma segura
  static String get theMovieDbKey => ApiKeys.tmdbApiKey;
  static String get traktClientId => ApiKeys.traktClientId;
  static String get traktClientSecret => ApiKeys.traktClientSecret;
  
  // Método mejorado de carga que usa la nueva estructura
  static Future<void> load() async {
    try {
      // Cargar .env para todas las plataformas (no solo móviles)
      await dotenv.load(fileName: '.env');
      
      if (kDebugMode) {
        LoggerFactory.info('Environment loaded from .env file');
      }
      
      // Validar que todas las claves estén configuradas
      ApiKeys.validateConfiguration();
      
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.warning('Could not load .env file: $e');
        LoggerFactory.info('Will try to use dart-define values');
      }
      
      // Intentar validar usando dart-define
      try {
        ApiKeys.validateConfiguration();
        if (kDebugMode) {
          LoggerFactory.info('Using dart-define configuration');
        }
      } catch (configError) {
        LoggerFactory.error('Configuration error: $configError');
        
        if (kDebugMode) {
          LoggerFactory.error('''
❌ API Keys not configured properly!

Please set your API keys using ONE of these methods:

1. Create a .env file in the root directory:
   TMDB_API_KEY=your_tmdb_key_here
   TRAKT_API_KEY=your_trakt_key_here
   TRAKT_CLIENT_ID=your_trakt_client_id_here
   TRAKT_CLIENT_SECRET=your_trakt_secret_here

2. Use dart-define when running:
   flutter run --dart-define=TMDB_API_KEY=your_key_here

3. Set environment variables in your IDE run configuration.

Copy .env.example to .env and fill in your real keys.
''');
        }
        
        rethrow;
      }
    }
  }

  // Método helper para validar configuración en tests
  static bool isConfigured() {
    try {
      ApiKeys.validateConfiguration();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Método para obtener información de configuración (sin exponer claves)
  static Map<String, dynamic> getConfigurationStatus() {
    try {
      final tmdbConfigured = ApiKeys.tmdbApiKey.isNotEmpty;
      final traktConfigured = ApiKeys.traktApiKey.isNotEmpty;
      final traktIdConfigured = ApiKeys.traktClientId.isNotEmpty;
      final traktSecretConfigured = ApiKeys.traktClientSecret.isNotEmpty;
      
      return {
        'tmdb_configured': tmdbConfigured,
        'trakt_configured': traktConfigured,
        'trakt_id_configured': traktIdConfigured,
        'trakt_secret_configured': traktSecretConfigured,
        'all_configured': tmdbConfigured && traktConfigured && traktIdConfigured && traktSecretConfigured,
      };
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
        'all_configured': false,
      };
    }
  }
}
